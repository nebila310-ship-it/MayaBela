import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cctv/cctv_catalog_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/cloud_outbox_service.dart';
import 'package:mayabela/web_erp/pages/web_cctv_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CctvCatalogService.instance.resetForTest();
    await CloudOutboxService.instance.resetForTest();
    AuthService.currentUser = null;
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('CCTV is not a MayaBela cloud collection or sync lane', () {
    expect(CctvCatalogService.storesInMayaBelaCloud, isFalse);

    const banned = ['cctv', 'nvr', 'camera_stream', 'camera_feed'];
    final lanes = [
      ...CloudSyncEngine.highPriority,
      ...CloudSyncEngine.standardPriority,
      ...CloudSyncEngine.liveRealtimeCollections,
      ...CloudSyncEngine.transportBackupCollections,
    ];
    for (final name in lanes) {
      final lower = name.toLowerCase();
      expect(
        banned.any(lower.contains),
        isFalse,
        reason: '$name must not be a CCTV/NVR cloud collection',
      );
    }

    expect(CloudAppStore.instance.pullGroupKeyForTest('cctv'), isNull);
    expect(CloudAppStore.instance.pullGroupKeyForTest('cctv_cameras'), isNull);
    expect(CloudAppStore.instance.pullGroupKeyForTest(AppCollections.ictDevices), isNotNull);
  });

  test('NVR URL stays on this device and does not enqueue the outbox', () async {
    await CctvCatalogService.instance.ensureLoaded();
    await CctvCatalogService.instance.setLocalStreamUrl(
      siteId: 'TB-001-gate',
      streamUrl: 'https://nvr.school.local/hls/gate.m3u8',
    );

    final sites = CctvCatalogService.instance.sitesForSchool('TB-001');
    expect(sites.singleWhere((s) => s.id == 'TB-001-gate').isWired, isTrue);
    expect(
      sites.singleWhere((s) => s.id == 'TB-001-gate').streamUrl,
      'https://nvr.school.local/hls/gate.m3u8',
    );
    expect(sites.singleWhere((s) => s.id == 'TB-001-playground').isWired, isFalse);

    expect(CloudOutboxService.instance.hasPending, isFalse);
    expect(CloudOutboxService.instance.mutationCount, 0);
    expect(CloudOutboxService.instance.hasFullPush, isFalse);

    await CctvCatalogService.instance.setLocalStreamUrl(
      siteId: 'TB-001-gate',
      streamUrl: '',
    );
    expect(
      CctvCatalogService.instance.sitesForSchool('TB-001')
          .singleWhere((s) => s.id == 'TB-001-gate')
          .isWired,
      isFalse,
    );
    expect(CloudOutboxService.instance.hasPending, isFalse);
  });

  testWidgets('CCTV page states video is not in the school cloud', (tester) async {
    AuthService.currentUser = RegisteredUser(
      username: 'cctv.admin',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    await CctvCatalogService.instance.ensureLoaded();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebCctvPage())),
    );
    await tester.pump();

    final s = AppStrings('en');
    expect(find.byKey(const Key('cctv-local-only-banner')), findsOneWidget);
    expect(find.text(s.cctvLocalOnlyBanner), findsOneWidget);
    expect(find.text(s.cctvNotInCloudChip), findsWidgets);
    expect(find.text('Main gate'), findsOneWidget);
    expect(find.text(s.cctvReadyToConnect), findsWidgets);
  });
}
