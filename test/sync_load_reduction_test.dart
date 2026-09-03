import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/cloud/staff_content_realtime_sync.dart';
import 'package:mayabela/services/cloud/student_realtime_sync.dart';
import 'package:mayabela/services/cloud/sync_cursor_store.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SyncCursorStore.instance.resetForTests();
  });

  test('same-school login keeps cursors; school switch wipes them', () async {
    final cursors = SyncCursorStore.instance;
    await cursors.ensureLoaded();
    await cursors.bindToSchool('TB-001');
    await cursors.setCursor('homework', DateTime.utc(2026, 9, 1));
    await cursors.markRoleBoot(const ['homework']);

    await cursors.bindToSchool('TB-001');
    expect(cursors.cursorFor('homework'), isNotNull);
    expect(cursors.cursorFor(SyncCursorStore.bootCursorKey), isNotNull);
    expect(cursors.boundSchoolId, 'TB-001');

    await cursors.bindToSchool('TB-002');
    expect(cursors.cursorFor('homework'), isNull);
    expect(cursors.cursorFor(SyncCursorStore.bootCursorKey), isNull);
    expect(cursors.boundSchoolId, 'TB-002');
  });

  test('unchanged payloads ignore updatedAt so republish does not wake peers', () {
    expect(
      DocumentStore.sameDocumentPayload(
        {
          '_docId': 'STU-1001',
          'fullName': 'Abel',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
        {
          'fullName': 'Abel',
          'updatedAt': '2026-09-04T00:00:00.000Z',
        },
      ),
      isTrue,
    );
    expect(
      DocumentStore.sameDocumentPayload(
        {'fullName': 'Abel'},
        {'fullName': 'Sara'},
      ),
      isFalse,
    );
  });

  test('fast ticks skip live GPS/messages; slow ticks still cover the role pack', () {
    expect(CloudSyncEngine.interval, const Duration(seconds: 5));
    expect(CloudSyncEngine.highPriority, contains(AppCollections.busLivePositions));

    final fast = CloudSyncEngine.probeCollectionsForTick(1);
    expect(fast, isNotEmpty);
    expect(fast, isNot(contains(AppCollections.busLivePositions)));
    expect(fast, isNot(contains(AppCollections.conversations)));
    expect(fast, isNot(contains(AppCollections.appNotifications)));
    expect(fast, contains(AppCollections.gradeReports));
    expect(fast, contains(AppCollections.attendanceSessions));
    expect(fast, contains(AppCollections.parentLinkRequests));

    // Signed-out tests use the default high-priority pack, including live
    // collections as a backup on the slow tick.
    final slow = CloudSyncEngine.probeCollectionsForTick(6);
    expect(slow, equals(CloudSyncEngine.highPriority));
    expect(slow, contains(AppCollections.busLivePositions));
    expect(slow, contains(AppCollections.conversations));
  });

  test('staff realtime watches only the parent-link queue', () {
    expect(
      StaffContentRealtimeSync.watchedCollections,
      [AppCollections.parentLinkRequests],
    );
    expect(StudentRealtimeSync.watchedCollections, isEmpty);
  });

  test('every engine collection maps to a local apply group', () {
    final store = CloudAppStore.instance;
    final all = {
      ...CloudSyncEngine.highPriority,
      ...CloudSyncEngine.standardPriority,
    };
    for (final collection in all) {
      expect(
        store.pullGroupKeyForTest(collection),
        isNotNull,
        reason: '$collection must map to a pull group',
      );
    }
  });
}
