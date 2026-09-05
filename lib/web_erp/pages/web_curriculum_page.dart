import 'package:flutter/material.dart';

import 'package:mayabela/constants/school_subjects.dart';
import 'package:mayabela/models/curriculum_models.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/widgets/course_attachment_picker.dart';

/// Staff curriculum office — maps, DH lesson-plan review, academic evals, meetings.
class WebCurriculumPage extends StatefulWidget {
  const WebCurriculumPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebCurriculumPage> createState() => _WebCurriculumPageState();
}

class _WebCurriculumPageState extends State<WebCurriculumPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _curriculum = CurriculumService.instance;
  final _plans = LessonPlanService.instance;

  bool get _canLead => ModuleAccess.canManage('curriculum');
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
    return names.where((n) => n.trim().isNotEmpty).toList()..sort();
  }

  List<String> get _subjects => {...SchoolSubjects.all}.toList()..sort();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _curriculum.ensureLoaded();
    _plans.ensureLoaded();
    ExamService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_curriculum, _plans, ExamService.instance]),
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(narrow ? 12 : 20, narrow ? 12 : 20, narrow ? 12 : 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Curriculum office', style: WebErpTheme.sectionTitle(context)),
                  const SizedBox(height: 4),
                  Text(
                    'Map units to national or international standards, keep version '
                    'history, and align lesson plans with assessments. Department '
                    'heads review plans and record academic-only teacher evaluations. '
                    'This does not enter grades.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Units (${_curriculum.unitsForSchool(_schoolId).length})'),
                      Tab(text: 'Reviews (${_plans.pendingReviewCount(_schoolId)})'),
                      Tab(text: 'Evaluations (${_curriculum.evaluationsForSchool(_schoolId).length})'),
                      Tab(text: 'Feedback (${_curriculum.openFeedbackCount(_schoolId)})'),
                      Tab(text: 'Meetings (${_curriculum.meetingsForSchool(_schoolId).length})'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _unitsTab(),
                  _reviewsTab(),
                  _evaluationsTab(),
                  _feedbackTab(),
                  _meetingsTab(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _unitsTab() {
    final items = _curriculum.unitsForSchool(_schoolId);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (_canLead)
              FilledButton.icon(
                onPressed: () => _editUnit(),
                icon: const Icon(Icons.add),
                label: const Text('New unit'),
              ),
            TextButton(
              onPressed: () => widget.onNavigate?.call('lesson_plans'),
              child: const Text('Open lesson plans'),
            ),
            TextButton(
              onPressed: () => widget.onNavigate?.call('exam_bank'),
              child: const Text('Open exam bank'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _empty('No curriculum units yet. Map a strand to national or international standards.')
        else
          for (final unit in items) _unitCard(unit),
      ],
    );
  }

  Widget _unitCard(CurriculumUnit unit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: WebErpTheme.cardDecoration(context),
        child: ExpansionTile(
          title: Text(unit.title),
          subtitle: Text(
            '${unit.subject}'
            '${unit.gradeLevel == null || unit.gradeLevel!.isEmpty ? '' : ' · ${unit.gradeLevel}'}'
            ' · ${unit.framework.name} v${unit.version}'
            ' · ${unit.status.name}'
            '${unit.standardCodes.isEmpty ? '' : ' · ${unit.standardCodes.join(', ')}'}',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            if (unit.objectives.trim().isNotEmpty) Text(unit.objectives),
            if (unit.description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(unit.description),
            ],
            const SizedBox(height: 8),
            Text(
              'Linked: ${unit.lessonPlanIds.length} plans · '
              '${unit.examPaperIds.length} papers · '
              '${unit.homeworkIds.length} homework'
              '${unit.attachmentPaths.isEmpty ? '' : ' · ${unit.attachmentPaths.length} file(s)'}',
            ),
            if (unit.attachmentPaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              CourseAttachmentPicker(
                paths: unit.attachmentPaths,
                subdir: 'curriculum_attachments',
                canEdit: false,
                allowShareDownload: true,
                sectionTitle: 'Course files',
              ),
            ],
            if (unit.versions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Version history',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final v in unit.versions.reversed.take(8))
                Text(
                  'v${v.version} · ${v.changedBy} · '
                  '${v.changedAt.day}/${v.changedAt.month}'
                  '${v.note == null || v.note!.isEmpty ? '' : ' — ${v.note}'}',
                ),
            ],
            if (_canLead)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 4,
                  children: [
                    if (unit.status != CurriculumUnitStatus.published)
                      TextButton(
                        onPressed: () => _curriculum.setUnitStatus(
                          unit.id,
                          CurriculumUnitStatus.published,
                        ),
                        child: const Text('Publish'),
                      )
                    else
                      TextButton(
                        onPressed: () => _curriculum.setUnitStatus(
                          unit.id,
                          CurriculumUnitStatus.draft,
                        ),
                        child: const Text('Unpublish'),
                      ),
                    TextButton(
                      onPressed: () => _editUnit(unit),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reviewsTab() {
    final pending = _plans.forSchool(_schoolId).where((p) {
      return p.isPublished &&
          (p.reviewStatus == LessonPlanReviewStatus.none ||
              p.reviewStatus == LessonPlanReviewStatus.pending ||
              p.reviewStatus == LessonPlanReviewStatus.changesRequested);
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final done = _curriculum.reviewsForSchool(_schoolId);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Department-head review of published lesson plans. Approval does not '
          'change the plan publish state or write any grades.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (pending.isEmpty)
          _empty('No published plans waiting for review.')
        else
          for (final plan in pending) _reviewPlanCard(plan),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Recent decisions', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final review in done.take(20))
            ListTile(
              dense: true,
              title: Text(
                '${review.decision == LessonPlanReviewDecision.approved ? 'Approved' : 'Changes requested'} · ${review.lessonPlanId}',
              ),
              subtitle: Text(
                '${review.reviewerUsername}'
                '${review.notes.isEmpty ? '' : ' — ${review.notes}'}',
              ),
            ),
        ],
      ],
    );
  }

  Widget _reviewPlanCard(LessonPlan plan) {
    final unit = plan.curriculumUnitId == null
        ? null
        : _curriculum.unitById(plan.curriculumUnitId!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: WebErpTheme.cardDecoration(context),
        child: ListTile(
          title: Text(plan.title),
          subtitle: Text(
            '${plan.className} · ${plan.subject} · ${plan.reviewStatus.name}'
            '${unit == null ? '' : ' · ${unit.title}'}',
          ),
          trailing: _canLead
              ? TextButton(
                  onPressed: () => _reviewPlan(plan),
                  child: const Text('Review'),
                )
              : null,
        ),
      ),
    );
  }

  Widget _evaluationsTab() {
    final items = _curriculum.evaluationsForSchool(_schoolId);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Academic-only scores (curriculum fidelity, planning, assessment '
          'alignment). No salary, HR, or payroll fields.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (_canLead)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _recordEvaluation,
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Record evaluation'),
            ),
          ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _empty('No academic evaluations yet.')
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DecoratedBox(
                decoration: WebErpTheme.cardDecoration(context),
                child: ListTile(
                  title: Text('${item.teacherName} · ${item.periodLabel}'),
                  subtitle: Text(
                    'Fidelity ${item.curriculumFidelity}/5 · '
                    'Planning ${item.planningQuality}/5 · '
                    'Alignment ${item.assessmentAlignment}/5 · '
                    'avg ${item.average.toStringAsFixed(1)}'
                    '${item.notes.isEmpty ? '' : '\n${item.notes}'}',
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _feedbackTab() {
    final items = _curriculum.feedbackForSchool(_schoolId);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => showCurriculumFeedbackDialog(context),
            icon: const Icon(Icons.comment_outlined),
            label: const Text('Add feedback'),
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _empty('No curriculum feedback yet.')
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DecoratedBox(
                decoration: WebErpTheme.cardDecoration(context),
                child: ListTile(
                  title: Text(
                    '${item.authorRole} · ${item.authorName ?? item.authorUsername}'
                    '${item.rating == null ? '' : ' · ${item.rating}/5'}',
                  ),
                  subtitle: Text(
                    '${_curriculum.unitById(item.curriculumUnitId)?.title ?? item.curriculumUnitId}\n${item.body}',
                  ),
                  trailing: _canLead && item.status == CurriculumFeedbackStatus.open
                      ? TextButton(
                          onPressed: () => _curriculum.setFeedbackStatus(
                            item.id,
                            CurriculumFeedbackStatus.acknowledged,
                          ),
                          child: const Text('Acknowledge'),
                        )
                      : Text(item.status.name),
                ),
              ),
            ),
      ],
    );
  }

  Widget _meetingsTab() {
    final items = _curriculum.meetingsForSchool(_schoolId);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_canLead)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _recordMeeting,
              icon: const Icon(Icons.event_outlined),
              label: const Text('Add meeting notes'),
            ),
          ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _empty('No academic meetings recorded.')
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DecoratedBox(
                decoration: WebErpTheme.cardDecoration(context),
                child: ListTile(
                  title: Text(item.title),
                  subtitle: Text(
                    '${item.startsAt.day}/${item.startsAt.month}/${item.startsAt.year}'
                    '${item.agenda.isEmpty ? '' : ' · ${item.agenda}'}'
                    '${item.notes.isEmpty ? '' : '\n${item.notes}'}',
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _empty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: WebErpTheme.cardDecoration(context),
      child: Text(text),
    );
  }

  Future<void> _editUnit([CurriculumUnit? existing]) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _UnitEditorDialog(
        existing: existing,
        classes: _classes,
        subjects: _subjects,
      ),
    );
  }

  Future<void> _reviewPlan(LessonPlan plan) async {
    final notes = TextEditingController();
    final decision = await showDialog<LessonPlanReviewDecision>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Review ${plan.title}'),
        content: TextField(
          controller: notes,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Notes for the teacher',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              LessonPlanReviewDecision.changesRequested,
            ),
            child: const Text('Request changes'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, LessonPlanReviewDecision.approved),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    final text = notes.text;
    notes.dispose();
    if (decision == null) return;
    await _curriculum.reviewLessonPlan(
      lessonPlanId: plan.id,
      decision: decision,
      notes: text,
      curriculumUnitId: plan.curriculumUnitId,
    );
  }

  Future<void> _recordEvaluation() async {
    final teachers = TeacherRegistryService.instance.teachersForSchool(_schoolId);
    if (teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add teachers in HR before recording an evaluation.')),
      );
      return;
    }
    var teacherId = teachers.first.teacherId;
    var fidelity = 3;
    var planning = 3;
    var alignment = 3;
    final period = TextEditingController(text: 'Term 1');
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Academic evaluation'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey('te-$teacherId'),
                    initialValue: teacherId,
                    decoration: const InputDecoration(labelText: 'Teacher'),
                    items: [
                      for (final t in teachers)
                        DropdownMenuItem(
                          value: t.teacherId,
                          child: Text(t.fullName),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => teacherId = v ?? teacherId),
                  ),
                  TextField(
                    controller: period,
                    decoration: const InputDecoration(labelText: 'Period'),
                  ),
                  _scoreSlider('Curriculum fidelity', fidelity, (v) {
                    setLocal(() => fidelity = v);
                  }),
                  _scoreSlider('Planning quality', planning, (v) {
                    setLocal(() => planning = v);
                  }),
                  _scoreSlider('Assessment alignment', alignment, (v) {
                    setLocal(() => alignment = v);
                  }),
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
              ),
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
      ),
    );
    final periodText = period.text;
    final notesText = notes.text;
    period.dispose();
    notes.dispose();
    if (ok != true) return;
    final teacher = teachers.firstWhere((t) => t.teacherId == teacherId);
    await _curriculum.recordEvaluation(
      teacherId: teacher.teacherId,
      teacherName: teacher.fullName,
      teacherUsername: teacher.loginUsername,
      periodLabel: periodText,
      curriculumFidelity: fidelity,
      planningQuality: planning,
      assessmentAlignment: alignment,
      notes: notesText,
    );
  }

  Widget _scoreSlider(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value / 5'),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  Future<void> _recordMeeting() async {
    final title = TextEditingController();
    final agenda = TextEditingController();
    final notes = TextEditingController();
    var starts = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Academic meeting'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Starts'),
                  subtitle: Text(
                    '${starts.day}/${starts.month}/${starts.year} ${starts.hour}:${starts.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final day = await showDatePicker(
                        context: context,
                        initialDate: starts,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (day == null || !context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(starts),
                      );
                      setLocal(() {
                        starts = DateTime(
                          day.year,
                          day.month,
                          day.day,
                          time?.hour ?? starts.hour,
                          time?.minute ?? starts.minute,
                        );
                      });
                    },
                    child: const Text('Change'),
                  ),
                ),
                TextField(
                  controller: agenda,
                  decoration: const InputDecoration(labelText: 'Agenda'),
                ),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
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
      ),
    );
    final titleText = title.text;
    final agendaText = agenda.text;
    final notesText = notes.text;
    title.dispose();
    agenda.dispose();
    notes.dispose();
    if (ok != true || titleText.trim().isEmpty) return;
    await _curriculum.recordMeeting(
      title: titleText,
      startsAt: starts,
      agenda: agendaText,
      notes: notesText,
    );
  }
}

class _UnitEditorDialog extends StatefulWidget {
  const _UnitEditorDialog({
    required this.classes,
    required this.subjects,
    this.existing,
  });

  final CurriculumUnit? existing;
  final List<String> classes;
  final List<String> subjects;

  @override
  State<_UnitEditorDialog> createState() => _UnitEditorDialogState();
}

class _UnitEditorDialogState extends State<_UnitEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _strand;
  late final TextEditingController _objectives;
  late final TextEditingController _description;
  late final TextEditingController _standards;
  late String _subject;
  String? _className;
  late CurriculumFramework _framework;
  late Set<String> _papers;
  late Set<String> _homework;
  late List<String> _attachments;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _title = TextEditingController(text: u?.title ?? '');
    _strand = TextEditingController(text: u?.strand ?? '');
    _objectives = TextEditingController(text: u?.objectives ?? '');
    _description = TextEditingController(text: u?.description ?? '');
    _standards = TextEditingController(text: u?.standardCodes.join(', ') ?? '');
    _subject = u?.subject ??
        (widget.subjects.contains('Science')
            ? 'Science'
            : widget.subjects.firstOrNull ?? 'Science');
    _className = u?.className;
    _framework = u?.framework ?? CurriculumFramework.national;
    _papers = {...?u?.examPaperIds};
    _homework = {...?u?.homeworkIds};
    _attachments = List<String>.from(u?.attachmentPaths ?? const []);
  }

  @override
  void dispose() {
    _title.dispose();
    _strand.dispose();
    _objectives.dispose();
    _description.dispose();
    _standards.dispose();
    super.dispose();
  }

  List<String> get _standardList => _standards.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.')),
      );
      return;
    }
    if (widget.existing == null) {
      await CurriculumService.instance.createUnit(
        title: title,
        subject: _subject,
        className: _className,
        gradeLevel: _className,
        strand: _strand.text,
        description: _description.text,
        objectives: _objectives.text,
        framework: _framework,
        standardCodes: _standardList,
        examPaperIds: _papers.toList(),
        homeworkIds: _homework.toList(),
        attachmentPaths: _attachments,
      );
    } else {
      await CurriculumService.instance.updateUnit(
        widget.existing!.id,
        title: title,
        subject: _subject,
        className: _className,
        gradeLevel: _className,
        strand: _strand.text,
        description: _description.text,
        objectives: _objectives.text,
        framework: _framework,
        standardCodes: _standardList,
        examPaperIds: _papers.toList(),
        homeworkIds: _homework.toList(),
        attachmentPaths: _attachments,
        note: 'Edited from curriculum office',
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final papers = ExamService.instance.papersForSchool();
    final homework = SchoolDataService.instance.homeworkSnapshot();
    return AlertDialog(
      title: Text(widget.existing == null ? 'New curriculum unit' : 'Edit unit'),
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
                key: ValueKey('cu-subject-$_subject'),
                initialValue:
                    widget.subjects.contains(_subject) ? _subject : null,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: [
                  for (final name in widget.subjects)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) => setState(() => _subject = v ?? _subject),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                key: ValueKey('cu-class-$_className'),
                initialValue: _className,
                decoration: const InputDecoration(
                  labelText: 'Class (optional — blank is school-wide)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All classes'),
                  ),
                  for (final name in widget.classes)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) => setState(() => _className = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<CurriculumFramework>(
                key: ValueKey('cu-fw-${_framework.name}'),
                initialValue: _framework,
                decoration: const InputDecoration(labelText: 'Framework'),
                items: const [
                  DropdownMenuItem(
                    value: CurriculumFramework.national,
                    child: Text('National'),
                  ),
                  DropdownMenuItem(
                    value: CurriculumFramework.international,
                    child: Text('International'),
                  ),
                  DropdownMenuItem(
                    value: CurriculumFramework.school,
                    child: Text('School'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _framework = v ?? _framework),
              ),
              TextField(
                controller: _strand,
                decoration: const InputDecoration(labelText: 'Strand'),
              ),
              TextField(
                controller: _standards,
                decoration: const InputDecoration(
                  labelText: 'Standard codes (comma-separated)',
                ),
              ),
              TextField(
                controller: _objectives,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Objectives'),
              ),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              CourseAttachmentPicker(
                paths: _attachments,
                subdir: 'curriculum_attachments',
                sectionTitle: 'Course files',
                onChanged: (next) => setState(() => _attachments = next),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Linked assessments (ids only — does not score)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final p in papers.where((p) => p.subject == _subject).take(20))
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
              for (final h in homework.where((h) => h.subject == _subject).take(20))
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

Future<void> showCurriculumFeedbackDialog(
  BuildContext context, {
  String? unitId,
}) async {
  await CurriculumService.instance.ensureLoaded();
  if (!context.mounted) return;
  final units = CurriculumService.instance
      .unitsForSchool()
      .where((u) => u.isPublished || ModuleAccess.canManage('curriculum'))
      .toList();
  if (units.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Publish a curriculum unit before adding feedback.')),
    );
    return;
  }
  var selected = unitId ?? units.first.id;
  if (!units.any((u) => u.id == selected)) selected = units.first.id;
  final body = TextEditingController();
  var rating = 4;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: const Text('Curriculum feedback'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('cf-$selected'),
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: [
                  for (final u in units)
                    DropdownMenuItem(value: u.id, child: Text(u.title)),
                ],
                onChanged: (v) => setLocal(() => selected = v ?? selected),
              ),
              Text('$rating / 5'),
              Slider(
                value: rating.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: (v) => setLocal(() => rating = v.round()),
              ),
              TextField(
                controller: body,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Comment'),
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
            child: const Text('Submit'),
          ),
        ],
      ),
    ),
  );
  final text = body.text;
  body.dispose();
  if (ok != true || text.trim().isEmpty) return;
  await CurriculumService.instance.addFeedback(
    curriculumUnitId: selected,
    body: text,
    rating: rating,
  );
}
