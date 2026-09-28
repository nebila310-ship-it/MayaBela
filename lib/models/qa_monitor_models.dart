// LIA Phase I — QA monitoring on top of the findings register.
// Not a grade store, not Phase E teacher_evaluations, not Phase G/H care.

enum ObservationStatus { draft, submitted, shared }

enum AuditVerdict { aligned, gaps, notReviewed }

enum AuditStatus { planned, inProgress, completed }

enum SurveyAudience { parent, teacher, student, all }

enum SurveyQuestionKind { rating, text }

enum ActionResearchStatus { planned, active, complete }

class TeachingObservation {
  TeachingObservation({
    required this.id,
    required this.schoolId,
    required this.teacherName,
    required this.observedAt,
    required this.createdAt,
    required this.updatedAt,
    this.teacherUsername = '',
    this.teacherId,
    this.className = '',
    this.subject = '',
    this.curriculumUnitId,
    this.planning = 3,
    this.instruction = 3,
    this.engagement = 3,
    this.assessment = 3,
    this.notes = '',
    this.status = ObservationStatus.draft,
    this.observerUsername,
  });

  final String id;
  final String schoolId;
  String teacherUsername;
  String? teacherId;
  String teacherName;
  String className;
  String subject;
  String? curriculumUnitId;
  DateTime observedAt;
  int planning;
  int instruction;
  int engagement;
  int assessment;
  String notes;
  ObservationStatus status;
  String? observerUsername;
  final DateTime createdAt;
  DateTime updatedAt;

  double get averageScore =>
      (planning + instruction + engagement + assessment) / 4;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'teacherUsername': teacherUsername,
        if (teacherId != null) 'teacherId': teacherId,
        'teacherName': teacherName,
        'className': className,
        'subject': subject,
        if (curriculumUnitId != null) 'curriculumUnitId': curriculumUnitId,
        'observedAt': observedAt.toIso8601String(),
        'planning': planning,
        'instruction': instruction,
        'engagement': engagement,
        'assessment': assessment,
        'notes': notes,
        'status': status.name,
        if (observerUsername != null) 'observerUsername': observerUsername,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TeachingObservation.fromMap(Map<String, dynamic> map) {
    return TeachingObservation(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      teacherUsername: map['teacherUsername'] as String? ?? '',
      teacherId: map['teacherId'] as String?,
      teacherName: map['teacherName'] as String? ?? '',
      className: map['className'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      curriculumUnitId: map['curriculumUnitId'] as String?,
      observedAt: DateTime.tryParse(map['observedAt'] as String? ?? '') ??
          DateTime.now(),
      planning: (map['planning'] as num?)?.toInt() ?? 3,
      instruction: (map['instruction'] as num?)?.toInt() ?? 3,
      engagement: (map['engagement'] as num?)?.toInt() ?? 3,
      assessment: (map['assessment'] as num?)?.toInt() ?? 3,
      notes: map['notes'] as String? ?? '',
      status: ObservationStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => ObservationStatus.draft,
      ),
      observerUsername: map['observerUsername'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class AcademicAudit {
  AcademicAudit({
    required this.id,
    required this.schoolId,
    required this.curriculumUnitId,
    required this.unitTitle,
    required this.createdAt,
    required this.updatedAt,
    this.standardCodes = const [],
    this.verdict = AuditVerdict.notReviewed,
    this.status = AuditStatus.planned,
    this.notes = '',
    this.auditorUsername,
  });

  final String id;
  final String schoolId;
  final String curriculumUnitId;
  String unitTitle;
  List<String> standardCodes;
  AuditVerdict verdict;
  AuditStatus status;
  String notes;
  String? auditorUsername;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'curriculumUnitId': curriculumUnitId,
        'unitTitle': unitTitle,
        'standardCodes': standardCodes,
        'verdict': verdict.name,
        'status': status.name,
        'notes': notes,
        if (auditorUsername != null) 'auditorUsername': auditorUsername,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AcademicAudit.fromMap(Map<String, dynamic> map) {
    final codes = map['standardCodes'];
    return AcademicAudit(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      curriculumUnitId: map['curriculumUnitId'] as String? ?? '',
      unitTitle: map['unitTitle'] as String? ?? '',
      standardCodes: codes is List
          ? codes.map((e) => e.toString()).toList()
          : const [],
      verdict: AuditVerdict.values.firstWhere(
        (v) => v.name == map['verdict'],
        orElse: () => AuditVerdict.notReviewed,
      ),
      status: AuditStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => AuditStatus.planned,
      ),
      notes: map['notes'] as String? ?? '',
      auditorUsername: map['auditorUsername'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class QaSurveyQuestion {
  QaSurveyQuestion({
    required this.id,
    required this.prompt,
    this.kind = SurveyQuestionKind.rating,
  });

  final String id;
  String prompt;
  SurveyQuestionKind kind;

  Map<String, dynamic> toMap() => {
        'id': id,
        'prompt': prompt,
        'kind': kind.name,
      };

  factory QaSurveyQuestion.fromMap(Map<String, dynamic> map) {
    return QaSurveyQuestion(
      id: map['id'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      kind: SurveyQuestionKind.values.firstWhere(
        (v) => v.name == map['kind'],
        orElse: () => SurveyQuestionKind.rating,
      ),
    );
  }
}

class QaSurvey {
  QaSurvey({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.audience = SurveyAudience.all,
    this.questions = const [],
    this.published = false,
    this.createdBy,
  });

  final String id;
  final String schoolId;
  String title;
  SurveyAudience audience;
  List<QaSurveyQuestion> questions;
  bool published;
  String? createdBy;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'title': title,
        'audience': audience.name,
        'questions': questions.map((q) => q.toMap()).toList(),
        'published': published,
        if (createdBy != null) 'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory QaSurvey.fromMap(Map<String, dynamic> map) {
    final raw = map['questions'];
    return QaSurvey(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      title: map['title'] as String? ?? '',
      audience: SurveyAudience.values.firstWhere(
        (v) => v.name == map['audience'],
        orElse: () => SurveyAudience.all,
      ),
      questions: raw is List
          ? raw
              .whereType<Map>()
              .map(
                (row) =>
                    QaSurveyQuestion.fromMap(Map<String, dynamic>.from(row)),
              )
              .toList()
          : const [],
      published: map['published'] as bool? ?? false,
      createdBy: map['createdBy'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class QaSurveyResponse {
  QaSurveyResponse({
    required this.id,
    required this.schoolId,
    required this.surveyId,
    required this.authorUsername,
    required this.createdAt,
    required this.updatedAt,
    this.authorRole,
    this.answers = const {},
  });

  final String id;
  final String schoolId;
  final String surveyId;
  final String authorUsername;
  String? authorRole;
  Map<String, String> answers;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'surveyId': surveyId,
        'authorUsername': authorUsername,
        if (authorRole != null) 'authorRole': authorRole,
        'answers': answers,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory QaSurveyResponse.fromMap(Map<String, dynamic> map) {
    final raw = map['answers'];
    return QaSurveyResponse(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      surveyId: map['surveyId'] as String? ?? '',
      authorUsername: map['authorUsername'] as String? ?? '',
      authorRole: map['authorRole'] as String?,
      answers: raw is Map
          ? raw.map((key, value) => MapEntry(key.toString(), value.toString()))
          : const {},
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ActionResearch {
  ActionResearch({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.inquiry = '',
    this.method = '',
    this.findings = '',
    this.nextSteps = '',
    this.status = ActionResearchStatus.planned,
    this.linkedFindingId,
    this.linkedUnitId,
    this.ownerUsername,
  });

  final String id;
  final String schoolId;
  String title;
  String inquiry;
  String method;
  String findings;
  String nextSteps;
  ActionResearchStatus status;
  String? linkedFindingId;
  String? linkedUnitId;
  String? ownerUsername;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'title': title,
        'inquiry': inquiry,
        'method': method,
        'findings': findings,
        'nextSteps': nextSteps,
        'status': status.name,
        if (linkedFindingId != null) 'linkedFindingId': linkedFindingId,
        if (linkedUnitId != null) 'linkedUnitId': linkedUnitId,
        if (ownerUsername != null) 'ownerUsername': ownerUsername,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ActionResearch.fromMap(Map<String, dynamic> map) {
    return ActionResearch(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      title: map['title'] as String? ?? '',
      inquiry: map['inquiry'] as String? ?? '',
      method: map['method'] as String? ?? '',
      findings: map['findings'] as String? ?? '',
      nextSteps: map['nextSteps'] as String? ?? '',
      status: ActionResearchStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => ActionResearchStatus.planned,
      ),
      linkedFindingId: map['linkedFindingId'] as String?,
      linkedUnitId: map['linkedUnitId'] as String?,
      ownerUsername: map['ownerUsername'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class QaAnalyticsSnapshot {
  const QaAnalyticsSnapshot({
    required this.atRisk,
    required this.academicWatch,
    required this.attendanceWatch,
    required this.withGrades,
    required this.averageAbsenceRate,
  });

  final int atRisk;
  final int academicWatch;
  final int attendanceWatch;
  final int withGrades;
  final double averageAbsenceRate;
}
