import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/golive_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String read(String path) => File(path).readAsStringSync();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoliveService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'admin.p7',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
  });

  tearDown(() {
    GoliveService.resetForTests();
    AuthService.currentUser = null;
  });

  test('live dry-run starts open and signs off when every row passes', () async {
    final svc = GoliveService.instance;
    expect(svc.dryRunComplete(), isFalse);
    expect(svc.signOffForSchool().items, hasLength(GoliveService.dryRunCatalog.length));
    expect(svc.capacitySnapshot().dryRunTotal, GoliveService.dryRunCatalog.length);

    for (final item in GoliveService.dryRunCatalog) {
      await svc.setDryRunItem(item.id, DryRunStatus.pass);
    }
    expect(svc.dryRunComplete(), isTrue);
    expect(svc.capacitySnapshot().dryRunComplete, isTrue);
    expect(
      svc.signOffForSchool().items.every((item) => item.signedBy == 'admin.p7'),
      isTrue,
    );
  });

  test('Supabase backup confirmation is a record, not a dump', () async {
    final svc = GoliveService.instance;
    expect(svc.supabaseBackupConfirmed(), isFalse);
    final row = await svc.confirmSupabaseBackup(
      kind: 'daily_snapshots',
      note: 'Dashboard daily backups visible',
    );
    expect(row.supabaseBackupConfirmed, isTrue);
    expect(row.supabaseKind, 'daily_snapshots');
    expect(row.supabaseProjectRef, GoliveService.defaultSupabaseProjectRef);
    expect(row.supabaseConfirmedBy, 'admin.p7');
    expect(svc.capacitySnapshot().supabaseBackupConfirmed, isTrue);
  });

  test('teachers cannot sign off the dry-run', () async {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.p7',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    await expectLater(
      GoliveService.instance.setDryRunItem(
        'login-password',
        DryRunStatus.pass,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('sign-off leftover stays on the 30s lane', () {
    expect(AppCollections.goliveSignoffs, 'golive_signoffs');
    expect(CloudSyncEngine.standardPriority, contains('golive_signoffs'));
    expect(CloudSyncEngine.highPriority, isNot(contains('golive_signoffs')));
    expect(
      CloudAppStore.instance.pullGroupKeyForTest(AppCollections.goliveSignoffs),
      'golive',
    );
    expect(
      read('lib/web_erp/pages/web_go_live_page.dart'),
      contains('Confirm Supabase backup'),
    );
    expect(
      read('lib/web_erp/pages/web_go_live_page.dart'),
      contains('Sign-off'),
    );
  });
}
