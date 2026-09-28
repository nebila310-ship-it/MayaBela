/// Named term / semester window on the school academic calendar.
class AcademicTerm {
  const AcademicTerm({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.examStart,
    this.examEnd,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? examStart;
  final DateTime? examEnd;

  bool contains(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  bool get hasExamWindow => examStart != null && examEnd != null;

  AcademicTerm copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? examStart,
    DateTime? examEnd,
    bool clearExamWindow = false,
  }) {
    return AcademicTerm(
      id: id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      examStart: clearExamWindow ? null : (examStart ?? this.examStart),
      examEnd: clearExamWindow ? null : (examEnd ?? this.examEnd),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    if (examStart != null) 'examStart': examStart!.toIso8601String(),
    if (examEnd != null) 'examEnd': examEnd!.toIso8601String(),
  };

  factory AcademicTerm.fromJson(Map<String, dynamic> json) {
    return AcademicTerm(
      id: json['id'] as String? ?? 'term',
      name: json['name'] as String? ?? 'Term',
      startDate:
          DateTime.tryParse(json['startDate'] as String? ?? '') ??
          DateTime.now(),
      endDate:
          DateTime.tryParse(json['endDate'] as String? ?? '') ?? DateTime.now(),
      examStart: json['examStart'] == null
          ? null
          : DateTime.tryParse(json['examStart'] as String),
      examEnd: json['examEnd'] == null
          ? null
          : DateTime.tryParse(json['examEnd'] as String),
    );
  }
}
