class Student {
  Student({
    required this.name,
    required this.grade,
    this.parentName,
  });

  final String name;
  final String grade;
  final String? parentName;
}

class SchoolClass {
  SchoolClass({
    required this.name,
    required this.subject,
    required this.schedule,
    required this.room,
    required this.students,
  });

  final String name;
  final String subject;
  final String schedule;
  final String room;
  final List<Student> students;

  int get studentCount => students.length;
}

class ChildProfile {
  ChildProfile({
    required this.name,
    required this.grade,
    required this.className,
    required this.teacher,
    required this.attendanceRate,
    this.studentId,
    this.section,
  });

  final String name;
  final String grade;
  final String className;
  final String teacher;
  final double attendanceRate;
  final String? studentId;
  final String? section;

  /// Section letter parsed from [className] when [section] is omitted (e.g. Grade 4A → A).
  String get displaySection {
    if (section != null && section!.trim().isNotEmpty) {
      return section!.trim();
    }
    final match = RegExp(r'([A-Za-z])$').firstMatch(className.trim());
    return match?.group(1)?.toUpperCase() ?? '';
  }

  static String sectionFromClassName(String className) {
    final match = RegExp(r'([A-Za-z])$').firstMatch(className.trim());
    return match?.group(1)?.toUpperCase() ?? '';
  }
}
