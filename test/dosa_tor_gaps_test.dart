import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/attendance_intelligence_models.dart';
import 'package:mayabela/models/bus_record.dart';
import 'package:mayabela/models/dosa_models.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/dosa_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DosaService.resetForTests();
    ExamService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'vp.dosa',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('scholarship refresh re-reads the markbook and never writes exams',
      () async {
    SchoolDataService.instance.applyPersistedGradeReports([
      StudentGradeReport(
        studentId: 'STU-H001',
        studentName: 'Hana Bekele',
        className: 'Grade 11-H',
        term: 'Term 1',
        subjects: [
          SubjectGrade(subject: 'Math', score: 70, maxScore: 100),
          SubjectGrade(subject: 'Science', score: 70, maxScore: 100),
        ],
      ),
    ]);
    final grant = await DosaService.instance.applyScholarship(
      studentId: 'STU-H001',
      minAverage: 80,
      schoolId: 'TB-001',
    );
    expect(grant.status, ScholarshipStatus.applied);

    SchoolDataService.instance.applyPersistedGradeReports([
      StudentGradeReport(
        studentId: 'STU-H001',
        studentName: 'Hana Bekele',
        className: 'Grade 11-H',
        term: 'Term 1',
        subjects: [
          SubjectGrade(subject: 'Math', score: 92, maxScore: 100),
          SubjectGrade(subject: 'Science', score: 88, maxScore: 100),
        ],
      ),
    ]);
    final refreshed =
        await DosaService.instance.refreshScholarshipAverage(grant.id);
    expect(refreshed.snapshotAverage, 90);
    expect(refreshed.status, ScholarshipStatus.eligible);
    expect(ExamService.instance.attempts, isEmpty);
  });

  test('grievance assignment stays on grievances, not discipline', () async {
    final row = await DosaService.instance.fileGrievance(
      title: 'Late pickup',
      studentId: 'STU-1001',
      category: 'transport',
      schoolId: 'TB-001',
    );
    await DosaService.instance.reviewGrievance(
      row.id,
      GrievanceStatus.reviewing,
      assignedTo: 'dosa.desk',
      dueAt: DateTime.utc(2026, 9, 20),
      category: 'transport',
    );
    final stored = DosaService.instance.grievancesForSchool('TB-001').single;
    expect(Grievance.fromMap(stored.toMap()).assignedTo, 'dosa.desk');
    expect(stored.category, 'transport');
    expect(stored.status, GrievanceStatus.reviewing);
  });

  test('internship career hours stay on internships', () async {
    final intern = await DosaService.instance.addInternship(
      studentId: 'STU-H002',
      host: 'City clinic',
      role: 'Shadow',
      careerField: 'Health',
      supervisor: 'Dr. Alemu',
      schoolId: 'TB-001',
    );
    await DosaService.instance.logInternshipHours(intern.id, 4);
    final stored = DosaService.instance.internshipsForSchool('TB-001').single;
    expect(Internship.fromMap(stored.toMap()).careerField, 'Health');
    expect(stored.hoursLogged, 4);
  });

  test('graduation events can carry venue and academic transport notes',
      () async {
    final event = await DosaService.instance.recordMeeting(
      title: 'Graduation rehearsal',
      startsAt: DateTime.utc(2026, 9, 20),
      kind: DosaMeetingKind.graduation,
      venue: 'Main hall',
      transportRoute: 'Bole → School',
      transportNote: 'Two buses after rehearsal',
      schoolId: 'TB-001',
    );
    expect(event.calendarEventId, isNotNull);
    await DosaService.instance.updateMeetingLogistics(
      id: event.id,
      transportNote: 'Parents wait at gate B',
    );
    final stored = DosaService.instance.academicTransportEvents('TB-001').single;
    expect(DosaMeeting.fromMap(stored.toMap()).venue, 'Main hall');
    expect(stored.transportNote, 'Parents wait at gate B');

    AuthService.currentUser = RegisteredUser(
      username: 'parent.h',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
    );
    expect(DosaService.instance.meetingsForSchool('TB-001'), hasLength(1));
    expect(DosaService.instance.attendanceOversight('TB-001'), isEmpty);
    expect(DosaService.instance.transportCoordination('TB-001'), isEmpty);
  });

  test('oversight reads attendance flags and the bus register', () {
    SchoolDataService.instance.applyPersistedAttendance([
      for (final day in [
        DateTime.utc(2026, 9, 8),
        DateTime.utc(2026, 9, 9),
        DateTime.utc(2026, 9, 10),
      ])
        AttendanceSession(
          className: 'Grade 11-H',
          date: day,
          conductedBy: 'Ms. Test',
          entries: [
            StudentAttendanceEntry(
              studentName: 'Hana Bekele',
              status: AttendanceStatus.absent,
            ),
          ],
        ),
    ]);
    final flags = DosaService.instance.attendanceOversight('TB-001');
    expect(flags, isNotEmpty);
    expect(
      flags.first.level,
      anyOf(RiskLevel.atRisk, RiskLevel.attendanceWatch),
    );

    BusRegistryService.instance.applyPersistedBuses(
      [
        BusRecord(
          busId: 'BUS-9001',
          busNumber: 'MB-11',
          schoolId: 'TB-001',
          routeName: 'Bole → School',
        ),
      ],
      replace: true,
    );
    expect(
      DosaService.instance
          .transportCoordination('TB-001')
          .map((b) => b.routeName),
      contains('Bole → School'),
    );
  });
}
