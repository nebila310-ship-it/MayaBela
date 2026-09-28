import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/services/login_prefs_service.dart';
import 'package:mayabela/widgets/launch_school_splash.dart';
import 'package:mayabela/widgets/login_brand_header.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LoginPrefsService.instance.debugReset();
    await LoginPrefsService.instance.load();
  });

  test('persists remembered school brand for the next launch', () async {
    await LoginPrefsService.instance.rememberSchoolBrand(
      schoolId: 'brandtest',
      name: 'Sunrise Academy',
      logoUrl: 'https://example.com/sunrise.jpg',
      logoStyle: SchoolLogoStyle.circular,
    );

    LoginPrefsService.instance.debugReset();
    await LoginPrefsService.instance.load();

    final brand = LoginPrefsService.instance.rememberedBrand;
    expect(LoginPrefsService.instance.lastSchoolId, 'BRANDTEST');
    expect(brand?.name, 'Sunrise Academy');
    expect(brand?.logoUrl, 'https://example.com/sunrise.jpg');
    expect(brand?.logoStyle, SchoolLogoStyle.circular);
    expect(LoginPrefsService.instance.brandForSchool('brandtest'), isNotNull);
    expect(LoginPrefsService.instance.brandForSchool('OTHER'), isNull);
  });

  test('switching school id clears a mismatched remembered brand', () async {
    await LoginPrefsService.instance.rememberSchoolBrand(
      schoolId: 'ONE',
      name: 'One School',
    );
    await LoginPrefsService.instance.saveLastSchoolId('TWO');
    expect(LoginPrefsService.instance.lastSchoolId, 'TWO');
    expect(LoginPrefsService.instance.rememberedBrand, isNull);
  });

  testWidgets('login header shows remembered school before registry lookup',
      (tester) async {
    await LoginPrefsService.instance.rememberSchoolBrand(
      schoolId: 'BRANDTEST',
      name: 'Sunrise Academy',
      logoUrl: 'https://example.com/sunrise.jpg',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoginBrandHeader(schoolId: 'BRANDTEST'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sunrise Academy'), findsOneWidget);
  });

  testWidgets('launch splash shows remembered school name', (tester) async {
    await LoginPrefsService.instance.rememberSchoolBrand(
      schoolId: 'BRANDTEST',
      name: 'Sunrise Academy',
    );
    final brand = LoginPrefsService.instance.rememberedBrand;

    await tester.pumpWidget(
      MaterialApp(
        home: LaunchSchoolSplash(brand: brand),
      ),
    );
    await tester.pump();

    expect(find.text('Sunrise Academy'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
