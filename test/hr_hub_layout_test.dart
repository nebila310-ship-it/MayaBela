import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/web_erp/pages/web_hr_hub_page.dart';
import 'package:mayabela/web_erp/pages/web_teachers_table_page.dart';
import 'package:mayabela/web_erp/pages/web_transport_dashboard_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'hr.admin',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'FR-001',
      fullName: 'HR Admin',
    );
    TeacherRegistryService.instance.applyPersistedTeachers([
      AdminTeacherRecord(
        teacherId: 'TCH-STAT-1',
        employeeId: 'TCH-STAT-1',
        fullName: 'Status Visible',
        assignedClass: 'Grade 1A',
        schoolId: 'FR-001',
        phone: '0911000000',
      ),
    ]);
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  testWidgets('teacher Status column stays fully visible on a tight desktop width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WebTeachersTablePage(
            directoryMode: WebTeachersDirectoryMode.classroomTeachers,
            embedded: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(WebTeachersTablePage.directoryMinTableWidth, 1180);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Stat'), findsNothing);
  });

  testWidgets('HR Teachers tab does not show driver or GPS actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WebHrHubPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teachers'), findsOneWidget);
    expect(find.byKey(const ValueKey('hr-register-driver')), findsNothing);
    expect(find.byKey(const ValueKey('hr-live-gps')), findsNothing);

    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hr-register-driver')), findsOneWidget);
    expect(find.byKey(const ValueKey('hr-live-gps')), findsOneWidget);
  });

  testWidgets('Transport tile hosts Register Driver and Live GPS',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WebTransportDashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('hr-register-driver')), findsOneWidget);
    expect(find.byKey(const ValueKey('hr-live-gps')), findsOneWidget);
    expect(find.text('Register Driver'), findsOneWidget);
    expect(find.text('Live GPS'), findsOneWidget);
  });
}
