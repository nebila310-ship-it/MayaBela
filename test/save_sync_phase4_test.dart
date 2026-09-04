import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/cloud/staff_content_realtime_sync.dart';
import 'package:mayabela/services/persistence/cloud_outbox_service.dart';
import 'package:mayabela/services/persistence/cloud_save_honesty.dart';
import 'package:mayabela/web_erp/widgets/web_cloud_sync_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CloudOutboxService.instance.resetForTest();
    AuthService.currentUser = null;
    AuthService.clearCloudAccessScope();
  });

  tearDown(() {
    AuthService.currentUser = null;
    AuthService.clearCloudAccessScope();
  });

  test('odd ticks skip bus GPS; even ticks poll it without restoring messages', () {
    expect(CloudSyncEngine.interval.inSeconds * CloudSyncEngine.transportBackupTickEvery, 10);

    for (final tick in const [1, 3, 5, 7]) {
      final collections = CloudSyncEngine.probeCollectionsForTick(tick);
      expect(
        collections,
        isNot(contains(AppCollections.busLivePositions)),
        reason: 'tick $tick must stay on the fast lane',
      );
      expect(collections, isNot(contains(AppCollections.conversations)));
    }

    for (final tick in const [2, 4, 8, 10]) {
      final collections = CloudSyncEngine.probeCollectionsForTick(tick);
      expect(
        collections,
        contains(AppCollections.busLivePositions),
        reason: 'tick $tick is the ~10s GPS backup',
      );
      expect(collections, isNot(contains(AppCollections.conversations)));
      expect(collections, isNot(contains(AppCollections.appNotifications)));
    }
  });

  test('parent GPS backup stays in the role pack; staff watches stay tiny', () {
    AuthService.currentUser = RegisteredUser(
      username: 'parent.phase4',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      contains(AppCollections.busLivePositions),
    );
    expect(
      CloudSyncEngine.probeCollectionsForTick(2),
      contains(AppCollections.busLivePositions),
    );
    expect(
      StaffContentRealtimeSync.watchedCollections,
      [AppCollections.parentLinkRequests],
    );
  });

  test('honesty copy stays local when the outbox still has work', () async {
    final s = AppStrings('en');
    expect(CloudSaveHonesty.bannerLabel(s), isNull);
    expect(
      await CloudSaveHonesty.settle(),
      CloudSaveOutcome.synced,
    );

    await CloudOutboxService.instance.enqueue(
      collection: 'homework',
      docId: 'HW-1',
      data: {'description': 'read chapter 2'},
    );
    expect(CloudOutboxService.instance.pendingCount, 1);
    expect(CloudSaveHonesty.bannerLabel(s), '1 change waiting to sync');
    expect(
      await CloudSaveHonesty.settle(),
      CloudSaveOutcome.waiting,
    );
    expect(
      CloudSaveHonesty.snackbarMessage(
        savedOk: s.homeworkPostedForParents,
        outcome: CloudSaveOutcome.waiting,
        strings: s,
      ),
      s.savedWaitingToSync,
    );
    expect(
      CloudSaveHonesty.snackbarMessage(
        savedOk: s.homeworkPostedForParents,
        outcome: CloudSaveOutcome.synced,
        strings: s,
      ),
      s.homeworkPostedForParents,
    );

    CloudOutboxService.instance.setFlushing(true);
    expect(CloudSaveHonesty.bannerLabel(s), s.cloudSyncingBanner);
    CloudOutboxService.instance.setFlushing(false);
  });

  testWidgets('sync banner is hidden until the outbox has pending writes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebCloudSyncBar())),
    );
    expect(find.byKey(const Key('cloud-sync-status-banner')), findsNothing);

    await CloudOutboxService.instance.enqueue(
      collection: 'homework',
      docId: 'HW-2',
      data: {'description': 'queued'},
    );
    await tester.pump();
    expect(find.byKey(const Key('cloud-sync-status-banner')), findsOneWidget);
    expect(find.text('1 change waiting to sync'), findsOneWidget);
  });
}
