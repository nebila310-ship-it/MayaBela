/// Weekly lesson plans (LIA Phase D). Planning/content only — never a grade store.
enum LessonPlanStatus { draft, published }

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
    this.activities = '',
    this.homeworkIds = const [],
    this.examPaperIds = const [],
    this.learningMaterialIds = const [],
    this.status = LessonPlanStatus.draft,
    this.createdBy,
    this.publishedAt,
  });

  final String id;
  final String schoolId;
  String title;
  String className;
  String subject;
  DateTime weekStart;
  String objectives;
  String activities;
  List<String> homeworkIds;
  List<String> examPaperIds;
  List<String> learningMaterialIds;
  LessonPlanStatus status;
  String? createdBy;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? publishedAt;

  bool get isPublished => status == LessonPlanStatus.published;

  bool get hasLinks =>
      homeworkIds.isNotEmpty ||
      examPaperIds.isNotEmpty ||
      learningMaterialIds.isNotEmpty;

  DateTime get weekEnd => weekStart.add(const Duration(days: 6));

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
        'activities': activities,
        'homeworkIds': homeworkIds,
        'examPaperIds': examPaperIds,
        'learningMaterialIds': learningMaterialIds,
        'status': status.name,
        if (createdBy != null) 'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
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
      activities: map['activities'] as String? ?? '',
      homeworkIds: _ids(map['homeworkIds']),
      examPaperIds: _ids(map['examPaperIds']),
      learningMaterialIds: _ids(map['learningMaterialIds']),
      status: LessonPlanStatus.values.firstWhere(
        (v) => v.name == map['status'],
        orElse: () => LessonPlanStatus.draft,
      ),
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

  static List<String> _ids(Object? raw) =>
      (raw as List?)?.map((e) => e.toString()).toList() ?? const [];

  static DateTime mondayOf(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  static DateTime _dateOnly(DateTime day) =>
      DateTime(day.year, day.month, day.day);
}
