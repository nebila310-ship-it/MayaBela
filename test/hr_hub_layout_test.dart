import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/web_erp/pages/web_hr_hub_page.dart';
import 'package:mayabela/web_erp/pages/web_payroll_page.dart';
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
    expect(find.text('Payroll'), findsOneWidget);
    expect(find.byKey(const ValueKey('hr-register-driver')), findsNothing);
    expect(find.byKey(const ValueKey('hr-live-gps')), findsNothing);

    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hr-register-driver')), findsOneWidget);
    expect(find.byKey(const ValueKey('hr-live-gps')), findsOneWidget);

    await tester.tap(find.text('Payroll'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Income tax (PAYE)'), findsOneWidget);
    expect(find.text('Run payroll'), findsOneWidget);
    expect(find.text('Export Excel'), findsOneWidget);
    expect(find.text('Print / PDF'), findsOneWidget);
    expect(find.text('Income tax'), findsWidgets);
    expect(find.text('Net pay'), findsWidgets);
    expect(find.text('Payroll register'), findsOneWidget);
    expect(find.textContaining('Every column stays on this page'), findsOneWidget);
    expect(find.byKey(const ValueKey('payroll-scroll-right')), findsNothing);
    expect(find.byKey(const ValueKey('web-erp-hscroll-view')), findsNothing);
    expect(find.text('Staff ID'), findsWidgets);
    expect(find.text('Staff pension'), findsOneWidget);
    expect(find.text('Total deduct.'), findsOneWidget);
    expect(find.text('Set salary'), findsWidgets);
    final tableSize = tester.getSize(
      find.byKey(const ValueKey('payroll-register-table')),
    );
    expect(tableSize.width, lessThanOrEqualTo(1200));
    expect(tableSize.width, greaterThan(700));
  });

  testWidgets('payroll register pages 10 employees and keeps every column visible',
      (tester) async {
    TeacherRegistryService.instance.applyPersistedTeachers([
      for (var i = 1; i <= 12; i++)
        AdminTeacherRecord(
          teacherId: 'TCH-PAGE-${i.toString().padLeft(2, '0')}',
          employeeId: 'TCH-PAGE-${i.toString().padLeft(2, '0')}',
          fullName: 'Employee ${i.toString().padLeft(2, '0')}',
          assignedClass: 'Grade 1A',
          schoolId: 'FR-001',
          phone: '09110000${i.toString().padLeft(2, '0')}',
        ),
    ]);

    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WebPayrollPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('payroll-register-table')), findsOneWidget);
    expect(find.text('Employee 01'), findsOneWidget);
    expect(find.text('Employee 10'), findsOneWidget);
    expect(find.text('Employee 12'), findsNothing);
    expect(find.textContaining('1–10 of'), findsOneWidget);
    expect(find.text('Net pay'), findsWidgets);
    expect(find.text('Income tax'), findsWidgets);
    expect(find.text('Staff pension'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('payroll-page-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payroll-page-next')));
    await tester.pumpAndSettle();

    expect(find.text('Employee 12'), findsOneWidget);
    expect(find.text('Employee 01'), findsNothing);
    expect(find.text('Net pay'), findsWidgets);
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
