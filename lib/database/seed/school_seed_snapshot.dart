import 'package:mayabela/database/models/database_models.dart';

/// Full in-memory snapshot of all school database collections.
class SchoolSeedSnapshot {
  const SchoolSeedSnapshot({
    this.users = const [],
    this.classes = const [],
    this.students = const [],
    this.parents = const [],
    this.parentLinks = const [],
    this.teachers = const [],
    this.teacherAssignments = const [],
    this.drivers = const [],
    this.routes = const [],
    this.transportAssignments = const [],
    this.attendance = const [],
    this.grades = const [],
    this.announcements = const [],
  });

  final List<UserRecord> users;
  final List<ClassRecord> classes;
  final List<StudentRecord> students;
  final List<ParentRecord> parents;
  final List<ParentStudentLink> parentLinks;
  final List<TeacherRecord> teachers;
  final List<TeacherAssignment> teacherAssignments;
  final List<DriverRecord> drivers;
  final List<RouteRecord> routes;
  final List<TransportAssignment> transportAssignments;
  final List<AttendanceRecord> attendance;
  final List<GradeRecord> grades;
  final List<AnnouncementRecord> announcements;

  SchoolSeedSnapshot copyWith({
    List<UserRecord>? users,
    List<ClassRecord>? classes,
    List<StudentRecord>? students,
    List<ParentRecord>? parents,
    List<ParentStudentLink>? parentLinks,
    List<TeacherRecord>? teachers,
    List<TeacherAssignment>? teacherAssignments,
    List<DriverRecord>? drivers,
    List<RouteRecord>? routes,
    List<TransportAssignment>? transportAssignments,
    List<AttendanceRecord>? attendance,
    List<GradeRecord>? grades,
    List<AnnouncementRecord>? announcements,
  }) {
    return SchoolSeedSnapshot(
      users: users ?? this.users,
      classes: classes ?? this.classes,
      students: students ?? this.students,
      parents: parents ?? this.parents,
      parentLinks: parentLinks ?? this.parentLinks,
      teachers: teachers ?? this.teachers,
      teacherAssignments: teacherAssignments ?? this.teacherAssignments,
      drivers: drivers ?? this.drivers,
      routes: routes ?? this.routes,
      transportAssignments: transportAssignments ?? this.transportAssignments,
      attendance: attendance ?? this.attendance,
      grades: grades ?? this.grades,
      announcements: announcements ?? this.announcements,
    );
  }
}
