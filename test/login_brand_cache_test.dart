import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/platform/login_chrome_brand.dart';
import 'package:mayabela/services/login_prefs_service.dart';
import 'package:mayabela/services/school_public_brand_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/widgets/fancy_loading_ring.dart';
import 'package:mayabela/widgets/launch_school_splash.dart';
import 'package:mayabela/widgets/login_brand_header.dart';
import 'package:mayabela/web_erp/login/web_login_shell.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SchoolRegistryService.instance.applyPersistedSchools([]);
    LoginPrefsService.instance.debugReset();
    await LoginPrefsService.instance.load();
    SchoolPublicBrandService.instance.debugReset();
    SchoolPublicBrandService.instance.debugAllowNetwork = false;
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

  test(
    'switching school id keeps the previous school brand for later',
    () async {
      await LoginPrefsService.instance.rememberSchoolBrand(
        schoolId: 'ONE',
        name: 'One School',
      );
      await LoginPrefsService.instance.saveLastSchoolId('TWO');
      expect(LoginPrefsService.instance.lastSchoolId, 'TWO');
      expect(LoginPrefsService.instance.rememberedBrand, isNull);
      expect(
        LoginPrefsService.instance.brandForSchool('ONE')?.name,
        'One School',
      );
      expect(LoginPrefsService.instance.brandForSchool('TWO'), isNull);
    },
  );

  testWidgets('login header shows remembered school before registry lookup', (
    tester,
  ) async {
    await LoginPrefsService.instance.rememberSchoolBrand(
      schoolId: 'BRANDTEST',
      name: 'Sunrise Academy',
      logoUrl: 'https://example.com/sunrise.jpg',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LoginBrandHeader(schoolId: 'BRANDTEST')),
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
      MaterialApp(home: LaunchSchoolSplash(brand: brand)),
    );
    await tester.pump();

    expect(find.text('Sunrise Academy'), findsOneWidget);
    expect(find.byType(FancyLoadingRing), findsWidgets);
    expect(find.byKey(const ValueKey('splash-loading-ring')), findsOneWidget);
    expect(find.text('LOADING'), findsOneWidget);
  });

  testWidgets('empty school id shows MaJo Bridge OS, not a remembered school', (
    tester,
  ) async {
    await LoginPrefsService.instance.rememberSchoolBrand(
      schoolId: 'BRANDTEST',
      name: 'Sunrise Academy',
      logoUrl: 'https://example.com/sunrise.jpg',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LoginBrandHeader(schoolId: '')),
      ),
    );
    await tester.pump();

    expect(find.text('MaJo Bridge OS'), findsOneWidget);
    expect(find.text('Sunrise Academy'), findsNothing);
  });

  testWidgets('typed school id switches the login header to the school name', (
    tester,
  ) async {
    await LoginPrefsService.instance.rememberSchoolBrand(
      schoolId: 'BRANDTEST',
      name: 'Sunrise Academy',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LoginBrandHeader(schoolId: 'BRANDTEST')),
      ),
    );
    await tester.pump();

    expect(find.text('Sunrise Academy'), findsOneWidget);
    expect(find.text('MaJo Bridge OS'), findsNothing);
  });

  testWidgets('launch splash without a school id shows MaJo Bridge OS', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LaunchSchoolSplash()));
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

  test('browser tab uses the school name, never the school id', () async {
    SchoolRegistryService.instance.applyPersistedSchools([
      SchoolRecord(id: 'TB-001', name: 'Maya School'),
    ]);

    LoginChromeBrand.apply(schoolId: 'TB-001');
    expect(LoginChromeBrand.tabTitle.value, 'Maya School');
    expect(LoginChromeBrand.tabTitle.value, isNot('TB-001'));

    SchoolRegistryService.instance.applyPersistedSchools([]);
    LoginPrefsService.instance.debugReset();
    await LoginPrefsService.instance.load();
    LoginChromeBrand.apply(schoolId: 'UNKNOWN-99');
    expect(LoginChromeBrand.tabTitle.value, 'MaJo Bridge OS');
    expect(LoginChromeBrand.tabTitle.value, isNot('UNKNOWN-99'));
  });

  testWidgets('web login side brand is MaJo until a school id is typed', (
    tester,
  ) async {
    await LoginPrefsService.instance.rememberSchoolBrand(
      schoolId: 'BRANDTEST',
      name: 'Sunrise Academy',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WebLoginSideBrand(schoolId: '')),
      ),
    );
    await tester.pump();
    expect(find.text('MaJo Bridge OS'), findsOneWidget);
    expect(find.text('Sunrise Academy'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WebLoginSideBrand(schoolId: 'BRANDTEST')),
      ),
    );
    await tester.pump();
    expect(find.text('Sunrise Academy'), findsOneWidget);
    expect(find.text('MaJo Bridge OS'), findsNothing);
  });

  testWidgets(
    'fresh laptop shows logo without using the school id as the name',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WebLoginSideBrand(schoolId: 'MAL838')),
        ),
      );
      await tester.pump();
      expect(find.text('MAL838'), findsNothing);
      expect(find.text('MaJo Bridge OS'), findsOneWidget);

      LoginChromeBrand.apply(schoolId: 'MAL838');
      expect(LoginChromeBrand.tabTitle.value, 'MaJo Bridge OS');
      expect(LoginChromeBrand.tabTitle.value, isNot('MAL838'));
    },
  );

  testWidgets('public school name fills login chrome and the browser tab', (
    tester,
  ) async {
    SchoolPublicBrandService.instance.debugFetchOverride = (id) async {
      expect(id, 'MAL838');
      return const SchoolPublicBrand(
        schoolId: 'MAL838',
        name: 'Fenote Raey Academy',
      );
    };

    final brand = await SchoolPublicBrandService.instance.loadAndRemember(
      'mal838',
    );
    expect(brand?.name, 'Fenote Raey Academy');
    LoginChromeBrand.apply(schoolId: 'MAL838');
    expect(LoginChromeBrand.tabTitle.value, 'Fenote Raey Academy');
    expect(LoginChromeBrand.tabTitle.value, isNot('MAL838'));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              WebLoginSideBrand(schoolId: 'MAL838'),
              LoginBrandHeader(schoolId: 'MAL838'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Fenote Raey Academy'), findsWidgets);
    expect(find.text('MAL838'), findsNothing);
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
    expect(html, contains('mayabela_school_brands'));
    final splashDiv = html.indexOf('<div id="splash">');
    final halo = html.indexOf('id="splash-halo"');
    final splashEnd = html.indexOf(
      '</div>',
      html.indexOf('id="splash-loader-wrap"'),
    );
    expect(splashDiv, greaterThan(0));
    expect(halo, greaterThan(splashDiv));
    expect(halo, lessThan(splashEnd));
  });

  testWidgets('loading ring keeps spinning and changing color', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: FancyLoadingRing(size: 72))),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FancyLoadingRing), findsOneWidget);
    expect(find.text('LOADING'), findsOneWidget);
  });
}
