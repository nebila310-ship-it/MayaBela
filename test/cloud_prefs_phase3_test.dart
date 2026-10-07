import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/notification_preference.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cctv/cctv_catalog_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/cloud/school_account_ids.dart';
import 'package:mayabela/services/cloud/user_cloud_preferences.dart';
import 'package:mayabela/services/notification_preference_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/web_erp/services/web_erp_prefs_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'admin.mal838',
      password: 'secret-must-not-sync',
      roleKey: AuthService.roleAdmin,
      schoolId: 'MAL838',
      fullName: 'Nabil Ahmed',
    );
    UserCloudPreferences.instance.resetForTests();
    UserPreferencesService.instance.resetForTests();
    WebErpPrefsService.instance.resetForTests();
    NotificationPreferenceService.instance.resetForTests();
    NotificationService.instance.resetForTests();
    AppLocale.instance.resetForTests();
  });

  tearDown(() {
    AuthService.currentUser = null;
    UserCloudPreferences.instance.resetForTests();
    UserPreferencesService.instance.resetForTests();
    WebErpPrefsService.instance.resetForTests();
    NotificationPreferenceService.instance.resetForTests();
    NotificationService.instance.resetForTests();
    AppLocale.instance.resetForTests();
  });

  test('prefs snapshot round-trips without passwords or owner PIN', () async {
    AppLocale.instance.setLanguage('am');
    UserPreferencesService.instance.setDarkMode(true);
    UserPreferencesService.instance.setCompactDashboard(true);
    UserPreferencesService.instance.setOrder('admin', ['fees', 'students']);
    await WebErpPrefsService.instance.toggleFavorite('payroll');
    await WebErpPrefsService.instance.recordVisit('inventory');
    await NotificationPreferenceService.instance.setEnabled(
      AuthService.roleAdmin,
      NotificationPreferenceKey.messages,
      false,
    );
    await NotificationService.instance.applyCloudReadIds(['n1', 'n2']);

    final snapshot = UserCloudPreferences.instance.buildSnapshot();
    expect(snapshot['languageCode'], 'am');
    expect(snapshot['darkMode'], isTrue);
    expect(snapshot['compactDashboard'], isTrue);
    expect(snapshot['webErpFavorites'], contains('payroll'));
    expect(snapshot['webErpRecents'], contains('inventory'));
    expect(snapshot['notificationReadIds'], containsAll(['n1', 'n2']));
    expect(
      snapshot['notificationPrefsByRole'][AuthService.roleAdmin]['messages'],
      isFalse,
    );
    expect(snapshot['username'], 'admin.mal838');
    expect(snapshot['schoolId'], 'MAL838');
    expect(snapshot.containsKey('password'), isFalse);
    expect(snapshot.containsKey('passwordHash'), isFalse);
    expect(snapshot.containsKey('pin'), isFalse);
    expect(snapshot.containsKey('login_saved_entries'), isFalse);
    expect(
      snapshot.values.whereType<String>().any(
        (v) => v.contains('secret-must-not-sync'),
      ),
      isFalse,
    );

    final stuffed = UserCloudPreferences.sanitize({
      ...snapshot,
      'password': 'hacked',
      'platform_owner_pin_hash': 'abc',
      'rememberMePassword': 'nope',
      'accessToken': 'jwt-here',
    });
    expect(stuffed.containsKey('password'), isFalse);
    expect(stuffed.containsKey('platform_owner_pin_hash'), isFalse);
    expect(stuffed.containsKey('rememberMePassword'), isFalse);
    expect(stuffed.containsKey('accessToken'), isFalse);
    expect(UserCloudPreferences.isSecretKey('password'), isTrue);
    expect(UserCloudPreferences.isSecretKey('darkMode'), isFalse);

    AppLocale.instance.resetForTests();
    UserPreferencesService.instance.resetForTests();
    WebErpPrefsService.instance.resetForTests();
    NotificationPreferenceService.instance.resetForTests();

    await UserCloudPreferences.instance.applySnapshot(snapshot);
    expect(AppLocale.instance.code, 'am');
    expect(UserPreferencesService.instance.darkMode, isTrue);
    expect(UserPreferencesService.instance.compactDashboard, isTrue);
    expect(
      UserPreferencesService.instance.getOrder('admin', const [
        'students',
        'fees',
      ]),
      ['fees', 'students'],
    );
    expect(WebErpPrefsService.instance.favorites, contains('payroll'));
    expect(WebErpPrefsService.instance.recents, contains('inventory'));
    expect(
      NotificationPreferenceService.instance.isEnabled(
        AuthService.roleAdmin,
        NotificationPreferenceKey.messages,
      ),
      isFalse,
    );
    expect(
      NotificationService.instance.cloudReadIds(),
      containsAll(['n1', 'n2']),
    );
  });

  test('prefs doc id is school-scoped like other account rows', () {
    expect(
      schoolAccountDocId('MAL838', 'admin.mal838'),
      'MAL838__admin.mal838',
    );
    expect(AppCollections.userPreferences, 'user_preferences');
  });

  test('login download pulls user prefs on every role session', () {
    final source = File(
      'lib/services/persistence/cloud_app_store.dart',
    ).readAsStringSync();
    for (final name in [
      'pullForAdminSession',
      'pullForTeacherSession',
      'pullForParentSession',
      'pullForDriverSession',
      'pullForStudentSession',
    ]) {
      expect(
        _methodBody(source, name),
        contains('_pullUserPreferences()'),
        reason: name,
      );
    }
  });

  test('idle sync can apply prefs on a second laptop for every role', () {
    expect(
      CloudAppStore.instance.pullGroupKeyForTest(
        AppCollections.userPreferences,
      ),
      'user_preferences',
    );
    expect(
      CloudSyncEngine.standardPriority,
      contains(AppCollections.userPreferences),
    );

    for (final role in [
      AuthService.roleAdmin,
      AuthService.roleTeacher,
      AuthService.roleParent,
      AuthService.roleDriver,
      AuthService.roleStudent,
    ]) {
      AuthService.currentUser = RegisteredUser(
        username: '$role.demo',
        password: 'x',
        roleKey: role,
        schoolId: 'MAL838',
      );
      expect(
        CloudSyncEngine.collectionsForCurrentRole(),
        contains(AppCollections.userPreferences),
        reason: role,
      );
    }
  });

  test('SQL write-guard allows only the signed-in user and strips secrets', () {
    final sql = File(
      'supabase/migrations/20261007120000_user_preferences_self_sync.sql',
    ).readAsStringSync();
    expect(sql, contains('app_doc_self_user_prefs'));
    expect(sql, contains("new.collection = 'user_preferences'"));
    expect(sql, contains("- 'password'"));
    expect(sql, contains("- 'platform_owner_pin_hash'"));
    expect(sql, contains("- 'login_saved_entries'"));
    expect(sql, contains("p_collection = 'user_preferences'"));
  });

  test('CCTV stream URLs already ride campus_cameras, not a prefs blob', () {
    const site = CctvCameraSite(
      id: 'cam-1',
      name: 'Gate',
      location: 'Main gate',
      streamUrl: 'rtsp://nvr.local/1',
    );
    expect(site.toMap()['streamUrl'], 'rtsp://nvr.local/1');
    expect(CctvCatalogService.collection, AppCollections.campusCameras);
  });
}

String _methodBody(String source, String name) {
  final start = source.indexOf('Future<void> $name');
  expect(start, greaterThan(0), reason: 'missing $name');
  final next = source.indexOf('\n  /// ', start + 10);
  final end = next < 0 ? source.length : next;
  return source.substring(start, end);
}
