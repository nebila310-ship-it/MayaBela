import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/screens/change_password_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/password_hash_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('redacted cloud session cannot match a typed current password locally',
      () {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.cloud',
      password: AuthService.passwordRedactedMarker,
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    expect(AuthService.isStoredPasswordVerifiable('__REDACTED__'), isFalse);
    expect(AuthService.currentPasswordMatches('Welcome12!'), isFalse);
    expect(AuthService.currentPasswordMatches(''), isFalse);
  });

  test('empty cloud profile password is not treated as the login secret', () {
    AuthService.currentUser = RegisteredUser(
      username: 'staff.cloud',
      password: '',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const ['student_affairs'],
    );
    expect(AuthService.currentPasswordMatches('Welcome12!'), isFalse);
  });

  test('hashed local password still verifies the current password', () {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.local',
      password: PasswordHashService.instance.hashPassword('OldPass1234'),
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    expect(AuthService.currentPasswordMatches('OldPass1234'), isTrue);
    expect(AuthService.currentPasswordMatches('wrong-pass'), isFalse);
  });

  testWidgets('current, new, and confirm passwords can be shown',
      (tester) async {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.local',
      password: PasswordHashService.instance.hashPassword('OldPass1234'),
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );

    await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.byTooltip('Show password'), findsNWidgets(3));

    await tester.enterText(
      find.byKey(const Key('change-password-current')),
      'OldPass1234',
    );
    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();

    expect(find.byTooltip('Hide password'), findsOneWidget);
    expect(find.text('OldPass1234'), findsOneWidget);
    expect(find.text('Current password is incorrect'), findsNothing);
  });

  testWidgets('correct hashed current password is accepted', (tester) async {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.local',
      password: PasswordHashService.instance.hashPassword('OldPass1234'),
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );

    await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('change-password-current')),
      'OldPass1234',
    );
    await tester.enterText(
      find.byKey(const Key('change-password-new')),
      'BrandNewPass99',
    );
    await tester.enterText(
      find.byKey(const Key('change-password-confirm')),
      'BrandNewPass99',
    );
    await tester.tap(find.text('Save password'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Current password is incorrect'), findsNothing);
    expect(find.text('Password updated'), findsOneWidget);
  });
}
