import 'dart:io';

import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/cloud_save_honesty.dart';
import 'package:mayabela/services/persistence/homework_persistence_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/student_account_service.dart';
import 'package:mayabela/services/student_portal_sync_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/attachment_share_actions.dart';
import 'package:mayabela/theme/classroom_palette.dart';
import 'package:mayabela/widgets/homework_attachments_panel.dart';
import 'package:mayabela/widgets/homework_brief_ui.dart';
import 'package:mayabela/widgets/class_picker_bar.dart';

enum HomeworkViewMode { teacher, parent, student }

class HomeworkScreen extends StatefulWidget {
  const HomeworkScreen({
    super.key,
    this.mode = HomeworkViewMode.teacher,
    this.initialClass,
    this.initialChildName,
  });

  final HomeworkViewMode mode;
  final String? initialClass;
  final String? initialChildName;

  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  final _data = SchoolDataService.instance;
  final _access = TeacherAccessService.instance;
  String? _selectedClass;
  String _focus = 'all';

  bool get _isParent =>
      widget.mode == HomeworkViewMode.parent ||
      widget.mode == HomeworkViewMode.student;

  bool get _isStudent => widget.mode == HomeworkViewMode.student;

  String? get _studentId =>
      AuthService.currentUser?.linkedStudentId?.trim().toUpperCase();

  bool get _canUploadWorksheets {
    if (!_isStudent) return false;
    return StudentAccountService.instance
        .settingsForSchool(AuthService.activeSchoolId)
        .allowHomeworkUpload;
  }

  List<String> get _classOptions {
    if (_isParent) {
      return _data.homeworkClassOptionsForViewer();
    }
    return _access.myClasses.map((assignment) => assignment.className).toList();
  }

  List<HomeworkItem> get _classItems {
    if (_isParent) {
      final className = _selectedClass;
      if (className != null) {
        return _data.getHomeworkForClass(className);
      }
      return _data.getHomeworkForParent();
    }
    final className = _selectedClass ?? _classOptions.firstOrNull;
    if (className == null) return [];
    final all = _data.getHomeworkForClass(className);
    if (_access.canViewAllHomeworkInClass(className)) return all;
    return all.where((item) => item.teacherId == _access.teacherId).toList();
  }

  List<HomeworkItem> get _items {
    final all = _classItems;
    return switch (_focus) {
      'soon' => all.where((item) => item.isDueSoon).toList(),
      'overdue' => all.where((item) => item.isOverdue).toList(),
      _ => all,
    };
  }

  @override
  void initState() {
    super.initState();
    if (_classOptions.isNotEmpty) {
      _selectedClass = widget.initialClass ?? _classOptions.first;
    }
    if (!_isParent) {
      SchoolDataService.instance.publishHomeworkReminders();
    }
  }

  Future<void> _saveHomework({
    required String className,
    required String subject,
    required String description,
    required String title,
    required String taskType,
    required String learningObjective,
    required String successCriteria,
    required int? estimatedMinutes,
    required String submissionMethod,
    required String resources,
    required String supportNote,
    required String extensionNote,
    required double maxScore,
    required List<String> attachmentPaths,
    DateTime? dueDate,
    String? homeworkId,
  }) async {
    final s = AppLocale.instance.strings;
    if (description.trim().isEmpty && title.trim().isEmpty) return;
    final note = description.trim().isEmpty ? title.trim() : description.trim();

    if (homeworkId == null) {
      final slot = _access.teachingSlotFor(className, subject);
      _data.addHomework(
        className: className,
        subject: subject,
        description: note,
        teacherName: _access.teacherName,
        teacherId: _access.teacherId,
        subjectId: slot?.subjectId,
        teachingSlotId: slot?.slotId,
        dueDate: dueDate,
        attachmentPaths: attachmentPaths,
        title: title,
        taskType: taskType,
        learningObjective: learningObjective,
        successCriteria: successCriteria,
        estimatedMinutes: estimatedMinutes,
        submissionMethod: submissionMethod,
        resources: resources,
        supportNote: supportNote,
        extensionNote: extensionNote,
        maxScore: maxScore,
      );
    } else {
      _data.updateHomework(
        id: homeworkId,
        description: note,
        attachmentPaths: attachmentPaths,
        dueDate: dueDate,
        clearDueDate: dueDate == null,
        title: title,
        taskType: taskType,
        learningObjective: learningObjective,
        successCriteria: successCriteria,
        estimatedMinutes: estimatedMinutes,
        updateEstimatedMinutes: true,
        submissionMethod: submissionMethod,
        resources: resources,
        supportNote: supportNote,
        extensionNote: extensionNote,
        maxScore: maxScore,
      );
    }
    if (mounted) setState(() {});
    final outcome = await CloudSaveHonesty.settle(
      persist: HomeworkPersistenceService.instance.saveFromService(),
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      CloudSaveHonesty.snackBar(
        savedOk: homeworkId == null
            ? s.homeworkPostedForParents
            : s.homeworkUpdated,
        outcome: outcome,
        strings: s,
      ),
    );
  }

  Future<void> _showHomeworkDialog({
    required String className,
    HomeworkItem? existing,
  }) async {
    final s = AppLocale.instance.strings;
    final subjects = _access.teachableSubjects(className);
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noSubjectsAssigned)),
      );
      return;
    }

    final titleController = TextEditingController(text: existing?.title ?? '');
    final descriptionController =
        TextEditingController(text: existing?.description ?? '');
    final objectiveController =
        TextEditingController(text: existing?.learningObjective ?? '');
    final criteriaController =
        TextEditingController(text: existing?.successCriteria ?? '');
    final resourcesController = TextEditingController(text: existing?.resources ?? '');
    final supportController = TextEditingController(text: existing?.supportNote ?? '');
    final extensionController =
        TextEditingController(text: existing?.extensionNote ?? '');
    final maxScoreController = TextEditingController(
      text: (existing?.maxScore ?? 100).toStringAsFixed(0),
    );
    var subject = existing?.subject ??
        _access.defaultHomeworkSubject(className) ??
        subjects.first;
    var taskType = existing?.taskType ?? '';
    var submissionMethod = existing?.submissionMethod ?? '';
    int? estimatedMinutes = existing?.estimatedMinutes;
    var attachmentPaths = List<String>.from(existing?.attachmentPaths ?? []);
    DateTime? dueDate = existing?.dueDate;

    final saved = await showAdminFormDialog(
      context: context,
      title: existing == null ? s.postHomework : s.editHomework,
      subtitle: className,
      accent: const Color(0xFFEF6C00),
      icon: Icons.assignment_outlined,
      saveLabel: existing == null ? s.publish : s.save,
      builder: (context, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          adminDialogField(
            DropdownButtonFormField<String>(
              key: ValueKey(subject),
              initialValue: subject,
              decoration: adminFieldDecoration(
                label: s.chooseSubjectYouTeach,
                icon: Icons.menu_book_outlined,
                accent: const Color(0xFFEF6C00),
              ),
              items: subjects
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item),
                    ),
                  )
                  .toList(),
              onChanged: existing == null
                  ? (value) {
                      if (value != null) {
                        setDialogState(() => subject = value);
                      }
                    }
                  : null,
            ),
          ),
          if (existing == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                s.homeworkVisibleToParentsHint,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          HomeworkPostFields(
            title: titleController,
            instructions: descriptionController,
            objective: objectiveController,
            criteria: criteriaController,
            resources: resourcesController,
            supportNote: supportController,
            extensionNote: extensionController,
            maxScore: maxScoreController,
            taskType: taskType,
            submissionMethod: submissionMethod,
            estimatedMinutes: estimatedMinutes,
            dueDate: dueDate,
            onTaskType: (value) => setDialogState(() => taskType = value),
            onSubmission: (value) =>
                setDialogState(() => submissionMethod = value),
            onMinutes: (value) =>
                setDialogState(() => estimatedMinutes = value),
            onPickDue: () async {
              final picked = await pickHomeworkDue(context, current: dueDate);
              if (picked != null) setDialogState(() => dueDate = picked);
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await AnnouncementAttachmentService.instance
                  .pickAndSaveFiles(subdir: 'homework_attachments');
              if (picked.isEmpty) return;
              setDialogState(() {
                attachmentPaths.addAll(picked.map((a) => a.filePath));
              });
            },
            icon: const Icon(Icons.attach_file),
            label: Text(s.announcementAddAttachment),
          ),
          if (attachmentPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attachmentPaths
                  .map(
                    (path) => InputChip(
                      label: Text(
                        path.split(Platform.pathSeparator).last,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () =>
                          openAttachmentWithFeedback(context, path: path),
                      onDeleted: () {
                        setDialogState(() => attachmentPaths.remove(path));
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );

    if (saved == true) {
      await _saveHomework(
        className: className,
        subject: subject,
        description: descriptionController.text.trim(),
        title: titleController.text.trim(),
        taskType: taskType,
        learningObjective: objectiveController.text.trim(),
        successCriteria: criteriaController.text.trim(),
        estimatedMinutes: estimatedMinutes,
        submissionMethod: submissionMethod,
        resources: resourcesController.text.trim(),
        supportNote: supportController.text.trim(),
        extensionNote: extensionController.text.trim(),
        maxScore: double.tryParse(maxScoreController.text.trim()) ?? 100,
        attachmentPaths: attachmentPaths,
        dueDate: dueDate,
        homeworkId: existing?.id,
      );
    }
    titleController.dispose();
    descriptionController.dispose();
    objectiveController.dispose();
    criteriaController.dispose();
    resourcesController.dispose();
    supportController.dispose();
    extensionController.dispose();
    maxScoreController.dispose();
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '${time.day}/${time.month}/${time.year} · $hour:${time.minute.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _uploadStudentWorksheet(HomeworkItem item) async {
    final s = AppLocale.instance.strings;
    final studentId = _studentId;
    if (studentId == null || studentId.isEmpty) return;

    final picked = await AnnouncementAttachmentService.instance
        .pickAndSaveFiles(subdir: 'student_homework_worksheets');
    if (picked.isEmpty) return;

    _data.addStudentWorksheets(
      homeworkId: item.id,
      studentId: studentId,
      paths: picked.map((attachment) => attachment.filePath).toList(),
    );
    final outcome = await CloudSaveHonesty.settle(
      persist: HomeworkPersistenceService.instance.saveFromService(),
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      CloudSaveHonesty.snackBar(
        savedOk: s.worksheetUploadedSuccess,
        outcome: outcome,
        strings: s,
      ),
    );
  }

  void _removeStudentWorksheet({
    required HomeworkItem item,
    required String path,
  }) {
    final studentId = _studentId;
    if (studentId == null || studentId.isEmpty) return;
    _data.removeStudentWorksheet(
      homeworkId: item.id,
      studentId: studentId,
      path: path,
    );
    setState(() {});
  }

  Future<void> _gradeStudent(HomeworkItem item, String studentId) async {
    final scoreCtrl = TextEditingController(
      text: item.studentScores[studentId]?.toStringAsFixed(0) ?? '',
    );
    final commentCtrl = TextEditingController(
      text: item.teacherComments[studentId] ?? '',
    );
    final student = StudentRegistryService.instance.lookupAnyById(studentId);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(student?.fullName ?? studentId),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: scoreCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      'Homework score (0–${item.scoreCap.toStringAsFixed(0)})',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Teacher comment',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'push'),
            child: const Text('Save & push to markbook'),
          ),
        ],
      ),
    );
    if (saved == null) return;
    final score = double.tryParse(scoreCtrl.text.trim());
    if (score != null) {
      _data.recordHomeworkScore(
        homeworkId: item.id,
        studentId: studentId,
        score: score,
      );
    }
    if (commentCtrl.text.trim().isNotEmpty ||
        item.teacherComments.containsKey(studentId)) {
      _data.commentOnHomework(
        homeworkId: item.id,
        studentId: studentId,
        comment: commentCtrl.text,
      );
    }
    if (saved == 'push') {
      _data.pushHomeworkScoreToMarkbook(
        homeworkId: item.id,
        studentId: studentId,
      );
    }
    await HomeworkPersistenceService.instance.saveFromService();
    if (mounted) setState(() {});
  }

  Widget _teacherSubmissionInbox(HomeworkItem item) {
    final roster = StudentRegistryService.instance.studentsForClass(
      item.className,
    );
    final ids = <String>{
      ...roster.map((s) => s.studentId.trim().toUpperCase()),
      ...item.studentWorksheetPaths.keys.map((k) => k.trim().toUpperCase()),
      ...item.studentScores.keys.map((k) => k.trim().toUpperCase()),
      ...item.teacherComments.keys.map((k) => k.trim().toUpperCase()),
    };
    if (ids.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'No student submissions yet',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      );
    }
    final count = item.submittedStudentCount;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 0
                ? 'Score homework'
                : '$count student submission${count == 1 ? '' : 's'}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final studentId in ids)
            Builder(
              builder: (context) {
                final student =
                    StudentRegistryService.instance.lookupAnyById(studentId);
                final files = item.worksheetsForStudent(studentId);
                final score = item.studentScores[studentId];
                final comment = item.teacherComments[studentId];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(student?.fullName ?? studentId),
                  subtitle: Text(
                    [
                      if (score != null) 'Score ${score.toStringAsFixed(0)}',
                      if ((comment ?? '').isNotEmpty) comment,
                      if (files.isNotEmpty)
                        '${files.length} file${files.length == 1 ? '' : 's'}',
                    ].join(' · '),
                  ),
                  trailing: TextButton(
                    onPressed: () => _gradeStudent(item, studentId),
                    child: const Text('Score'),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _studentWorksheetSection(HomeworkItem item) {
    final s = AppLocale.instance.strings;
    final studentId = _studentId;
    if (studentId == null || studentId.isEmpty) {
      return const SizedBox.shrink();
    }

    final uploads = _data.studentWorksheetsFor(
      homeworkId: item.id,
      studentId: studentId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Text(
          s.myWorksheetUploads,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.grey.shade800,
          ),
        ),
        if (uploads.isNotEmpty) ...[
          const SizedBox(height: 8),
          HomeworkAttachmentsPanel(
            attachmentPaths: uploads,
            compact: true,
            allowShareDownload: true,
            onRemovePath: _canUploadWorksheets
                ? (path) => _removeStudentWorksheet(item: item, path: path)
                : null,
          ),
        ],
        if (_canUploadWorksheets) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _uploadStudentWorksheet(item),
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(s.uploadWorksheet),
          ),
        ] else if (uploads.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            s.worksheetUploadDisabled,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppLocale.instance,
        SchoolContentSyncService.instance,
        if (_isStudent) StudentPortalSyncService.instance,
      ]),
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final className = _selectedClass;
        final canPost = !_isParent &&
            className != null &&
            _access.canAddHomework(className);
        final showSubjectHint = !_isParent &&
            className != null &&
            !_access.canViewAllHomeworkInClass(className);

        final accent = _isParent ? const Color(0xFF00695C) : TeacherTheme.primaryDark;

        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: accent,
            title: Text(
              _isStudent ? s.studentHomeworkScreenTitle : s.homeworkTitle,
            ),
          ),
          floatingActionButton: canPost
              ? FloatingActionButton.extended(
                  onPressed: () => _showHomeworkDialog(className: className),
                  icon: const Icon(Icons.add),
                  label: Text(s.addHomework),
                  backgroundColor: accent,
                )
              : null,
          body: WarmScreenBody(
            accentColor: accent,
            child: Column(
              children: [
                if (_classOptions.isNotEmpty)
                  ClassPickerBar(
                    label: s.className,
                    options: _classOptions,
                    selected: _selectedClass,
                    accent: accent,
                    onSelected: (value) => setState(() => _selectedClass = value),
                  )
                else if (!_isParent)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          s.noClassesAssigned,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_isParent && widget.initialChildName != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.child_care_outlined, color: accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.homeworkForChild(widget.initialChildName!),
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (showSubjectHint)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    s.subjectHomeworkOnlyHint,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ),
                if (_classOptions.isNotEmpty || _isParent)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _focusRow(s),
                  ),
                Expanded(
                  child: _classOptions.isEmpty && !_isParent
                      ? const SizedBox.shrink()
                      : _items.isEmpty
                    ? Center(child: Text(s.noHomeworkPosted))
                    : ListView.separated(
                        padding: listPagePadding(context),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final canEdit =
                              !_isParent && _access.canEditHomework(item);
                          final color = homeworkSubjectColor(item.subject);
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            elevation: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.35),
                                ),
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      width: 8,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: const BorderRadius.horizontal(
                                          left: Radius.circular(16),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: color,
                                                    borderRadius:
                                                        BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    item.subject,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    item.className,
                                                    style: TextStyle(
                                                      color: Colors.grey.shade700,
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                if (canEdit)
                                                  IconButton(
                                                    icon: const Icon(Icons.edit_outlined),
                                                    tooltip: s.editHomework,
                                                    onPressed: () =>
                                                        _showHomeworkDialog(
                                                      className: item.className,
                                                      existing: item,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            HomeworkBriefSections(item: item),
                                            if (item.attachmentPaths.isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              HomeworkAttachmentsPanel(
                                                attachmentPaths: item.attachmentPaths,
                                                compact: _isParent,
                                                allowShareDownload: _isParent,
                                                sectionTitle: _isStudent
                                                    ? s.teacherWorksheetLabel
                                                    : null,
                                              ),
                                            ],
                                            if (_isStudent)
                                              _studentWorksheetSection(item),
                                            if (!_isParent)
                                              _teacherSubmissionInbox(item),
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Icon(Icons.person, size: 16, color: color),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    item.teacherName,
                                                    style: const TextStyle(fontSize: 13),
                                                  ),
                                                ),
                                                Text(
                                                  _formatTime(item.postedAt),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _focusRow(AppStrings s) {
    final soon = _classItems.where((item) => item.isDueSoon).length;
    final overdue = _classItems.where((item) => item.isOverdue).length;
    Widget chip(String focus, String label, Color color, String count) {
      final selected = _focus == focus;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: selected ? color : color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _focus = focus),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                '$label · $count',
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('all', s.homeworkAllTasks, ClassroomPalette.blue, '${_classItems.length}'),
          chip('soon', s.homeworkDueSoon, ClassroomPalette.orange, '$soon'),
          chip('overdue', s.homeworkOverdue, ClassroomPalette.red, '$overdue'),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
