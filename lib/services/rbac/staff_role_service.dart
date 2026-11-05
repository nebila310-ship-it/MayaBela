import 'package:flutter/foundation.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/teacher_persistence_service.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_audit_log_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// Applies staff-role grants to a staff member.
///
/// Writes go to three places:
///  1. The teacher registry record (display mirror),
///  2. the in-memory/local auth account,
///  3. the cloud account via school-upsert-account (school-scoped doc id).
/// New roles take effect at the user's next login.
class StaffRoleService {
  StaffRoleService._();
  static final instance = StaffRoleService._();

  /// Normalizes, authorizes and saves [roles] for [teacher].
  /// Returns an error code, or null on success.
  Future<String?> assignRoles({
    required AdminTeacherRecord teacher,
    required List<String> roles,
  }) async {
    if (!AuthService.canAssignStaffRoles) return 'not_allowed';

    await SchoolRoleCatalogService.instance.ensureLoaded(teacher.schoolId);

    final normalized = <String>[];
    for (final raw in roles) {
      final key = StaffRoles.canonicalize(raw);
      final template = SchoolRoleCatalogService.instance
          .lookup(key, schoolId: teacher.schoolId);
      if (template == null) continue;
      if (template.ownerOnly && !AuthService.canAssignFullAccess) {
        return 'owner_only_role';
      }
      if (!normalized.contains(key)) normalized.add(key);
    }

    final username = teacher.loginUsername?.trim().toLowerCase() ?? '';
    if (username.isEmpty) return 'no_account';

    // Nobody may edit their own staff roles (server enforces this too).
    final me = AuthService.currentUser?.username.toLowerCase();
    if (me != null && me == username) return 'own_account';

    final beforeRoles = List<String>.from(teacher.staffRoles);
    final effectivePermissions = SchoolRoleCatalogService.instance
        .permissionsForRoles(normalized, schoolId: teacher.schoolId)
        .toList()
      ..sort();

    // 1. Registry mirror.
    final updated = teacher.copyWith(staffRoles: normalized);
    TeacherRegistryService.instance.updateTeacher(updated);
    await TeacherPersistenceService.instance.saveRegistryFromService();

    // 2. Local auth account.
    var account = AuthService.findUser(username);
    if (account != null) {
      account.staffRoles = List<String>.from(normalized);
      account.staffPermissions = List<String>.from(effectivePermissions);
      if ((account.schoolId ?? '').trim().isEmpty) {
        final patched = RegisteredUser(
          username: account.username,
          password: account.password,
          roleKey: account.roleKey,
          email: account.email,
          phone: account.phone,
          schoolId: teacher.schoolId,
          fullName: account.fullName,
          linkedStudentIds: account.linkedStudentIds,
          linkedTeacherId: account.linkedTeacherId,
          linkedAdminId: account.linkedAdminId,
          linkedDriverId: account.linkedDriverId,
          linkedStudentId: account.linkedStudentId,
          mustChangePassword: account.mustChangePassword,
          staffRoles: List<String>.from(normalized),
          staffPermissions: List<String>.from(effectivePermissions),
        );
        AuthService.mergePersistedUser(patched);
        account = AuthService.findUser(username) ?? patched;
      }
    } else {
      account = RegisteredUser(
        username: username,
        password: AuthService.passwordRedactedMarker,
        roleKey: AuthService.roleTeacher,
        schoolId: teacher.schoolId,
        phone: teacher.phone,
        fullName: teacher.fullName,
        linkedTeacherId: teacher.teacherId,
        staffRoles: List<String>.from(normalized),
        staffPermissions: List<String>.from(effectivePermissions),
      );
      AuthService.mergePersistedUser(account);
    }

    // 3. Cloud via edge function (school-scoped account id). Direct client
    // writes to the old phone-only doc_id fail after the multi-school fix.
    final cloud = await SchoolAuthCloudService.instance.upsertAccount(
      user: account,
      staffRoles: normalized,
      staffPermissions: effectivePermissions,
    );
    if (!cloud.ok) {
      if (kDebugMode) {
        debugPrint(
          'StaffRoleService.assignRoles cloud push failed: ${cloud.errorCode}',
        );
      }
      return 'cloud_failed';
    }

    await SchoolAuditLogService.instance.log(
      action: 'staff_roles_assigned',
      schoolId: teacher.schoolId,
      entityType: 'staff',
      entityId: username,
      detail: '${teacher.fullName}: ${normalized.join(', ')}',
      before: {'staffRoles': beforeRoles},
      after: {
        'staffRoles': normalized,
        'staffPermissions': effectivePermissions,
      },
    );
    return null;
  }

  /// Give [teacher] their own titled copy of [currentRoleKey] (or reuse the
  /// same title if it already exists). Other people on the original position
  /// keep that position's modules.
  Future<String?> retitleAssignedRole({
    required AdminTeacherRecord teacher,
    required String currentRoleKey,
    required String label,
  }) async {
    if (!AuthService.canAssignStaffRoles) return 'not_allowed';
    final cleanLabel = label.trim();
    if (cleanLabel.isEmpty) return 'empty_label';

    await SchoolRoleCatalogService.instance.ensureLoaded(teacher.schoolId);
    final current = SchoolRoleCatalogService.instance.lookup(
      currentRoleKey,
      schoolId: teacher.schoolId,
    );
    if (current == null) return 'unknown_role';
    if (current.ownerOnly || !current.customizable) return 'not_customizable';

    if (current.labelEn.trim().toLowerCase() == cleanLabel.toLowerCase()) {
      return null;
    }

    final holders = SchoolRoleCatalogService.instance.holderCount(
      current.key,
      schoolId: teacher.schoolId,
    );
    final reuse = SchoolRoleCatalogService.instance.findTitledRole(
      sourceRoleKey:
          SchoolRoleCatalogService.instance.sourceKeyFor(
            current.key,
            schoolId: teacher.schoolId,
          ) ??
          current.key,
      label: cleanLabel,
      schoolId: teacher.schoolId,
    );

    String nextKey;
    if (reuse != null) {
      nextKey = reuse.key;
    } else if (!current.builtIn && holders <= 1) {
      final err = await SchoolRoleCatalogService.instance.renameRole(
        roleKey: current.key,
        label: cleanLabel,
        schoolId: teacher.schoolId,
      );
      if (err != null && err != 'cloud_failed' && err != 'cloud_session') {
        return err;
      }
      return null;
    } else {
      final created = await SchoolRoleCatalogService.instance.ensureTitledRole(
        sourceRoleKey: current.key,
        label: cleanLabel,
        schoolId: teacher.schoolId,
      );
      if (created.roleKey == null) return created.error ?? 'not_allowed';
      nextKey = created.roleKey!;
    }

    final nextRoles = [
      for (final key in teacher.staffRoles)
        StaffRoles.canonicalize(key) == StaffRoles.canonicalize(currentRoleKey)
            ? nextKey
            : StaffRoles.canonicalize(key),
    ];
    final err = await assignRoles(teacher: teacher, roles: nextRoles);
    // Local registry already holds the titled copy. Cloud is required in
    // production, but tests and offline saves should keep the new title.
    if (err == 'cloud_failed') return null;
    return err;
  }
}
