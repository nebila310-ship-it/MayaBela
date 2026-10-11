import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/hr_workforce_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/employee_registry_service.dart';
import 'package:mayabela/services/hr_workforce_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/web_erp/pages/web_hr_workforce_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'FR-001';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'hr.admin',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
      fullName: 'HR Admin',
    );
    AuthService.applySchoolContext(schoolId);
    TeacherRegistryService.instance.applyPersistedTeachers([
      AdminTeacherRecord(
        teacherId: 'TCH-1',
        employeeId: 'TCH-1',
        fullName: 'Classroom Teacher',
        assignedClass: 'Grade 1A',
        schoolId: schoolId,
        phone: '0911000001',
      ),
      AdminTeacherRecord(
        teacherId: 'ADM-1',
        employeeId: 'ADM-1',
        fullName: 'Office Manager',
        assignedClass: '',
        schoolId: schoolId,
        phone: '0911000002',
        staffRoles: const [StaffRoles.generalManager],
      ),
    ]);
    EmployeeRegistryService.instance.applyPersistedEmployees([
      EmployeeRecord(
        employeeId: 'EMP-1',
        schoolId: schoolId,
        fullName: 'Night Guard',
        jobTitle: 'Guard',
      ),
    ]);
    HrWorkforceService.instance.resetForTests();
  });

  tearDown(() {
    AuthService.currentUser = null;
    HrWorkforceService.instance.resetForTests();
  });

  test('leave days, coverage, approve, and ending-soon contracts', () async {
    final person = HrWorkforceService.instance.peopleForSchool(schoolId).firstWhere(
          (p) => p.personId == 'ADM-1',
        );
    expect(person.kind, HrPersonKind.admin);

    final leave = await HrWorkforceService.instance.requestLeave(
      person: person,
      type: StaffLeaveType.annual,
      startDate: DateTime(2026, 10, 11),
      endDate: DateTime(2026, 10, 13),
      reason: 'Family visit',
    );
    expect(leave.days, 3);
    expect(leave.status, StaffLeaveStatus.pending);
    expect(leave.covers(DateTime(2026, 10, 12)), isTrue);
    expect(leave.covers(DateTime(2026, 10, 14)), isFalse);

    var snap = HrWorkforceService.instance.snapshot(
      schoolId,
      asOf: DateTime(2026, 10, 12),
    );
    expect(snap.headcount, 3);
    expect(snap.adminStaff, 1);
    expect(snap.teachers, 1);
    expect(snap.otherStaff, 1);
    expect(snap.pendingLeave, 1);
    expect(snap.onLeaveToday, 0);

    await HrWorkforceService.instance.reviewLeave(
      leaveId: leave.id,
      status: StaffLeaveStatus.approved,
    );
    snap = HrWorkforceService.instance.snapshot(
      schoolId,
      asOf: DateTime(2026, 10, 12),
    );
    expect(snap.pendingLeave, 0);
    expect(snap.onLeaveToday, 1);

    await HrWorkforceService.instance.upsertEmployment(
      StaffEmploymentFile(
        personId: 'TCH-1',
        schoolId: schoolId,
        personName: 'Classroom Teacher',
        kind: HrPersonKind.teacher,
        hiredOn: DateTime(2025, 1, 1),
        contractEnd: DateTime(2026, 11, 1),
      ),
    );
    final file = HrWorkforceService.instance.fileFor('TCH-1', schoolId: schoolId)!;
    expect(file.stageOn(DateTime(2026, 10, 11)), StaffEmploymentStage.endingSoon);
    expect(file.stageOn(DateTime(2026, 12, 1)), StaffEmploymentStage.expired);

    snap = HrWorkforceService.instance.snapshot(
      schoolId,
      asOf: DateTime(2026, 10, 11),
    );
    expect(snap.contractsWatch, 1);

    await HrWorkforceService.instance.upsertEmployment(
      StaffEmploymentFile(
        personId: 'TCH-1',
        schoolId: 'XX-999',
        personName: 'Other School',
        kind: HrPersonKind.teacher,
        contractEnd: DateTime(2026, 10, 20),
      ),
    );
    expect(
      HrWorkforceService.instance.filesForSchool(schoolId).length,
      1,
    );
  });

  testWidgets('workforce page shows colorful stats and leave actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final person = const HrPersonRef(
      personId: 'ADM-1',
      schoolId: schoolId,
      name: 'Office Manager',
      kind: HrPersonKind.admin,
    );
    await HrWorkforceService.instance.requestLeave(
      person: person,
      type: StaffLeaveType.sick,
      startDate: DateTime(2026, 10, 10),
      endDate: DateTime(2026, 10, 12),
      reason: 'Clinic',
    );
    await HrWorkforceService.instance.upsertEmployment(
      StaffEmploymentFile(
        personId: 'EMP-1',
        schoolId: schoolId,
        personName: 'Night Guard',
        kind: HrPersonKind.employee,
        hiredOn: DateTime(2026, 8, 1),
        probationEnds: DateTime(2026, 11, 1),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WebHrWorkforcePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leave & contracts'), findsOneWidget);
    expect(find.text('Headcount'), findsOneWidget);
    expect(find.text('Pending leave'), findsOneWidget);
    expect(find.text('Office Manager · Sick'), findsOneWidget);
    expect(find.text('Night Guard'), findsOneWidget);
    expect(find.text('Probation'), findsWidgets);
    expect(find.byTooltip('Approve'), findsOneWidget);

    await tester.tap(find.byTooltip('Approve'));
    await tester.pumpAndSettle();
    expect(
      HrWorkforceService.instance.leavesForSchool(schoolId).first.status,
      StaffLeaveStatus.approved,
    );
  });
}
