/// Weekly lesson plans (LIA Phase D). Planning/content only — never a grade store.
enum LessonPlanStatus { draft, published }

enum LessonPlanReviewStatus { none, pending, approved, changesRequested }

class LessonPlan {
  LessonPlan({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.className,
    required this.subject,
    required this.weekStart,
    required this.createdAt,
    required this.updatedAt,
    this.objectives = '',
    this.successCriteria = '',
    this.keyVocabulary = '',
    this.priorKnowledge = '',
    this.starter = '',
    this.activities = '',
    this.plenary = '',
    this.differentiation = '',
    this.assessment = '',
    this.homeLearning = '',
    this.inclusionNotes = '',
    this.durationMinutes,
    this.periodLabel = '',
    this.homeworkIds = const [],
    this.examPaperIds = const [],
    this.learningMaterialIds = const [],
    this.attachmentPaths = const [],
    this.status = LessonPlanStatus.draft,
    this.reviewStatus = LessonPlanReviewStatus.none,
    this.curriculumUnitId,
    this.latestReviewId,
    this.createdBy,
    this.publishedAt,
    this.onlineSessionUrl,
    this.onlineSessionLabel,
    this.onlineSessionIsLive = false,
    this.achievementPercent,
    this.achievementNotes = '',
    this.evaluatedBy,
    this.evaluatedAt,
  });

  final String id;
  final String schoolId;
  String title;
  String className;
  String subject;
  DateTime weekStart;
  String objectives;
  String successCriteria;
  String keyVocabulary;
  String priorKnowledge;
  String starter;
  String activities;
  String plenary;
  String differentiation;
  String assessment;
  String homeLearning;
  String inclusionNotes;
  int? durationMinutes;
  String periodLabel;
  List<String> homeworkIds;
  List<String> examPaperIds;
  List<String> learningMaterialIds;
  List<String> attachmentPaths;
  LessonPlanStatus status;
  LessonPlanReviewStatus reviewStatus;
  String? curriculumUnitId;
  String? latestReviewId;
  String? createdBy;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? publishedAt;
  String? onlineSessionUrl;
  String? onlineSessionLabel;
  bool onlineSessionIsLive;
  int? achievementPercent;
  String achievementNotes;
  String? evaluatedBy;
  DateTime? evaluatedAt;

  bool get isPublished => status == LessonPlanStatus.published;

  bool get hasOnlineSession =>
      (onlineSessionUrl ?? '').trim().isNotEmpty;

  bool get hasLinks =>
      homeworkIds.isNotEmpty ||
      examPaperIds.isNotEmpty ||
      learningMaterialIds.isNotEmpty;

  bool get hasSequence =>
      starter.trim().isNotEmpty ||
      activities.trim().isNotEmpty ||
      plenary.trim().isNotEmpty;

  String get reviewLabel => switch (reviewStatus) {
        LessonPlanReviewStatus.none => '',
        LessonPlanReviewStatus.pending => 'Review pending',
        LessonPlanReviewStatus.approved => 'Approved',
        LessonPlanReviewStatus.changesRequested => 'Changes requested',
      };

  bool get hasAchievement => achievementPercent != null;

  String get achievementLabel {
    final value = achievementPercent;
    if (value == null) return '';
    return 'Achievement $value%';
  }

  static int? clampPercent(int? value) {
    if (value == null) return null;
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
  }

  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

  String get weekLabel {
    final end = weekEnd;
    return '${weekStart.day}/${weekStart.month}–${end.day}/${end.month}';
  }

  bool covers(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(weekStart) && !d.isAfter(weekEnd);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'title': title,
        'className': className,
        'subject': subject,
        'weekStart': weekStart.toIso8601String(),
        'objectives': objectives,
        'successCriteria': successCriteria,
        'keyVocabulary': keyVocabulary,
        'priorKnowledge': priorKnowledge,
        'starter': starter,
        'activities': activities,
        'plenary': plenary,
        'differentiation': differentiation,
        'assessment': assessment,
        'homeLearning': homeLearning,
        'inclusionNotes': inclusionNotes,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        'periodLabel': periodLabel,
        'homeworkIds': homeworkIds,
        'examPaperIds': examPaperIds,
        'learningMaterialIds': learningMaterialIds,
        'attachmentPaths': attachmentPaths,
        'status': status.name,
        'reviewStatus': reviewStatus.name,
        if (curriculumUnitId != null) 'curriculumUnitId': curriculumUnitId,
        if (latestReviewId != null) 'latestReviewId': latestReviewId,
        if (createdBy != null) 'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
        if (onlineSessionUrl != null) 'onlineSessionUrl': onlineSessionUrl,
        if (onlineSessionLabel != null)
          'onlineSessionLabel': onlineSessionLabel,
        'onlineSessionIsLive': onlineSessionIsLive,
        if (achievementPercent != null) 'achievementPercent': achievementPercent,
        'achievementNotes': achievementNotes,
        if (evaluatedBy != null) 'evaluatedBy': evaluatedBy,
        if (evaluatedAt != null) 'evaluatedAt': evaluatedAt!.toIso8601String(),
      };

  factory LessonPlan.fromMap(Map<String, dynamic> map) {
    return LessonPlan(
      id: map['id'] as String? ?? '',
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      title: map['title'] as String? ?? '',
      className: map['className'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      weekStart: _dateOnly(
        DateTime.tryParse(map['weekStart'] as String? ?? '') ?? DateTime.now(),
      ),
      objectives: map['objectives'] as String? ?? '',
      successCriteria: map['successCriteria'] as String? ?? '',
      keyVocabulary: map['keyVocabulary'] as String? ?? '',
      priorKnowledge: map['priorKnowledge'] as String? ?? '',
      starter: map['starter'] as String? ?? '',
      activities: map['activities'] as String? ?? '',
      plenary: map['plenary'] as String? ?? '',
      differentiation: map['differentiation'] as String? ?? '',
      assessment: map['assessment'] as String? ?? '',
      homeLearning: map['homeLearning'] as String? ?? '',
      inclusionNotes: map['inclusionNotes'] as String? ?? '',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt(),
      periodLabel: map['periodLabel'] as String? ?? '',
      homeworkIds: _ids(map['homeworkIds']),
      examPaperIds: _ids(map['examPaperIds']),
      learningMaterialIds: _ids(map['learningMaterialIds']),
      attachmentPaths: _ids(map['attachmentPaths']),
      status: LessonPlanStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => LessonPlanStatus.draft,
      ),
      reviewStatus: LessonPlanReviewStatus.values.firstWhere(
        (v) => v.name == map['reviewStatus'],
        orElse: () => LessonPlanReviewStatus.none,
      ),
      curriculumUnitId: map['curriculumUnitId'] as String?,
      latestReviewId: map['latestReviewId'] as String?,
      createdBy: map['createdBy'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      publishedAt: map['publishedAt'] != null
          ? DateTime.tryParse(map['publishedAt'] as String)
          : null,
      onlineSessionUrl: map['onlineSessionUrl'] as String?,
      onlineSessionLabel: map['onlineSessionLabel'] as String?,
      onlineSessionIsLive: map['onlineSessionIsLive'] as bool? ?? false,
      achievementPercent: clampPercent((map['achievementPercent'] as num?)?.toInt()),
      achievementNotes: map['achievementNotes'] as String? ?? '',
      evaluatedBy: map['evaluatedBy'] as String?,
      evaluatedAt: map['evaluatedAt'] != null
          ? DateTime.tryParse(map['evaluatedAt'] as String)
          : null,
    );
  }

  static List<String> _ids(Object? raw) =>
      (raw as List?)?.map((e) => e.toString()).toList() ?? const [];

  static DateTime mondayOf(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  static DateTime _dateOnly(DateTime day) =>
      DateTime(day.year, day.month, day.day);
}
