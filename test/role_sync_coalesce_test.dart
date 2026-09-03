import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/cloud/role_sync_coordinator.dart';
import 'package:mayabela/services/cloud/sync_cursor_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RegisteredUser user(String name) => RegisteredUser(
        username: name,
        password: 'secret',
        roleKey: AuthService.roleTeacher,
        schoolId: 'ISO-001',
        fullName: name,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.clearSession();
    CloudSyncEngine.stop();
    RoleSyncCoordinator.resetForTests();
    await SyncCursorStore.instance.ensureLoaded();
    await SyncCursorStore.instance.clearAll();
  });

  tearDown(() async {
    RoleSyncCoordinator.resetForTests();
    await AuthService.clearSession();
    CloudSyncEngine.stop();
  });

  test('initial cursor stamp prevents a second full pull on engine boot',
      () async {
    AuthService.setSession(user('teacher.a'));
    final generation = AuthService.sessionGeneration;
    var pulls = 0;
    RoleSyncCoordinator.debugPullOverride = () async {
      pulls++;
    };

    await RoleSyncCoordinator.markInitialRoleSyncComplete(
      generation: generation,
    );
    expect(
      SyncCursorStore.instance.cursorFor(RoleSyncCoordinator.bootCursorKey),
      isNotNull,
    );

    // Engine-boot full pull only happens when the boot cursor is missing.
    if (SyncCursorStore.instance
            .cursorFor(RoleSyncCoordinator.bootCursorKey) ==
        null) {
      await RoleSyncCoordinator.requestFullRolePull(
        reason: 'engine-boot',
        generation: generation,
      );
    }

    expect(pulls, 0);
    expect(RoleSyncCoordinator.debugCompletedPulls, 0);
  });

  test('concurrent full-sync requests share one in-flight pull', () async {
    AuthService.setSession(user('teacher.a'));
    final generation = AuthService.sessionGeneration;
    final started = Completer<void>();
    final release = Completer<void>();
    var inFlightCount = 0;
    var maxInFlight = 0;

    RoleSyncCoordinator.debugPullOverride = () async {
      inFlightCount++;
      if (inFlightCount > maxInFlight) maxInFlight = inFlightCount;
      if (!started.isCompleted) started.complete();
      await release.future;
      inFlightCount--;
    };

    final first = RoleSyncCoordinator.requestFullRolePull(
      reason: 'polling',
      generation: generation,
    );
    await started.future;
    final second = RoleSyncCoordinator.requestFullRolePull(
      reason: 'realtime',
      generation: generation,
    );

    expect(RoleSyncCoordinator.isFullPullRunning, isTrue);
    expect(RoleSyncCoordinator.debugCompletedPulls, 0);
    expect(maxInFlight, 1);

    release.complete();
    await first;
    await second;

    expect(maxInFlight, 1);
    expect(RoleSyncCoordinator.debugSkippedBecauseRunning, greaterThan(0));
    expect(RoleSyncCoordinator.debugCompletedPulls, greaterThanOrEqualTo(1));
  });

  test('realtime and polling coalesce onto one follow-up', () async {
    AuthService.setSession(user('teacher.a'));
    final generation = AuthService.sessionGeneration;
    final release = Completer<void>();
    var pulls = 0;

    RoleSyncCoordinator.debugPullOverride = () async {
      pulls++;
      if (pulls == 1) await release.future;
    };

    final first = RoleSyncCoordinator.requestFullRolePull(
      reason: 'engine-delta',
      generation: generation,
    );
    await Future<void>.delayed(Duration.zero);
    unawaited(
      RoleSyncCoordinator.requestFullRolePull(
        reason: 'realtime-staff',
        generation: generation,
      ),
    );

    expect(RoleSyncCoordinator.debugFollowUpsScheduled, 1);
    release.complete();
    await first;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(pulls, 2);
    expect(RoleSyncCoordinator.debugCompletedPulls, 2);
  });

  test('stale session generation cannot start a full pull', () async {
    AuthService.setSession(user('teacher.a'));
    final genA = AuthService.sessionGeneration;
    await AuthService.clearSession();

    var pulls = 0;
    RoleSyncCoordinator.debugPullOverride = () async {
      pulls++;
    };

    final ran = await RoleSyncCoordinator.requestFullRolePull(
      reason: 'realtime-staff',
      generation: genA,
    );

    expect(ran, isFalse);
    expect(pulls, 0);
    expect(RoleSyncCoordinator.debugCompletedPulls, 0);
  });

  test('logout cancels coalesced follow-up for the next session', () async {
    AuthService.setSession(user('teacher.a'));
    final genA = AuthService.sessionGeneration;
    final release = Completer<void>();
    final pullGens = <int>[];

    RoleSyncCoordinator.debugPullOverride = () async {
      pullGens.add(AuthService.sessionGeneration);
      if (pullGens.length == 1) await release.future;
    };

    unawaited(
      RoleSyncCoordinator.requestFullRolePull(
        reason: 'engine-delta',
        generation: genA,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    unawaited(
      RoleSyncCoordinator.requestFullRolePull(
        reason: 'realtime-staff',
        generation: genA,
      ),
    );

    await AuthService.clearSession();
    AuthService.setSession(user('teacher.b'));
    final genB = AuthService.sessionGeneration;
    release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(genB, isNot(genA));
    expect(pullGens, isNot(contains(genB)));
    expect(AuthService.isLiveGeneration(genA), isFalse);
    expect(
      await RoleSyncCoordinator.requestFullRolePull(
        reason: 'engine-delta',
        generation: genA,
      ),
      isFalse,
    );
  });

  test('coalesced follow-up still performs a later legitimate sync', () async {
    AuthService.setSession(user('teacher.a'));
    final generation = AuthService.sessionGeneration;
    final release = Completer<void>();
    var pulls = 0;
    RoleSyncCoordinator.debugPullOverride = () async {
      pulls++;
      if (pulls == 1) await release.future;
    };

    final first = RoleSyncCoordinator.requestFullRolePull(
      reason: 'engine-delta',
      generation: generation,
    );
    await Future<void>.delayed(Duration.zero);
    unawaited(
      RoleSyncCoordinator.requestFullRolePull(
        reason: 'realtime-staff',
        generation: generation,
      ),
    );
    release.complete();
    await first;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(pulls, greaterThanOrEqualTo(2));
    expect(RoleSyncCoordinator.debugCompletedPulls, greaterThanOrEqualTo(2));
    expect(
      SyncCursorStore.instance.cursorFor(RoleSyncCoordinator.bootCursorKey),
      isNotNull,
    );
  });
}
