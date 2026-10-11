/// Academic exams: question bank, papers, and student attempts.
///
/// Scores land on Phase B markbook categories (`midterm`, `final`, `quiz`)
/// through [ExamService.pushAttemptToMarkbook] — not a parallel grade store.
enum ExamQuestionType { mcq, shortAnswer, essay }

enum ExamPaperStatus { draft, published, closed }

enum ExamAttemptStatus { inProgress, submitted, scored }

/// School-set vs national / model papers. Defaults keep existing papers
/// as in-school online sittings.
enum ExamKind { school, national, model }

/// Online = student portal sit. Offline = staff print / attach papers;
/// not a lockdown browser.
enum ExamSittingMode { online, offline }

/// Who else at the school may open this bank item.
///
/// `private` stays on the author's list. `vault` is the school teacher vault.
enum ExamVaultAccess { private, vault }

/// Teacher-defined folders for their own bank and papers.
abstract final class ExamBankCategories {
  static const suggested = <String>[
    'Quiz',
    'Midterm',
    'Final',
    'Worksheet',
    'Practice',
    'Model paper',
    'National',
  ];
}

class ExamChoice {
  const ExamChoice({required this.id, required this.text});

  final String id;
  final String text;

  Map<String, dynamic> toMap() => {'id': id, 'text': text};

  factory ExamChoice.fromMap(Map<String, dynamic> map) {
    return ExamChoice(
      id: map['id'] as String? ?? '',
      text: map['text'] as String? ?? '',
    );
  }
}

class ExamQuestion {
  ExamQuestion({
    required this.id,
    required this.schoolId,
    required this.subject,
    required this.prompt,
    required this.type,
    required this.points,
    required this.createdAt,
    required this.updatedAt,
    this.choices = const [],
    this.correctChoiceId,
    this.gradeLevel,
    this.createdBy,
    this.attachmentPaths = const [],
    this.category = '',
    this.vaultAccess = ExamVaultAccess.private,
  });

  final String id;
  final String schoolId;
  String subject;
  String prompt;
  ExamQuestionType type;
  List<ExamChoice> choices;
  String? correctChoiceId;
  double points;
  String? gradeLevel;
  String? createdBy;
  List<String> attachmentPaths;
  String category;
  ExamVaultAccess vaultAccess;
  final DateTime createdAt;
  DateTime updatedAt;

  bool get inSchoolVault => vaultAccess == ExamVaultAccess.vault;

  bool get isMcq => type == ExamQuestionType.mcq;

  /// Typed prompt, or a label when the question is a file only.
  String get displayPrompt {
    final typed = prompt.trim();
    if (typed.isNotEmpty) return typed;
    if (attachmentPaths.isNotEmpty) return 'Attached question';
    return 'Untitled question';
  }

  static String promptFromInput(String prompt, List<String> attachments) {
    final typed = prompt.trim();
    if (typed.isNotEmpty) return typed;
    if (attachments.isNotEmpty) return 'Attached question';
    return '';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'subject': subject,
        'prompt': prompt,
        'type': type.name,
        'points': points,
        'choices': choices.map((c) => c.toMap()).toList(),
        if (correctChoiceId != null) 'correctChoiceId': correctChoiceId,
        if (gradeLevel != null) 'gradeLevel': gradeLevel,
        if (createdBy != null) 'createdBy': createdBy,
        'attachmentPaths': attachmentPaths,
        if (category.trim().isNotEmpty) 'category': category.trim(),
        'vaultAccess': vaultAccess.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ExamQuestion.fromMap(Map<String, dynamic> map) {
    return ExamQuestion(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      subject: map['subject'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      type: ExamQuestionType.values.firstWhere(
        (v) => v.name == map['type'],
        orElse: () => ExamQuestionType.shortAnswer,
      ),
      points: (map['points'] as num?)?.toDouble() ?? 1,
      choices: (map['choices'] as List?)
              ?.whereType<Map>()
              .map((e) => ExamChoice.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      correctChoiceId: map['correctChoiceId'] as String?,
      gradeLevel: map['gradeLevel'] as String?,
      createdBy: map['createdBy'] as String?,
      attachmentPaths: (map['attachmentPaths'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      category: (map['category'] as String? ?? '').trim(),
      vaultAccess: ExamVaultAccess.values.firstWhere(
        (v) => v.name == map['vaultAccess'],
        orElse: () => ExamVaultAccess.vault,
      ),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ExamPaper {
  ExamPaper({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.className,
    required this.subject,
    required this.createdAt,
    required this.updatedAt,
    this.questionIds = const [],
    this.markbookCategoryId = 'final',
    this.status = ExamPaperStatus.draft,
    this.startAt,
    this.endAt,
    this.createdBy,
    this.attachmentPaths = const [],
    this.kind = ExamKind.school,
    this.sittingMode = ExamSittingMode.online,
    this.category = '',
    this.vaultAccess = ExamVaultAccess.private,
  });

  final String id;
  final String schoolId;
  String title;
  String className;
  String subject;
  List<String> questionIds;
  String markbookCategoryId;
  ExamPaperStatus status;
  DateTime? startAt;
  DateTime? endAt;
  String? createdBy;
  List<String> attachmentPaths;
  ExamKind kind;
  ExamSittingMode sittingMode;
  String category;
  ExamVaultAccess vaultAccess;
  final DateTime createdAt;
  DateTime updatedAt;

  bool get inSchoolVault => vaultAccess == ExamVaultAccess.vault;

  bool get hasContent =>
      questionIds.isNotEmpty || attachmentPaths.isNotEmpty;

  bool get isPublished => status == ExamPaperStatus.published;

  bool get isOnlineSit => sittingMode == ExamSittingMode.online;

  bool isOpenAt(DateTime now) {
    if (status != ExamPaperStatus.published) return false;
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }

  /// Closed papers and sittings whose window has ended.
  bool isHistoricalAt(DateTime now) {
    if (status == ExamPaperStatus.closed) return true;
    if (endAt != null && now.isAfter(endAt!)) return true;
    return false;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'title': title,
        'className': className,
        'subject': subject,
        'questionIds': questionIds,
        'markbookCategoryId': markbookCategoryId,
        'status': status.name,
        if (startAt != null) 'startAt': startAt!.toIso8601String(),
        if (endAt != null) 'endAt': endAt!.toIso8601String(),
        if (createdBy != null) 'createdBy': createdBy,
        'attachmentPaths': attachmentPaths,
        'kind': kind.name,
        'sittingMode': sittingMode.name,
        if (category.trim().isNotEmpty) 'category': category.trim(),
        'vaultAccess': vaultAccess.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ExamPaper.fromMap(Map<String, dynamic> map) {
    return ExamPaper(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      title: map['title'] as String? ?? '',
      className: map['className'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      questionIds: (map['questionIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      markbookCategoryId: map['markbookCategoryId'] as String? ?? 'final',
      status: ExamPaperStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => ExamPaperStatus.draft,
      ),
      startAt: map['startAt'] != null
          ? DateTime.tryParse(map['startAt'] as String)
          : null,
      endAt: map['endAt'] != null
          ? DateTime.tryParse(map['endAt'] as String)
          : null,
      createdBy: map['createdBy'] as String?,
      attachmentPaths: (map['attachmentPaths'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      kind: ExamKind.values.firstWhere(
        (v) => v.name == map['kind'],
        orElse: () => ExamKind.school,
      ),
      sittingMode: ExamSittingMode.values.firstWhere(
        (v) => v.name == map['sittingMode'],
        orElse: () => ExamSittingMode.online,
      ),
      category: (map['category'] as String? ?? '').trim(),
      vaultAccess: ExamVaultAccess.values.firstWhere(
        (v) => v.name == map['vaultAccess'],
        orElse: () => ExamVaultAccess.vault,
      ),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ExamAnswer {
  ExamAnswer({
    required this.questionId,
    this.choiceId,
    this.text,
    this.pointsAwarded,
  });

  final String questionId;
  String? choiceId;
  String? text;
  double? pointsAwarded;

  Map<String, dynamic> toMap() => {
        'questionId': questionId,
        if (choiceId != null) 'choiceId': choiceId,
        if (text != null) 'text': text,
        if (pointsAwarded != null) 'pointsAwarded': pointsAwarded,
      };

  factory ExamAnswer.fromMap(Map<String, dynamic> map) {
    return ExamAnswer(
      questionId: map['questionId'] as String? ?? '',
      choiceId: map['choiceId'] as String?,
      text: map['text'] as String?,
      pointsAwarded: (map['pointsAwarded'] as num?)?.toDouble(),
    );
  }
}

class ExamAttempt {
  ExamAttempt({
    required this.id,
    required this.paperId,
    required this.schoolId,
    required this.studentName,
    required this.className,
    required this.startedAt,
    required this.updatedAt,
    this.studentId,
    this.answers = const [],
    this.maxPoints = 0,
    this.status = ExamAttemptStatus.inProgress,
    this.submittedAt,
    this.scoredAt,
    this.scoredBy,
    this.pushedToMarkbook = false,
  });

  final String id;
  final String paperId;
  final String schoolId;
  final String studentName;
  final String className;
  String? studentId;
  List<ExamAnswer> answers;
  double maxPoints;
  ExamAttemptStatus status;
  final DateTime startedAt;
  DateTime updatedAt;
  DateTime? submittedAt;
  DateTime? scoredAt;
  String? scoredBy;
  bool pushedToMarkbook;

  double get awardedPoints => answers.fold(
        0,
        (sum, a) => sum + (a.pointsAwarded ?? 0),
      );

  double get percent => maxPoints <= 0 ? 0 : (awardedPoints / maxPoints) * 100;

  bool get needsManualScore =>
      status == ExamAttemptStatus.submitted ||
      (status == ExamAttemptStatus.scored &&
          answers.any((a) => a.pointsAwarded == null));

  Map<String, dynamic> toMap() => {
        'id': id,
        'paperId': paperId,
        'schoolId': schoolId,
        'studentName': studentName,
        'className': className,
        if (studentId != null) 'studentId': studentId,
        'answers': answers.map((a) => a.toMap()).toList(),
        'maxPoints': maxPoints,
        'status': status.name,
        'startedAt': startedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (submittedAt != null) 'submittedAt': submittedAt!.toIso8601String(),
        if (scoredAt != null) 'scoredAt': scoredAt!.toIso8601String(),
        if (scoredBy != null) 'scoredBy': scoredBy,
        'pushedToMarkbook': pushedToMarkbook,
      };

  factory ExamAttempt.fromMap(Map<String, dynamic> map) {
    return ExamAttempt(
      id: map['id'] as String? ?? '',
      paperId: map['paperId'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      className: map['className'] as String? ?? '',
      studentId: map['studentId'] as String?,
      answers: (map['answers'] as List?)
              ?.whereType<Map>()
              .map((e) => ExamAnswer.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      maxPoints: (map['maxPoints'] as num?)?.toDouble() ?? 0,
      status: ExamAttemptStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => ExamAttemptStatus.inProgress,
      ),
      startedAt:
          DateTime.tryParse(map['startedAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      submittedAt: map['submittedAt'] != null
          ? DateTime.tryParse(map['submittedAt'] as String)
          : null,
      scoredAt: map['scoredAt'] != null
          ? DateTime.tryParse(map['scoredAt'] as String)
          : null,
      scoredBy: map['scoredBy'] as String?,
      pushedToMarkbook: map['pushedToMarkbook'] as bool? ?? false,
    );
  }
}
