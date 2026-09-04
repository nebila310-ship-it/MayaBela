import 'package:flutter/material.dart';

import 'package:mayabela/constants/school_subjects.dart';
import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// Staff lesson plans — weekly planning that can link homework, materials, and exam papers.
class WebLessonPlansPage extends StatefulWidget {
  const WebLessonPlansPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebLessonPlansPage> createState() => _WebLessonPlansPageState();
}

class _WebLessonPlansPageState extends State<WebLessonPlansPage> {
  final _plans = LessonPlanService.instance;
  String? _className;
  String? _subject;

  bool get _canManage => ModuleAccess.canManage('lesson_plans');
  String get _schoolId => AuthService.activeSchoolId ?? '';

  List<String> get _classes {
    final names = <String>{
      ...SchoolRegistryService.instance.sectionsForSchool(_schoolId),
      ...SchoolDataService.instance.getAllGradeReports().map((r) => r.className),
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

  List<String> get _subjects {
    final list = {...SchoolSubjects.all}.toList()..sort();
    return list;
  }

  @override
  void initState() {
    super.initState();
    _plans.ensureLoaded();
    ExamService.instance.ensureLoaded();
    CurriculumService.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        _plans,
        ExamService.instance,
        CurriculumService.instance,
      ]),
      builder: (context, _) {
        var items = _plans.forSchool(_schoolId);
        if (_className != null) {
          items = items
              .where(
                (p) => StudentRegistryService.classNamesMatch(
                  p.className,
                  _className!,
                ),
              )
              .toList();
        }
        if (_subject != null) {
          items = items.where((p) => p.subject == _subject).toList();
        }
        items.sort((a, b) => b.weekStart.compareTo(a.weekStart));
        return ListView(
          padding: EdgeInsets.all(narrow ? 12 : 20),
          children: [
            Text('Lesson plans', style: WebErpTheme.sectionTitle(context)),
            const SizedBox(height: 4),
            Text(
              'Weekly plans for a class and subject. Link existing homework, '
              'learning materials, or an exam paper. This does not enter grades — '
              'scores still come from the markbook and exam desk.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_canManage)
                  FilledButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('New lesson plan'),
                  ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey('lp-class-$_className'),
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
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey('lp-subject-$_subject'),
                    initialValue: _subject,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All subjects'),
                      ),
                      for (final name in _subjects)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: (v) => setState(() => _subject = v),
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigate?.call('learning_materials'),
                  child: const Text('Open materials'),
                ),
                TextButton(
                  onPressed: () => widget.onNavigate?.call('exam_bank'),
                  child: const Text('Open exam bank'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: WebErpTheme.cardDecoration(context),
                child: const Text(
                  'No lesson plans yet. Create a weekly plan and publish it so students can see it.',
                ),
              )
            else
              for (final plan in items) _planCard(plan),
          ],
        );
      },
    );
  }

  Widget _planCard(LessonPlan plan) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: WebErpTheme.cardDecoration(context),
        child: ListTile(
          title: Text(plan.title),
          subtitle: Text(
            '${plan.className} · ${plan.subject} · '
            '${_weekLabel(plan.weekStart)} · '
            '${plan.isPublished ? 'Published' : 'Draft'}'
            '${plan.reviewStatus == LessonPlanReviewStatus.none ? '' : ' · ${_reviewLabel(plan.reviewStatus)}'}'
            '${plan.hasLinks ? ' · linked work' : ''}',
          ),
          trailing: _canManage
              ? Wrap(
                  spacing: 4,
                  children: [
                    if (!plan.isPublished)
                      TextButton(
                        onPressed: () =>
                            _plans.setStatus(plan.id, LessonPlanStatus.published),
                        child: const Text('Publish'),
                      )
                    else
                      TextButton(
                        onPressed: () =>
                            _plans.setStatus(plan.id, LessonPlanStatus.draft),
                        child: const Text('Unpublish'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _edit(plan),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _edit([LessonPlan? existing]) async {
    await showDialog<void>(
      context: context,
      builder: (context) => LessonPlanEditorDialog(
        existing: existing,
        classes: _classes,
        subjects: _subjects,
      ),
    );
  }

  static String _reviewLabel(LessonPlanReviewStatus status) => switch (status) {
        LessonPlanReviewStatus.none => '',
        LessonPlanReviewStatus.pending => 'Review pending',
        LessonPlanReviewStatus.approved => 'DH approved',
        LessonPlanReviewStatus.changesRequested => 'Changes requested',
      };

  static String _weekLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    return '${start.day}/${start.month}–${end.day}/${end.month}';
  }
}

class LessonPlanEditorDialog extends StatefulWidget {
  const LessonPlanEditorDialog({
    super.key,
    required this.classes,
    required this.subjects,
    this.existing,
  });

  final LessonPlan? existing;
  final List<String> classes;
  final List<String> subjects;

  @override
  State<LessonPlanEditorDialog> createState() => _LessonPlanEditorDialogState();
}

class _LessonPlanEditorDialogState extends State<LessonPlanEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _objectives;
  late final TextEditingController _activities;
  late String _className;
  late String _subject;
  late DateTime _weekStart;
  late Set<String> _homework;
  late Set<String> _papers;
  late Set<String> _materials;
  String? _unitId;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _title = TextEditingController(text: p?.title ?? '');
    _objectives = TextEditingController(text: p?.objectives ?? '');
    _activities = TextEditingController(text: p?.activities ?? '');
    _className = p?.className ?? widget.classes.firstOrNull ?? '';
    _subject = p?.subject ??
        (widget.subjects.contains('Science')
            ? 'Science'
            : widget.subjects.firstOrNull ?? 'Science');
    _weekStart = p?.weekStart ?? LessonPlan.mondayOf(DateTime.now());
    _homework = {...?p?.homeworkIds};
    _papers = {...?p?.examPaperIds};
    _materials = {...?p?.learningMaterialIds};
    _unitId = p?.curriculumUnitId;
  }

  @override
  void dispose() {
    _title.dispose();
    _objectives.dispose();
    _activities.dispose();
    super.dispose();
  }

  List<HomeworkItem> get _homeworkOptions {
    if (_className.isEmpty) return const [];
    return SchoolDataService.instance
        .getHomeworkForClass(_className)
        .where((h) => h.subject == _subject)
        .toList();
  }

  List<ExamPaper> get _paperOptions {
    return ExamService.instance
        .papersForSchool()
        .where((p) => p.className == _className && p.subject == _subject)
        .toList();
  }

  List<LearningMaterialItem> get _materialOptions {
    return SchoolDataService.instance
        .learningMaterialsSnapshot()
        .where((m) => m.className == _className && m.subject == _subject)
        .toList();
  }

  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() => _weekStart = LessonPlan.mondayOf(picked));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _className.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and class are required.')),
      );
      return;
    }
    final LessonPlan plan;
    if (widget.existing == null) {
      plan = await LessonPlanService.instance.createPlan(
        title: title,
        className: _className,
        subject: _subject,
        weekStart: _weekStart,
        objectives: _objectives.text,
        activities: _activities.text,
        homeworkIds: _homework.toList(),
        examPaperIds: _papers.toList(),
        learningMaterialIds: _materials.toList(),
        curriculumUnitId: _unitId,
      );
    } else {
      plan = (await LessonPlanService.instance.updatePlan(
        widget.existing!.id,
        title: title,
        className: _className,
        subject: _subject,
        weekStart: _weekStart,
        objectives: _objectives.text,
        activities: _activities.text,
        homeworkIds: _homework.toList(),
        examPaperIds: _papers.toList(),
        learningMaterialIds: _materials.toList(),
        curriculumUnitId: _unitId,
        clearCurriculumUnit: _unitId == null,
      ))!;
    }
    if (_unitId != null) {
      await CurriculumService.instance.attachLessonPlan(_unitId!, plan.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New lesson plan' : 'Edit lesson plan'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('lp-edit-class-$_className'),
                initialValue:
                    widget.classes.contains(_className) ? _className : null,
                decoration: const InputDecoration(labelText: 'Class'),
                items: [
                  for (final name in widget.classes)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) => setState(() {
                  _className = v ?? _className;
                  _homework.clear();
                  _papers.clear();
                  _materials.clear();
                }),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('lp-edit-subject-$_subject'),
                initialValue:
                    widget.subjects.contains(_subject) ? _subject : null,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: [
                  for (final name in widget.subjects)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) => setState(() {
                  _subject = v ?? _subject;
                  _homework.clear();
                  _papers.clear();
                  _materials.clear();
                }),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Week starting Monday'),
                subtitle: Text(_WebLessonPlansPageState._weekLabel(_weekStart)),
                trailing: TextButton(
                  onPressed: _pickWeek,
                  child: const Text('Change'),
                ),
              ),
              DropdownButtonFormField<String?>(
                key: ValueKey('lp-unit-$_unitId'),
                initialValue: _unitId,
                decoration: const InputDecoration(
                  labelText: 'Curriculum unit (optional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Not linked'),
                  ),
                  for (final unit in CurriculumService.instance.unitsForSchool())
                    DropdownMenuItem(value: unit.id, child: Text(unit.title)),
                ],
                onChanged: (v) => setState(() => _unitId = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _objectives,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Objectives'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _activities,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Activities'),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Linked work (optional)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (_homeworkOptions.isEmpty &&
                  _paperOptions.isEmpty &&
                  _materialOptions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No homework, materials, or papers for this class yet.'),
                ),
              for (final h in _homeworkOptions)
                CheckboxListTile(
                  dense: true,
                  value: _homework.contains(h.id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _homework.add(h.id);
                    } else {
                      _homework.remove(h.id);
                    }
                  }),
                  title: Text(h.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: const Text('Homework'),
                ),
              for (final p in _paperOptions)
                CheckboxListTile(
                  dense: true,
                  value: _papers.contains(p.id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _papers.add(p.id);
                    } else {
                      _papers.remove(p.id);
                    }
                  }),
                  title: Text(p.title),
                  subtitle: const Text('Exam paper'),
                ),
              for (final m in _materialOptions)
                CheckboxListTile(
                  dense: true,
                  value: _materials.contains(m.id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _materials.add(m.id);
                    } else {
                      _materials.remove(m.id);
                    }
                  }),
                  title: Text(m.bookName.isEmpty ? m.materialName : m.bookName),
                  subtitle: const Text('Learning material'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
