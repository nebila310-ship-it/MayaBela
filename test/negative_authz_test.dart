import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';

/// Negative cases: unauthorized roles must FAIL (not merely "happy path works").
void main() {
  tearDown(() {
    AuthService.currentUser = null;
  });

  void signIn({
    required String roleKey,
    List<String> staffRoles = const [],
  }) {
    AuthService.currentUser = RegisteredUser(
      username: 'neg.test',
      password: 'x',
      roleKey: roleKey,
      schoolId: 'TB-001',
      staffRoles: staffRoles,
    );
  }

  test('parent cannot open or mutate school-admin modules', () {
    signIn(roleKey: AuthService.roleParent);
    for (final id in [
      'finance',
      'hr',
      'academic',
      'examinations',
      'institution',
      'staff_roles',
      'inventory',
      'students',
    ]) {
      expect(ModuleAccess.canView(id), isFalse, reason: 'parent view $id');
      expect(ModuleAccess.canManage(id), isFalse, reason: 'parent manage $id');
    }
  });

  test('classroom teacher cannot manage finance, HR, or owner console', () {
    signIn(roleKey: AuthService.roleTeacher, staffRoles: const []);
    expect(ModuleAccess.canManage('finance'), isFalse);
    expect(ModuleAccess.canManage('hr'), isFalse);
    expect(ModuleAccess.canView('institution'), isFalse);
    expect(ModuleAccess.canManage('staff_roles'), isFalse);
    expect(AuthService.hasPermission(SchoolPermissions.assignRoles), isFalse);
    expect(AuthService.hasPermission(SchoolPermissions.manageFees), isFalse);
  });

  test('Full Access is owner-only and cannot be a default teacher grant', () {
    final full = StaffRoles.lookup(StaffRoles.fullAccess)!;
    expect(full.ownerOnly, isTrue);
    expect(StaffRoles.templates.where((r) => r.ownerOnly).length, 1);
    signIn(
      roleKey: AuthService.roleTeacher,
      staffRoles: const [StaffRoles.sectionDirector],
    );
    expect(
      AuthService.currentUser!.staffRoles.contains(StaffRoles.fullAccess),
      isFalse,
    );
  });

  test('QA can view attendance but cannot manage grades/exams', () {
    signIn(
      roleKey: AuthService.roleTeacher,
      staffRoles: const [StaffRoles.qualityAssurance],
    );
    expect(ModuleAccess.canView('attendance'), isTrue);
    expect(ModuleAccess.canManage('examinations'), isFalse);
    expect(ModuleAccess.canManage('finance'), isFalse);
  });

  test('classroom teacher cannot open the Administration Staff digital-ops desk', () {
    signIn(roleKey: AuthService.roleTeacher, staffRoles: const []);
    expect(ModuleAccess.canView('digital_ops'), isFalse);
    expect(ModuleAccess.canManage('digital_ops'), isFalse);
    expect(ModuleAccess.canView('go_live'), isFalse);
    expect(ModuleAccess.canView('cctv'), isFalse);
  });

  test('Staff role runs digital ops but not finance, exams, or parent approve', () {
    signIn(
      roleKey: AuthService.roleTeacher,
      staffRoles: const [StaffRoles.staffs],
    );
    expect(ModuleAccess.canView('digital_ops'), isTrue);
    expect(ModuleAccess.canManage('digital_ops'), isTrue);
    expect(ModuleAccess.canView('go_live'), isTrue);
    expect(ModuleAccess.canManage('go_live'), isTrue);
    expect(ModuleAccess.canView('cctv'), isTrue);
    expect(ModuleAccess.canView('system_health'), isTrue);
    expect(ModuleAccess.canManage('finance'), isFalse);
    expect(ModuleAccess.canManage('examinations'), isFalse);
    expect(ModuleAccess.canManage('parents'), isFalse);
    expect(
      AuthService.hasPermission(SchoolPermissions.manageParentLinks),
      isFalse,
    );
  });
}
