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
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/student_account_service.dart';
import 'package:mayabela/services/student_portal_sync_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/homework_attachments_panel.dart';
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
      return _data
          .getChildren()
          .map((child) => child.className)
          .toSet()
          .toList();
    }
    return _access.myClasses.map((assignment) => assignment.className).toList();
  }

  List<HomeworkItem> get _items {
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

  @override
  void initState() {
    super.initState();
    if (_classOptions.isNotEmpty) {
      _selectedClass = widget.initialClass ?? _classOptions.first;
    }
  }

  Future<void> _saveHomework({
    required String className,
    required String subject,
    required TextEditingController descriptionController,
    required List<String> attachmentPaths,
    String? homeworkId,
  }) async {
    final s = AppLocale.instance.strings;
    if (descriptionController.text.trim().isEmpty) return;

    if (homeworkId == null) {
      final slot = _access.teachingSlotFor(className, subject);
      _data.addHomework(
        className: className,
        subject: subject,
        description: descriptionController.text.trim(),
        teacherName: _access.teacherName,
        teacherId: _access.teacherId,
        subjectId: slot?.subjectId,
        teachingSlotId: slot?.slotId,
        attachmentPaths: attachmentPaths,
      );
    } else {
      _data.updateHomework(
        id: homeworkId,
        description: descriptionController.text.trim(),
        attachmentPaths: attachmentPaths,
      );
    }
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

    final descriptionController =
        TextEditingController(text: existing?.description ?? '');
    var subject = existing?.subject ??
        _access.defaultHomeworkSubject(className) ??
        subjects.first;
    var attachmentPaths = List<String>.from(existing?.attachmentPaths ?? []);

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
          adminDialogField(
            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: adminFieldDecoration(
                label: s.homeworkDetails,
                icon: Icons.notes_outlined,
                accent: const Color(0xFFEF6C00),
              ),
            ),
          ),
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
        descriptionController: descriptionController,
        attachmentPaths: attachmentPaths,
        homeworkId: existing?.id,
      );
    }
    descriptionController.dispose();
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
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          item.subject,
                                          style: TextStyle(
                                            color: Colors.indigo.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (canEdit)
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          tooltip: s.editHomework,
                                          onPressed: () => _showHomeworkDialog(
                                            className: item.className,
                                            existing: item,
                                          ),
                                        ),
                                      Text(
                                        item.className,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.description,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
                                  if (_isStudent) _studentWorksheetSection(item),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(Icons.person, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.teacherName,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const Spacer(),
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
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
