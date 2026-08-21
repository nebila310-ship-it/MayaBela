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
}
