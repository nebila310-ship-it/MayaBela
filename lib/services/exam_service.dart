import 'package:flutter/foundation.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/markbook_service.dart';
import 'package:mayabela/services/persistence/exam_persistence_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/short_registry_id.dart';

/// Question bank, exam papers, attempts, and markbook push.
class ExamService extends ChangeNotifier {
  ExamService._();
  static final instance = ExamService._();

  final List<ExamQuestion> _questions = [];
  final List<ExamPaper> _papers = [];
  final List<ExamAttempt> _attempts = [];
  bool _loaded = false;

  List<ExamQuestion> get questions => List.unmodifiable(_questions);
  List<ExamPaper> get papers => List.unmodifiable(_papers);
  List<ExamAttempt> get attempts => List.unmodifiable(_attempts);

  @visibleForTesting
  static void resetForTests() {
    instance._questions.clear();
    instance._papers.clear();
    instance._attempts.clear();
    instance._loaded = true;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await ExamPersistenceService.instance.loadIntoService();
  }

  String get _schoolId =>
      (AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId ?? '')
          .trim()
          .toUpperCase();

  List<ExamQuestion> questionsForSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    if (sid.isEmpty) return questions;
    return _questions.where((q) => q.schoolId == sid).toList();
  }

  List<ExamPaper> papersForSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    if (sid.isEmpty) return papers;
    return _papers.where((p) => p.schoolId == sid).toList();
  }

  List<ExamPaper> openPapersForClass(String className, {String? schoolId}) {
    final now = DateTime.now();
    return papersForSchool(schoolId)
        .where((p) => p.className == className && p.isOpenAt(now))
        .toList();
  }

  ExamQuestion? questionById(String id) {
    for (final q in _questions) {
      if (q.id == id) return q;
    }
    return null;
  }

  ExamPaper? paperById(String id) {
    for (final p in _papers) {
      if (p.id == id) return p;
    }
    return null;
  }

  ExamAttempt? attemptById(String id) {
    for (final a in _attempts) {
      if (a.id == id) return a;
    }
    return null;
  }

  ExamAttempt? attemptFor({
    required String paperId,
    required String studentName,
  }) {
    for (final a in _attempts) {
      if (a.paperId == paperId && a.studentName == studentName) return a;
    }
    return null;
  }

  List<ExamAttempt> attemptsForPaper(String paperId) =>
      _attempts.where((a) => a.paperId == paperId).toList();

  List<ExamAttempt> scoringQueue([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    return _attempts
        .where(
          (a) =>
              a.needsManualScore &&
              (sid.isEmpty || a.schoolId == sid),
        )
        .toList();
  }

  int unscoredCount([String? schoolId]) => scoringQueue(schoolId).length;

  List<ExamQuestion> questionsOnPaper(ExamPaper paper) => [
        for (final id in paper.questionIds)
          if (questionById(id) != null) questionById(id)!,
      ];

  Future<ExamQuestion> createQuestion({
    required String subject,
    required String prompt,
    required ExamQuestionType type,
    double points = 1,
    List<ExamChoice> choices = const [],
    String? correctChoiceId,
    String? gradeLevel,
    String? schoolId,
  }) async {
    final now = DateTime.now();
    final question = ExamQuestion(
      id: _allocateId('Q', _questions.map((q) => q.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      subject: subject.trim(),
      prompt: prompt.trim(),
      type: type,
      points: points,
      choices: choices,
      correctChoiceId: correctChoiceId,
      gradeLevel: gradeLevel,
      createdBy: AuthService.currentUser?.username,
      createdAt: now,
      updatedAt: now,
    );
    _questions.add(question);
    await _persist();
    return question;
  }

  Future<ExamQuestion?> updateQuestion(
    String id, {
    String? subject,
    String? prompt,
    double? points,
    List<ExamChoice>? choices,
    String? correctChoiceId,
  }) async {
    final question = questionById(id);
    if (question == null) return null;
    if (subject != null) question.subject = subject.trim();
    if (prompt != null) question.prompt = prompt.trim();
    if (points != null) question.points = points;
    if (choices != null) question.choices = choices;
    if (correctChoiceId != null) question.correctChoiceId = correctChoiceId;
    question.updatedAt = DateTime.now();
    await _persist();
    return question;
  }

  Future<ExamPaper> createPaper({
    required String title,
    required String className,
    required String subject,
    List<String> questionIds = const [],
    String markbookCategoryId = 'final',
    DateTime? startAt,
    DateTime? endAt,
    String? schoolId,
  }) async {
    final now = DateTime.now();
    final paper = ExamPaper(
      id: _allocateId('EX', _papers.map((p) => p.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      title: title.trim(),
      className: className.trim(),
      subject: subject.trim(),
      questionIds: List.of(questionIds),
      markbookCategoryId: markbookCategoryId,
      startAt: startAt,
      endAt: endAt,
      createdBy: AuthService.currentUser?.username,
      createdAt: now,
      updatedAt: now,
    );
    _papers.add(paper);
    await _persist();
    return paper;
  }

  Future<ExamPaper?> updatePaper(
    String id, {
    String? title,
    List<String>? questionIds,
    String? markbookCategoryId,
    DateTime? startAt,
    DateTime? endAt,
    bool clearWindow = false,
  }) async {
    final paper = paperById(id);
    if (paper == null) return null;
    if (title != null) paper.title = title.trim();
    if (questionIds != null) paper.questionIds = List.of(questionIds);
    if (markbookCategoryId != null) {
      paper.markbookCategoryId = markbookCategoryId;
    }
    if (clearWindow) {
      paper.startAt = null;
      paper.endAt = null;
    } else {
      if (startAt != null) paper.startAt = startAt;
      if (endAt != null) paper.endAt = endAt;
    }
    paper.updatedAt = DateTime.now();
    await _persist();
    return paper;
  }

  Future<ExamPaper?> setPaperStatus(String id, ExamPaperStatus status) async {
    final paper = paperById(id);
    if (paper == null) return null;
    paper.status = status;
    paper.updatedAt = DateTime.now();
    await _persist();
    return paper;
  }

  Future<ExamAttempt> startAttempt({
    required String paperId,
    required String studentName,
    String? studentId,
    String? className,
    String? schoolId,
  }) async {
    final existing = attemptFor(paperId: paperId, studentName: studentName);
    if (existing != null) return existing;
    final paper = paperById(paperId);
    final now = DateTime.now();
    final questions = paper == null ? const <ExamQuestion>[] : questionsOnPaper(paper);
    final attempt = ExamAttempt(
      id: _allocateId('AT', _attempts.map((a) => a.id)),
      paperId: paperId,
      schoolId: (schoolId ?? paper?.schoolId ?? _schoolId).toUpperCase(),
      studentName: studentName.trim(),
      className: (className ?? paper?.className ?? '').trim(),
      studentId: studentId ??
          StudentRegistryService.instance.lookupByName(studentName)?.studentId,
      answers: [
        for (final q in questions) ExamAnswer(questionId: q.id),
      ],
      maxPoints: questions.fold(0, (sum, q) => sum + q.points),
      startedAt: now,
      updatedAt: now,
    );
    _attempts.add(attempt);
    await _persist();
    return attempt;
  }

  Future<ExamAttempt?> saveAnswers(
    String attemptId,
    List<ExamAnswer> answers,
  ) async {
    final attempt = attemptById(attemptId);
    if (attempt == null || attempt.status != ExamAttemptStatus.inProgress) {
      return null;
    }
    attempt.answers = answers;
    attempt.updatedAt = DateTime.now();
    await _persist();
    return attempt;
  }

  /// Auto-scores MCQ. Short/essay stay unscored until a teacher awards points.
  Future<ExamAttempt?> submitAttempt(String attemptId) async {
    final attempt = attemptById(attemptId);
    if (attempt == null || attempt.status != ExamAttemptStatus.inProgress) {
      return null;
    }
    final paper = paperById(attempt.paperId);
    final questions = paper == null ? const <ExamQuestion>[] : questionsOnPaper(paper);
    var allAuto = true;
    for (final question in questions) {
      final answer = attempt.answers.cast<ExamAnswer?>().firstWhere(
            (a) => a?.questionId == question.id,
            orElse: () => null,
          );
      if (answer == null) {
        attempt.answers = [...attempt.answers, ExamAnswer(questionId: question.id)];
      }
      final current = attempt.answers.firstWhere((a) => a.questionId == question.id);
      if (question.isMcq) {
        final ok = current.choiceId != null &&
            current.choiceId == question.correctChoiceId;
        current.pointsAwarded = ok ? question.points : 0;
      } else {
        allAuto = false;
      }
    }
    attempt.maxPoints = questions.fold(0, (sum, q) => sum + q.points);
    attempt.status =
        allAuto ? ExamAttemptStatus.scored : ExamAttemptStatus.submitted;
    attempt.submittedAt = DateTime.now();
    attempt.updatedAt = attempt.submittedAt!;
    if (allAuto) {
      attempt.scoredAt = attempt.submittedAt;
      attempt.scoredBy = 'auto';
    }
    await _persist();
    return attempt;
  }

  Future<ExamAttempt?> awardPoints({
    required String attemptId,
    required String questionId,
    required double points,
    String? scoredBy,
  }) async {
    final attempt = attemptById(attemptId);
    if (attempt == null) return null;
    final answer = attempt.answers.cast<ExamAnswer?>().firstWhere(
          (a) => a?.questionId == questionId,
          orElse: () => null,
        );
    if (answer == null) {
      attempt.answers = [
        ...attempt.answers,
        ExamAnswer(questionId: questionId, pointsAwarded: points),
      ];
    } else {
      answer.pointsAwarded = points;
    }
    final paper = paperById(attempt.paperId);
    final questions = paper == null ? const <ExamQuestion>[] : questionsOnPaper(paper);
    final complete = questions.every((q) {
      final a = attempt.answers.cast<ExamAnswer?>().firstWhere(
            (x) => x?.questionId == q.id,
            orElse: () => null,
          );
      return a?.pointsAwarded != null;
    });
    if (complete) {
      attempt.status = ExamAttemptStatus.scored;
      attempt.scoredAt = DateTime.now();
      attempt.scoredBy = scoredBy ?? AuthService.currentUser?.username;
    } else {
      attempt.status = ExamAttemptStatus.submitted;
    }
    attempt.updatedAt = DateTime.now();
    await _persist();
    return attempt;
  }

  /// Writes the attempt percent into the paper's markbook category (draft).
  bool pushAttemptToMarkbook(String attemptId, {String? teacherId}) {
    final attempt = attemptById(attemptId);
    final paper = attempt == null ? null : paperById(attempt.paperId);
    if (attempt == null || paper == null) return false;
    if (attempt.status != ExamAttemptStatus.scored) return false;

    final data = SchoolDataService.instance;
    data.addSubjectToGradeReport(
      studentName: attempt.studentName,
      className: attempt.className.isEmpty ? paper.className : attempt.className,
      subject: paper.subject,
      teacherId: teacherId ?? AuthService.currentUser?.username ?? 'exam',
    );
    SubjectGrade? grade;
    final report = data.getGradeReportForStudent(attempt.studentName);
    if (report != null) {
      for (final item in report.subjects) {
        if (item.subject == paper.subject) {
          grade = item;
          break;
        }
      }
    }
    if (grade == null || !grade.canTeacherEdit) return false;

    final marks = MarkbookService.instance.marksForSubject(grade);
    final category = paper.markbookCategoryId;
    final next = [
      for (final mark in marks)
        AssessmentMark(
          categoryId: mark.categoryId,
          label: mark.label,
          weightPercent: mark.weightPercent,
          score: mark.categoryId == category ? attempt.percent : mark.score,
          maxScore: mark.maxScore,
          enteredAt: mark.categoryId == category ? DateTime.now() : mark.enteredAt,
        ),
    ];
    if (!next.any((m) => m.categoryId == category)) {
      next.add(
        AssessmentMark(
          categoryId: category,
          label: category,
          weightPercent: 0,
          score: attempt.percent,
          enteredAt: DateTime.now(),
        ),
      );
    }
    final ok = data.updateSubjectGrade(
      studentName: attempt.studentName,
      className: attempt.className.isEmpty ? paper.className : attempt.className,
      subject: paper.subject,
      score: MarkbookMath.weightedPercentage(
        next,
        missingCountsAsZero:
            MarkbookService.instance.settingsForSchool().missingCountsAsZero,
      ),
      assessments: next,
      enteredByTeacherId: teacherId ?? AuthService.currentUser?.username,
    );
    if (ok) {
      attempt.pushedToMarkbook = true;
      attempt.updatedAt = DateTime.now();
      unawaitedPersist();
    }
    return ok;
  }

  int pushScoredAttemptsToMarkbook(String paperId, {String? teacherId}) {
    var count = 0;
    for (final attempt in attemptsForPaper(paperId)) {
      if (attempt.status != ExamAttemptStatus.scored) continue;
      if (pushAttemptToMarkbook(attempt.id, teacherId: teacherId)) count++;
    }
    return count;
  }

  void applyPersistedData({
    List<ExamQuestion>? questions,
    List<ExamPaper>? papers,
    List<ExamAttempt>? attempts,
    bool merge = false,
  }) {
    void mergeList<T>(List<T> local, List<T> incoming, String Function(T) idOf) {
      if (!merge) {
        local
          ..clear()
          ..addAll(incoming);
        return;
      }
      final byId = {for (final item in local) idOf(item): item};
      for (final item in incoming) {
        byId[idOf(item)] = item;
      }
      local
        ..clear()
        ..addAll(byId.values);
    }

    if (questions != null) {
      mergeList(_questions, questions, (q) => q.id);
    }
    if (papers != null) {
      mergeList(_papers, papers, (p) => p.id);
    }
    if (attempts != null) {
      mergeList(_attempts, attempts, (a) => a.id);
    }
    _loaded = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> questionMaps() =>
      _questions.map((q) => q.toMap()).toList();
  List<Map<String, dynamic>> paperMaps() =>
      _papers.map((p) => p.toMap()).toList();
  List<Map<String, dynamic>> attemptMaps() =>
      _attempts.map((a) => a.toMap()).toList();

  Future<void> _persist() async {
    notifyListeners();
    await ExamPersistenceService.instance.saveFromService();
  }

  void unawaitedPersist() {
    notifyListeners();
    ExamPersistenceService.instance.saveFromService();
  }

  String _allocateId(String prefix, Iterable<String> existing) {
    return ShortRegistryId.allocate(
      prefix: prefix,
      existingIds: existing,
      isTaken: (id) => existing.contains(id),
    );
  }
}
