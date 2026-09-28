import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/cloud_idle_sync.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/cloud/cloud_sync_flags.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CloudIdleSync.resetForTests();
    CloudSyncEngine.stop();
    AuthService.currentUser = RegisteredUser(
      username: 'idle.cpu',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
  });

  tearDown(() {
    CloudIdleSync.resetForTests();
    CloudSyncEngine.stop();
    AuthService.currentUser = null;
  });

  test('cloud sync stays enabled so Admin login is unchanged', () {
    expect(CloudSyncFlags.enabled, isTrue);
  });

  test('two minutes with no input pauses the 5s poll', () async {
    CloudIdleSync.idleAfter = const Duration(milliseconds: 20);
    CloudIdleSync.onEngineStarted();
    expect(CloudIdleSync.isIdle, isFalse);
    expect(CloudSyncEngine.isPaused, isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(CloudIdleSync.isIdle, isTrue);
    expect(CloudIdleSync.isLivePaused, isTrue);
    expect(CloudSyncEngine.isPaused, isTrue);
  });

  test('pointer activity wakes the poll after idle', () async {
    CloudIdleSync.idleAfter = const Duration(milliseconds: 20);
    CloudIdleSync.onEngineStarted();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(CloudIdleSync.isIdle, isTrue);

    CloudIdleSync.bumpActivity();
    expect(CloudIdleSync.isIdle, isFalse);
    expect(CloudSyncEngine.isPaused, isFalse);
  });

  test('hidden tab pauses live sync immediately without waiting for idle', () {
    CloudIdleSync.onEngineStarted();
    expect(CloudIdleSync.isHidden, isFalse);

    CloudIdleSync.onAppHidden();
    expect(CloudIdleSync.isHidden, isTrue);
    expect(CloudIdleSync.isLivePaused, isTrue);
    expect(CloudSyncEngine.isPaused, isTrue);

    CloudIdleSync.onAppResumed();
    expect(CloudIdleSync.isHidden, isFalse);
    expect(CloudIdleSync.isIdle, isFalse);
  });
}
