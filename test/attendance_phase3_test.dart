import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/cloud/app_data_maps.dart';
import 'package:mayabela/models/leave_request.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/screens/attendance_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/leave_request_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

/// Attendance Phase 3: excused/leave, period rolls, safer same-day merge.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.instance.resetForTests();
    LeaveRequestService.instance.applyPersistedData(const []);
    AuthService.currentUser = RegisteredUser(
      username: 'admin.p3',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
    NotificationService.instance.resetForTests();
    LeaveRequestService.instance.applyPersistedData(const []);
  });

  test('excused is excluded from the rate denominator and breaks a streak', () {
    final data = SchoolDataService.instance;
    const className = 'Grade 9Z-P3R';
    const student = 'Phase Three Rate';

    expect(
      data.saveAttendanceSession(
        className: className,
        date: DateTime.utc(2026, 12, 1),
        conductedBy: 'Ms Hana',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: student,
            studentId: 'STU-P3R',
            status: AttendanceStatus.absent,
            updatedAt: DateTime.utc(2026, 12, 1, 8),
          ),
        ],
      ),
      isTrue,
    );
    expect(
      data.saveAttendanceSession(
        className: className,
        date: DateTime.utc(2026, 12, 2),
        conductedBy: 'Ms Hana',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: student,
            studentId: 'STU-P3R',
            status: AttendanceStatus.excused,
            updatedAt: DateTime.utc(2026, 12, 2, 8),
          ),
        ],
      ),
      isTrue,
    );
    expect(
      data.saveAttendanceSession(
        className: className,
        date: DateTime.utc(2026, 12, 3),
        conductedBy: 'Ms Hana',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: student,
            studentId: 'STU-P3R',
            status: AttendanceStatus.present,
            updatedAt: DateTime.utc(2026, 12, 3, 8),
          ),
        ],
      ),
      isTrue,
    );

    final snap = data.attendanceSnapshotForStudent(
      studentName: student,
      className: className,
      studentId: 'STU-P3R',
    );
    expect(snap.present, 1);
    expect(snap.absent, 1);
    expect(snap.excused, 1);
    expect(snap.sessions, 2);
    expect(snap.rate, 0.5);

    expect(
      data.saveAttendanceSession(
        className: className,
        date: DateTime.utc(2026, 12, 3),
        conductedBy: 'Ms Hana',
        notifyParents: true,
        entries: [
          StudentAttendanceEntry(
            studentName: student,
            studentId: 'STU-P3R',
            status: AttendanceStatus.excused,
            updatedAt: DateTime.utc(2026, 12, 3, 9),
          ),
        ],
      ),
      isTrue,
    );
    expect(
      NotificationService.instance.itemsForTests().where(
        (n) => n.type == NotificationType.attendance,
      ),
      isEmpty,
    );
  });

  test(
    'approved leave overlays present/absent, keeps late, and skips a lock',
    () {
      final data = SchoolDataService.instance;
      const className = 'Grade 9Z-P3L';
      final presentDay = DateTime.utc(2026, 12, 7);
      final lateDay = DateTime.utc(2026, 12, 8);
      final lockedDay = DateTime.utc(2026, 12, 9);

      expect(
        data.saveAttendanceSession(
          className: className,
          date: presentDay,
          conductedBy: 'Ms Hana',
          notifyParents: false,
          entries: [
            StudentAttendanceEntry(
              studentName: 'Leave Child',
              studentId: 'STU-P3L',
              status: AttendanceStatus.absent,
              updatedAt: DateTime.utc(2026, 12, 7, 8),
            ),
          ],
        ),
        isTrue,
      );
      expect(
        data.saveAttendanceSession(
          className: className,
          date: lateDay,
          conductedBy: 'Ms Hana',
          notifyParents: false,
          entries: [
            StudentAttendanceEntry(
              studentName: 'Leave Child',
              studentId: 'STU-P3L',
              status: AttendanceStatus.late,
              updatedAt: DateTime.utc(2026, 12, 8, 8),
            ),
          ],
        ),
        isTrue,
      );
      expect(
        data.saveAttendanceSession(
          className: className,
          date: lockedDay,
          conductedBy: 'Ms Hana',
          notifyParents: false,
          locked: true,
          entries: [
            StudentAttendanceEntry(
              studentName: 'Leave Child',
              studentId: 'STU-P3L',
              status: AttendanceStatus.present,
              updatedAt: DateTime.utc(2026, 12, 9, 8),
            ),
          ],
        ),
        isTrue,
      );

      data.applyApprovedLeave(
        LeaveRequest(
          id: 'lr-p3',
          schoolId: 'TB-001',
          studentId: 'STU-P3L',
          studentName: 'Leave Child',
          className: className,
          parentUsername: 'parent.p3',
          parentName: 'Parent P3',
          startDate: presentDay,
          endDate: lockedDay,
          reason: 'Clinic',
          status: LeaveRequestStatus.approved,
          createdAt: DateTime.utc(2026, 12, 6),
          updatedAt: DateTime.utc(2026, 12, 6),
        ),
      );

      expect(
        data.getAttendanceSession(className, presentDay)!.entries.single.status,
        AttendanceStatus.excused,
      );
      expect(
        data.getAttendanceSession(className, lateDay)!.entries.single.status,
        AttendanceStatus.late,
      );
      expect(
        data.getAttendanceSession(className, lockedDay)!.entries.single.status,
        AttendanceStatus.present,
      );
      expect(data.getAttendanceSession(className, lockedDay)!.locked, isTrue);
    },
  );

  test('save overlays an already-approved leave onto a new daily register', () {
    final data = SchoolDataService.instance;
    const className = 'Grade 9Z-P3S';
    final day = DateTime.utc(2026, 12, 10);
    final now = DateTime.now();
    LeaveRequestService.instance.applyPersistedData([
      LeaveRequest(
        id: 'lr-p3-save',
        schoolId: 'TB-001',
        studentId: 'STU-P3S',
        studentName: 'Save Leave',
        className: className,
        parentUsername: 'parent.p3',
        parentName: 'Parent P3',
        startDate: day,
        endDate: day,
        reason: 'Family',
        status: LeaveRequestStatus.approved,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    expect(
      data.saveAttendanceSession(
        className: className,
        date: day,
        conductedBy: 'Ms Hana',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: 'Save Leave',
            studentId: 'STU-P3S',
            status: AttendanceStatus.present,
          ),
        ],
      ),
      isTrue,
    );
    expect(
      data.getAttendanceSession(className, day)!.entries.single.status,
      AttendanceStatus.excused,
    );
  });

  test('period rolls stay off daily lookup, reports, and default history', () {
    final data = SchoolDataService.instance;
    const className = 'Grade 9Z-P3P';
    final day = DateTime.utc(2026, 12, 11);

    expect(
      data.saveAttendanceSession(
        className: className,
        date: day,
        conductedBy: 'Ms Hana',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: 'Period Kid',
            studentId: 'STU-P3P',
            status: AttendanceStatus.present,
            updatedAt: DateTime.utc(2026, 12, 11, 8),
          ),
        ],
      ),
      isTrue,
    );
    expect(
      data.saveAttendanceSession(
        className: className,
        date: day,
        conductedBy: 'Ms Hana',
        notifyParents: false,
        periodKey: 'slot_eng_2',
        periodLabel: 'Period 2 · English',
        entries: [
          StudentAttendanceEntry(
            studentName: 'Period Kid',
            studentId: 'STU-P3P',
            status: AttendanceStatus.absent,
            updatedAt: DateTime.utc(2026, 12, 11, 10),
          ),
        ],
      ),
      isTrue,
    );

    expect(
      data.getAttendanceSession(className, day)!.entries.single.status,
      AttendanceStatus.present,
    );
    expect(
      data
          .getAttendanceSession(className, day, periodKey: 'slot_eng_2')!
          .entries
          .single
          .status,
      AttendanceStatus.absent,
    );

    final daily = data.buildDailyAttendanceReport(day);
    final classSessions = daily.sessions.where(
      (session) => session.className == className,
    );
    expect(classSessions, hasLength(1));
    expect(classSessions.single.presentCount, 1);
    expect(classSessions.single.absentCount, 0);

    expect(data.getAttendanceHistory(className), hasLength(1));
    expect(
      data.getAttendanceHistory(className, dailyOnly: false),
      hasLength(2),
    );

    final dailyMap = AppDataMaps.attendanceSessionToMap(
      data.getAttendanceSession(className, day)!,
    );
    final periodMap = AppDataMaps.attendanceSessionToMap(
      data.getAttendanceSession(className, day, periodKey: 'slot_eng_2')!,
    );
    expect(
      AppDataMaps.attendanceDocId(
        AppDataMaps.attendanceSessionFromMap(dailyMap),
      ),
      isNot(
        AppDataMaps.attendanceDocId(
          AppDataMaps.attendanceSessionFromMap(periodMap),
        ),
      ),
    );
  });

  test(
    'incoming present without updatedAt does not overwrite a later mark',
    () {
      final data = SchoolDataService.instance;
      const className = 'Grade 9Z-P3M';
      final day = DateTime.utc(2026, 12, 12);
      final lateAt = DateTime.utc(2026, 12, 12, 9, 15);

      expect(
        data.saveAttendanceSession(
          className: className,
          date: day,
          conductedBy: 'Ms Hana',
          notifyParents: false,
          entries: [
            StudentAttendanceEntry(
              studentName: 'Merge Kid',
              studentId: 'STU-P3M',
              status: AttendanceStatus.late,
              updatedAt: lateAt,
            ),
          ],
        ),
        isTrue,
      );

      expect(
        data.saveAttendanceSession(
          className: className,
          date: day,
          conductedBy: 'Gate',
          notifyParents: false,
          entries: [
            StudentAttendanceEntry(
              studentName: 'Merge Kid',
              studentId: 'STU-P3M',
              status: AttendanceStatus.present,
            ),
          ],
        ),
        isTrue,
      );
      expect(
        data.getAttendanceSession(className, day)!.entries.single.status,
        AttendanceStatus.late,
      );

      data.applyPersistedAttendance([
        AttendanceSession(
          className: className,
          date: day,
          conductedBy: 'Cloud',
          entries: [
            StudentAttendanceEntry(
              studentName: 'Merge Kid',
              studentId: 'STU-P3M',
              status: AttendanceStatus.absent,
              updatedAt: DateTime.utc(2026, 12, 12, 8),
            ),
          ],
        ),
      ]);
      expect(
        data.getAttendanceSession(className, day)!.entries.single.status,
        AttendanceStatus.late,
      );

      data.applyPersistedAttendance([
        AttendanceSession(
          className: className,
          date: day,
          conductedBy: 'Cloud',
          entries: [
            StudentAttendanceEntry(
              studentName: 'Merge Kid',
              studentId: 'STU-P3M',
              status: AttendanceStatus.excused,
              updatedAt: DateTime.utc(2026, 12, 12, 10),
            ),
          ],
        ),
      ]);
      expect(
        data.getAttendanceSession(className, day)!.entries.single.status,
        AttendanceStatus.excused,
      );
    },
  );

  test('register follows the class list, not a leftover seed session', () {
    final data = SchoolDataService.instance;
    const className = 'Grade 9Z-P3MAYA';
    final day = DateTime.utc(2026, 10, 2);

    expect(
      data.saveAttendanceSession(
        className: className,
        date: day,
        conductedBy: 'Mr. Samuel',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: 'Kidus Bekele',
            status: AttendanceStatus.late,
          ),
        ],
      ),
      isTrue,
    );
    expect(
      data.getAttendanceSession(className, day)!.entries.single.studentName,
      'Kidus Bekele',
    );

    final maya = StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'Maya Live',
      grade: '2',
      className: className,
      dateOfBirth: DateTime(2018, 5, 1),
    );
    data.syncChildFromRegistry(maya.studentId);

    final view = data.attendanceRegisterView(
      className: className,
      date: day,
    );
    expect(view.entries.map((e) => e.studentName), ['Maya Live']);
    expect(view.conductedBy, isNull);
    expect(
      view.entries.any((e) => e.studentName == 'Kidus Bekele'),
      isFalse,
    );

    expect(
      data.saveAttendanceSession(
        className: className,
        date: day,
        conductedBy: 'Homeroom',
        notifyParents: false,
        entries: view.entries,
      ),
      isTrue,
    );
    expect(
      data
          .getAttendanceSession(className, day)!
          .entries
          .map((e) => e.studentName),
      ['Maya Live'],
    );
  });

  testWidgets('register shows excused and a daily period picker', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 1200,
            child: AttendanceScreen(initialClass: 'Grade 4A'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Excused'), findsWidgets);
    expect(find.text('Daily register'), findsOneWidget);
    expect(find.byIcon(Icons.event_available), findsWidgets);
  });
}
