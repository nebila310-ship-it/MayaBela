import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/teacher_credentials_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/web_erp/widgets/web_admin_profile_dialog.dart';
import 'package:mayabela/widgets/staff_role_labels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';

  AdminTeacherRecord staffRecord() => AdminTeacherRecord(
        teacherId: 'GM-10001',
        fullName: 'Desaalegn Hailu',
        assignedClass: '',
        schoolId: schoolId,
        email: 'desa@school.test',
        phone: '09392885399',
        employeeId: 'GM-10001',
        roles: const [],
        loginUsername: 'desa.gm',
        initialPassword: 'Temp#2026',
        staffRoles: const [StaffRoles.generalManager],
      );

  AdminTeacherRecord teacherRecord() => AdminTeacherRecord(
        teacherId: 'TCH-1888',
        fullName: 'Sara Teacher',
        assignedClass: 'Grade 1A',
        subjects: const ['Mathematics'],
        schoolId: schoolId,
        email: 'sara@school.test',
        phone: '0911000001',
        employeeId: 'TCH-1888',
        roles: const [TeacherStaffRole.homeroomTeacher],
        loginUsername: 'sara.tch',
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'owner',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
      fullName: 'School Owner',
    );
    AuthService.applySchoolContext(schoolId);
    SchoolRoleCatalogService.instance.resetForTests();
    SchoolRoleCatalogService.instance.putEmptyForTests(schoolId);
    TeacherRegistryService.instance.applyPersistedTeachers([
      staffRecord(),
      teacherRecord(),
    ]);
  });

  tearDown(() {
    AuthService.currentUser = null;
    SchoolRoleCatalogService.instance.resetForTests();
  });

  test('administration staff login message is not worded as a teacher', () {
    final message =
        TeacherCredentialsService.instance.buildMessage(staffRecord());
    expect(message, contains('administration staff account'));
    expect(message, contains('Sign in as Administration Staff'));
    expect(message, isNot(contains('teacher account')));
    expect(message, contains('09392885399'));
  });

  test('staff role summary uses the school rename', () async {
    await SchoolRoleCatalogService.instance.renameRole(
      roleKey: StaffRoles.generalManager,
      label: 'CEO',
      schoolId: schoolId,
    );
    expect(
      staffRolesSummary(
        const [StaffRoles.generalManager],
        AppLocale.instance.strings,
        schoolId: schoolId,
      ),
      'CEO',
    );
    expect(isAdministrationStaffRecord(staffRecord()), isTrue);
    expect(isAdministrationStaffRecord(teacherRecord()), isFalse);
  });

  test('staff profile dialog source uses staff login resend and edit staff', () {
    final web = File('lib/web_erp/widgets/web_admin_profile_dialog.dart')
        .readAsStringSync();
    expect(web, contains('StaffLoginResendBar'));
    expect(web, contains('s.editStaff'));
    expect(web, contains('s.renameRoleTitle'));
    expect(web, contains('s.staffJobTitle'));
    expect(web, contains('showRenameStaffRoleTitleDialog'));
  });

  testWidgets(
    'administration staff card hides teacher fields and can rename the role',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showWebTeacherProfileDialog(
                  context,
                  teacherId: 'GM-10001',
                  administrationStaff: true,
                ),
                child: const Text('open-staff'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open-staff'));
      await tester.pumpAndSettle();

      expect(find.text('Desaalegn Hailu'), findsWidgets);
      expect(find.text('Edit staff'), findsOneWidget);
      expect(find.text('Edit teacher'), findsNothing);
      expect(find.text('Subjects'), findsNothing);
      expect(find.text('Assigned classes'), findsNothing);
      expect(find.text('Role title'), findsOneWidget);
      expect(find.text('General Manager'), findsOneWidget);
      expect(
        find.text('Resend login information', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('WhatsApp', skipOffstage: false), findsOneWidget);
      expect(find.text('Telegram', skipOffstage: false), findsOneWidget);
      expect(find.text('Copy full login', skipOffstage: false), findsOneWidget);
      expect(find.text('Rename role title'), findsWidgets);

      await tester.tap(find.text('Rename role title').first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'General Manager'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'General Manager'),
        'CEO',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        SchoolRoleCatalogService.instance
            .lookup(StaffRoles.generalManager, schoolId: schoolId)
            ?.labelEn,
        'CEO',
      );
      expect(find.text('CEO'), findsWidgets);
    },
  );

  testWidgets('classroom teacher card still shows subjects and edit teacher',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showWebTeacherProfileDialog(
                context,
                teacherId: 'TCH-1888',
                administrationStaff: false,
              ),
              child: const Text('open-teacher'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-teacher'));
    await tester.pumpAndSettle();

    expect(find.text('Edit teacher'), findsOneWidget);
    expect(find.text('Edit staff'), findsNothing);
    expect(find.text('Subjects'), findsOneWidget);
    expect(find.text('Assigned classes'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Role title'), findsNothing);
    expect(find.text('Rename role title'), findsNothing);
  });
}
