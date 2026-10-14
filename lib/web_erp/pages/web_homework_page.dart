import 'package:flutter/material.dart';

import 'package:mayabela/constants/school_subjects.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/cloud_save_honesty.dart';
import 'package:mayabela/services/persistence/homework_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/theme/classroom_palette.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/widgets/homework_brief_ui.dart';

/// Office homework desk — create, score, comment, and push to markbook.
class WebHomeworkPage extends StatefulWidget {
  const WebHomeworkPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebHomeworkPage> createState() => _WebHomeworkPageState();
}

class _WebHomeworkPageState extends State<WebHomeworkPage> {
  String? _className;
  String _focus = 'all';
  String? _openId;

  bool get _canView => ModuleAccess.canView('homework');
  bool get _canManage => ModuleAccess.canManage('homework');
  String get _schoolId => AuthService.activeSchoolId ?? '';

  @override
  void initState() {
    super.initState();
    SchoolDataService.instance.publishHomeworkReminders();
  }

  List<String> get _classes {
    final names = <String>{
      ...SchoolRegistryService.instance.sectionsForSchool(_schoolId),
      ...SchoolDataService.instance
          .homeworkForSchool(_schoolId)
          .map((h) => h.className),
      ...StudentRegistryService.instance.classNamesForSchool(_schoolId),
    };
    final list = names.where((n) => n.trim().isNotEmpty).toList()..sort();
    return list;
  }

  List<HomeworkItem> _classItems() {
    final all = SchoolDataService.instance.homeworkForSchool(_schoolId);
    final list = _className == null
        ? all.toList()
        : all
            .where(
              (h) => StudentRegistryService.classNamesMatch(
                h.className,
                _className!,
              ),
            )
            .toList();
    list.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return list;
  }

  List<HomeworkItem> _itemsForFilter() {
    final all = _classItems();
    return switch (_focus) {
      'soon' => all.where((h) => h.isDueSoon).toList(),
      'overdue' => all.where((h) => h.isOverdue).toList(),
      'waiting' => all.where((h) => h.unmarkedSubmissionCount > 0).toList(),
      _ => all,
    };
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
    DateTime? dueDate,
    String? homeworkId,
  }) async {
    final user = AuthService.currentUser;
    if (homeworkId == null) {
      SchoolDataService.instance.addHomework(
        className: className,
        subject: subject,
        description: description,
        teacherName: user?.fullName ?? user?.username ?? 'Staff',
        teacherId: user?.username ?? 'staff',
        dueDate: dueDate,
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
      SchoolDataService.instance.updateHomework(
        id: homeworkId,
        description: description,
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
        savedOk: homeworkId == null ? 'Homework posted' : 'Homework updated',
        outcome: outcome,
        strings: AppLocale.instance.strings,
      ),
    );
  }

  Future<void> _editHomework([HomeworkItem? existing]) async {
    if (!_canManage) return;
    final classes = _classes;
    var className = existing?.className ?? _className ?? (classes.isEmpty ? '' : classes.first);
    var subject = existing?.subject ??
        (SchoolSubjects.all.isEmpty ? 'English' : SchoolSubjects.all.first);
    final s = AppLocale.instance.strings;
    final title = TextEditingController(text: existing?.title ?? '');
    final description = TextEditingController(text: existing?.description ?? '');
    final objective = TextEditingController(text: existing?.learningObjective ?? '');
    final criteria = TextEditingController(text: existing?.successCriteria ?? '');
    final resources = TextEditingController(text: existing?.resources ?? '');
    final supportNote = TextEditingController(text: existing?.supportNote ?? '');
    final extensionNote = TextEditingController(text: existing?.extensionNote ?? '');
    final maxScore = TextEditingController(
      text: (existing?.maxScore ?? 100).toStringAsFixed(0),
    );
    var taskType = existing?.taskType ?? '';
    var submissionMethod = existing?.submissionMethod ?? '';
    int? estimatedMinutes = existing?.estimatedMinutes;
    var dueDate = existing?.dueDate;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          existing == null ? s.postHomework : s.editHomework,
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: HomeworkPostFields(
                        title: title,
                        instructions: description,
                        objective: objective,
                        criteria: criteria,
                        resources: resources,
                        supportNote: supportNote,
                        extensionNote: extensionNote,
                        maxScore: maxScore,
                        taskType: taskType,
                        submissionMethod: submissionMethod,
                        estimatedMinutes: estimatedMinutes,
                        dueDate: dueDate,
                        onTaskType: (value) => setDialog(() => taskType = value),
                        onSubmission: (value) =>
                            setDialog(() => submissionMethod = value),
                        onMinutes: (value) =>
                            setDialog(() => estimatedMinutes = value),
                        onPickDue: () async {
                          final picked = await pickHomeworkDue(ctx, current: dueDate);
                          if (picked != null) setDialog(() => dueDate = picked);
                        },
                        leading: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue:
                                  classes.contains(className) ? className : null,
                              decoration: const InputDecoration(
                                labelText: 'Class',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final name in classes)
                                  DropdownMenuItem(value: name, child: Text(name)),
                              ],
                              onChanged: existing == null
                                  ? (v) => setDialog(() => className = v ?? className)
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: SchoolSubjects.all.contains(subject)
                                  ? subject
                                  : subject,
                              decoration: const InputDecoration(
                                labelText: 'Subject',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final name in SchoolSubjects.all)
                                  DropdownMenuItem(value: name, child: Text(name)),
                              ],
                              onChanged: existing == null
                                  ? (v) => setDialog(() => subject = v ?? subject)
                                  : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(s.cancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final hasText = title.text.trim().isNotEmpty ||
                              description.text.trim().isNotEmpty;
                          if (className.trim().isEmpty || !hasText) return;
                          Navigator.pop(ctx, true);
                        },
                        child: Text(existing == null ? s.publish : s.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final postedTitle = title.text.trim();
    final postedDescription = description.text.trim().isEmpty
        ? postedTitle
        : description.text.trim();
    final postedObjective = objective.text.trim();
    final postedCriteria = criteria.text.trim();
    final postedResources = resources.text.trim();
    final postedSupport = supportNote.text.trim();
    final postedExtension = extensionNote.text.trim();
    final postedMax = double.tryParse(maxScore.text.trim()) ?? 100;
    title.dispose();
    description.dispose();
    objective.dispose();
    criteria.dispose();
    resources.dispose();
    supportNote.dispose();
    extensionNote.dispose();
    maxScore.dispose();
    if (saved != true) return;
    await _saveHomework(
      className: className,
      subject: subject,
      description: postedDescription,
      title: postedTitle,
      taskType: taskType,
      learningObjective: postedObjective,
      successCriteria: postedCriteria,
      estimatedMinutes: estimatedMinutes,
      submissionMethod: submissionMethod,
      resources: postedResources,
      supportNote: postedSupport,
      extensionNote: postedExtension,
      maxScore: postedMax,
      dueDate: dueDate,
      homeworkId: existing?.id,
    );
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
      SchoolDataService.instance.recordHomeworkScore(
        homeworkId: item.id,
        studentId: studentId,
        score: score,
      );
    }
    if (commentCtrl.text.trim().isNotEmpty ||
        item.teacherComments.containsKey(studentId)) {
      SchoolDataService.instance.commentOnHomework(
        homeworkId: item.id,
        studentId: studentId,
        comment: commentCtrl.text,
      );
    }
    if (saved == 'push') {
      SchoolDataService.instance.pushHomeworkScoreToMarkbook(
        homeworkId: item.id,
        studentId: studentId,
      );
    }
    await HomeworkPersistenceService.instance.saveFromService();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    final s = AppLocale.instance.strings;
    if (!_canView) {
      return const Center(child: Text('You do not have access to homework.'));
    }
    return ListenableBuilder(
      listenable: SchoolContentSyncService.instance,
      builder: (context, _) {
        final inClass = _classItems();
        final items = _itemsForFilter();
        final dueSoon = inClass.where((h) => h.isDueSoon).length;
        final overdue = inClass.where((h) => h.isOverdue).length;
        final waiting = inClass.fold<int>(
          0,
          (sum, item) => sum + item.unmarkedSubmissionCount,
        );
        return ListView(
          padding: EdgeInsets.all(narrow ? 12 : 20),
          children: [
            _banner(s, narrow),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _stat(
                  s.homeworkOpenTasks,
                  '${inClass.length}',
                  ClassroomPalette.blue,
                  'all',
                  Icons.assignment_outlined,
                ),
                _stat(
                  s.homeworkDueSoon,
                  '$dueSoon',
                  ClassroomPalette.orange,
                  'soon',
                  Icons.schedule,
                ),
                _stat(
                  s.homeworkOverdue,
                  '$overdue',
                  ClassroomPalette.red,
                  'overdue',
                  Icons.warning_amber_rounded,
                ),
                _stat(
                  s.homeworkWaitingMark,
                  '$waiting',
                  ClassroomPalette.purple,
                  'waiting',
                  Icons.rate_review_outlined,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String?>(
                key: ValueKey('hw-class-$_className'),
                initialValue: _className,
                decoration: const InputDecoration(
                  labelText: 'Class',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All classes'),
                  ),
                  for (final name in _classes)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) => setState(() => _className = v),
              ),
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: WebErpTheme.cardDecoration(context),
                child: Text(s.noHomeworkPosted),
              )
            else
              for (final item in items) _card(item),
          ],
        );
      },
    );
  }

  Widget _banner(AppStrings s, bool narrow) {
    return Container(
      padding: EdgeInsets.all(narrow ? 16 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1A73E8),
            Color(0xFF8E24AA),
            Color(0xFFE37400),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.auto_stories, color: Colors.white, size: 36),
          SizedBox(
            width: narrow ? double.infinity : 460,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.homeworkDeskTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.homeworkDeskHint,
                  style: const TextStyle(color: Colors.white, height: 1.35),
                ),
              ],
            ),
          ),
          if (_canManage)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: ClassroomPalette.navy,
              ),
              onPressed: () => _editHomework(),
              icon: const Icon(Icons.add),
              label: Text(s.postHomework),
            ),
        ],
      ),
    );
  }

  Widget _stat(
    String label,
    String value,
    Color color,
    String focus,
    IconData icon,
  ) {
    final selected = _focus == focus;
    return Material(
      color: selected ? color : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _focus = focus),
        child: Container(
          width: 168,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: selected ? Colors.white : color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        color: selected ? Colors.white : color,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(HomeworkItem item) {
    final open = _openId == item.id;
    final color = homeworkSubjectColor(item.subject);
    final students = StudentRegistryService.instance.studentsForClass(
      item.className,
      schoolId: _schoolId.isEmpty ? null : _schoolId,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: ClassroomPalette.cardOf(context),
        elevation: open ? 3 : 0,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _openId = open ? null : item.id),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.35)),
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
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                                  color: color,
                                  borderRadius: BorderRadius.circular(20),
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
                              Text(
                                item.className,
                                style: TextStyle(
                                  color: ClassroomPalette.mutedOf(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                open
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: color,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          HomeworkBriefSections(item: item),
                          const SizedBox(height: 8),
                          Text(
                            '${item.teacherName} · ${item.submittedStudentCount} submission${item.submittedStudentCount == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: ClassroomPalette.mutedOf(context),
                              fontSize: 12,
                            ),
                          ),
                          if (open) ...[
                            if (_canManage)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _editHomework(item),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: Text(
                                    AppLocale.instance.strings.editHomework,
                                  ),
                                ),
                              ),
                            if (students.isEmpty)
                              const ListTile(
                                title: Text('No students listed for this class.'),
                              )
                            else
                              for (final student in students)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(student.fullName),
                                  subtitle: Text(
                                    [
                                      if (item.studentScores[student.studentId] !=
                                          null)
                                        'Score ${item.studentScores[student.studentId]!.toStringAsFixed(0)}',
                                      if ((item.teacherComments[
                                                  student.studentId] ??
                                              '')
                                          .isNotEmpty)
                                        item.teacherComments[student.studentId]!,
                                      if (item
                                          .worksheetsForStudent(student.studentId)
                                          .isNotEmpty)
                                        '${item.worksheetsForStudent(student.studentId).length} file(s)',
                                    ].join(' · '),
                                  ),
                                  trailing: _canManage
                                      ? TextButton(
                                          onPressed: () => _gradeStudent(
                                            item,
                                            student.studentId,
                                          ),
                                          child: const Text('Score'),
                                        )
                                      : null,
                                ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
