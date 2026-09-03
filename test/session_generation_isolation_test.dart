import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/cloud/role_sync_coordinator.dart';
import 'package:mayabela/services/cloud/session_cloud_sync.dart';

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
  });

  tearDown(() async {
    await AuthService.clearSession();
    CloudSyncEngine.stop();
    RoleSyncCoordinator.resetForTests();
  });

  test('A logout then B login invalidates A generation (Tests A/E)', () async {
    AuthService.setSession(user('teacher.a'));
    final genA = AuthService.sessionGeneration;
    expect(AuthService.isCurrentGeneration(genA), isTrue);
    expect(AuthService.isLiveGeneration(genA), isTrue);

    await AuthService.clearSession();
    expect(AuthService.currentUser, isNull);
    expect(AuthService.isCurrentGeneration(genA), isFalse);
    expect(AuthService.isLiveGeneration(genA), isFalse);
    expect(CloudSyncEngine.isStarted, isFalse);

    await SessionCloudSync.startSessionWithCloudSync();
    expect(CloudSyncEngine.isStarted, isFalse);
  });

  test('A finally generation cannot match B session (Tests B/F)', () async {
    AuthService.setSession(user('teacher.a'));
    final genA = AuthService.sessionGeneration;
    await AuthService.clearSession();

    AuthService.setSession(user('teacher.b'));
    final genB = AuthService.sessionGeneration;

    expect(genB, isNot(genA));
    expect(AuthService.isCurrentGeneration(genA), isFalse);
    expect(AuthService.isLiveGeneration(genA), isFalse);
    expect(AuthService.isCurrentGeneration(genB), isTrue);
    expect(AuthService.isLiveGeneration(genB), isTrue);
    expect(AuthService.currentUser?.username, 'teacher.b');
  });

  test('A delayed 600ms callback generation is dead after B login (Test C)',
      () async {
    AuthService.setSession(user('teacher.a'));
    final genA = AuthService.sessionGeneration;
    CloudSyncEngine.start();
    await AuthService.clearSession();

    AuthService.setSession(user('teacher.b'));
    await Future<void>.delayed(const Duration(milliseconds: 700));

    expect(AuthService.isLiveGeneration(genA), isFalse);
    expect(CloudSyncEngine.isStarted, isFalse);
  });

  test('old tick cannot stay live after logout then B login (Test D)', () async {
    AuthService.setSession(user('teacher.a'));
    final genA = AuthService.sessionGeneration;
    await CloudSyncEngine.tick(reason: 'manual');
    await AuthService.clearSession();
    AuthService.setSession(user('teacher.b'));

    expect(AuthService.isLiveGeneration(genA), isFalse);
    await CloudSyncEngine.tick(reason: 'manual');
    expect(CloudSyncEngine.isStarted, isFalse);
  });
}
