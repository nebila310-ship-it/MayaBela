import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';

void main() {
  tearDown(() {
    AuthService.currentUser = null;
  });

  void signIn(String roleKey) {
    AuthService.currentUser = RegisteredUser(
      username: 'phase3.$roleKey',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: [roleKey],
    );
  }

  test('every allocated manager holds a matching JWT write permission', () {
    for (final role in StaffRoles.templates) {
      if (role.ownerOnly) continue;
      signIn(role.key);
      expect(
        ModuleAccess.allocationJwtManageIsCovered(role.key, role.permissions),
        isTrue,
        reason: '${role.key} is missing JWT write coverage for a manage desk',
      );
      for (final moduleId in ModuleAccess.rules.keys) {
        if (!ModuleAccess.canManage(moduleId)) continue;
        final rule = ModuleAccess.ruleFor(moduleId);
        if (rule == null || rule.manage.isEmpty) continue;
        expect(
          AuthService.hasAnyPermission(rule.manage),
          isTrue,
          reason: '${role.key} canManage($moduleId) without JWT ${rule.manage}',
        );
      }
    }
  });

  test('VP JWT now matches finance, parents, attendance, and QA desks', () {
    signIn(StaffRoles.vicePresident);
    expect(ModuleAccess.canManage('finance'), isTrue);
    expect(AuthService.hasPermission(SchoolPermissions.manageFees), isTrue);
    expect(ModuleAccess.canManage('parents'), isTrue);
    expect(AuthService.hasPermission(SchoolPermissions.manageParentLinks), isTrue);
    expect(ModuleAccess.canManage('attendance'), isTrue);
    expect(AuthService.hasPermission(SchoolPermissions.manageStudents), isTrue);
    expect(ModuleAccess.canManage('quality_assurance'), isTrue);
    expect(AuthService.hasPermission(SchoolPermissions.manageQaFindings), isTrue);
    expect(ModuleAccess.canManage('homework'), isFalse);
    expect(ModuleAccess.canManage('students'), isFalse);
    expect(ModuleAccess.canManage('calendar'), isFalse);
  });

  test('Section Director can manage calendar because JWT has send_announcements', () {
    signIn(StaffRoles.sectionDirector);
    expect(ModuleAccess.canView('calendar'), isTrue);
    expect(ModuleAccess.canManage('calendar'), isTrue);
    expect(ModuleAccess.canManage('events'), isTrue);
    expect(
      AuthService.hasPermission(SchoolPermissions.sendAnnouncements),
      isTrue,
    );
  });

  test('Staff still cannot manage parents after JWT cleanup', () {
    signIn(StaffRoles.staffs);
    expect(ModuleAccess.canManage('parents'), isFalse);
    expect(
      AuthService.hasPermission(SchoolPermissions.manageParentLinks),
      isFalse,
    );
    expect(ModuleAccess.canManage('digital_ops'), isTrue);
  });

  test('classroom teacher JWT is unchanged and stays off ERP manage desks', () {
    AuthService.currentUser = RegisteredUser(
      username: 'phase3.teacher',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    expect(ModuleAccess.hasErpAccess, isFalse);
    expect(ModuleAccess.canManage('finance'), isFalse);
    expect(ModuleAccess.canManage('parents'), isFalse);
    expect(AuthService.mayReadAllSchoolData, isFalse);
  });

  test('edge JWT catalog lists the new VP and SD write claims', () {
    final ts = File('supabase/functions/_shared/school_auth.ts').readAsStringSync();
    final vp = _roleBlock(ts, 'vice_president');
    for (final perm in [
      'manage_students',
      'manage_parent_links',
      'manage_fees',
      'record_payments',
      'manage_staff_accounts',
      'manage_qa_findings',
      'manage_digital_ops',
    ]) {
      expect(vp, contains('"$perm"'), reason: 'vice_president missing $perm');
    }
    final sd = _roleBlock(ts, 'section_director');
    expect(sd, contains('"send_announcements"'));
    expect(ts.contains('LEADERSHIP_CORE'), isFalse);
  });
}

String _roleBlock(String source, String roleKey) {
  final start = source.indexOf('$roleKey: withBaseline([');
  expect(start, greaterThan(0), reason: 'missing $roleKey in school_auth.ts');
  final end = source.indexOf(']),', start);
  expect(end, greaterThan(start), reason: 'unclosed $roleKey block');
  return source.substring(start, end);
}
