import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/module_right.dart';
import 'package:mayabela/services/rbac/role_module_catalog.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_items.dart';
import 'package:mayabela/web_erp/pages/staff_role_config_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';

  void signIn({
    required String roleKey,
    List<String> staffRoles = const [],
  }) {
    AuthService.currentUser = RegisteredUser(
      username: 'role.rights.test',
      password: 'x',
      roleKey: roleKey,
      schoolId: schoolId,
      staffRoles: staffRoles,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    SchoolRoleCatalogService.instance.resetForTests();
    SchoolRoleCatalogService.instance.putEmptyForTests(schoolId);
  });

  tearDown(() {
    AuthService.currentUser = null;
    SchoolRoleCatalogService.instance.resetForTests();
  });

  group('RoleModuleCatalog', () {
    test('lists every ERP sidebar module and sub-module', () {
      final ids = RoleModuleCatalog.byId.keys.toSet();
      for (final item in webErpAllNavItems) {
        if (item.isLogout) continue;
        expect(ids, contains(item.id), reason: item.id);
      }
      expect(ids, contains('school_wide_data'));
      expect(ids, contains('markbook'));
      expect(ids, contains('payroll'));
      expect(ids, contains('cctv'));
      expect(ids, contains('lesson_plans'));
      expect(RoleModuleCatalog.sections, contains('Academics'));
      expect(RoleModuleCatalog.sections, contains('HR Branch'));
    });

    test('owner-only desks cannot be granted to staff roles', () {
      expect(RoleModuleCatalog.byId['institution']!.ownerOnly, isTrue);
      expect(RoleModuleCatalog.byId['staff_roles']!.ownerOnly, isTrue);
      expect(RoleModuleCatalog.byId['institution']!.configurable, isFalse);
      expect(RoleModuleCatalog.byId['support']!.alwaysOn, isTrue);
      expect(RoleModuleCatalog.byId['markbook']!.configurable, isTrue);
    });

    test('librarian defaults keep library edit and hide finance', () {
      final librarian = StaffRoles.lookup(StaffRoles.librarian)!;
      final rights = RoleModuleCatalog.defaultsForRole(librarian);
      expect(rights['library'], ModuleRight.edit);
      expect(rights['learning_materials'], ModuleRight.edit);
      expect(rights['finance'], ModuleRight.none);
      expect(rights['students'], ModuleRight.none);
      expect(rights['support'], ModuleRight.edit);
      expect(rights['dashboard'], ModuleRight.read);
    });

    test('vice principal students stay read while examinations are edit', () {
      final vp = StaffRoles.lookup(StaffRoles.vicePresident)!;
      final rights = RoleModuleCatalog.defaultsForRole(vp);
      expect(rights['students'], ModuleRight.read);
      expect(rights['examinations'], ModuleRight.edit);
      expect(rights['homework'], ModuleRight.read);
      expect(rights['institution'], ModuleRight.none);
    });

    test('section summary is partial when sub-modules mix rights', () {
      final rights = RoleModuleCatalog.defaultsForRole(
        StaffRoles.lookup(StaffRoles.librarian)!,
      );
      rights['markbook'] = ModuleRight.read;
      rights['examinations'] = ModuleRight.edit;
      rights['homework'] = ModuleRight.none;
      expect(
        RoleModuleCatalog.sectionSummary('Academics', rights),
        SectionRight.partial,
      );
    });

    test('edit rights stamp manage permissions and read stamps view only', () {
      final perms = RoleModuleCatalog.permissionsFor({
        'finance': ModuleRight.edit,
        'students': ModuleRight.read,
        'school_wide_data': ModuleRight.edit,
      });
      expect(perms, contains(SchoolPermissions.viewFinanceReports));
      expect(perms, contains(SchoolPermissions.manageFees));
      expect(perms, contains(SchoolPermissions.viewStudents));
      expect(perms, isNot(contains(SchoolPermissions.manageStudents)));
      expect(perms, contains(SchoolPermissions.viewAllSchoolData));
      expect(perms, contains(SchoolPermissions.accessSupport));
    });

    test('applying a section right updates every configurable child', () {
      final start = RoleModuleCatalog.defaultsForRole(
        StaffRoles.lookup(StaffRoles.librarian)!,
      );
      final next = RoleModuleCatalog.applySectionRight(
        current: start,
        section: 'Finance Branch',
        right: ModuleRight.read,
      );
      expect(next['finance'], ModuleRight.read);
      expect(next['inventory'], ModuleRight.read);
      expect(next['support'], ModuleRight.edit);
    });
  });

  group('Owner-configured module rights', () {
    test('admin can grant finance edit to librarian without the rest of ERP', () {
      final librarian = StaffRoles.lookup(StaffRoles.librarian)!;
      final rights = RoleModuleCatalog.defaultsForRole(librarian);
      rights['finance'] = ModuleRight.edit;
      SchoolRoleCatalogService.instance.seedModuleRightsForTests(
        schoolId: schoolId,
        roleKey: StaffRoles.librarian,
        rights: rights,
        permissions: RoleModuleCatalog.permissionsFor(rights),
      );
      signIn(roleKey: AuthService.roleTeacher, staffRoles: [StaffRoles.librarian]);

      expect(ModuleAccess.canView('finance'), isTrue);
      expect(ModuleAccess.canManage('finance'), isTrue);
      expect(ModuleAccess.isReadOnly('finance'), isFalse);
      expect(ModuleAccess.canView('library'), isTrue);
      expect(ModuleAccess.canManage('library'), isTrue);
      expect(ModuleAccess.canView('students'), isFalse);
      expect(ModuleAccess.canView('academic'), isFalse);
    });

    test('read-only grant opens the desk without mutations', () {
      final librarian = StaffRoles.lookup(StaffRoles.librarian)!;
      final rights = RoleModuleCatalog.defaultsForRole(librarian);
      rights['students'] = ModuleRight.read;
      SchoolRoleCatalogService.instance.seedModuleRightsForTests(
        schoolId: schoolId,
        roleKey: StaffRoles.librarian,
        rights: rights,
        permissions: RoleModuleCatalog.permissionsFor(rights),
      );
      signIn(roleKey: AuthService.roleTeacher, staffRoles: [StaffRoles.librarian]);

      expect(ModuleAccess.canView('students'), isTrue);
      expect(ModuleAccess.canManage('students'), isFalse);
      expect(ModuleAccess.isReadOnly('students'), isTrue);
    });

    test('sub-module rights are independent of the parent module', () {
      final librarian = StaffRoles.lookup(StaffRoles.librarian)!;
      final rights = RoleModuleCatalog.defaultsForRole(librarian);
      rights['examinations'] = ModuleRight.none;
      rights['markbook'] = ModuleRight.edit;
      rights['report_cards'] = ModuleRight.read;
      SchoolRoleCatalogService.instance.seedModuleRightsForTests(
        schoolId: schoolId,
        roleKey: StaffRoles.librarian,
        rights: rights,
        permissions: RoleModuleCatalog.permissionsFor(rights),
      );
      signIn(roleKey: AuthService.roleTeacher, staffRoles: [StaffRoles.librarian]);

      expect(ModuleAccess.canView('examinations'), isFalse);
      expect(ModuleAccess.canView('markbook'), isTrue);
      expect(ModuleAccess.canManage('markbook'), isTrue);
      expect(ModuleAccess.canView('report_cards'), isTrue);
      expect(ModuleAccess.canManage('report_cards'), isFalse);
    });

    test('turning a default module off hides it for that role', () {
      final librarian = StaffRoles.lookup(StaffRoles.librarian)!;
      final rights = RoleModuleCatalog.defaultsForRole(librarian);
      rights['library'] = ModuleRight.none;
      SchoolRoleCatalogService.instance.seedModuleRightsForTests(
        schoolId: schoolId,
        roleKey: StaffRoles.librarian,
        rights: rights,
        permissions: RoleModuleCatalog.permissionsFor(rights),
      );
      signIn(roleKey: AuthService.roleTeacher, staffRoles: [StaffRoles.librarian]);

      expect(ModuleAccess.canView('library'), isFalse);
      expect(ModuleAccess.canManage('library'), isFalse);
      expect(ModuleAccess.canView('support'), isTrue);
    });

    test('procurement grants still apply after a fresh login load', () async {
      signIn(roleKey: AuthService.roleAdmin);
      final procurement = StaffRoles.lookup(StaffRoles.procurement)!;
      final rights = RoleModuleCatalog.defaultsForRole(procurement);
      rights['finance'] = ModuleRight.edit;
      rights['students'] = ModuleRight.read;
      final err = await SchoolRoleCatalogService.instance.saveRoleModules(
        roleKey: StaffRoles.procurement,
        permissions: RoleModuleCatalog.permissionsFor(rights),
        moduleRights: rights,
        schoolId: schoolId,
      );
      expect(err, isNull);

      SchoolRoleCatalogService.instance.resetForTests();
      signIn(
        roleKey: AuthService.roleTeacher,
        staffRoles: [StaffRoles.procurement],
      );
      await SchoolRoleCatalogService.instance.ensureLoaded(schoolId);

      expect(
        SchoolRoleCatalogService.instance.hasModuleRights(StaffRoles.procurement),
        isTrue,
      );
      expect(ModuleAccess.canView('finance'), isTrue);
      expect(ModuleAccess.canManage('finance'), isTrue);
      expect(ModuleAccess.canView('students'), isTrue);
      expect(ModuleAccess.canManage('students'), isFalse);
      expect(ModuleAccess.canView('inventory'), isTrue);
    });
  });

  group('Role permission editor', () {
    testWidgets('lists sub-modules with none, read, and edit controls',
        (tester) async {
      await AppLocale.instance.load();
      signIn(roleKey: AuthService.roleAdmin);
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StaffRoleConfigPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Staff roles'), findsOneWidget);
      expect(find.text('All edit'), findsOneWidget);
      expect(find.text('Read'), findsWidgets);
      expect(find.text('Edit'), findsWidgets);
      expect(find.text('None'), findsWidgets);

      await tester.enterText(find.byType(TextField).last, 'markbook');
      await tester.pumpAndSettle();
      expect(find.text('Weighted Markbook'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'payroll');
      await tester.pumpAndSettle();
      expect(find.text('Payroll'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'school student');
      await tester.pumpAndSettle();
      expect(find.text('See all school student data'), findsOneWidget);
    });
  });
}
