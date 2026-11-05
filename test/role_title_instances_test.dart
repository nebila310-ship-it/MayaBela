import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/module_right.dart';
import 'package:mayabela/services/rbac/role_module_catalog.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';

  void signInAdmin() {
    AuthService.currentUser = RegisteredUser(
      username: 'owner',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    SchoolRoleCatalogService.instance.resetForTests();
    SchoolRoleCatalogService.instance.putEmptyForTests(schoolId);
    signInAdmin();
  });

  tearDown(() {
    AuthService.currentUser = null;
    SchoolRoleCatalogService.instance.resetForTests();
  });

  test('sourceKeyOf reads titled copies and StaffRoles.holds them', () {
    expect(StaffRoles.sourceKeyOf('custom_principal_1_8'), StaffRoles.principal);
    expect(StaffRoles.sourceKeyOf('custom_principal_kg'), StaffRoles.principal);
    expect(StaffRoles.holds(const ['custom_principal_kg'], StaffRoles.principal),
        isTrue);
    expect(
      StaffRoles.holds(const ['custom_librarian_kg'], StaffRoles.principal),
      isFalse,
    );
    expect(StaffRoles.idPrefixFor('custom_principal_kg'), 'PRI');
  });

  test('Principal 1-8 and Principal KG keep separate module maps', () async {
    final grades = await SchoolRoleCatalogService.instance.ensureTitledRole(
      sourceRoleKey: StaffRoles.principal,
      label: 'Principal 1-8',
      schoolId: schoolId,
    );
    final kg = await SchoolRoleCatalogService.instance.ensureTitledRole(
      sourceRoleKey: StaffRoles.principal,
      label: 'Principal KG',
      schoolId: schoolId,
    );
    expect(grades.roleKey, isNotNull);
    expect(kg.roleKey, isNotNull);
    expect(grades.roleKey, isNot(kg.roleKey));
    expect(grades.roleKey, isNot(StaffRoles.principal));

    final principal = StaffRoles.lookup(StaffRoles.principal)!;
    final gradesRights = RoleModuleCatalog.defaultsForRole(principal);
    gradesRights['students'] = ModuleRight.edit;
    gradesRights['admissions'] = ModuleRight.none;
    final kgRights = RoleModuleCatalog.defaultsForRole(principal);
    kgRights['students'] = ModuleRight.read;
    kgRights['admissions'] = ModuleRight.edit;

    expect(
      await SchoolRoleCatalogService.instance.saveRoleModules(
        roleKey: grades.roleKey!,
        permissions: RoleModuleCatalog.permissionsFor(gradesRights),
        moduleRights: gradesRights,
        schoolId: schoolId,
      ),
      isNull,
    );
    expect(
      await SchoolRoleCatalogService.instance.saveRoleModules(
        roleKey: kg.roleKey!,
        permissions: RoleModuleCatalog.permissionsFor(kgRights),
        moduleRights: kgRights,
        schoolId: schoolId,
      ),
      isNull,
    );

    expect(
      SchoolRoleCatalogService.instance.moduleRightFor(
        grades.roleKey!,
        'admissions',
        schoolId: schoolId,
      ),
      ModuleRight.none,
    );
    expect(
      SchoolRoleCatalogService.instance.moduleRightFor(
        kg.roleKey!,
        'admissions',
        schoolId: schoolId,
      ),
      ModuleRight.edit,
    );
    expect(
      SchoolRoleCatalogService.instance.moduleRightFor(
        grades.roleKey!,
        'students',
        schoolId: schoolId,
      ),
      ModuleRight.edit,
    );
    expect(
      SchoolRoleCatalogService.instance.moduleRightFor(
        kg.roleKey!,
        'students',
        schoolId: schoolId,
      ),
      ModuleRight.read,
    );
  });

  test('signed-in Principal KG does not receive Principal 1-8 module edits',
      () async {
    final grades = await SchoolRoleCatalogService.instance.ensureTitledRole(
      sourceRoleKey: StaffRoles.principal,
      label: 'Principal 1-8',
      schoolId: schoolId,
    );
    final kg = await SchoolRoleCatalogService.instance.ensureTitledRole(
      sourceRoleKey: StaffRoles.principal,
      label: 'Principal KG',
      schoolId: schoolId,
    );
    final principal = StaffRoles.lookup(StaffRoles.principal)!;
    final gradesRights = RoleModuleCatalog.defaultsForRole(principal)
      ..['finance'] = ModuleRight.edit;
    final kgRights = RoleModuleCatalog.defaultsForRole(principal)
      ..['finance'] = ModuleRight.none;
    await SchoolRoleCatalogService.instance.saveRoleModules(
      roleKey: grades.roleKey!,
      permissions: RoleModuleCatalog.permissionsFor(gradesRights),
      moduleRights: gradesRights,
      schoolId: schoolId,
    );
    await SchoolRoleCatalogService.instance.saveRoleModules(
      roleKey: kg.roleKey!,
      permissions: RoleModuleCatalog.permissionsFor(kgRights),
      moduleRights: kgRights,
      schoolId: schoolId,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'pri.kg',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: schoolId,
      staffRoles: [kg.roleKey!],
    );
    expect(ModuleAccess.canView('finance'), isFalse);
    expect(ModuleAccess.canManage('finance'), isFalse);

    AuthService.currentUser = RegisteredUser(
      username: 'pri.g18',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: schoolId,
      staffRoles: [grades.roleKey!],
    );
    expect(ModuleAccess.canView('finance'), isTrue);
    expect(ModuleAccess.canManage('finance'), isTrue);
  });

  test('same title reuses the instance so two KG principals share that map',
      () async {
    final first = await SchoolRoleCatalogService.instance.ensureTitledRole(
      sourceRoleKey: StaffRoles.principal,
      label: 'Principal KG',
      schoolId: schoolId,
    );
    final second = await SchoolRoleCatalogService.instance.ensureTitledRole(
      sourceRoleKey: StaffRoles.principal,
      label: 'Principal KG',
      schoolId: schoolId,
    );
    expect(second.roleKey, first.roleKey);
  });

  test('cannot title Full Access into a separate permission set', () async {
    final created = await SchoolRoleCatalogService.instance.ensureTitledRole(
      sourceRoleKey: StaffRoles.fullAccess,
      label: 'Owner 2',
      schoolId: schoolId,
    );
    expect(created.error, 'not_customizable');
    expect(created.roleKey, isNull);
  });

  test('cannot delete a titled role while a staff member holds it', () async {
    final created = await SchoolRoleCatalogService.instance.ensureTitledRole(
      sourceRoleKey: StaffRoles.principal,
      label: 'Principal 1-8',
      schoolId: schoolId,
    );
    TeacherRegistryService.instance.addTeacher(
      schoolId: schoolId,
      fullName: 'Amina Principal',
      email: 'amina@school.test',
      phone: '0911222333',
      assignedClass: '',
      roles: const [],
      loginUsername: 'amina.pri',
      staffRoles: [created.roleKey!],
    );
    expect(
      await SchoolRoleCatalogService.instance.deleteCustomRole(
        created.roleKey!,
        schoolId: schoolId,
      ),
      'in_use',
    );
  });
}
