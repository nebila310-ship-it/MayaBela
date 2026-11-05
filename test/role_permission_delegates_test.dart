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
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/web_erp/pages/staff_role_config_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';

  void signIn({required String roleKey, List<String> staffRoles = const []}) {
    AuthService.currentUser = RegisteredUser(
      username: 'delegate.test',
      password: 'x',
      roleKey: roleKey,
      schoolId: schoolId,
      staffRoles: staffRoles,
    );
  }

  Future<String?> saveLibrarianEdit() {
    final librarian = StaffRoles.lookup(StaffRoles.librarian)!;
    final rights = RoleModuleCatalog.defaultsForRole(librarian);
    rights['library'] = ModuleRight.edit;
    return SchoolRoleCatalogService.instance.saveRoleModules(
      roleKey: StaffRoles.librarian,
      permissions: RoleModuleCatalog.permissionsFor(rights),
      moduleRights: rights,
      schoolId: schoolId,
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

  group('Role permission delegates', () {
    test(
      'Full Access cannot open Role Permissions until the owner allows it',
      () {
        signIn(
          roleKey: AuthService.roleTeacher,
          staffRoles: const [StaffRoles.fullAccess],
        );
        expect(AuthService.canConfigureRolePermissions, isFalse);
        expect(ModuleAccess.canView('staff_roles'), isFalse);
        expect(ModuleAccess.canManage('staff_roles'), isFalse);
        expect(
          webErpNavItemsForCurrentUser().map((e) => e.id),
          isNot(contains('staff_roles')),
        );
      },
    );

    test('owner can grant Full Access the Role Permissions page', () {
      SchoolRoleCatalogService.instance.seedRolePermissionDelegatesForTests(
        schoolId: schoolId,
        roleKeys: const [StaffRoles.fullAccess],
      );
      signIn(
        roleKey: AuthService.roleTeacher,
        staffRoles: const [StaffRoles.fullAccess],
      );
      expect(AuthService.canConfigureRolePermissions, isTrue);
      expect(ModuleAccess.canView('staff_roles'), isTrue);
      expect(ModuleAccess.canManage('staff_roles'), isTrue);
      expect(
        webErpNavItemsForCurrentUser().map((e) => e.id),
        contains('staff_roles'),
      );
    });

    test('owner can grant General Manager the Role Permissions page', () {
      SchoolRoleCatalogService.instance.seedRolePermissionDelegatesForTests(
        schoolId: schoolId,
        roleKeys: const [StaffRoles.generalManager],
      );
      signIn(
        roleKey: AuthService.roleTeacher,
        staffRoles: const [StaffRoles.generalManager],
      );
      expect(AuthService.canConfigureRolePermissions, isTrue);
      expect(ModuleAccess.canView('staff_roles'), isTrue);
    });

    test('Vice President still cannot open Role Permissions', () {
      SchoolRoleCatalogService.instance.seedRolePermissionDelegatesForTests(
        schoolId: schoolId,
        roleKeys: const [StaffRoles.fullAccess, StaffRoles.generalManager],
      );
      signIn(
        roleKey: AuthService.roleTeacher,
        staffRoles: const [StaffRoles.vicePresident],
      );
      expect(AuthService.canConfigureRolePermissions, isFalse);
      expect(ModuleAccess.canView('staff_roles'), isFalse);
    });

    test(
      'delegated Full Access can save other roles but not Full Access',
      () async {
        SchoolRoleCatalogService.instance.seedRolePermissionDelegatesForTests(
          schoolId: schoolId,
          roleKeys: const [StaffRoles.fullAccess],
        );
        signIn(
          roleKey: AuthService.roleTeacher,
          staffRoles: const [StaffRoles.fullAccess],
        );

        expect(await saveLibrarianEdit(), isNull);
        expect(
          await SchoolRoleCatalogService.instance.saveRoleModules(
            roleKey: StaffRoles.fullAccess,
            permissions: SchoolPermissions.all,
            schoolId: schoolId,
          ),
          'not_customizable',
        );
        expect(
          await SchoolRoleCatalogService.instance.setRolePermissionDelegates(
            const [StaffRoles.generalManager],
            schoolId: schoolId,
          ),
          'not_allowed',
        );
        expect(
          await SchoolRoleCatalogService.instance.addCustomRole(
            label: 'Discipline Officer',
            permissions: const {},
            schoolId: schoolId,
          ),
          'not_allowed',
        );

        signIn(roleKey: AuthService.roleAdmin);
        final created = await SchoolRoleCatalogService.instance
            .ensureTitledRole(
              sourceRoleKey: StaffRoles.librarian,
              label: 'Librarian KG',
              schoolId: schoolId,
            );
        expect(created.roleKey, isNotNull);
        signIn(
          roleKey: AuthService.roleTeacher,
          staffRoles: const [StaffRoles.fullAccess],
        );
        expect(
          await SchoolRoleCatalogService.instance.renameRole(
            roleKey: created.roleKey!,
            label: 'Librarian KG A',
            schoolId: schoolId,
          ),
          isNull,
        );
      },
    );

    test('undecided Full Access cannot save role modules', () async {
      signIn(
        roleKey: AuthService.roleTeacher,
        staffRoles: const [StaffRoles.fullAccess],
      );
      expect(await saveLibrarianEdit(), 'not_allowed');
    });

    test('only the school owner can change the delegate list', () async {
      signIn(roleKey: AuthService.roleAdmin);
      expect(
        await SchoolRoleCatalogService.instance.setRolePermissionDelegates(
          const [StaffRoles.fullAccess, StaffRoles.generalManager],
          schoolId: schoolId,
        ),
        isNull,
      );
      expect(
        SchoolRoleCatalogService.instance.rolePermissionDelegates(
          schoolId: schoolId,
        ),
        containsAll([StaffRoles.fullAccess, StaffRoles.generalManager]),
      );

      signIn(
        roleKey: AuthService.roleTeacher,
        staffRoles: const [StaffRoles.fullAccess],
      );
      expect(
        await SchoolRoleCatalogService.instance.setRolePermissionDelegates(
          const [],
          schoolId: schoolId,
        ),
        'not_allowed',
      );
    });

    test('unknown role keys are ignored when saving delegates', () async {
      signIn(roleKey: AuthService.roleAdmin);
      expect(
        await SchoolRoleCatalogService.instance.setRolePermissionDelegates(
          const ['vice_president', StaffRoles.fullAccess],
          schoolId: schoolId,
        ),
        isNull,
      );
      expect(
        SchoolRoleCatalogService.instance.rolePermissionDelegates(
          schoolId: schoolId,
        ),
        [StaffRoles.fullAccess],
      );
    });

    test('delegate list survives a catalog reload', () async {
      signIn(roleKey: AuthService.roleAdmin);
      expect(
        await SchoolRoleCatalogService.instance.setRolePermissionDelegates(
          const [StaffRoles.generalManager],
          schoolId: schoolId,
        ),
        isNull,
      );
      SchoolRoleCatalogService.instance.resetForTests();
      signIn(
        roleKey: AuthService.roleTeacher,
        staffRoles: const [StaffRoles.generalManager],
      );
      await SchoolRoleCatalogService.instance.ensureLoaded(schoolId);
      expect(AuthService.canConfigureRolePermissions, isTrue);
      expect(ModuleAccess.canView('staff_roles'), isTrue);
    });
  });

  group('Role permission editor for delegates', () {
    testWidgets('owner sees checkboxes to grant Full Access and GM', (
      tester,
    ) async {
      await AppLocale.instance.load();
      signIn(roleKey: AuthService.roleAdmin);
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StaffRoleConfigPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Who else may edit role permissions'), findsOneWidget);
      expect(find.text("May edit other roles' permissions"), findsNWidgets(2));
      expect(find.text('Add custom role'), findsOneWidget);
    });

    testWidgets('delegated Full Access can edit modules but not add roles', (
      tester,
    ) async {
      await AppLocale.instance.load();
      SchoolRoleCatalogService.instance.seedRolePermissionDelegatesForTests(
        schoolId: schoolId,
        roleKeys: const [StaffRoles.fullAccess],
      );
      signIn(
        roleKey: AuthService.roleTeacher,
        staffRoles: const [StaffRoles.fullAccess],
      );
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StaffRoleConfigPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Staff roles'), findsOneWidget);
      expect(find.text('All edit'), findsOneWidget);
      expect(find.text('Add custom role'), findsNothing);
      expect(find.text("May edit other roles' permissions"), findsNothing);
    });

    testWidgets('Full Access without the grant is blocked', (tester) async {
      await AppLocale.instance.load();
      signIn(
        roleKey: AuthService.roleTeacher,
        staffRoles: const [StaffRoles.fullAccess],
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StaffRoleConfigPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Staff roles'), findsNothing);
      expect(
        find.textContaining('unless they have given this right'),
        findsOneWidget,
      );
    });
  });
}
