import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_live_location_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

/// Deeper sell-critical integration: grades, parent link, attendance, GPS.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';

  void signIn({
    required String username,
    required String roleKey,
    List<String> staffRoles = const [],
  }) {
    AuthService.currentUser = RegisteredUser(
      username: username,
      password: 'x',
      roleKey: roleKey,
      schoolId: schoolId,
      fullName: username,
      staffRoles: staffRoles,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    SchoolRegistryService.instance.applyPersistedSchools([
      SchoolRecord(
        id: schoolId,
        name: 'Test School',
        gradeLevels: const ['Grade 4', 'Grade 5'],
        sections: const ['A', 'B'],
        gradeWorkflow: const GradeWorkflowSettings(
          requireApproval: true,
          approvalChain: [GradeApprovalRole.academicCoordinator],
        ),
      ),
    ]);
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  group('Grade approve → publish', () {
    test('teacher submit → Section Director approve publishes to parents', () {
      final data = SchoolDataService.instance;
      const student = 'Sara Bekele';
      const className = 'Grade 4A';
      const subject = 'Science';

      signIn(username: 'admin.unlock', roleKey: AuthService.roleAdmin);
      data.adminUnlockSubjectGrade(
        studentName: student,
        className: className,
        subject: subject,
        adminId: 'ADM-1',
        adminName: 'Admin',
      );

      signIn(username: 'teacher.math', roleKey: AuthService.roleTeacher);
      expect(
        data.updateSubjectGrade(
          studentName: student,
          className: className,
          subject: subject,
          score: 91,
          enteredByTeacherId: 'TCH-1001',
        ),
        isTrue,
      );
      expect(
        data.submitSubjectGradeForApproval(
          studentName: student,
          className: className,
          subject: subject,
          teacherId: 'TCH-1001',
        ),
        isTrue,
      );

      var grade = data
          .getGradeReportForStudent(student)!
          .subjects
          .firstWhere((s) => s.subject == subject);
      expect(grade.status, SubjectGradeStatus.pendingApproval);
      expect(grade.publishedToParents, isFalse);
      expect(grade.isVisibleToParent, isFalse);

      // Teacher cannot approve own submission.
      expect(
        data.approveSubjectGrade(
          studentName: student,
          className: className,
          subject: subject,
          reviewerId: 'TCH-1001',
          reviewerName: 'Teacher',
          reviewerRole: AuthService.roleTeacher,
        ),
        isFalse,
      );

      signIn(
        username: 'sd.approver',
        roleKey: AuthService.roleTeacher,
        staffRoles: [StaffRoles.sectionDirector],
      );
      expect(
        data.approveSubjectGrade(
          studentName: student,
          className: className,
          subject: subject,
          reviewerId: 'SD-1',
          reviewerName: 'Section Director',
          reviewerRole: AuthService.roleTeacher,
        ),
        isTrue,
      );

      grade = data
          .getGradeReportForStudent(student)!
          .subjects
          .firstWhere((s) => s.subject == subject);
      expect(grade.status, SubjectGradeStatus.approved);
      expect(grade.publishedToParents, isTrue);
      expect(grade.isVisibleToParent, isTrue);
      expect(grade.score, 91);
    });

    test('with approval required, publish routes to submit (not direct publish)',
        () {
      final data = SchoolDataService.instance;
      const student = 'Daniel Tesfaye';
      const className = 'Grade 4A';
      const subject = 'Amharic';

      signIn(username: 'admin.unlock', roleKey: AuthService.roleAdmin);
      data.adminUnlockSubjectGrade(
        studentName: student,
        className: className,
        subject: subject,
      );

      signIn(username: 'teacher', roleKey: AuthService.roleTeacher);
      data.updateSubjectGrade(
        studentName: student,
        className: className,
        subject: subject,
        score: 80,
        enteredByTeacherId: 'TCH-1001',
      );

      expect(
        data.publishSubjectGrade(
          studentName: student,
          className: className,
          subject: subject,
          teacherId: 'TCH-1001',
        ),
        isTrue,
      );

      final grade = data
          .getGradeReportForStudent(student)!
          .subjects
          .firstWhere((s) => s.subject == subject);
      expect(grade.status, SubjectGradeStatus.pendingApproval);
      expect(grade.publishedToParents, isFalse);
    });
  });

  group('Parent link', () {
    test('verify → pending → admin approve grants access', () async {
      EnrollmentService.instance.replaceLinks([], nextId: 500);
      final dob = DateTime(2015, 6, 1);
      StudentRegistryService.instance.applyPersistedStudents([
        AdminStudentRecord(
          studentId: 'STU-LINK1',
          fullName: 'Link Child',
          grade: 'Grade 4',
          className: 'Grade 4A',
          schoolId: schoolId,
          dateOfBirth: dob,
        ),
      ], replace: true);

      final err = EnrollmentService.instance.verifyAndCreateParentLink(
        schoolId: schoolId,
        studentId: 'STU-LINK1',
        dateOfBirth: dob,
        parentUsername: '0911999888',
        parentFullName: 'Link Parent',
        relationship: ParentRelationship.father,
      );
      expect(err, isNull);

      final links =
          EnrollmentService.instance.linksForParent('0911999888');
      expect(links, hasLength(1));
      expect(links.single.status, ParentLinkStatus.pending);
      expect(links.single.className, 'Grade 4A');
      expect(
        EnrollmentService.instance.approvedStudentIdsForParent('0911999888'),
        isEmpty,
      );

      signIn(username: 'owner', roleKey: AuthService.roleAdmin);
      await EnrollmentService.instance.approveLink(
        links.single.id,
        'Owner',
      );

      expect(links.single.status, ParentLinkStatus.approved);
      expect(
        EnrollmentService.instance.approvedStudentIdsForParent('0911999888'),
        contains('STU-LINK1'),
      );
    });

    test('wrong DOB is rejected', () {
      EnrollmentService.instance.replaceLinks([], nextId: 510);
      StudentRegistryService.instance.applyPersistedStudents([
        AdminStudentRecord(
          studentId: 'STU-LINK2',
          fullName: 'Dob Child',
          grade: 'Grade 4',
          className: 'Grade 4A',
          schoolId: schoolId,
          dateOfBirth: DateTime(2014, 1, 1),
        ),
      ], replace: true);

      final err = EnrollmentService.instance.verifyAndCreateParentLink(
        schoolId: schoolId,
        studentId: 'STU-LINK2',
        dateOfBirth: DateTime(2014, 1, 2),
        parentUsername: '0911777666',
        parentFullName: 'Wrong Dob Parent',
        relationship: ParentRelationship.mother,
      );
      expect(err, isNotNull);
      expect(
        EnrollmentService.instance.linksForParent('0911777666'),
        isEmpty,
      );
    });
  });

  group('Attendance', () {
    test('save session → daily and range reports reflect counts', () {
      final data = SchoolDataService.instance;
      final day = DateTime(2026, 8, 4);

      data.saveAttendanceSession(
        className: 'Grade 4A',
        date: day,
        conductedBy: 'Miss Belen',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: 'Sara Bekele',
            status: AttendanceStatus.present,
          ),
          StudentAttendanceEntry(
            studentName: 'Daniel Tesfaye',
            status: AttendanceStatus.absent,
          ),
          StudentAttendanceEntry(
            studentName: 'Hanna Girma',
            status: AttendanceStatus.late,
          ),
        ],
      );

      final session = data.getAttendanceSession('Grade 4A', day);
      expect(session, isNotNull);
      expect(session!.entries, hasLength(3));

      final daily = data.buildDailyAttendanceReport(day);
      expect(daily.presentCount, greaterThanOrEqualTo(1));
      expect(daily.absentCount, greaterThanOrEqualTo(1));
      expect(daily.lateCount, greaterThanOrEqualTo(1));

      final range = data.buildAttendanceReportForRange(
        fromDate: day.subtract(const Duration(days: 1)),
        toDate: day,
      );
      expect(range.totalCount, greaterThanOrEqualTo(3));
      expect(range.presentCount, greaterThanOrEqualTo(1));
    });
  });

  group('GPS / bus live position', () {
    test('seed and cloud apply store fresh driver positions', () {
      final live = BusLiveLocationService.instance;

      live.seedDemoPosition(
        driverId: 'DRV-1001',
        latitude: 9.03,
        longitude: 38.74,
      );
      final seeded = live.positionFor('DRV-1001');
      expect(seeded, isNotNull);
      expect(seeded!.latitude, closeTo(9.03, 0.0001));
      expect(seeded.longitude, closeTo(38.74, 0.0001));
      expect(seeded.isFresh, isTrue);

      live.applyCloudPosition(
        BusLivePosition(
          driverId: 'drv-1001',
          latitude: 9.04,
          longitude: 38.75,
          timestamp: DateTime.now(),
        ),
      );
      final updated = live.positionFor('DRV-1001');
      expect(updated!.latitude, closeTo(9.04, 0.0001));
      expect(updated.isFresh, isTrue);

      live.applyCloudPosition(
        BusLivePosition(
          driverId: 'DRV-1001',
          latitude: 9.01,
          longitude: 38.70,
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      );
      expect(live.positionFor('DRV-1001')!.isFresh, isFalse);
    });

    test('bus registry has school buses for TB-001', () {
      BusRegistryService.instance.seedFromDriversIfEmpty();
      final buses = BusRegistryService.instance.busesForSchool(schoolId);
      expect(buses, isNotEmpty);
      expect(buses.first.busId, isNotEmpty);
    });
  });
}
