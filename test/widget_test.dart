import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/login_screen.dart';
import 'package:mayabela/services/login_prefs_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LoginPrefsService.instance.debugReset();
    await AppLocale.instance.load();
    await SchoolRegistryService.instance.load();
    await LoginPrefsService.instance.load();
  });

  testWidgets('Login screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Sign in as'), findsWidgets);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register as Parent'), findsOneWidget);
    expect(find.textContaining('Teacher'), findsWidgets);
  });

  testWidgets('school id and username sit on separate rows', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final schoolId = find.byKey(const Key('login-school-id'));
    final username = find.byKey(const Key('login-username'));
    expect(schoolId, findsOneWidget);
    expect(username, findsOneWidget);

    final schoolRect = tester.getRect(schoolId);
    final userRect = tester.getRect(username);
    expect(schoolRect.overlaps(userRect), isFalse);
    expect(userRect.top, greaterThanOrEqualTo(schoolRect.bottom));
    expect(find.text('School ID'), findsOneWidget);
    expect(find.text('Email, phone, or username'), findsOneWidget);
    expect(find.text('Email / Phone'), findsNothing);
  });
}
