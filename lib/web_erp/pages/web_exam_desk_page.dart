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
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/widgets/course_attachment_picker.dart';
import 'package:mayabela/widgets/student_photo_avatar.dart';

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
  String? _bankCategory;
  String? _paperCategory;
  String? _vaultCategory;
  String? _scorePaperId;
  ExamKind? _kindFilter;
  bool _showHistory = false;
  String _vaultKind = 'all';

  bool get _teacherScoped => AuthService.isClassroomTeacher;
  bool get _canManage =>
      ModuleAccess.canManage('exam_bank') || _teacherScoped;
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
      final names = <String>{
        ..._exams.questionsForTeacher(null, _schoolId).map((q) => q.subject),
      };
      for (final className in _classes) {
        names.addAll(TeacherAccessService.instance.teachableSubjects(className));
      }
      if (names.isNotEmpty) return names.toList()..sort();
    }
    final fromBank = _exams.questionsForSchool(_schoolId).map((q) => q.subject);
    final list = {...fromBank, ...SchoolSubjects.all}.toList()..sort();
    return list;
  }

  List<String> get _mineCategories => _exams.bankCategories(
        schoolId: _schoolId,
        mineOnly: _teacherScoped,
      );

  List<String> get _vaultCategories => _exams.bankCategories(
        schoolId: _schoolId,
        vaultOnly: true,
      );

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
    _tabs = TabController(length: 4, vsync: this);
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
                    _teacherScoped
                        ? 'Keep questions and papers in your own categorized '
                            'list. Share a copy into the school vault so other '
                            'teachers can open and reuse it. Scoring still writes '
                            'the markbook; parents see numbers only after approval.'
                        : 'Build questions, publish a paper onto a class, score '
                            'short/essay answers, then push the percent into the '
                            'weighted markbook (quiz, midterm, or final). The '
                            'school vault holds papers teachers chose to share. '
                            'Parents still see numbers only after grade approval.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabs: [
                      Tab(
                        text: _teacherScoped ? 'My question bank' : 'Question bank',
                      ),
                      Tab(text: _teacherScoped ? 'My papers' : 'Papers'),
                      const Tab(text: 'School vault'),
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
                  _vaultTab(narrow),
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
    var questions = _teacherScoped
        ? _exams.questionsForTeacher(null, _schoolId)
        : _exams.questionsForSchool(_schoolId);
    if (_bankSubject != null) {
      questions =
          questions.where((q) => q.subject == _bankSubject).toList();
    }
    if (_bankCategory != null) {
      questions = questions
          .where((q) => q.category.trim() == _bankCategory)
          .toList();
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
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                key: ValueKey('bank-cat-$_bankCategory'),
                initialValue: _bankCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All categories'),
                  ),
                  for (final name in _mineCategories)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) => setState(() => _bankCategory = v),
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
          _emptyCard(
            _teacherScoped
                ? 'Your question list is empty. Add an MCQ, short answer, or essay and file it under a category.'
                : 'No questions in the bank yet. Add an MCQ, short answer, or essay.',
          )
        else
          for (final question in questions)
            _card(
              child: ListTile(
                title: Text(question.prompt),
                subtitle: Text(
                  '${question.subject} · ${_categoryOrUnfiled(question.category)} · '
                  '${_typeLabel(question.type)} · '
                  '${question.points.toStringAsFixed(0)} pts · '
                  '${_accessLabel(question.vaultAccess)} · ${question.id}'
                  '${question.attachmentPaths.isEmpty ? '' : ' · ${question.attachmentPaths.length} file(s)'}',
                ),
                trailing: _exams.canEditQuestion(question)
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
    final now = DateTime.now();
    var papers = _teacherScoped
        ? _exams.papersForTeacher(null, _schoolId)
        : _exams.papersForSchool(_schoolId);
    if (_kindFilter != null) {
      papers = papers.where((p) => p.kind == _kindFilter).toList();
    }
    if (_paperCategory != null) {
      papers = papers
          .where((p) => p.category.trim() == _paperCategory)
          .toList();
    }
    papers = papers
        .where((p) => _showHistory ? p.isHistoricalAt(now) : !p.isHistoricalAt(now))
        .toList();
    return ListView(
      padding: EdgeInsets.all(narrow ? 12 : 20),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_canManage)
              FilledButton.icon(
                onPressed: () => _editPaper(),
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('New paper'),
              ),
            FilterChip(
              label: const Text('All kinds'),
              selected: _kindFilter == null,
              onSelected: (_) => setState(() => _kindFilter = null),
            ),
            FilterChip(
              label: const Text('School'),
              selected: _kindFilter == ExamKind.school,
              onSelected: (_) => setState(() => _kindFilter = ExamKind.school),
            ),
            FilterChip(
              label: const Text('National'),
              selected: _kindFilter == ExamKind.national,
              onSelected: (_) => setState(() => _kindFilter = ExamKind.national),
            ),
            FilterChip(
              label: const Text('Model'),
              selected: _kindFilter == ExamKind.model,
              onSelected: (_) => setState(() => _kindFilter = ExamKind.model),
            ),
            FilterChip(
              label: const Text('History'),
              selected: _showHistory,
              onSelected: (v) => setState(() => _showHistory = v),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                key: ValueKey('paper-list-cat-$_paperCategory'),
                initialValue: _paperCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All categories'),
                  ),
                  for (final name in _mineCategories)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) => setState(() => _paperCategory = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (papers.isEmpty)
          _emptyCard(
            _showHistory
                ? 'No closed or expired papers in the historical repository yet.'
                : _teacherScoped
                    ? 'Compose a paper from your bank, file it in a category, and optionally share it to the school vault.'
                    : 'Compose a paper from the bank, pick a class and markbook category, then publish.',
          )
        else
          for (final paper in papers)
            _card(
              child: ListTile(
                title: Text(paper.title),
                subtitle: Text(
                  '${paper.className} · ${paper.subject} · '
                  '${_categoryOrUnfiled(paper.category)} · '
                  '${_accessLabel(paper.vaultAccess)} · '
                  '${_kindLabel(paper.kind)} · ${_sittingLabel(paper.sittingMode)} · '
                  '${_categoryLabel(paper.markbookCategoryId)} · '
                  '${paper.questionIds.length} questions · ${_statusLabel(paper.status)}'
                  '${_windowLabel(paper)}'
                  '${paper.attachmentPaths.isEmpty ? '' : ' · ${paper.attachmentPaths.length} file(s)'}',
                ),
                trailing: _exams.canEditPaper(paper)
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
                          TextButton(
                            onPressed: () async {
                              await _exams.duplicatePaper(paper.id);
                              if (mounted) setState(() {});
                            },
                            child: const Text('Template'),
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

  Widget _vaultTab(bool narrow) {
    var questions = _exams.vaultQuestions(_schoolId);
    var papers = _exams.vaultPapers(_schoolId);
    if (_vaultCategory != null) {
      questions = questions
          .where((q) => q.category.trim() == _vaultCategory)
          .toList();
      papers = papers
          .where((p) => p.category.trim() == _vaultCategory)
          .toList();
    }
    final showQuestions = _vaultKind != 'papers';
    final showPapers = _vaultKind != 'questions';
    return ListView(
      padding: EdgeInsets.all(narrow ? 12 : 20),
      children: [
        Text(
          'Every teacher’s shared exams live here. Copy an item into your own '
          'list to edit it; the original stays with its author.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              label: const Text('All'),
              selected: _vaultKind == 'all',
              onSelected: (_) => setState(() => _vaultKind = 'all'),
            ),
            FilterChip(
              label: const Text('Questions'),
              selected: _vaultKind == 'questions',
              onSelected: (_) => setState(() => _vaultKind = 'questions'),
            ),
            FilterChip(
              label: const Text('Papers'),
              selected: _vaultKind == 'papers',
              onSelected: (_) => setState(() => _vaultKind = 'papers'),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                key: ValueKey('vault-cat-$_vaultCategory'),
                initialValue: _vaultCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All categories'),
                  ),
                  for (final name in _vaultCategories)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) => setState(() => _vaultCategory = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (showQuestions) ...[
          Text('Shared questions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (questions.isEmpty)
            _emptyCard('No shared questions in the vault yet.')
          else
            for (final question in questions)
              _card(
                child: ListTile(
                  title: Text(question.prompt),
                  subtitle: Text(
                    '${question.subject} · ${_categoryOrUnfiled(question.category)} · '
                    '${_typeLabel(question.type)} · '
                    'by ${question.createdBy ?? 'unknown'}',
                  ),
                  trailing: _canManage
                      ? TextButton(
                          onPressed: () async {
                            await _exams.copyQuestionToMyBank(question.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to your question bank.'),
                                ),
                              );
                            }
                          },
                          child: const Text('Copy to my list'),
                        )
                      : null,
                ),
              ),
          const SizedBox(height: 16),
        ],
        if (showPapers) ...[
          Text('Shared papers', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (papers.isEmpty)
            _emptyCard('No shared papers in the vault yet.')
          else
            for (final paper in papers)
              _card(
                child: ListTile(
                  title: Text(paper.title),
                  subtitle: Text(
                    '${paper.className} · ${paper.subject} · '
                    '${_categoryOrUnfiled(paper.category)} · '
                    '${_kindLabel(paper.kind)} · '
                    'by ${paper.createdBy ?? 'unknown'}',
                  ),
                  trailing: _canManage
                      ? TextButton(
                          onPressed: () async {
                            await _exams.copyPaperToMyBank(paper.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to your papers.'),
                                ),
                              );
                            }
                          },
                          child: const Text('Copy to my list'),
                        )
                      : null,
                ),
              ),
        ],
      ],
    );
  }

  Widget _scoringTab(bool narrow) {
    final papers = _teacherScoped
        ? () {
            final byId = <String, ExamPaper>{
              for (final paper in _exams.papersForTeacher(null, _schoolId))
                paper.id: paper,
            };
            for (final paper in _exams.papersForSchool(_schoolId)) {
              if (_exams.canEditPaper(paper) ||
                  TeacherAccessService.instance.assignmentFor(paper.className) !=
                      null) {
                byId[paper.id] = paper;
              }
            }
            return byId.values.toList();
          }()
        : _exams.papersForSchool(_schoolId);
    final selected =
        _scorePaperId == null ? null : _exams.paperById(_scorePaperId!);
    var attempts = _scorePaperId == null
        ? _exams.attempts
            .where((a) => _schoolId.isEmpty || a.schoolId == _schoolId.toUpperCase())
            .toList()
        : _exams.attemptsForPaper(_scorePaperId!);
    if (_teacherScoped) {
      attempts = attempts.where((a) {
        final paper = _exams.paperById(a.paperId);
        if (paper != null && _exams.canEditPaper(paper)) return true;
        if (TeacherAccessService.instance.assignmentFor(a.className) != null) {
          return true;
        }
        return paper != null &&
            TeacherAccessService.instance.assignmentFor(paper.className) !=
                null;
      }).toList();
    }
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
        if (selected != null && !selected.isOnlineSit) ...[
          _offlineRoster(selected),
          const SizedBox(height: 8),
        ] else if (attempts.isEmpty)
          _emptyCard(
            'No attempts yet. Students sit a published online paper, or pick '
            'an offline / lockdown paper to enter percents for the class roster.',
          )
        else
          for (final attempt in attempts)
            _card(
              child: ListTile(
                leading: StudentPhotoAvatar(
                  studentId: attempt.studentId,
                  name: attempt.studentName,
                  radius: 20,
                ),
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

  Widget _offlineRoster(ExamPaper paper) {
    final students = StudentRegistryService.instance.studentsForClass(
      paper.className,
      schoolId: _schoolId.isEmpty ? null : _schoolId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Offline / lockdown paper — enter a percent for each student. '
          'Students do not sit this in the portal.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 10),
        if (students.isEmpty)
          _emptyCard(
            'No students listed for ${paper.className}. Add the class roster, '
            'then enter percents here.',
          )
        else
          for (final student in students)
            _card(
              child: ListTile(
                leading: StudentPhotoAvatar(
                  studentId: student.studentId,
                  name: student.fullName,
                  radius: 20,
                ),
                title: Text(student.fullName),
                subtitle: Text(_offlineScoreLabel(paper, student)),
                trailing: _canManage
                    ? TextButton(
                        onPressed: () => _enterOfflinePercent(paper, student),
                        child: const Text('Enter %'),
                      )
                    : null,
              ),
            ),
      ],
    );
  }

  String _offlineScoreLabel(ExamPaper paper, AdminStudentRecord student) {
    final attempt = _exams.attemptFor(
      paperId: paper.id,
      studentName: student.fullName,
    );
    if (attempt == null || attempt.status != ExamAttemptStatus.scored) {
      return 'No score yet';
    }
    return '${attempt.percent.toStringAsFixed(0)}%'
        '${attempt.pushedToMarkbook ? ' · in markbook' : ''}';
  }

  Future<void> _enterOfflinePercent(
    ExamPaper paper,
    AdminStudentRecord student,
  ) async {
    final existing = _exams.attemptFor(
      paperId: paper.id,
      studentName: student.fullName,
    );
    final ctrl = TextEditingController(
      text: existing == null || existing.status != ExamAttemptStatus.scored
          ? ''
          : existing.percent.toStringAsFixed(0),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(student.fullName),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Percent (0–100)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final percent = double.tryParse(ctrl.text.trim());
    if (percent == null) return;
    try {
      await _exams.recordStaffOfflineResult(
        paperId: paper.id,
        studentName: student.fullName,
        percent: percent,
        studentId: student.studentId,
        className: student.className,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
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

  static String _categoryOrUnfiled(String category) {
    final trimmed = category.trim();
    return trimmed.isEmpty ? 'Unfiled' : trimmed;
  }

  static String _accessLabel(ExamVaultAccess access) => switch (access) {
        ExamVaultAccess.private => 'My list only',
        ExamVaultAccess.vault => 'School vault',
      };

  static String _statusLabel(ExamPaperStatus status) => switch (status) {
        ExamPaperStatus.draft => 'Draft',
        ExamPaperStatus.published => 'Published',
        ExamPaperStatus.closed => 'Closed',
      };

  static String _kindLabel(ExamKind kind) => switch (kind) {
        ExamKind.school => 'School',
        ExamKind.national => 'National',
        ExamKind.model => 'Model',
      };

  static String _sittingLabel(ExamSittingMode mode) => switch (mode) {
        ExamSittingMode.online => 'Online sit',
        ExamSittingMode.offline => 'Offline / lockdown',
      };

  static String _windowLabel(ExamPaper paper) {
    if (paper.startAt == null && paper.endAt == null) return '';
    String d(DateTime day) => '${day.day}/${day.month}/${day.year}';
    if (paper.startAt != null && paper.endAt != null) {
      return ' · ${d(paper.startAt!)}–${d(paper.endAt!)}';
    }
    if (paper.startAt != null) return ' · from ${d(paper.startAt!)}';
    return ' · until ${d(paper.endAt!)}';
  }
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
  late List<String> _attachments;
  late String _category;
  late ExamVaultAccess _vaultAccess;
  late final TextEditingController _customCategory;

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
    _attachments = List<String>.from(q?.attachmentPaths ?? const []);
    _category = q?.category.trim() ?? '';
    _vaultAccess = q?.vaultAccess ?? ExamVaultAccess.private;
    _customCategory = TextEditingController(
      text: _category.isNotEmpty &&
              !ExamBankCategories.suggested.contains(_category)
          ? _category
          : '',
    );
  }

  @override
  void dispose() {
    _prompt.dispose();
    _points.dispose();
    _customCategory.dispose();
    for (final c in _choices) {
      c.dispose();
    }
    super.dispose();
  }

  String get _resolvedCategory {
    if (_category == '__custom__') return _customCategory.text.trim();
    return _category.trim();
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
        attachmentPaths: _attachments,
        category: _resolvedCategory,
        vaultAccess: _vaultAccess,
      );
    } else {
      await ExamService.instance.updateQuestion(
        widget.existing!.id,
        subject: _subject,
        prompt: prompt,
        points: points,
        choices: choices,
        correctChoiceId: _type == ExamQuestionType.mcq ? _correctId : null,
        attachmentPaths: _attachments,
        category: _resolvedCategory,
        vaultAccess: _vaultAccess,
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
              DropdownButtonFormField<String>(
                key: ValueKey('q-cat-$_category'),
                initialValue: _category.isEmpty
                    ? ''
                    : ExamBankCategories.suggested.contains(_category)
                        ? _category
                        : '__custom__',
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Unfiled')),
                  for (final name in ExamBankCategories.suggested)
                    DropdownMenuItem(value: name, child: Text(name)),
                  const DropdownMenuItem(
                    value: '__custom__',
                    child: Text('Custom category'),
                  ),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              if (_category == '__custom__' ||
                  (_category.isNotEmpty &&
                      !ExamBankCategories.suggested.contains(_category))) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customCategory,
                  decoration: const InputDecoration(
                    labelText: 'Custom category name',
                  ),
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<ExamVaultAccess>(
                key: ValueKey('q-vault-$_vaultAccess'),
                initialValue: _vaultAccess,
                decoration: const InputDecoration(
                  labelText: 'Accessibility',
                  helperText:
                      'My list stays private. School vault lets every teacher open and copy it.',
                ),
                items: const [
                  DropdownMenuItem(
                    value: ExamVaultAccess.private,
                    child: Text('My list only'),
                  ),
                  DropdownMenuItem(
                    value: ExamVaultAccess.vault,
                    child: Text('Share to school vault'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _vaultAccess = v ?? _vaultAccess),
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
              const SizedBox(height: 12),
              CourseAttachmentPicker(
                paths: _attachments,
                subdir: 'exam_question_attachments',
                sectionTitle: 'Question files',
                onChanged: (next) => setState(() => _attachments = next),
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
  late List<String> _attachments;
  late ExamKind _kind;
  late ExamSittingMode _sittingMode;
  DateTime? _startAt;
  DateTime? _endAt;
  late String _bankCategory;
  late ExamVaultAccess _vaultAccess;
  late final TextEditingController _customCategory;

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
    _attachments = List<String>.from(p?.attachmentPaths ?? const []);
    _kind = p?.kind ?? ExamKind.school;
    _sittingMode = p?.sittingMode ?? ExamSittingMode.online;
    _startAt = p?.startAt;
    _endAt = p?.endAt;
    _bankCategory = p?.category.trim() ?? '';
    _vaultAccess = p?.vaultAccess ?? ExamVaultAccess.private;
    _customCategory = TextEditingController(
      text: _bankCategory.isNotEmpty &&
              !ExamBankCategories.suggested.contains(_bankCategory)
          ? _bankCategory
          : '',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _customCategory.dispose();
    super.dispose();
  }

  String get _resolvedBankCategory {
    if (_bankCategory == '__custom__') return _customCategory.text.trim();
    return _bankCategory.trim();
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
        attachmentPaths: _attachments,
        kind: _kind,
        sittingMode: _sittingMode,
        startAt: _startAt,
        endAt: _endAt,
        category: _resolvedBankCategory,
        vaultAccess: _vaultAccess,
      );
    } else {
      await ExamService.instance.updatePaper(
        widget.existing!.id,
        title: title,
        questionIds: _selected.toList(),
        markbookCategoryId: _categoryId,
        attachmentPaths: _attachments,
        kind: _kind,
        sittingMode: _sittingMode,
        startAt: _startAt,
        endAt: _endAt,
        clearWindow: _startAt == null && _endAt == null,
        category: _resolvedBankCategory,
        vaultAccess: _vaultAccess,
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final questions = ExamService.instance
        .questionsVisibleToCurrentUser()
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
                key: ValueKey('paper-bank-cat-$_bankCategory'),
                initialValue: _bankCategory.isEmpty
                    ? ''
                    : ExamBankCategories.suggested.contains(_bankCategory)
                        ? _bankCategory
                        : '__custom__',
                decoration: const InputDecoration(
                  labelText: 'Bank category',
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Unfiled')),
                  for (final name in ExamBankCategories.suggested)
                    DropdownMenuItem(value: name, child: Text(name)),
                  const DropdownMenuItem(
                    value: '__custom__',
                    child: Text('Custom category'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _bankCategory = v ?? _bankCategory),
              ),
              if (_bankCategory == '__custom__' ||
                  (_bankCategory.isNotEmpty &&
                      !ExamBankCategories.suggested.contains(_bankCategory))) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customCategory,
                  decoration: const InputDecoration(
                    labelText: 'Custom category name',
                  ),
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<ExamVaultAccess>(
                key: ValueKey('paper-vault-$_vaultAccess'),
                initialValue: _vaultAccess,
                decoration: const InputDecoration(
                  labelText: 'Accessibility',
                  helperText:
                      'My list stays private. School vault lets every teacher open and copy it.',
                ),
                items: const [
                  DropdownMenuItem(
                    value: ExamVaultAccess.private,
                    child: Text('My list only'),
                  ),
                  DropdownMenuItem(
                    value: ExamVaultAccess.vault,
                    child: Text('Share to school vault'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _vaultAccess = v ?? _vaultAccess),
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
              const SizedBox(height: 8),
              DropdownButtonFormField<ExamKind>(
                key: ValueKey('paper-kind-$_kind'),
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Paper kind'),
                items: const [
                  DropdownMenuItem(
                    value: ExamKind.school,
                    child: Text('School exam'),
                  ),
                  DropdownMenuItem(
                    value: ExamKind.national,
                    child: Text('National exam desk'),
                  ),
                  DropdownMenuItem(
                    value: ExamKind.model,
                    child: Text('Model exam'),
                  ),
                ],
                onChanged: (v) => setState(() => _kind = v ?? _kind),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ExamSittingMode>(
                key: ValueKey('paper-sit-$_sittingMode'),
                initialValue: _sittingMode,
                decoration: const InputDecoration(
                  labelText: 'Sitting',
                  helperText:
                      'Offline / lockdown papers are printed or attached. '
                      'Students do not sit them in the portal.',
                ),
                items: const [
                  DropdownMenuItem(
                    value: ExamSittingMode.online,
                    child: Text('Online (student portal)'),
                  ),
                  DropdownMenuItem(
                    value: ExamSittingMode.offline,
                    child: Text('Offline / lockdown print'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _sittingMode = v ?? _sittingMode),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _startAt == null
                      ? 'Sitting opens (optional)'
                      : 'Opens ${_startAt!.day}/${_startAt!.month}/${_startAt!.year}',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startAt ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => _startAt = picked);
                  },
                  child: const Text('Set start'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _endAt == null
                      ? 'Sitting closes (optional)'
                      : 'Closes ${_endAt!.day}/${_endAt!.month}/${_endAt!.year}',
                ),
                trailing: Wrap(
                  children: [
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endAt ?? _startAt ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() => _endAt = picked);
                      },
                      child: const Text('Set end'),
                    ),
                    if (_startAt != null || _endAt != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _startAt = null;
                          _endAt = null;
                        }),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              CourseAttachmentPicker(
                paths: _attachments,
                subdir: 'exam_paper_attachments',
                sectionTitle: 'Paper files',
                onChanged: (next) => setState(() => _attachments = next),
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
          if (question.attachmentPaths.isNotEmpty) ...[
            const SizedBox(height: 6),
            CourseAttachmentPicker(
              paths: question.attachmentPaths,
              subdir: 'exam_question_attachments',
              canEdit: false,
              allowShareDownload: true,
              sectionTitle: 'Question files',
            ),
          ],
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
