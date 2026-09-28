import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/grade_analytics_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/web_erp/pages/web_attendance_hub_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const className = 'Grade 9Z-ATT';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.att',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      fullName: 'Ms Hana',
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('absent and late notify the linked parent, not the whole class', () {
    final data = SchoolDataService.instance;
    final day = DateTime.utc(2026, 9, 1);

    data.saveAttendanceSession(
      className: className,
      date: day,
      conductedBy: 'Ms Hana',
      entries: [
        StudentAttendanceEntry(
          studentName: 'Sara Bekele',
          status: AttendanceStatus.absent,
        ),
        StudentAttendanceEntry(
          studentName: 'Kidus Bekele',
          status: AttendanceStatus.late,
        ),
        StudentAttendanceEntry(
          studentName: 'Present Peer',
          status: AttendanceStatus.present,
        ),
      ],
    );

    final notes = NotificationService.instance
        .itemsForTests()
        .where((n) => n.type == NotificationType.attendance)
        .where((n) => n.body.contains(className))
        .toList();

    expect(notes.where((n) => n.body.contains('absent')), hasLength(1));
    expect(notes.where((n) => n.body.contains('late')), hasLength(1));
    expect(
      notes.any((n) => n.body.contains('saved attendance for')),
      isFalse,
    );
    expect(
      notes.firstWhere((n) => n.body.contains('Sara Bekele')).targetStudentId,
      'STU-1001',
    );
    expect(
      notes.firstWhere((n) => n.body.contains('Kidus Bekele')).targetStudentId,
      'STU-1002',
    );

    final before = notes.length;
    data.saveAttendanceSession(
      className: className,
      date: day,
      conductedBy: 'Ms Hana',
      entries: [
        StudentAttendanceEntry(
          studentName: 'Sara Bekele',
          status: AttendanceStatus.absent,
        ),
        StudentAttendanceEntry(
          studentName: 'Kidus Bekele',
          status: AttendanceStatus.late,
        ),
      ],
    );
    expect(
      NotificationService.instance
          .itemsForTests()
          .where((n) => n.type == NotificationType.attendance)
          .where((n) => n.body.contains(className))
          .length,
      before,
    );
  });

  test('third consecutive absence alerts admin once', () {
    final data = SchoolDataService.instance;
    final start = DateTime.utc(2026, 9, 2);
    for (var i = 0; i < 2; i++) {
      data.saveAttendanceSession(
        className: className,
        date: start.add(Duration(days: i)),
        conductedBy: 'Ms Hana',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: 'Amina TorAtt',
            status: AttendanceStatus.absent,
          ),
        ],
      );
    }

    data.saveAttendanceSession(
      className: className,
      date: start.add(const Duration(days: 2)),
      conductedBy: 'Ms Hana',
      notifyParents: false,
      entries: [
        StudentAttendanceEntry(
          studentName: 'Amina TorAtt',
          status: AttendanceStatus.absent,
        ),
      ],
    );

    final alerts = NotificationService.instance.itemsForTests().where(
          (n) =>
              n.title == 'Absence pattern detected' &&
              n.body.contains('Amina TorAtt') &&
              n.recipientRole == AuthService.roleAdmin,
        );
    expect(alerts, hasLength(1));
    expect(alerts.first.body, contains('3 consecutive absences'));

    data.saveAttendanceSession(
      className: className,
      date: start.add(const Duration(days: 3)),
      conductedBy: 'Ms Hana',
      notifyParents: false,
      entries: [
        StudentAttendanceEntry(
          studentName: 'Amina TorAtt',
          status: AttendanceStatus.absent,
        ),
      ],
    );
    expect(
      NotificationService.instance.itemsForTests().where(
            (n) =>
                n.title == 'Absence pattern detected' &&
                n.body.contains('Amina TorAtt'),
          ),
      hasLength(1),
    );
  });

  test('analytics joins markbook averages to the live register', () {
    final data = SchoolDataService.instance;
    const student = 'Sara Bekele';
    const joinClass = 'Grade 4A';
    data.saveAttendanceSession(
      className: joinClass,
      date: DateTime.utc(2026, 9, 8),
      conductedBy: 'Ms Hana',
      notifyParents: false,
      entries: [
        StudentAttendanceEntry(
          studentName: student,
          status: AttendanceStatus.present,
        ),
      ],
    );

    final row = GradeAnalyticsService.instance
        .gradeAttendanceRows(className: joinClass)
        .firstWhere((r) => r.studentName == student);
    expect(row.sessions, greaterThan(0));
    expect(row.gradeAverage, greaterThan(0));
  });

  test('attendance hub stays on the existing module', () {
    AuthService.currentUser = RegisteredUser(
      username: 'admin.att',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    expect(ModuleAccess.canView('attendance'), isTrue);
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    expect(ids, contains('attendance'));
    expect(ids, contains('at_risk'));
    expect(ids, contains('analytics'));
  });

  testWidgets('web attendance hub offers take-roll and daily reports',
      (tester) async {
    AuthService.currentUser = RegisteredUser(
      username: 'admin.att.hub',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 1200,
            child: WebAttendanceHubPage(),
          ),
        ),
      ),
    );

    expect(find.text('Attendance'), findsWidgets);
    expect(find.text('Take attendance'), findsOneWidget);
    expect(find.text('Daily reports'), findsOneWidget);
    expect(find.text('Absence patterns & at-risk'), findsNothing);
  });
}
