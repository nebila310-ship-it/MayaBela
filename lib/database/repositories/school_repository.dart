import 'package:mayabela/database/models/database_models.dart';
import 'package:mayabela/database/seed/school_seed_snapshot.dart';

/// Persistence contract for all school database collections.
abstract class SchoolRepository {
  Future<void> loadSnapshot(SchoolSeedSnapshot snapshot);

  Future<SchoolSeedSnapshot> exportSnapshot();

  List<UserRecord> get users;
  List<ClassRecord> get classes;
  List<StudentRecord> get students;
  List<ParentRecord> get parents;
  List<ParentStudentLink> get parentLinks;
  List<TeacherRecord> get teachers;
  List<TeacherAssignment> get teacherAssignments;
  List<DriverRecord> get drivers;
  List<RouteRecord> get routes;
  List<TransportAssignment> get transportAssignments;
  List<AttendanceRecord> get attendance;
  List<GradeRecord> get grades;
  List<AnnouncementRecord> get announcements;

  Future<void> upsertStudent(StudentRecord record);
  Future<void> upsertClass(ClassRecord record);
  Future<void> upsertUser(UserRecord record);
  Future<void> upsertParent(ParentRecord record);
  Future<void> upsertTeacher(TeacherRecord record);
  Future<void> upsertParentLink(ParentStudentLink link);
  Future<void> upsertTransportAssignment(TransportAssignment assignment);
  Future<void> removeTransportForStudent(String studentId);
  Future<void> upsertTeacherAssignment(TeacherAssignment assignment);
  Future<void> upsertAttendance(AttendanceRecord record);
  Future<void> upsertGrade(GradeRecord record);
  Future<void> upsertAnnouncement(AnnouncementRecord record);
}
