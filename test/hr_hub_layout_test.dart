import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/ethiopia_payroll_tax.dart';
import 'package:mayabela/services/payroll_service.dart';
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
    PayrollService.instance.applyPersistedData(profiles: const [], runs: const []);
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
    expect(find.textContaining('Click Basic, Advance, or Other deduct'), findsWidgets);
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
    expect(find.text('Set salary'), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.textContaining('Click Basic, Advance, or Other deduct'), findsOneWidget);
    expect(find.byKey(const ValueKey('payroll-cell-basic-TCH-STAT-1')), findsOneWidget);
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

  testWidgets('payroll cells recalc tax, pension, and net as figures are typed',
      (tester) async {
    TeacherRegistryService.instance.applyPersistedTeachers([
      AdminTeacherRecord(
        teacherId: 'TCH-EDIT-1',
        employeeId: 'TCH-EDIT-1',
        fullName: 'Editable Staff',
        assignedClass: 'Grade 1A',
        schoolId: 'FR-001',
        phone: '0911000099',
      ),
    ]);

    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WebPayrollPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('payroll-cell-basic-TCH-EDIT-1')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('payroll-input-basic-TCH-EDIT-1')),
      '12000',
    );
    await tester.pump();

    final afterBasic = EthiopianPayrollTax.breakdown(basicSalary: 12000);
    expect(find.text('2,250.00'), findsWidgets);
    expect(find.text('840.00'), findsWidgets);
    expect(find.text('8,910.00'), findsWidgets);
    expect(afterBasic.paye, 2250);
    expect(afterBasic.employeePension, 840);
    expect(afterBasic.net, 8910);

    await tester.tap(
      find.byKey(const ValueKey('payroll-cell-advance-TCH-EDIT-1')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('payroll-input-advance-TCH-EDIT-1')),
      '1000',
    );
    await tester.pump();

    expect(find.text('7,910.00'), findsWidgets);
    expect(find.text('840.00'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('payroll-cell-other-TCH-EDIT-1')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('payroll-input-other-TCH-EDIT-1')),
      '250',
    );
    await tester.pump();

    expect(find.text('7,660.00'), findsWidgets);
    expect(find.byKey(const ValueKey('payroll-cell-pension-TCH-EDIT-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('payroll-input-pension-TCH-EDIT-1')), findsNothing);
    expect(find.byKey(const ValueKey('payroll-total-net')), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final saved = PayrollService.instance.registerRows().firstWhere(
          (r) => r.person.personId == 'TCH-EDIT-1',
        );
    expect(saved.calc.basicSalary, 12000);
    expect(saved.calc.salaryAdvance, 1000);
    expect(saved.calc.otherDeductions, 250);
    expect(saved.calc.employeePension, 840);
    expect(saved.calc.net, 7660);
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
