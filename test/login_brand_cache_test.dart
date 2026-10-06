import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/platform/login_chrome_brand.dart';
import 'package:mayabela/services/login_prefs_service.dart';
import 'package:mayabela/widgets/fancy_loading_ring.dart';
import 'package:mayabela/widgets/launch_school_splash.dart';
import 'package:mayabela/widgets/login_brand_header.dart';
import 'package:mayabela/web_erp/login/web_login_shell.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LoginPrefsService.instance.debugReset();
    await LoginPrefsService.instance.load();
    LoginChromeBrand.tabTitle.value = LoginChromeBrand.productTitle;
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
    expect(find.byType(FancyLoadingRing), findsWidgets);
    expect(find.byKey(const ValueKey('splash-loading-ring')), findsOneWidget);
    expect(find.text('LOADING'), findsOneWidget);
  });

  testWidgets('empty school id shows MaJo Bridge OS, not a remembered school',
      (tester) async {
    await LoginPrefsService.instance.rememberSchoolBrand(
      schoolId: 'BRANDTEST',
      name: 'Sunrise Academy',
      logoUrl: 'https://example.com/sunrise.jpg',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoginBrandHeader(schoolId: ''),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('MaJo Bridge OS'), findsOneWidget);
    expect(find.text('Sunrise Academy'), findsNothing);
  });

  testWidgets('typed school id switches the login header to the school name',
      (tester) async {
    await LoginPrefsService.instance.rememberSchoolBrand(
      schoolId: 'BRANDTEST',
      name: 'Sunrise Academy',
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
    expect(find.text('MaJo Bridge OS'), findsNothing);
  });

  testWidgets('launch splash without a school id shows MaJo Bridge OS',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LaunchSchoolSplash(),
      ),
    );
    await tester.pump();

    expect(find.text('MaJo Bridge OS'), findsOneWidget);
    expect(find.byType(FancyLoadingRing), findsWidgets);
    expect(find.byKey(const ValueKey('splash-loading-ring')), findsOneWidget);
    expect(find.text('LOADING'), findsOneWidget);
  });

  test('chrome title is MaJo Bridge OS until a school id is entered', () async {
    await LoginPrefsService.instance.rememberSchoolBrand(
      schoolId: 'BRANDTEST',
      name: 'Sunrise Academy',
    );

    LoginChromeBrand.apply(schoolId: '');
    expect(LoginChromeBrand.tabTitle.value, 'MaJo Bridge OS');

    LoginChromeBrand.apply(schoolId: 'BRANDTEST');
    expect(LoginChromeBrand.tabTitle.value, 'Sunrise Academy');

    LoginChromeBrand.apply(schoolId: '  ');
    expect(LoginChromeBrand.tabTitle.value, 'MaJo Bridge OS');
  });

  testWidgets('web login side brand is MaJo until a school id is typed',
      (tester) async {
    await LoginPrefsService.instance.rememberSchoolBrand(
      schoolId: 'BRANDTEST',
      name: 'Sunrise Academy',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WebLoginSideBrand(schoolId: ''),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('MaJo Bridge OS'), findsOneWidget);
    expect(find.text('Sunrise Academy'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WebLoginSideBrand(schoolId: 'BRANDTEST'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Sunrise Academy'), findsOneWidget);
    expect(find.text('MaJo Bridge OS'), findsNothing);
  });

  test('html splash includes a color-shifting loading ring', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('id="splash-halo"'));
    expect(html, contains('id="splash-loading-label"'));
    expect(html, contains('splash-orbit'));
    expect(html, contains('hue-rotate'));
    expect(html, contains('Loading'));
    expect(html, contains("flutter-first-frame"));
    expect(html, contains('flt-glass-pane'));
    final splashDiv = html.indexOf('<div id="splash">');
    final halo = html.indexOf('id="splash-halo"');
    final splashEnd = html.indexOf('</div>', html.indexOf('id="splash-loader-wrap"'));
    expect(splashDiv, greaterThan(0));
    expect(halo, greaterThan(splashDiv));
    expect(halo, lessThan(splashEnd));
  });

  testWidgets('loading ring keeps spinning and changing color', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: FancyLoadingRing(size: 72)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FancyLoadingRing), findsOneWidget);
    expect(find.text('LOADING'), findsOneWidget);
  });
}
