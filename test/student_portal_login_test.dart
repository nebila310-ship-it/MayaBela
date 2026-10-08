import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/screens/login_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/login_prefs_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_account_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'MAL838';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    SchoolRegistryService.instance.applyPersistedSchools([
      SchoolRecord(
        id: schoolId,
        name: 'Mayu International Academy',
        studentPortal: const StudentPortalSettings(
          enabled: true,
          minimumGrade: 7,
          tempPasswordTemplate: 'EduAba@2026',
        ),
      ),
    ]);
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('school template is the student password, not a unique suffix', () {
    final accounts = StudentAccountService.instance;
    final first = accounts.generateTempPassword(schoolId);
    final second = accounts.generateTempPassword(schoolId);
    expect(first, 'EduAba@2026');
    expect(second, first);
    expect(first.contains('-'), isFalse);
    expect(first, isNot(contains('#')));
  });

  test('{year} in the school template resolves to the current year', () {
    SchoolRegistryService.instance.applyPersistedSchools([
      SchoolRecord(
        id: schoolId,
        name: 'Mayu International Academy',
        studentPortal: const StudentPortalSettings(
          tempPasswordTemplate: 'EduAba@{year}',
        ),
      ),
    ]);
    expect(
      StudentAccountService.instance.resolvedTempPassword(schoolId),
      'EduAba@${DateTime.now().year}',
    );
  });

  test(
    'shared credentials use the set password even if a unique leftover is stored',
    () {
      final leftover = AdminStudentRecord(
        studentId: 'STU-1013',
        fullName: 'Sami Test',
        grade: 'Grade 8',
        className: 'Grade 8A',
        schoolId: schoolId,
        dateOfBirth: DateTime(2012, 1, 1),
        loginUsername: 'sami1013',
        initialPassword: 'EduAba@2-2#SXN#LTQD',
        portalAccountStatus: StudentAccountStatus.active,
      );
      expect(
        StudentAccountService.instance.passwordForShare(leftover),
        'EduAba@2026',
      );
    },
  );

  test('new portal account logs in with the school-set password', () async {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: schoolId,
      fullName: 'Sami Portal',
      grade: 'Grade 8',
      className: 'Grade 8A',
      dateOfBirth: DateTime(2012, 4, 10),
    );

    final created = await StudentAccountService.instance.createPortalAccount(
      studentId: student.studentId,
      createdBy: 'admin',
      schoolId: schoolId,
    );
    expect(created, isNotNull);
    expect(created!.loginUsername, isNotEmpty);
    expect(created.initialPassword, 'EduAba@2026');

    final error = AuthService.validateLogin(
      roleKey: AuthService.roleStudent,
      username: created.loginUsername!,
      password: 'EduAba@2026',
      schoolId: schoolId,
    );
    expect(error, isNull);
    expect(AuthService.currentUser?.roleKey, AuthService.roleStudent);
    expect(AuthService.currentUser?.linkedStudentId, student.studentId);

    final uniqueRejected = AuthService.validateLogin(
      roleKey: AuthService.roleStudent,
      username: created.loginUsername!,
      password: 'EduAba@2-2#SXN#LTQD',
      schoolId: schoolId,
    );
    expect(uniqueRejected, 'invalid');
  });

  test('first-login student still signs in with the school template', () {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: schoolId,
      fullName: 'Sami Leftover',
      grade: 'Grade 8',
      className: 'Grade 8A',
      dateOfBirth: DateTime(2012, 4, 10),
    );
    const username = 'samileftover1013';
    expect(
      AuthService.registerStudentAccount(
        fullName: student.fullName,
        schoolId: schoolId,
        username: username,
        linkedStudentId: student.studentId,
        password: 'EduAba@2-2#SXN#LTQD',
        mustChangePassword: true,
      ),
      isNull,
    );
    StudentRegistryService.instance.replaceStudent(
      student.copyWith(
        loginUsername: username,
        initialPassword: 'EduAba@2-2#SXN#LTQD',
        mustChangePassword: true,
        portalAccountStatus: StudentAccountStatus.active,
      ),
    );

    expect(
      AuthService.validateLogin(
        roleKey: AuthService.roleStudent,
        username: username,
        password: 'EduAba@2026',
        schoolId: schoolId,
      ),
      isNull,
    );
  });

  testWidgets('student login does not show the public demo banner', (
    tester,
  ) async {
    LoginPrefsService.instance.debugReset();
    await AppLocale.instance.load();
    await LoginPrefsService.instance.load();

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const ValueKey('login-role-teacher')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Student').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-student-demo')), findsNothing);
    expect(find.textContaining('demo.student'), findsNothing);
    expect(find.textContaining('Use student demo'), findsNothing);
    expect(find.textContaining('Welcome12!'), findsNothing);
  });
}
