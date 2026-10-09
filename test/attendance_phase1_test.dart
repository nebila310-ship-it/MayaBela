import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/notification_preference.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/notification_preference_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/setup/dashboard_setup.dart';

/// Attendance Phase 1: live parent %, safer QR, notify prefs, teacher at-risk.
///
/// Later phases (not in this PR):
/// Phase 2 — student-id rows, save RBAC, register lock.
/// Phase 3 — excused/leave, period attendance, merge policy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.instance.resetForTests();
    AuthService.currentUser = null;
  });

  tearDown(() {
    AuthService.currentUser = null;
    NotificationService.instance.resetForTests();
  });

  test('parent child attendance rate follows the live register', () {
    AuthService.currentUser = RegisteredUser(
      username: 'parent.p1',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
    );

    final data = SchoolDataService.instance;
    data.saveAttendanceSession(
      className: 'Grade 4A',
      date: DateTime.utc(2026, 10, 2),
      conductedBy: 'Miss Belen',
      notifyParents: false,
      entries: [
        StudentAttendanceEntry(
          studentName: 'Sara Bekele',
          status: AttendanceStatus.absent,
        ),
      ],
    );

    final live = data.attendanceSnapshotForStudent(
      studentName: 'Sara Bekele',
      className: 'Grade 4A',
    );
    expect(live.sessions, greaterThan(0));
    expect(data.getChildById('STU-1001')!.attendanceRate, live.rate);
    expect(
      data
          .getChildren()
          .singleWhere((c) => c.studentId == 'STU-1001')
          .attendanceRate,
      live.rate,
    );
  });

  test('attendance notify is skipped when the parent toggle is off', () async {
    await NotificationPreferenceService.instance.setEnabled(
      AuthService.roleParent,
      NotificationPreferenceKey.attendance,
      false,
    );

    SchoolDataService.instance.saveAttendanceSession(
      className: 'Grade 9Z-P1N',
      date: DateTime.utc(2026, 10, 3),
      conductedBy: 'Ms Hana',
      entries: [
        StudentAttendanceEntry(
          studentName: 'Sara Bekele',
          status: AttendanceStatus.absent,
        ),
      ],
    );

    expect(
      NotificationService.instance.itemsForTests().where(
        (n) =>
            n.type == NotificationType.attendance &&
            n.recipientRole == AuthService.roleParent &&
            n.body.contains('Grade 9Z-P1N'),
      ),
      isEmpty,
    );

    await NotificationPreferenceService.instance.setEnabled(
      AuthService.roleParent,
      NotificationPreferenceKey.attendance,
      true,
    );
  });

  test(
    'first QR scan of the day does not mark the rest of the class absent',
    () {
      const className = 'Grade 9Z-P1QR';
      StudentRegistryService.instance.applyPersistedStudents([
        AdminStudentRecord(
          studentId: 'STU-P1A',
          fullName: 'Phase One Alpha',
          grade: 'Grade 9',
          className: className,
          schoolId: 'TB-001',
          dateOfBirth: DateTime(2012, 1, 1),
        ),
        AdminStudentRecord(
          studentId: 'STU-P1B',
          fullName: 'Phase One Beta',
          grade: 'Grade 9',
          className: className,
          schoolId: 'TB-001',
          dateOfBirth: DateTime(2012, 2, 2),
        ),
      ]);
      final data = SchoolDataService.instance;
      data.upsertStudentQrProfile(
        StudentQrProfile(
          id: 'stu-p1a',
          name: 'Phase One Alpha',
          className: className,
          qrCode: 'STUDENT:STU-P1A',
        ),
      );

    final error = data.recordQrScan(
      qrCode: 'STUDENT:STU-P1A',
      action: QrScanAction.late,
      scannedBy: 'Ms Hana',
      allowedClassName: className,
      syncAttendance: true,
    );
    expect(error, isNull);

    data.upsertStudentQrProfile(
      StudentQrProfile(
        id: 'stu-1005',
        name: 'Liya Solomon',
        className: 'Grade 5B',
        qrCode: 'STUDENT:STU-1005',
      ),
    );
    expect(
      data.recordQrScan(
        qrCode: 'STUDENT:STU-1005',
        action: QrScanAction.present,
        scannedBy: 'Abebe',
        allowedClassName: '5B',
        syncAttendance: true,
      ),
      isNull,
    );

      final session = data.getAttendanceSession(className, DateTime.now());
      expect(session, isNotNull);
      expect(
        session!.entries
            .firstWhere((e) => e.studentName == 'Phase One Alpha')
            .status,
        AttendanceStatus.late,
      );
      final others = session.entries.where(
        (e) => e.studentName != 'Phase One Alpha',
      );
      expect(others, isNotEmpty);
      expect(others.every((e) => e.status == AttendanceStatus.present), isTrue);
    },
  );

  test('teacher dashboard exposes the at-risk tile', () {
    registerAllDashboards();
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.p1',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    expect(
      DashboardRegistry.visibleEntriesFor(
        AuthService.roleTeacher,
      ).map((e) => e.id),
      contains('at_risk'),
    );
  });
}
