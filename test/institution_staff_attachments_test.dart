import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/institution_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/employee_registry_service.dart';
import 'package:mayabela/services/institution_service.dart';
import 'package:mayabela/web_erp/pages/web_institution_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'owner',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
    );
    InstitutionService.instance.resetForTests();
    EmployeeRegistryService.instance.applyPersistedEmployees(
      <EmployeeRecord>[],
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
    InstitutionService.instance.resetForTests();
    EmployeeRegistryService.instance.applyPersistedEmployees(
      <EmployeeRecord>[],
    );
  });

  test('committee memberList round-trips and derives the members label', () {
    final row = InstitutionCommittee(
      id: 'com-1',
      name: 'Safeguarding committee',
      memberList: const [
        InstitutionStaffMember(
          kind: InstitutionStaffKind.teacher,
          personId: 'TCH-1001',
          name: 'Miss Belen',
          title: 'Teacher · Mathematics',
        ),
        InstitutionStaffMember(
          kind: InstitutionStaffKind.employee,
          personId: 'EMP-9001',
          name: 'Amina Driver',
          title: 'Driver',
        ),
      ],
    );
    expect(row.members, 'Miss Belen, Amina Driver');
    final restored = InstitutionCommittee.fromMap(row.toMap());
    expect(restored.memberList.map((m) => m.personId).toList(), [
      'TCH-1001',
      'EMP-9001',
    ]);
    expect(restored.members, 'Miss Belen, Amina Driver');
  });

  test('committee fromMap keeps legacy comma-separated members', () {
    final row = InstitutionCommittee.fromMap({
      'id': 'com-legacy',
      'name': 'Board sub-committee',
      'members': 'Amina, Samuel',
    });
    expect(row.memberList, isEmpty);
    expect(row.members, 'Amina, Samuel');
  });

  test('policy and license keep multiple attachment paths', () {
    final policy = InstitutionPolicy.fromMap({
      'id': 'p1',
      'number': 'POL-1',
      'title': 'Safeguarding',
      'attachmentPaths': ['a.pdf', 'b.docx', ''],
    });
    expect(policy.attachmentPaths, ['a.pdf', 'b.docx']);
    expect(policy.toMap()['attachmentPaths'], ['a.pdf', 'b.docx']);

    final license = InstitutionLicense(
      id: 'l1',
      title: 'MoE operating license',
      attachmentPaths: const ['lic.pdf'],
    );
    expect(
      license
          .copyWith(attachmentPaths: const ['lic.pdf', 'scan.jpg'])
          .attachmentPaths,
      ['lic.pdf', 'scan.jpg'],
    );
  });

  test(
    'staff directory lists teachers and employees and skips linked HR rows',
    () {
      EmployeeRegistryService.instance.applyPersistedEmployees([
        EmployeeRecord(
          employeeId: 'EMP-001',
          schoolId: schoolId,
          fullName: 'Miss Belen HR',
          jobTitle: 'Teacher',
        ),
        EmployeeRecord(
          employeeId: 'EMP-9001',
          schoolId: schoolId,
          fullName: 'Amina Driver',
          jobTitle: 'Driver',
        ),
      ]);

      final staff = InstitutionService.instance.staffDirectory(schoolId);
      expect(staff.any((m) => m.personId == 'TCH-1001'), isTrue);
      expect(staff.any((m) => m.personId == 'EMP-9001'), isTrue);
      expect(staff.any((m) => m.personId == 'EMP-001'), isFalse);
      expect(
        staff.firstWhere((m) => m.personId == 'TCH-1001').kind,
        InstitutionStaffKind.teacher,
      );
      expect(
        staff.firstWhere((m) => m.personId == 'EMP-9001').kind,
        InstitutionStaffKind.employee,
      );
    },
  );

  test('committee members persist on the school snapshot', () async {
    await InstitutionService.instance.upsertCommittee(
      InstitutionCommittee(
        id: 'com-staff',
        name: 'Safeguarding committee',
        memberList: const [
          InstitutionStaffMember(
            kind: InstitutionStaffKind.teacher,
            personId: 'TCH-1001',
            name: 'Miss Belen',
          ),
        ],
      ),
      schoolId: schoolId,
    );
    final rec = InstitutionService.instance.recordFor(schoolId);
    expect(rec.committees.single.memberList.single.personId, 'TCH-1001');
    expect(rec.committees.single.members, 'Miss Belen');
  });

  testWidgets('committee dialog selects staff by name and ID', (tester) async {
    EmployeeRegistryService.instance.applyPersistedEmployees([
      EmployeeRecord(
        employeeId: 'EMP-9001',
        schoolId: schoolId,
        fullName: 'Amina Driver',
        jobTitle: 'Driver',
      ),
    ]);
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebInstitutionPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Governance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Committees'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Members (from school staff)'), findsOneWidget);
    expect(find.text('Miss Belen'), findsOneWidget);
    expect(find.textContaining('TCH-1001'), findsOneWidget);
    expect(find.text('Amina Driver'), findsOneWidget);
    expect(find.textContaining('EMP-9001'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'Safeguarding committee',
    );
    await tester.tap(find.text('Miss Belen'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Safeguarding committee'), findsOneWidget);
    expect(find.textContaining('Miss Belen'), findsWidgets);
  });

  testWidgets('policy and license dialogs offer repeatable attachments', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebInstitutionPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Governance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Policies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add attachment'), findsOneWidget);
    expect(
      find.text(
        'Attach one or more files. Tap Add attachment again to add more.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.attach_file), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Licenses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add attachment'), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
    expect(
      find.text(
        'Attach one or more files. Tap Add attachment again to add more.',
      ),
      findsOneWidget,
    );
  });
}
