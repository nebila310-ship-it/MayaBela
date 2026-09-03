import 'package:flutter/material.dart';

import 'package:mayabela/constants/school_subjects.dart';
import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/markbook_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// Staff exam desk: question bank, papers, and scoring that writes Phase B.
class WebExamDeskPage extends StatefulWidget {
  const WebExamDeskPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebExamDeskPage> createState() => _WebExamDeskPageState();
}

class _WebExamDeskPageState extends State<WebExamDeskPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _exams = ExamService.instance;
  String? _bankSubject;
  String? _scorePaperId;

  bool get _canManage => ModuleAccess.canManage('exam_bank');
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
    final fromBank = _exams.questionsForSchool(_schoolId).map((q) => q.subject);
    final list = {...fromBank, ...SchoolSubjects.all}.toList()..sort();
    return list;
  }

  List<AssessmentCategory> get _examCategories {
    final cats = MarkbookService.instance.settingsForSchool().categories;
    final allowed = {'quiz', 'midterm', 'final'};
    final filtered = cats.where((c) => allowed.contains(c.id)).toList();
    return filtered.isEmpty
        ? const [
            AssessmentCategory(id: 'quiz', label: 'Quizzes', weightPercent: 15),
            AssessmentCategory(
              id: 'midterm',
              label: 'Midterm',
              weightPercent: 25,
            ),
            AssessmentCategory(
              id: 'final',
              label: 'Final exam',
              weightPercent: 35,
            ),
          ]
        : filtered;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _exams.ensureLoaded();
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
      listenable: _exams,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                narrow ? 12 : 20,
                narrow ? 12 : 20,
                narrow ? 12 : 20,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exam bank & papers',
                    style: WebErpTheme.sectionTitle(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Build questions, publish a paper onto a class, score '
                    'short/essay answers, then push the percent into the '
                    'weighted markbook (quiz, midterm, or final). Parents still '
                    'see numbers only after the existing grade approval chain.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabs: [
                      const Tab(text: 'Question bank'),
                      const Tab(text: 'Papers'),
                      Tab(
                        text: _exams.unscoredCount(_schoolId) == 0
                            ? 'Scoring desk'
                            : 'Scoring desk (${_exams.unscoredCount(_schoolId)})',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _bankTab(narrow),
                  _papersTab(narrow),
                  _scoringTab(narrow),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bankTab(bool narrow) {
    var questions = _exams.questionsForSchool(_schoolId);
    if (_bankSubject != null) {
      questions =
          questions.where((q) => q.subject == _bankSubject).toList();
    }
    return ListView(
      padding: EdgeInsets.all(narrow ? 12 : 20),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_canManage)
              FilledButton.icon(
                onPressed: () => _editQuestion(),
                icon: const Icon(Icons.add),
                label: const Text('New question'),
              ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                key: ValueKey('bank-subject-$_bankSubject'),
                initialValue: _bankSubject,
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
                onChanged: (v) => setState(() => _bankSubject = v),
              ),
            ),
            TextButton(
              onPressed: () => widget.onNavigate?.call('markbook'),
              child: const Text('Open markbook'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (questions.isEmpty)
          _emptyCard('No questions in the bank yet. Add an MCQ, short answer, or essay.')
        else
          for (final question in questions)
            _card(
              child: ListTile(
                title: Text(question.prompt),
                subtitle: Text(
                  '${question.subject} · ${_typeLabel(question.type)} · '
                  '${question.points.toStringAsFixed(0)} pts · ${question.id}',
                ),
                trailing: _canManage
                    ? IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editQuestion(question),
                      )
                    : null,
              ),
            ),
      ],
    );
  }

  Widget _papersTab(bool narrow) {
    final papers = _exams.papersForSchool(_schoolId);
    return ListView(
      padding: EdgeInsets.all(narrow ? 12 : 20),
      children: [
        if (_canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _editPaper(),
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('New paper'),
            ),
          ),
        const SizedBox(height: 14),
        if (papers.isEmpty)
          _emptyCard('Compose a paper from the bank, pick a class and markbook category, then publish.')
        else
          for (final paper in papers)
            _card(
              child: ListTile(
                title: Text(paper.title),
                subtitle: Text(
                  '${paper.className} · ${paper.subject} · '
                  '${_categoryLabel(paper.markbookCategoryId)} · '
                  '${paper.questionIds.length} questions · ${_statusLabel(paper.status)}',
                ),
                trailing: _canManage
                    ? Wrap(
                        spacing: 4,
                        children: [
                          if (paper.status == ExamPaperStatus.draft)
                            TextButton(
                              onPressed: () => _exams.setPaperStatus(
                                paper.id,
                                ExamPaperStatus.published,
                              ),
                              child: const Text('Publish'),
                            ),
                          if (paper.status == ExamPaperStatus.published)
                            TextButton(
                              onPressed: () => _exams.setPaperStatus(
                                paper.id,
                                ExamPaperStatus.closed,
                              ),
                              child: const Text('Close'),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editPaper(paper),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
      ],
    );
  }

  Widget _scoringTab(bool narrow) {
    final papers = _exams.papersForSchool(_schoolId);
    var attempts = _scorePaperId == null
        ? _exams.attempts
            .where((a) => _schoolId.isEmpty || a.schoolId == _schoolId.toUpperCase())
            .toList()
        : _exams.attemptsForPaper(_scorePaperId!);
    attempts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return ListView(
      padding: EdgeInsets.all(narrow ? 12 : 20),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: DropdownButtonFormField<String?>(
                key: ValueKey('score-paper-$_scorePaperId'),
                initialValue: _scorePaperId,
                decoration: const InputDecoration(
                  labelText: 'Paper',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All papers'),
                  ),
                  for (final paper in papers)
                    DropdownMenuItem(
                      value: paper.id,
                      child: Text('${paper.title} (${paper.className})'),
                    ),
                ],
                onChanged: (v) => setState(() => _scorePaperId = v),
              ),
            ),
            if (_canManage && _scorePaperId != null)
              FilledButton.tonal(
                onPressed: () {
                  final n = _exams.pushScoredAttemptsToMarkbook(_scorePaperId!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        n == 0
                            ? 'No scored attempts could be written (locked grades stay skipped).'
                            : 'Pushed $n score(s) into the markbook as drafts.',
                      ),
                    ),
                  );
                },
                child: const Text('Push scored to markbook'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (attempts.isEmpty)
          _emptyCard('No attempts yet. Students sit a published paper, or a teacher can start one from the mobile exam tile.')
        else
          for (final attempt in attempts)
            _card(
              child: ListTile(
                title: Text(attempt.studentName),
                subtitle: Text(
                  '${_exams.paperById(attempt.paperId)?.title ?? attempt.paperId} · '
                  '${attempt.status.name} · '
                  '${attempt.awardedPoints.toStringAsFixed(0)} / '
                  '${attempt.maxPoints.toStringAsFixed(0)} '
                  '(${attempt.percent.toStringAsFixed(1)}%)'
                  '${attempt.pushedToMarkbook ? ' · in markbook' : ''}',
                ),
                trailing: _canManage
                    ? Wrap(
                        spacing: 4,
                        children: [
                          if (attempt.needsManualScore ||
                              attempt.status == ExamAttemptStatus.scored)
                            TextButton(
                              onPressed: () => _scoreAttempt(attempt),
                              child: Text(
                                attempt.needsManualScore ? 'Score' : 'Review',
                              ),
                            ),
                          if (attempt.status == ExamAttemptStatus.scored &&
                              !attempt.pushedToMarkbook)
                            TextButton(
                              onPressed: () {
                                final ok = _exams.pushAttemptToMarkbook(attempt.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Saved ${attempt.percent.toStringAsFixed(1)}% as a draft markbook score.'
                                          : 'Could not write — grade may be locked pending approval.',
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Push'),
                            ),
                        ],
                      )
                    : null,
              ),
            ),
      ],
    );
  }

  Future<void> _editQuestion([ExamQuestion? existing]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _QuestionEditorDialog(
        existing: existing,
        subjects: _subjects,
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _editPaper([ExamPaper? existing]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _PaperEditorDialog(
        existing: existing,
        classes: _classes,
        subjects: _subjects,
        categories: _examCategories,
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _scoreAttempt(ExamAttempt attempt) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _AttemptScoreDialog(attemptId: attempt.id),
    );
  }

  Widget _card({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: WebErpTheme.cardDecoration(context),
        child: child,
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: WebErpTheme.cardDecoration(context),
      child: Text(text),
    );
  }

  static String _typeLabel(ExamQuestionType type) => switch (type) {
        ExamQuestionType.mcq => 'MCQ',
        ExamQuestionType.shortAnswer => 'Short answer',
        ExamQuestionType.essay => 'Essay',
      };

  String _categoryLabel(String id) {
    for (final cat in _examCategories) {
      if (cat.id == id) return cat.label;
    }
    return id;
  }

  static String _statusLabel(ExamPaperStatus status) => switch (status) {
        ExamPaperStatus.draft => 'Draft',
        ExamPaperStatus.published => 'Published',
        ExamPaperStatus.closed => 'Closed',
      };
}

class _QuestionEditorDialog extends StatefulWidget {
  const _QuestionEditorDialog({
    required this.subjects,
    this.existing,
  });

  final ExamQuestion? existing;
  final List<String> subjects;

  @override
  State<_QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<_QuestionEditorDialog> {
  late final TextEditingController _prompt;
  late final TextEditingController _points;
  late final List<TextEditingController> _choices;
  late String _subject;
  late ExamQuestionType _type;
  String? _correctId;

  @override
  void initState() {
    super.initState();
    final q = widget.existing;
    _subject = q?.subject ??
        (widget.subjects.contains('Science')
            ? 'Science'
            : widget.subjects.firstOrNull ?? 'Science');
    _type = q?.type ?? ExamQuestionType.mcq;
    _prompt = TextEditingController(text: q?.prompt ?? '');
    _points = TextEditingController(
      text: (q?.points ?? 1).toStringAsFixed(0),
    );
    final existingChoices = q?.choices ?? const <ExamChoice>[];
    _choices = [
      for (var i = 0; i < 4; i++)
        TextEditingController(
          text: i < existingChoices.length ? existingChoices[i].text : '',
        ),
    ];
    _correctId = q?.correctChoiceId ?? 'A';
  }

  @override
  void dispose() {
    _prompt.dispose();
    _points.dispose();
    for (final c in _choices) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final prompt = _prompt.text.trim();
    final points = double.tryParse(_points.text.trim()) ?? 1;
    if (prompt.isEmpty) return;
    final choices = <ExamChoice>[];
    if (_type == ExamQuestionType.mcq) {
      const ids = ['A', 'B', 'C', 'D'];
      for (var i = 0; i < ids.length; i++) {
        final text = _choices[i].text.trim();
        if (text.isEmpty) continue;
        choices.add(ExamChoice(id: ids[i], text: text));
      }
      if (choices.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least two MCQ choices.')),
        );
        return;
      }
    }
    if (widget.existing == null) {
      await ExamService.instance.createQuestion(
        subject: _subject,
        prompt: prompt,
        type: _type,
        points: points,
        choices: choices,
        correctChoiceId: _type == ExamQuestionType.mcq ? _correctId : null,
      );
    } else {
      await ExamService.instance.updateQuestion(
        widget.existing!.id,
        subject: _subject,
        prompt: prompt,
        points: points,
        choices: choices,
        correctChoiceId: _type == ExamQuestionType.mcq ? _correctId : null,
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New question' : 'Edit question'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('q-subject-$_subject'),
                initialValue: widget.subjects.contains(_subject) ? _subject : null,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: [
                  for (final name in widget.subjects)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) => setState(() => _subject = v ?? _subject),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ExamQuestionType>(
                key: ValueKey('q-type-$_type'),
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                    value: ExamQuestionType.mcq,
                    child: Text('Multiple choice'),
                  ),
                  DropdownMenuItem(
                    value: ExamQuestionType.shortAnswer,
                    child: Text('Short answer'),
                  ),
                  DropdownMenuItem(
                    value: ExamQuestionType.essay,
                    child: Text('Essay'),
                  ),
                ],
                onChanged: widget.existing == null
                    ? (v) => setState(() => _type = v ?? _type)
                    : null,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _prompt,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Prompt'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _points,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Points'),
              ),
              if (_type == ExamQuestionType.mcq) ...[
                const SizedBox(height: 12),
                for (var i = 0; i < 4; i++)
                  RadioListTile<String>(
                    dense: true,
                    value: const ['A', 'B', 'C', 'D'][i],
                    groupValue: _correctId,
                    onChanged: (v) => setState(() => _correctId = v),
                    title: TextField(
                      controller: _choices[i],
                      decoration: InputDecoration(
                        labelText: 'Choice ${const ['A', 'B', 'C', 'D'][i]}',
                      ),
                    ),
                  ),
                const Text('Select the radio next to the correct choice.'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _PaperEditorDialog extends StatefulWidget {
  const _PaperEditorDialog({
    required this.classes,
    required this.subjects,
    required this.categories,
    this.existing,
  });

  final ExamPaper? existing;
  final List<String> classes;
  final List<String> subjects;
  final List<AssessmentCategory> categories;

  @override
  State<_PaperEditorDialog> createState() => _PaperEditorDialogState();
}

class _PaperEditorDialogState extends State<_PaperEditorDialog> {
  late final TextEditingController _title;
  late String _className;
  late String _subject;
  late String _categoryId;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _title = TextEditingController(text: p?.title ?? '');
    _className = p?.className ?? widget.classes.firstOrNull ?? '';
    _subject = p?.subject ??
        (widget.subjects.contains('Science')
            ? 'Science'
            : widget.subjects.firstOrNull ?? 'Science');
    _categoryId = p?.markbookCategoryId ?? 'final';
    if (!widget.categories.any((c) => c.id == _categoryId) &&
        widget.categories.isNotEmpty) {
      _categoryId = widget.categories.first.id;
    }
    _selected = {...?p?.questionIds};
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _className.isEmpty || _selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title, class, and at least one question are required.')),
      );
      return;
    }
    if (widget.existing == null) {
      await ExamService.instance.createPaper(
        title: title,
        className: _className,
        subject: _subject,
        questionIds: _selected.toList(),
        markbookCategoryId: _categoryId,
      );
    } else {
      await ExamService.instance.updatePaper(
        widget.existing!.id,
        title: title,
        questionIds: _selected.toList(),
        markbookCategoryId: _categoryId,
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final questions = ExamService.instance
        .questionsForSchool()
        .where((q) => q.subject == _subject)
        .toList();
    return AlertDialog(
      title: Text(widget.existing == null ? 'New paper' : 'Edit paper'),
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
                key: ValueKey('paper-class-$_className'),
                initialValue:
                    widget.classes.contains(_className) ? _className : null,
                decoration: const InputDecoration(labelText: 'Class'),
                items: [
                  for (final name in widget.classes)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: widget.existing == null
                    ? (v) => setState(() => _className = v ?? _className)
                    : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('paper-subject-$_subject'),
                initialValue:
                    widget.subjects.contains(_subject) ? _subject : null,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: [
                  for (final name in widget.subjects)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: widget.existing == null
                    ? (v) => setState(() {
                          _subject = v ?? _subject;
                          _selected.clear();
                        })
                    : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('paper-cat-$_categoryId'),
                initialValue: widget.categories.any((c) => c.id == _categoryId)
                    ? _categoryId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Markbook category',
                ),
                items: [
                  for (final cat in widget.categories)
                    DropdownMenuItem(value: cat.id, child: Text(cat.label)),
                ],
                onChanged: (v) => setState(() => _categoryId = v ?? _categoryId),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Questions',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (questions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No bank questions for this subject yet.'),
                )
              else
                for (final q in questions)
                  CheckboxListTile(
                    dense: true,
                    value: _selected.contains(q.id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selected.add(q.id);
                      } else {
                        _selected.remove(q.id);
                      }
                    }),
                    title: Text(q.prompt, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${_WebExamDeskPageState._typeLabel(q.type)} · ${q.points.toStringAsFixed(0)} pts',
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _AttemptScoreDialog extends StatefulWidget {
  const _AttemptScoreDialog({required this.attemptId});

  final String attemptId;

  @override
  State<_AttemptScoreDialog> createState() => _AttemptScoreDialogState();
}

class _AttemptScoreDialogState extends State<_AttemptScoreDialog> {
  final _controllers = <String, TextEditingController>{};

  ExamAttempt? get _attempt =>
      ExamService.instance.attemptById(widget.attemptId);

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(ExamAnswer answer) {
    return _controllers.putIfAbsent(
      answer.questionId,
      () => TextEditingController(
        text: answer.pointsAwarded == null
            ? ''
            : answer.pointsAwarded!.toStringAsFixed(0),
      ),
    );
  }

  Future<void> _save() async {
    final attempt = _attempt;
    if (attempt == null) return;
    final paper = ExamService.instance.paperById(attempt.paperId);
    final questions = paper == null
        ? const <ExamQuestion>[]
        : ExamService.instance.questionsOnPaper(paper);
    for (final q in questions) {
      if (q.isMcq) continue;
      final raw = _ctrl(
        attempt.answers.cast<ExamAnswer?>().firstWhere(
              (a) => a?.questionId == q.id,
              orElse: () => ExamAnswer(questionId: q.id),
            )!,
      ).text.trim();
      if (raw.isEmpty) continue;
      final points = double.tryParse(raw);
      if (points == null) continue;
      await ExamService.instance.awardPoints(
        attemptId: attempt.id,
        questionId: q.id,
        points: points.clamp(0, q.points),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final attempt = _attempt;
    if (attempt == null) {
      return const AlertDialog(content: Text('Attempt not found.'));
    }
    final paper = ExamService.instance.paperById(attempt.paperId);
    final questions = paper == null
        ? const <ExamQuestion>[]
        : ExamService.instance.questionsOnPaper(paper);
    return AlertDialog(
      title: Text('Score ${attempt.studentName}'),
      content: SizedBox(
        width: 520,
        child: ListenableBuilder(
          listenable: ExamService.instance,
          builder: (context, _) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${paper?.title ?? attempt.paperId} · '
                    '${attempt.percent.toStringAsFixed(1)}%',
                  ),
                  const SizedBox(height: 12),
                  for (final q in questions)
                    _answerBlock(q, attempt),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save scores')),
      ],
    );
  }

  Widget _answerBlock(ExamQuestion question, ExamAttempt attempt) {
    final answer = attempt.answers.cast<ExamAnswer?>().firstWhere(
          (a) => a?.questionId == question.id,
          orElse: () => null,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.prompt,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            question.isMcq
                ? 'Choice: ${answer?.choiceId ?? '—'} · '
                    'Awarded ${answer?.pointsAwarded?.toStringAsFixed(0) ?? '—'} / '
                    '${question.points.toStringAsFixed(0)}'
                : 'Answer: ${answer?.text?.trim().isNotEmpty == true ? answer!.text : '—'}',
          ),
          if (!question.isMcq) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _ctrl(answer ?? ExamAnswer(questionId: question.id)),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Points (max ${question.points.toStringAsFixed(0)})',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
