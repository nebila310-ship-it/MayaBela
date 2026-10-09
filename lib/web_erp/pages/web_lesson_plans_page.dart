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
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/widgets/lesson_plan_view_card.dart';

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
  bool get _teacherScoped =>
      AuthService.currentUser?.roleKey == AuthService.roleTeacher &&
      !_canManage;
  String get _schoolId => AuthService.activeSchoolId ?? '';

  List<String> get _classes {
    if (_teacherScoped) {
      final names = <String>{
        ...TeacherAccessService.instance.myClasses.map((a) => a.className),
        ...AuthService.accessClassNamesForSync(),
      };
      return names.where((n) => n.trim().isNotEmpty).toList()..sort();
    }
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
    if (_teacherScoped) {
      final names = <String>{};
      for (final className in _classes) {
        names.addAll(
          TeacherAccessService.instance.teachableSubjects(className),
        );
      }
      return names.where((n) => n.trim().isNotEmpty).toList()..sort();
    }
    final list = {...SchoolSubjects.all}.toList()..sort();
    return list;
  }

  List<String> _subjectsForClass(String className) {
    if (!_teacherScoped) return _subjects;
    return TeacherAccessService.instance.teachableSubjects(className);
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
        var items = _plans.visibleForCurrentUser(
          className: _className,
          schoolId: _schoolId,
        );
        if (_subject != null) {
          items = items
              .where(
                (p) => TeacherAccessService.subjectsMatch(p.subject, _subject!),
              )
              .toList();
        }
        return ListView(
          padding: EdgeInsets.all(narrow ? 12 : 20),
          children: [
            Text('Lesson plans', style: WebErpTheme.sectionTitle(context)),
            const SizedBox(height: 4),
            Text(
              _teacherScoped
                  ? 'Prepare weekly plans for the subjects you teach. Other '
                      'subjects stay hidden. Submit a plan to send it to the '
                      'parents of that class. Parents can read it only.'
                  : 'Teachers write a weekly plan for their own subject. '
                      'Publishing sends it to parents of that class (read-only). '
                      'Record an achievement % so leadership can evaluate delivery. '
                      'This does not enter grades.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (_canManage) ...[
              const SizedBox(height: 12),
              _evaluationSummary(items),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_canManage || _teacherScoped)
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
                  'No lesson plans yet. Create a weekly plan with objectives and a '
                  'lesson sequence, then publish it so the class can open it.',
                ),
              )
            else
              for (final plan in items)
                _planCard(plan, expand: items.length == 1),
          ],
        );
      },
    );
  }

  Widget _planCard(LessonPlan plan, {required bool expand}) {
    return LessonPlanViewCard(
      key: ValueKey(plan.id),
      plan: plan,
      initiallyExpanded: expand,
      actions: [
        if (_canManage)
          TextButton(
            onPressed: () => _evaluate(plan),
            child: Text(
              plan.hasAchievement ? 'Update achievement' : 'Evaluate',
            ),
          ),
        if (_canManage || _teacherScoped) ...[
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
          FilledButton.tonalIcon(
            onPressed: () => _edit(plan),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
        ],
      ],
    );
  }

  Future<void> _edit([LessonPlan? existing]) async {
    await showDialog<void>(
      context: context,
      builder: (context) => LessonPlanEditorDialog(
        existing: existing,
        classes: _classes,
        subjects: _subjects,
        subjectsForClass: _teacherScoped ? _subjectsForClass : null,
      ),
    );
  }

  Widget _evaluationSummary(List<LessonPlan> items) {
    final scored = items.where((p) => p.hasAchievement).toList();
    final average = scored.isEmpty
        ? null
        : scored.fold<int>(0, (sum, p) => sum + p.achievementPercent!) /
            scored.length;
    final pending = items.where((p) => p.isPublished && !p.hasAchievement).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: WebErpTheme.cardDecoration(context),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: [
          _stat('Plans', '${items.length}'),
          _stat(
            'Average achievement',
            average == null ? '—' : '${average.round()}%',
          ),
          _stat('Awaiting evaluation', '$pending'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(value, style: WebErpTheme.sectionTitle(context)),
      ],
    );
  }

  Future<void> _evaluate(LessonPlan plan) async {
    final percent = TextEditingController(
      text: plan.achievementPercent?.toString() ?? '',
    );
    final notes = TextEditingController(text: plan.achievementNotes);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Evaluate lesson plan'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${plan.title} · ${plan.className} · ${plan.subject}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: percent,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Achievement %',
                  hintText: '0–100',
                  helperText:
                      'How well this weekly plan met its learning aims.',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Evaluation notes (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final value = int.tryParse(percent.text.trim());
    final noteText = notes.text;
    percent.dispose();
    notes.dispose();
    if (saved != true || value == null) return;
    await _plans.evaluatePlan(plan.id, percent: value, notes: noteText);
  }

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
    this.subjectsForClass,
  });

  final LessonPlan? existing;
  final List<String> classes;
  final List<String> subjects;
  final List<String> Function(String className)? subjectsForClass;

  @override
  State<LessonPlanEditorDialog> createState() => _LessonPlanEditorDialogState();
}

class _LessonPlanEditorDialogState extends State<LessonPlanEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _objectives;
  late final TextEditingController _successCriteria;
  late final TextEditingController _vocabulary;
  late final TextEditingController _priorKnowledge;
  late final TextEditingController _starter;
  late final TextEditingController _activities;
  late final TextEditingController _plenary;
  late final TextEditingController _differentiation;
  late final TextEditingController _assessment;
  late final TextEditingController _homeLearning;
  late final TextEditingController _inclusion;
  late final TextEditingController _duration;
  late final TextEditingController _period;
  late final TextEditingController _onlineUrl;
  late final TextEditingController _onlineLabel;
  late String _className;
  late String _subject;
  late DateTime _weekStart;
  late Set<String> _homework;
  late Set<String> _papers;
  late Set<String> _materials;
  late List<String> _attachments;
  String? _unitId;
  late bool _onlineLive;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _title = TextEditingController(text: p?.title ?? '');
    _objectives = TextEditingController(text: p?.objectives ?? '');
    _successCriteria = TextEditingController(text: p?.successCriteria ?? '');
    _vocabulary = TextEditingController(text: p?.keyVocabulary ?? '');
    _priorKnowledge = TextEditingController(text: p?.priorKnowledge ?? '');
    _starter = TextEditingController(text: p?.starter ?? '');
    _activities = TextEditingController(text: p?.activities ?? '');
    _plenary = TextEditingController(text: p?.plenary ?? '');
    _differentiation = TextEditingController(text: p?.differentiation ?? '');
    _assessment = TextEditingController(text: p?.assessment ?? '');
    _homeLearning = TextEditingController(text: p?.homeLearning ?? '');
    _inclusion = TextEditingController(text: p?.inclusionNotes ?? '');
    _duration = TextEditingController(
      text: p?.durationMinutes == null ? '' : '${p!.durationMinutes}',
    );
    _period = TextEditingController(text: p?.periodLabel ?? '');
    _className = p?.className ?? widget.classes.firstOrNull ?? '';
    final initialSubjects = _subjectsFor(_className);
    _subject = p?.subject ??
        (initialSubjects.contains('Science')
            ? 'Science'
            : initialSubjects.firstOrNull ??
                widget.subjects.firstOrNull ??
                'Science');
    _weekStart = p?.weekStart ?? LessonPlan.mondayOf(DateTime.now());
    _homework = {...?p?.homeworkIds};
    _papers = {...?p?.examPaperIds};
    _materials = {...?p?.learningMaterialIds};
    _attachments = List<String>.from(p?.attachmentPaths ?? const []);
    _unitId = p?.curriculumUnitId;
    _onlineUrl = TextEditingController(text: p?.onlineSessionUrl ?? '');
    _onlineLabel = TextEditingController(text: p?.onlineSessionLabel ?? '');
    _onlineLive = p?.onlineSessionIsLive ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _objectives.dispose();
    _successCriteria.dispose();
    _vocabulary.dispose();
    _priorKnowledge.dispose();
    _starter.dispose();
    _activities.dispose();
    _plenary.dispose();
    _differentiation.dispose();
    _assessment.dispose();
    _homeLearning.dispose();
    _inclusion.dispose();
    _duration.dispose();
    _period.dispose();
    _onlineUrl.dispose();
    _onlineLabel.dispose();
    super.dispose();
  }

  List<String> _subjectsFor(String className) {
    final fromClass = widget.subjectsForClass?.call(className);
    if (fromClass != null) {
      return fromClass.where((name) => name.trim().isNotEmpty).toList();
    }
    return widget.subjects;
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
    final allowedSubjects = _subjectsFor(_className);
    if (allowedSubjects.isNotEmpty && !allowedSubjects.contains(_subject)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only save a plan for your assigned subjects.'),
        ),
      );
      return;
    }
    final minutes = int.tryParse(_duration.text.trim());
    final LessonPlan plan;
    if (widget.existing == null) {
      plan = await LessonPlanService.instance.createPlan(
        title: title,
        className: _className,
        subject: _subject,
        weekStart: _weekStart,
        objectives: _objectives.text,
        successCriteria: _successCriteria.text,
        keyVocabulary: _vocabulary.text,
        priorKnowledge: _priorKnowledge.text,
        starter: _starter.text,
        activities: _activities.text,
        plenary: _plenary.text,
        differentiation: _differentiation.text,
        assessment: _assessment.text,
        homeLearning: _homeLearning.text,
        inclusionNotes: _inclusion.text,
        durationMinutes: minutes,
        periodLabel: _period.text,
        homeworkIds: _homework.toList(),
        examPaperIds: _papers.toList(),
        learningMaterialIds: _materials.toList(),
        attachmentPaths: _attachments,
        curriculumUnitId: _unitId,
        onlineSessionUrl: _onlineUrl.text,
        onlineSessionLabel: _onlineLabel.text,
        onlineSessionIsLive: _onlineLive,
      );
    } else {
      plan = (await LessonPlanService.instance.updatePlan(
        widget.existing!.id,
        title: title,
        className: _className,
        subject: _subject,
        weekStart: _weekStart,
        objectives: _objectives.text,
        successCriteria: _successCriteria.text,
        keyVocabulary: _vocabulary.text,
        priorKnowledge: _priorKnowledge.text,
        starter: _starter.text,
        activities: _activities.text,
        plenary: _plenary.text,
        differentiation: _differentiation.text,
        assessment: _assessment.text,
        homeLearning: _homeLearning.text,
        inclusionNotes: _inclusion.text,
        durationMinutes: minutes,
        clearDuration: _duration.text.trim().isEmpty,
        periodLabel: _period.text,
        homeworkIds: _homework.toList(),
        examPaperIds: _papers.toList(),
        learningMaterialIds: _materials.toList(),
        attachmentPaths: _attachments,
        curriculumUnitId: _unitId,
        clearCurriculumUnit: _unitId == null,
        onlineSessionUrl: _onlineUrl.text,
        onlineSessionLabel: _onlineLabel.text,
        onlineSessionIsLive: _onlineLive,
        clearOnlineSession: _onlineUrl.text.trim().isEmpty,
      ))!;
    }
    await CurriculumService.instance.syncLessonPlanUnit(
      planId: plan.id,
      previousUnitId: widget.existing?.curriculumUnitId,
      nextUnitId: _unitId,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New lesson plan' : 'Edit lesson plan'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Write a weekly plan in the shape international schools use: '
                  'learning intentions, a starter–main–plenary sequence, '
                  'support for every learner, assessment, home learning, and '
                  'worksheets. Empty sections stay hidden when the class opens it.',
                  style: TextStyle(height: 1.35, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Grade 4 Science — Plant parts',
                ),
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
                  final next = _subjectsFor(_className);
                  if (!next.contains(_subject)) {
                    _subject = next.firstOrNull ?? _subject;
                  }
                  _homework.clear();
                  _papers.clear();
                  _materials.clear();
                }),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('lp-edit-subject-$_className-$_subject'),
                initialValue:
                    _subjectsFor(_className).contains(_subject) ? _subject : null,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: [
                  for (final name in _subjectsFor(_className))
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
                controller: _period,
                decoration: const InputDecoration(
                  labelText: 'Period / block (optional)',
                  hintText: 'Period 3–4',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                  hintText: '40',
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Learning intentions',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _objectives,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Learning objectives',
                  hintText: 'By the end of this week, learners will be able to…',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _successCriteria,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Success criteria',
                  hintText: 'I can… / Learners can show…',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _vocabulary,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Key vocabulary',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _priorKnowledge,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Prior knowledge / connection',
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Lesson sequence',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _starter,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Starter / hook',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _activities,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Main teaching & learning',
                  hintText: 'Modelling, guided practice, independent work…',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _plenary,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Plenary'),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Support, assessment & home learning',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _differentiation,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Differentiation (support / core / challenge)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _inclusion,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Inclusion / SEN notes',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _assessment,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Assessment for learning',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _homeLearning,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Home learning',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _onlineUrl,
                decoration: const InputDecoration(
                  labelText: 'Live or recorded class link',
                  hintText: 'https://…',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _onlineLabel,
                decoration: const InputDecoration(
                  labelText: 'Link label (optional)',
                  hintText: 'Join Grade 4 Science',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('This is a live class'),
                value: _onlineLive,
                onChanged: (v) => setState(() => _onlineLive = v),
              ),
              const SizedBox(height: 12),
              LessonPlanAttachmentPicker(
                paths: _attachments,
                onChanged: (next) => setState(() => _attachments = next),
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
