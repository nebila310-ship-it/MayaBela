/// LIA Phase E — curriculum office and academic leadership.
/// Link-only to lesson plans / homework / exam papers. Never a grade store.

enum CurriculumFramework { national, international, school }

enum CurriculumUnitStatus { draft, published, archived }

enum CurriculumFeedbackStatus { open, acknowledged, resolved }

enum LessonPlanReviewDecision { approved, changesRequested }

class CurriculumUnitVersion {
  const CurriculumUnitVersion({
    required this.version,
    required this.snapshot,
    required this.changedBy,
    required this.changedAt,
    this.note,
  });

  final int version;
  final Map<String, dynamic> snapshot;
  final String changedBy;
  final DateTime changedAt;
  final String? note;

  Map<String, dynamic> toMap() => {
        'version': version,
        'snapshot': snapshot,
        'changedBy': changedBy,
        'changedAt': changedAt.toIso8601String(),
        if (note != null) 'note': note,
      };

  factory CurriculumUnitVersion.fromMap(Map<String, dynamic> map) {
    return CurriculumUnitVersion(
      version: (map['version'] as num?)?.toInt() ?? 1,
      snapshot: Map<String, dynamic>.from(map['snapshot'] as Map? ?? {}),
      changedBy: map['changedBy'] as String? ?? '',
      changedAt:
          DateTime.tryParse(map['changedAt'] as String? ?? '') ?? DateTime.now(),
      note: map['note'] as String?,
    );
  }
}

class CurriculumUnit {
  CurriculumUnit({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.subject,
    required this.createdAt,
    required this.updatedAt,
    this.gradeLevel,
    this.className,
    this.strand = '',
    this.description = '',
    this.objectives = '',
    this.framework = CurriculumFramework.national,
    this.standardCodes = const [],
    this.status = CurriculumUnitStatus.draft,
    this.version = 1,
    this.versions = const [],
    this.lessonPlanIds = const [],
    this.examPaperIds = const [],
    this.homeworkIds = const [],
    this.createdBy,
    this.publishedAt,
  });

  final String id;
  final String schoolId;
  String title;
  String subject;
  String? gradeLevel;
  String? className;
  String strand;
  String description;
  String objectives;
  CurriculumFramework framework;
  List<String> standardCodes;
  CurriculumUnitStatus status;
  int version;
  List<CurriculumUnitVersion> versions;
  List<String> lessonPlanIds;
  List<String> examPaperIds;
  List<String> homeworkIds;
  String? createdBy;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? publishedAt;

  bool get isPublished => status == CurriculumUnitStatus.published;

  Map<String, dynamic> toMap({bool includeHistory = true}) => {
        'id': id,
        'schoolId': schoolId,
        'title': title,
        'subject': subject,
        if (gradeLevel != null) 'gradeLevel': gradeLevel,
        if (className != null) 'className': className,
        'strand': strand,
        'description': description,
        'objectives': objectives,
        'framework': framework.name,
        'standardCodes': standardCodes,
        'status': status.name,
        'version': version,
        if (includeHistory)
          'versions': versions.map((v) => v.toMap()).toList(),
        'lessonPlanIds': lessonPlanIds,
        'examPaperIds': examPaperIds,
        'homeworkIds': homeworkIds,
        if (createdBy != null) 'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
      };

  factory CurriculumUnit.fromMap(Map<String, dynamic> map) {
    return CurriculumUnit(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      title: map['title'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      gradeLevel: map['gradeLevel'] as String?,
      className: map['className'] as String?,
      strand: map['strand'] as String? ?? '',
      description: map['description'] as String? ?? '',
      objectives: map['objectives'] as String? ?? '',
      framework: CurriculumFramework.values.firstWhere(
        (v) => v.name == map['framework'],
        orElse: () => CurriculumFramework.national,
      ),
      standardCodes: (map['standardCodes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      status: CurriculumUnitStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => CurriculumUnitStatus.draft,
      ),
      version: (map['version'] as num?)?.toInt() ?? 1,
      versions: (map['versions'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => CurriculumUnitVersion.fromMap(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList() ??
          const [],
      lessonPlanIds: (map['lessonPlanIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      examPaperIds:
          (map['examPaperIds'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      homeworkIds:
          (map['homeworkIds'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      createdBy: map['createdBy'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      publishedAt: map['publishedAt'] != null
          ? DateTime.tryParse(map['publishedAt'] as String)
          : null,
    );
  }
}

class CurriculumFeedback {
  CurriculumFeedback({
    required this.id,
    required this.schoolId,
    required this.curriculumUnitId,
    required this.authorRole,
    required this.authorUsername,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.authorName,
    this.rating,
    this.status = CurriculumFeedbackStatus.open,
  });

  final String id;
  final String schoolId;
  final String curriculumUnitId;
  final String authorRole;
  final String authorUsername;
  String? authorName;
  String body;
  int? rating;
  CurriculumFeedbackStatus status;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'curriculumUnitId': curriculumUnitId,
        'authorRole': authorRole,
        'authorUsername': authorUsername,
        if (authorName != null) 'authorName': authorName,
        'body': body,
        if (rating != null) 'rating': rating,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CurriculumFeedback.fromMap(Map<String, dynamic> map) {
    return CurriculumFeedback(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      curriculumUnitId: map['curriculumUnitId'] as String? ?? '',
      authorRole: map['authorRole'] as String? ?? '',
      authorUsername: map['authorUsername'] as String? ?? '',
      authorName: map['authorName'] as String?,
      body: map['body'] as String? ?? '',
      rating: (map['rating'] as num?)?.toInt(),
      status: CurriculumFeedbackStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => CurriculumFeedbackStatus.open,
      ),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class LessonPlanReview {
  LessonPlanReview({
    required this.id,
    required this.schoolId,
    required this.lessonPlanId,
    required this.decision,
    required this.reviewerUsername,
    required this.createdAt,
    this.curriculumUnitId,
    this.reviewerRole,
    this.notes = '',
  });

  final String id;
  final String schoolId;
  final String lessonPlanId;
  String? curriculumUnitId;
  LessonPlanReviewDecision decision;
  String reviewerUsername;
  String? reviewerRole;
  String notes;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'lessonPlanId': lessonPlanId,
        if (curriculumUnitId != null) 'curriculumUnitId': curriculumUnitId,
        'decision': decision.name,
        'reviewerUsername': reviewerUsername,
        if (reviewerRole != null) 'reviewerRole': reviewerRole,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LessonPlanReview.fromMap(Map<String, dynamic> map) {
    return LessonPlanReview(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      lessonPlanId: map['lessonPlanId'] as String? ?? '',
      curriculumUnitId: map['curriculumUnitId'] as String?,
      decision: LessonPlanReviewDecision.values.firstWhere(
        (v) => v.name == map['decision'],
        orElse: () => LessonPlanReviewDecision.changesRequested,
      ),
      reviewerUsername: map['reviewerUsername'] as String? ?? '',
      reviewerRole: map['reviewerRole'] as String?,
      notes: map['notes'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class TeacherEvaluation {
  TeacherEvaluation({
    required this.id,
    required this.schoolId,
    required this.teacherId,
    required this.teacherName,
    required this.periodLabel,
    required this.createdAt,
    required this.updatedAt,
    this.curriculumFidelity = 3,
    this.planningQuality = 3,
    this.assessmentAlignment = 3,
    this.notes = '',
    this.teacherUsername,
    this.evaluatorUsername,
    this.evaluatorRole,
    this.lessonPlanReviewIds = const [],
  });

  final String id;
  final String schoolId;
  final String teacherId;
  String teacherName;
  String periodLabel;
  int curriculumFidelity;
  int planningQuality;
  int assessmentAlignment;
  String notes;
  String? teacherUsername;
  String? evaluatorUsername;
  String? evaluatorRole;
  List<String> lessonPlanReviewIds;
  final DateTime createdAt;
  DateTime updatedAt;

  double get average =>
      (curriculumFidelity + planningQuality + assessmentAlignment) / 3;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'periodLabel': periodLabel,
        'curriculumFidelity': curriculumFidelity,
        'planningQuality': planningQuality,
        'assessmentAlignment': assessmentAlignment,
        'notes': notes,
        if (teacherUsername != null) 'teacherUsername': teacherUsername,
        if (evaluatorUsername != null) 'evaluatorUsername': evaluatorUsername,
        if (evaluatorRole != null) 'evaluatorRole': evaluatorRole,
        'lessonPlanReviewIds': lessonPlanReviewIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TeacherEvaluation.fromMap(Map<String, dynamic> map) {
    return TeacherEvaluation(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      teacherId: map['teacherId'] as String? ?? '',
      teacherName: map['teacherName'] as String? ?? '',
      periodLabel: map['periodLabel'] as String? ?? '',
      curriculumFidelity: (map['curriculumFidelity'] as num?)?.toInt() ?? 3,
      planningQuality: (map['planningQuality'] as num?)?.toInt() ?? 3,
      assessmentAlignment: (map['assessmentAlignment'] as num?)?.toInt() ?? 3,
      notes: map['notes'] as String? ?? '',
      teacherUsername: map['teacherUsername'] as String?,
      evaluatorUsername: map['evaluatorUsername'] as String?,
      evaluatorRole: map['evaluatorRole'] as String?,
      lessonPlanReviewIds: (map['lessonPlanReviewIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class AcademicMeeting {
  AcademicMeeting({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.startsAt,
    required this.createdAt,
    required this.updatedAt,
    this.agenda = '',
    this.notes = '',
    this.endsAt,
    this.attendeeRoles = const [],
    this.createdBy,
    this.calendarEventId,
  });

  final String id;
  final String schoolId;
  String title;
  String agenda;
  String notes;
  DateTime startsAt;
  DateTime? endsAt;
  List<String> attendeeRoles;
  String? createdBy;
  String? calendarEventId;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'title': title,
        'agenda': agenda,
        'notes': notes,
        'startsAt': startsAt.toIso8601String(),
        if (endsAt != null) 'endsAt': endsAt!.toIso8601String(),
        'attendeeRoles': attendeeRoles,
        if (createdBy != null) 'createdBy': createdBy,
        if (calendarEventId != null) 'calendarEventId': calendarEventId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AcademicMeeting.fromMap(Map<String, dynamic> map) {
    return AcademicMeeting(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      title: map['title'] as String? ?? '',
      agenda: map['agenda'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      startsAt:
          DateTime.tryParse(map['startsAt'] as String? ?? '') ?? DateTime.now(),
      endsAt: map['endsAt'] != null
          ? DateTime.tryParse(map['endsAt'] as String)
          : null,
      attendeeRoles:
          (map['attendeeRoles'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      createdBy: map['createdBy'] as String?,
      calendarEventId: map['calendarEventId'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
