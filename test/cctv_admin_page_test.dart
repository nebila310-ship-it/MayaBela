import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cctv/cctv_catalog_service.dart';
import 'package:mayabela/web_erp/pages/web_cctv_page.dart';
import 'package:mayabela/web_erp/router/web_erp_router.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CctvCatalogService.instance.resetForTest();
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  testWidgets('admin CCTV page lists campus camera sites', (tester) async {
    AuthService.currentUser = RegisteredUser(
      username: 'cctv.admin',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebCctvPage())),
    );
    await tester.pump();

    expect(find.text('CCTV'), findsOneWidget);
    expect(find.text('Main gate'), findsOneWidget);
    expect(find.text('Playground'), findsOneWidget);
    expect(find.text('Ready to connect'), findsWidgets);
    expect(find.byKey(const Key('cctv-local-only-banner')), findsOneWidget);
    expect(WebErpRouter.pageFor('cctv'), isA<WebCctvPage>());
  });

  group('school camera list', () {
    setUp(() {
      AuthService.currentUser = RegisteredUser(
        username: 'cctv.admin',
        password: 'x',
        roleKey: AuthService.roleAdmin,
        schoolId: 'FN0597',
      );
    });

    test('adds as many cameras as the school has', () async {
      final cctv = CctvCatalogService.instance;
      for (var i = 1; i <= 8; i++) {
        await cctv.addSite(name: 'Classroom $i', campusName: 'Main Campus');
      }
      final sites = cctv.sitesForSchool('FN0597');
      expect(sites, hasLength(12));
      expect(sites.map((s) => s.id).toSet(), hasLength(12));
      expect(sites.where((s) => s.name.startsWith('Classroom')), hasLength(8));
    });

    test('edits and removes cameras, and removed starters stay gone', () async {
      final cctv = CctvCatalogService.instance;
      final lab = await cctv.addSite(name: 'Lab', campusName: 'Main Campus');
      await cctv.updateSite(
        siteId: lab.id,
        name: 'Science lab',
        campusName: 'Main Campus',
        location: 'Block B',
        streamUrl: 'https://nvr.school.local/hls/lab.m3u8',
      );
      final edited =
          cctv.sitesForSchool('FN0597').singleWhere((s) => s.id == lab.id);
      expect(edited.name, 'Science lab');
      expect(edited.location, 'Block B');
      expect(edited.isWired, isTrue);

      for (final site in cctv.sitesForSchool('FN0597').toList()) {
        await cctv.removeSite(site.id);
      }
      expect(cctv.sitesForSchool('FN0597'), isEmpty);

      await cctv.resetForTest();
      await cctv.ensureLoaded();
      expect(cctv.sitesForSchool('FN0597'), isEmpty);
    });

    testWidgets('admin adds a camera from the page', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WebCctvPage())),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cctv-add-camera-tile')), findsOneWidget);
      await tester.tap(find.byKey(const Key('cctv-add-camera')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('cctv-camera-name')),
        'Library',
      );
      await tester.pump();
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();

      expect(find.text('Library'), findsOneWidget);
      expect(
        CctvCatalogService.instance.sitesForSchool('FN0597'),
        hasLength(5),
      );
    });
  });
}
