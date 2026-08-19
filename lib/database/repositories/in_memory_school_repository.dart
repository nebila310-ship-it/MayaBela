import 'package:mayabela/database/models/database_models.dart';
import 'package:mayabela/database/repositories/school_repository.dart';
import 'package:mayabela/database/seed/school_seed_snapshot.dart';

/// In-memory repository — default backend for demo / offline mode.
class InMemorySchoolRepository implements SchoolRepository {
  final List<UserRecord> _users = [];
  final List<ClassRecord> _classes = [];
  final List<StudentRecord> _students = [];
  final List<ParentRecord> _parents = [];
  final List<ParentStudentLink> _parentLinks = [];
  final List<TeacherRecord> _teachers = [];
  final List<TeacherAssignment> _teacherAssignments = [];
  final List<DriverRecord> _drivers = [];
  final List<RouteRecord> _routes = [];
  final List<TransportAssignment> _transportAssignments = [];
  final List<AttendanceRecord> _attendance = [];
  final List<GradeRecord> _grades = [];
  final List<AnnouncementRecord> _announcements = [];

  @override
  Future<void> loadSnapshot(SchoolSeedSnapshot snapshot) async {
    _users
      ..clear()
      ..addAll(snapshot.users);
    _classes
      ..clear()
      ..addAll(snapshot.classes);
    _students
      ..clear()
      ..addAll(snapshot.students);
    _parents
      ..clear()
      ..addAll(snapshot.parents);
    _parentLinks
      ..clear()
      ..addAll(snapshot.parentLinks);
    _teachers
      ..clear()
      ..addAll(snapshot.teachers);
    _teacherAssignments
      ..clear()
      ..addAll(snapshot.teacherAssignments);
    _drivers
      ..clear()
      ..addAll(snapshot.drivers);
    _routes
      ..clear()
      ..addAll(snapshot.routes);
    _transportAssignments
      ..clear()
      ..addAll(snapshot.transportAssignments);
    _attendance
      ..clear()
      ..addAll(snapshot.attendance);
    _grades
      ..clear()
      ..addAll(snapshot.grades);
    _announcements
      ..clear()
      ..addAll(snapshot.announcements);
  }

  @override
  Future<SchoolSeedSnapshot> exportSnapshot() async {
    return SchoolSeedSnapshot(
      users: List.unmodifiable(_users),
      classes: List.unmodifiable(_classes),
      students: List.unmodifiable(_students),
      parents: List.unmodifiable(_parents),
      parentLinks: List.unmodifiable(_parentLinks),
      teachers: List.unmodifiable(_teachers),
      teacherAssignments: List.unmodifiable(_teacherAssignments),
      drivers: List.unmodifiable(_drivers),
      routes: List.unmodifiable(_routes),
      transportAssignments: List.unmodifiable(_transportAssignments),
      attendance: List.unmodifiable(_attendance),
      grades: List.unmodifiable(_grades),
      announcements: List.unmodifiable(_announcements),
    );
  }

  @override
  List<UserRecord> get users => List.unmodifiable(_users);

  @override
  List<ClassRecord> get classes => List.unmodifiable(_classes);

  @override
  List<StudentRecord> get students => List.unmodifiable(_students);

  @override
  List<ParentRecord> get parents => List.unmodifiable(_parents);

  @override
  List<ParentStudentLink> get parentLinks => List.unmodifiable(_parentLinks);

  @override
  List<TeacherRecord> get teachers => List.unmodifiable(_teachers);

  @override
  List<TeacherAssignment> get teacherAssignments =>
      List.unmodifiable(_teacherAssignments);

  @override
  List<DriverRecord> get drivers => List.unmodifiable(_drivers);

  @override
  List<RouteRecord> get routes => List.unmodifiable(_routes);

  @override
  List<TransportAssignment> get transportAssignments =>
      List.unmodifiable(_transportAssignments);

  @override
  List<AttendanceRecord> get attendance => List.unmodifiable(_attendance);

  @override
  List<GradeRecord> get grades => List.unmodifiable(_grades);

  @override
  List<AnnouncementRecord> get announcements => List.unmodifiable(_announcements);

  @override
  Future<void> upsertStudent(StudentRecord record) async {
    final idx = _students.indexWhere((s) => s.studentId == record.studentId);
    if (idx >= 0) {
      _students[idx] = record;
    } else {
      _students.add(record);
    }
  }

  @override
  Future<void> upsertClass(ClassRecord record) async {
    final idx = _classes.indexWhere((c) => c.classId == record.classId);
    if (idx >= 0) {
      _classes[idx] = record;
    } else {
      _classes.add(record);
    }
  }

  @override
  Future<void> upsertUser(UserRecord record) async {
    final idx = _users.indexWhere((u) => u.userId == record.userId);
    if (idx >= 0) {
      _users[idx] = record;
    } else {
      _users.add(record);
    }
  }

  @override
  Future<void> upsertParent(ParentRecord record) async {
    final idx = _parents.indexWhere((p) => p.parentId == record.parentId);
    if (idx >= 0) {
      _parents[idx] = record;
    } else {
      _parents.add(record);
    }
  }

  @override
  Future<void> upsertTeacher(TeacherRecord record) async {
    final idx = _teachers.indexWhere((t) => t.teacherId == record.teacherId);
    if (idx >= 0) {
      _teachers[idx] = record;
    } else {
      _teachers.add(record);
    }
  }

  @override
  Future<void> upsertParentLink(ParentStudentLink link) async {
    final idx = _parentLinks.indexWhere((l) => l.linkId == link.linkId);
    if (idx >= 0) {
      _parentLinks[idx] = link;
    } else {
      _parentLinks.add(link);
    }
  }

  @override
  Future<void> upsertTransportAssignment(TransportAssignment assignment) async {
    final idx = _transportAssignments.indexWhere(
      (a) => a.studentId == assignment.studentId,
    );
    if (idx >= 0) {
      _transportAssignments[idx] = assignment;
    } else {
      _transportAssignments.add(assignment);
    }
  }

  @override
  Future<void> removeTransportForStudent(String studentId) async {
    _transportAssignments.removeWhere((a) => a.studentId == studentId);
  }

  @override
  Future<void> upsertTeacherAssignment(TeacherAssignment assignment) async {
    final idx = _teacherAssignments.indexWhere(
      (a) => a.assignmentId == assignment.assignmentId,
    );
    if (idx >= 0) {
      _teacherAssignments[idx] = assignment;
    } else {
      _teacherAssignments.add(assignment);
    }
  }

  @override
  Future<void> upsertAttendance(AttendanceRecord record) async {
    final idx = _attendance.indexWhere(
      (a) => a.attendanceId == record.attendanceId,
    );
    if (idx >= 0) {
      _attendance[idx] = record;
    } else {
      _attendance.add(record);
    }
  }

  @override
  Future<void> upsertGrade(GradeRecord record) async {
    final idx = _grades.indexWhere((g) => g.gradeId == record.gradeId);
    if (idx >= 0) {
      _grades[idx] = record;
    } else {
      _grades.add(record);
    }
  }

  @override
  Future<void> upsertAnnouncement(AnnouncementRecord record) async {
    final idx = _announcements.indexWhere(
      (a) => a.announcementId == record.announcementId,
    );
    if (idx >= 0) {
      _announcements[idx] = record;
    } else {
      _announcements.add(record);
    }
  }
}
