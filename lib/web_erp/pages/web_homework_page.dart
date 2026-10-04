import 'package:flutter/material.dart';

import 'package:mayabela/constants/school_subjects.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/cloud_save_honesty.dart';
import 'package:mayabela/services/persistence/homework_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// Office homework desk — create, score, comment, and push to markbook.
class WebHomeworkPage extends StatefulWidget {
  const WebHomeworkPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebHomeworkPage> createState() => _WebHomeworkPageState();
}

class _WebHomeworkPageState extends State<WebHomeworkPage> {
  String? _className;

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
      ...SchoolDataService.instance.homeworkSnapshot().map((h) => h.className),
      ...StudentRegistryService.instance
          .registrySnapshot()
          .where(
            (s) =>
                _schoolId.isEmpty ||
                s.schoolId.toUpperCase() == _schoolId.toUpperCase(),
          )
          .map((s) => s.className),
    };
    final list = names.where((n) => n.trim().isNotEmpty).toList()..sort();
    return list;
  }

  List<HomeworkItem> _itemsForFilter() {
    final all = SchoolDataService.instance.homeworkSnapshot();
    if (_className == null) {
      return all.toList()..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    }
    return all
        .where(
          (h) => StudentRegistryService.classNamesMatch(h.className, _className!),
        )
        .toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
  }

  Future<void> _saveHomework({
    required String className,
    required String subject,
    required String description,
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
      );
    } else {
      SchoolDataService.instance.updateHomework(
        id: homeworkId,
        description: description,
        dueDate: dueDate,
        clearDueDate: dueDate == null,
      );
    }
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
    final description = TextEditingController(text: existing?.description ?? '');
    var dueDate = existing?.dueDate;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(existing == null ? 'Post homework' : 'Edit homework'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: classes.contains(className) ? className : null,
                  decoration: const InputDecoration(labelText: 'Class'),
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
                  initialValue: SchoolSubjects.all.contains(subject) ? subject : subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: [
                    for (final name in SchoolSubjects.all)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: existing == null
                      ? (v) => setDialog(() => subject = v ?? subject)
                      : null,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Assignment'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    dueDate == null
                        ? 'No due date'
                        : 'Due ${dueDate!.day}/${dueDate!.month}/${dueDate!.year}',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 180)),
                        initialDate: dueDate ?? DateTime.now().add(const Duration(days: 2)),
                      );
                      if (picked != null) setDialog(() => dueDate = picked);
                    },
                    child: const Text('Due date'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (className.trim().isEmpty || description.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(existing == null ? 'Post' : 'Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await _saveHomework(
      className: className,
      subject: subject,
      description: description.text.trim(),
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
                decoration: const InputDecoration(
                  labelText: 'Homework score (0–100)',
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
    if (!_canView) {
      return const Center(child: Text('You do not have access to homework.'));
    }
    final items = _itemsForFilter();
    return ListView(
      padding: EdgeInsets.all(narrow ? 12 : 20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Homework', style: WebErpTheme.sectionTitle(context)),
            ),
            if (_canManage)
              FilledButton.icon(
                onPressed: () => _editHomework(),
                icon: const Icon(Icons.add),
                label: const Text('Post homework'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _canManage
              ? 'Post assignments, comment on submissions, and push scores into the markbook homework category.'
              : 'Posted assignments for each class.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 220,
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
            padding: const EdgeInsets.all(20),
            decoration: WebErpTheme.cardDecoration(context),
            child: const Text('No homework posted for this class yet.'),
          )
        else
          for (final item in items) _card(item),
      ],
    );
  }

  Widget _card(HomeworkItem item) {
    final posted =
        '${item.postedAt.day}/${item.postedAt.month}/${item.postedAt.year}';
    final due = item.dueDate == null
        ? ''
        : ' · due ${item.dueDate!.day}/${item.dueDate!.month}/${item.dueDate!.year}';
    final students = StudentRegistryService.instance.studentsForClass(
      item.className,
      schoolId: _schoolId.isEmpty ? null : _schoolId,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: WebErpTheme.cardDecoration(context),
        child: ExpansionTile(
          title: Text('${item.subject} · ${item.className}'),
          subtitle: Text(
            '${item.description}\n${item.teacherName} · $posted$due'
            ' · ${item.submittedStudentCount} submission${item.submittedStudentCount == 1 ? '' : 's'}',
          ),
          children: [
            if (_canManage)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _editHomework(item),
                  child: const Text('Edit'),
                ),
              ),
            if (students.isEmpty)
              const ListTile(title: Text('No students listed for this class.'))
            else
              for (final student in students)
                ListTile(
                  title: Text(student.fullName),
                  subtitle: Text(
                    [
                      if (item.studentScores[student.studentId] != null)
                        'Score ${item.studentScores[student.studentId]!.toStringAsFixed(0)}',
                      if ((item.teacherComments[student.studentId] ?? '').isNotEmpty)
                        item.teacherComments[student.studentId]!,
                      if (item.worksheetsForStudent(student.studentId).isNotEmpty)
                        '${item.worksheetsForStudent(student.studentId).length} file(s)',
                    ].join(' · '),
                  ),
                  trailing: _canManage
                      ? TextButton(
                          onPressed: () => _gradeStudent(item, student.studentId),
                          child: const Text('Score'),
                        )
                      : null,
                ),
          ],
        ),
      ),
    );
  }
}
