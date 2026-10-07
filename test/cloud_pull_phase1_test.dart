import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';

void main() {
  test(
    'login download pulls payroll and QR history that used to stay on one PC',
    () {
      final source = File(
        'lib/services/persistence/cloud_app_store.dart',
      ).readAsStringSync();
      final admin = _methodBody(source, 'pullForAdminSession');
      final teacher = _methodBody(source, 'pullForTeacherSession');
      final driver = _methodBody(source, 'pullForDriverSession');

      expect(admin, contains('_pullPayroll()'));
      expect(admin, contains('_pullQrScans()'));
      expect(teacher, contains('_pullPayroll()'));
      expect(teacher, contains('_pullQrScans()'));
      expect(driver, contains('_pullSchoolRegistry()'));
    },
  );

  test('idle sync can apply payroll and QR scans on a second laptop', () {
    final store = CloudAppStore.instance;
    expect(
      store.pullGroupKeyForTest(AppCollections.payrollProfiles),
      'payroll',
    );
    expect(store.pullGroupKeyForTest(AppCollections.payrollRuns), 'payroll');
    expect(store.pullGroupKeyForTest(AppCollections.qrScans), 'qr_scans');
    expect(
      store.pullGroupKeyForTest(AppCollections.schoolRegistry),
      'school_registry',
    );
    expect(CloudSyncEngine.standardPriority, contains(AppCollections.qrScans));
    expect(
      CloudSyncEngine.standardPriority,
      contains(AppCollections.payrollProfiles),
    );
  });

  test('driver idle pack includes the school registry for branding', () {
    AuthService.currentUser = RegisteredUser(
      username: 'driver.demo',
      password: 'x',
      roleKey: AuthService.roleDriver,
      schoolId: 'MAL838',
    );
    addTearDown(() => AuthService.currentUser = null);

    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      contains(AppCollections.schoolRegistry),
    );
  });
}

String _methodBody(String source, String name) {
  final start = source.indexOf('Future<void> $name');
  expect(start, greaterThan(0), reason: 'missing $name');
  final next = source.indexOf('\n  /// ', start + 10);
  final end = next < 0 ? source.length : next;
  return source.substring(start, end);
}
