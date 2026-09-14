import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/school_module_catalog.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';

  void signInAdmin() {
    AuthService.currentUser = RegisteredUser(
      username: 'owner.admin',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
    );
  }

  void setSchool({Set<String>? enabledModules}) {
    SchoolRegistryService.instance.applyPersistedSchools([
      SchoolRecord(
        id: schoolId,
        name: 'Pack School',
        enabledModules: enabledModules,
      ),
    ]);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    SchoolRegistryService.instance.applyPersistedSchools(const []);
  });

  tearDown(() {
    AuthService.currentUser = null;
    SchoolRegistryService.instance.applyPersistedSchools(const []);
  });

  test('catalog covers every togglable sidebar item', () {
    final ids = SchoolModuleCatalog.togglableNavIds();
    for (final item in webErpAllNavItems) {
      if (item.isLogout ||
          SchoolModuleCatalog.alwaysOnModuleIds.contains(item.id)) {
        expect(ids.contains(item.id), isFalse, reason: item.id);
        continue;
      }
      expect(ids.contains(item.id), isTrue, reason: item.id);
    }
    expect(ids.length, greaterThan(40));
  });

  test('null pack leaves every module on, including school admin', () {
    signInAdmin();
    setSchool(enabledModules: null);
    expect(SchoolModuleCatalog.isEnabled('finance'), isTrue);
    expect(ModuleAccess.canView('finance'), isTrue);
    expect(ModuleAccess.canManage('finance'), isTrue);
    expect(ModuleAccess.canView('dashboard'), isTrue);
  });

  test('subset pack hides finance even for the school admin', () {
    signInAdmin();
    setSchool(enabledModules: {'attendance', 'students'});
    expect(SchoolModuleCatalog.isEnabled('finance'), isFalse);
    expect(ModuleAccess.canView('finance'), isFalse);
    expect(ModuleAccess.canManage('finance'), isFalse);
    expect(ModuleAccess.canView('attendance'), isTrue);
    expect(webErpNavItemsForCurrentUser().map((e) => e.id), isNot(contains('finance')));
    expect(webErpNavItemsForCurrentUser().map((e) => e.id), contains('attendance'));
    expect(webErpNavItemsForCurrentUser().map((e) => e.id), contains('dashboard'));
    expect(webErpNavItemsForCurrentUser().map((e) => e.id), contains('settings'));
  });

  test('always-on chrome stays visible when the pack is empty', () {
    signInAdmin();
    setSchool(enabledModules: {});
    expect(ModuleAccess.canView('dashboard'), isTrue);
    expect(ModuleAccess.canView('profile'), isTrue);
    expect(ModuleAccess.canView('settings'), isTrue);
    expect(ModuleAccess.canView('logout'), isTrue);
    expect(ModuleAccess.canView('finance'), isFalse);
    expect(ModuleAccess.canView('maya_assistant'), isFalse);
  });

  test('markbook can be off while examinations stays on', () {
    expect(
      SchoolModuleCatalog.isEnabledFor(
        {'examinations', 'attendance'},
        'markbook',
      ),
      isFalse,
    );
    expect(
      SchoolModuleCatalog.isEnabledFor(
        {'examinations', 'attendance'},
        'examinations',
      ),
      isTrue,
    );
  });

  test('parent fee tile follows the finance module', () {
    expect(
      SchoolModuleCatalog.isEnabledFor({'attendance'}, 'fees'),
      isFalse,
    );
    expect(
      SchoolModuleCatalog.isEnabledFor({'finance'}, 'fees'),
      isTrue,
    );
  });

  test('unknown teacher chrome such as QR stays on', () {
    expect(
      SchoolModuleCatalog.isEnabledFor({'attendance'}, 'qr'),
      isTrue,
    );
    expect(
      SchoolModuleCatalog.isEnabledFor({'students'}, 'children'),
      isTrue,
    );
  });

  test('selecting every togglable module persists as null (all on)', () {
    final all = SchoolModuleCatalog.togglableNavIds();
    expect(SchoolModuleCatalog.packForPersistence(all), isNull);
    expect(
      SchoolModuleCatalog.packForPersistence({'finance', 'attendance'}),
      {'finance', 'attendance'},
    );
  });

  test('SchoolRecord round-trips enabledModules in settings', () {
    final packed = SchoolRecord(
      id: 'AB-1',
      name: 'Alpha',
      enabledModules: {'finance', 'attendance'},
    );
    final packedJson = packed.toJson();
    expect(
      packedJson['settings']['enabledModules'],
      unorderedEquals(['attendance', 'finance']),
    );
    expect(
      SchoolRecord.fromJson(packedJson).enabledModules,
      {'finance', 'attendance'},
    );

    final allOn = SchoolRecord(id: 'AB-2', name: 'Beta');
    expect(allOn.toJson()['settings']['enabledModules'], isNull);
    expect(SchoolRecord.fromJson(allOn.toJson()).enabledModules, isNull);

    final cleared = packed.copyWith(enabledModules: null);
    expect(cleared.enabledModules, isNull);
    final kept = packed.copyWith(name: 'Alpha 2');
    expect(kept.enabledModules, {'finance', 'attendance'});
  });

  test('dashboard shouldShow hides finance tiles when the pack is off', () {
    signInAdmin();
    setSchool(enabledModules: {'attendance'});
    final finance = DashboardEntry(
      id: 'finance',
      icon: Icons.payments,
      color: const Color(0xFF000000),
      builder: (_) => const SizedBox.shrink(),
    );
    final attendance = DashboardEntry(
      id: 'attendance',
      icon: Icons.check,
      color: const Color(0xFF000000),
      builder: (_) => const SizedBox.shrink(),
    );
    final children = DashboardEntry(
      id: 'children',
      icon: Icons.child_care,
      color: const Color(0xFF000000),
      builder: (_) => const SizedBox.shrink(),
    );
    expect(DashboardRegistry.shouldShow(finance), isFalse);
    expect(DashboardRegistry.shouldShow(attendance), isTrue);
    expect(DashboardRegistry.shouldShow(children), isTrue);
  });
}
