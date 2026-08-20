import 'dart:async';
import 'dart:math';

import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/school_lifecycle.dart';
import 'package:mayabela/services/app_lock_service.dart';
import 'package:mayabela/services/cloud_sync_progress_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/material_access_service.dart';
import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/persistence/auth_persistence_service.dart';
import 'package:mayabela/services/persistence/teacher_persistence_service.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/session_prefs_service.dart';
import 'package:mayabela/services/cloud/realtime_messaging_bootstrap.dart';
import 'package:mayabela/services/cloud/role_cloud_live_sync.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/password_hash_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/student_account_service.dart';
import 'package:mayabela/services/student_portal_audit_service.dart';
import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/utils/email_utils.dart';
import 'package:mayabela/utils/phone_utils.dart';
import 'package:flutter/foundation.dart';

class RegisteredUser {
  RegisteredUser({
    required this.username,
    required this.password,
    required this.roleKey,
    this.email,
    this.phone,
    this.schoolId,
    this.fullName,
    this.linkedStudentIds = const [],
    this.linkedTeacherId,
    this.linkedAdminId,
    this.linkedDriverId,
    this.linkedStudentId,
    this.mustChangePassword = false,
    this.staffRoles = const [],
    this.staffPermissions = const [],
  });

  final String username;
  String password;
  final String roleKey;
  final String? email;
  final String? phone;
  final String? schoolId;
  String? fullName;
  List<String> linkedStudentIds;
  String? linkedTeacherId;
  final String? linkedAdminId;
  String? linkedDriverId;
  final String? linkedStudentId;
  bool mustChangePassword;

  /// RBAC staff role keys (see [StaffRoles]) granted to this account.
  /// Multiple roles combine into one permission set at login.
  List<String> staffRoles;

  /// Effective permissions stamped at assign/login (supports custom roles).
  List<String> staffPermissions;
}

class AuthService {
  /// Debug-only demo password. Never used in release builds.
  /// Below [minPasswordLength] so cloud school-login rejects it if leaked.
  static const demoPassword = '1234';
  /// Legacy shared temp — prefer [generateTempPassword] for new accounts.
  static const tempPassword = 'Welcome12!';
  static const minPasswordLength = 10;

  static String? _requireEmail(String? email) {
    return EmailUtils.isValid(email) ? null : 'invalid_email';
  }

  static String? _normalizedEmail(String? email) => EmailUtils.normalize(email);
  static const passwordRedactedMarker = '__REDACTED__';

  /// Release-safe fallback when a registry record has no password.
  /// Debug keeps [demoPassword] for local smoke accounts only.
  static String driverPasswordFallback({required bool debugMode}) =>
      debugMode ? demoPassword : passwordRedactedMarker;

  static const _tempAlphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%';

  /// Unique temporary password for a newly created account (≥ [minPasswordLength]).
  static String generateTempPassword({int length = 12}) {
    final n = length < minPasswordLength ? minPasswordLength : length;
    final random = Random.secure();
    return List.generate(
      n,
      (_) => _tempAlphabet[random.nextInt(_tempAlphabet.length)],
    ).join();
  }
  static const supportPhone = '+251911646444';
  static const supportEmail = 'nebila310@gmail.com';

  static const roleTeacher = 'teacher';
  static const roleParent = 'parent';
  static const roleAdmin = 'admin';
  static const roleDriver = 'driver';
  static const roleStudent = 'student';

  /// Login-tile / dashboard key for administration staff (not a cloud roleKey).
  /// Cloud auth still uses [roleTeacher]; routing uses [isAdministrationStaff].
  static const roleStaff = 'staff';

  static const roles = [
    roleTeacher,
    roleParent,
    roleStudent,
    roleAdmin,
    roleDriver,
  ];

  /// Roles shown on the login screen. [roleStaff] and [roleTeacher] both
  /// authenticate with cloud roleKey `teacher`, then land on different homes.
  static const loginRoles = [
    roleTeacher,
    roleStaff,
    roleParent,
    roleStudent,
    roleAdmin,
    roleDriver,
  ];

  /// Maps a login-tile selection to the cloud/account `roleKey`.
  static String apiRoleKeyForLogin(String loginRole) {
    if (loginRole == roleStaff) return roleTeacher;
    return loginRole;
  }

  /// Administration / custom staff (has assigned staffRoles), not classroom-only.
  static bool get isAdministrationStaff {
    final user = currentUser;
    if (user == null || user.roleKey != roleTeacher) return false;
    if (user.staffRoles.isNotEmpty || user.staffPermissions.isNotEmpty) {
      return true;
    }
    // Fallback: teacher_registry may still hold roles if auth doc was wiped.
    final record = TeacherRegistryService.instance.resolveForAuthUser(
      linkedTeacherId: user.linkedTeacherId,
      username: user.username,
      phone: user.phone,
      schoolId: activeSchoolId ?? user.schoolId,
    );
    if (record == null || record.staffRoles.isEmpty) return false;
    user.staffRoles = List<String>.from(record.staffRoles);
    return true;
  }

  /// Classroom teacher account (no administration staffRoles).
  static bool get isClassroomTeacher {
    final user = currentUser;
    if (user == null || user.roleKey != roleTeacher) return false;
    return !isAdministrationStaff;
  }

  static final Map<String, RegisteredUser> _users = {
    if (kDebugMode) ...{
      'teacher': RegisteredUser(
        username: 'teacher',
        password: demoPassword,
        roleKey: roleTeacher,
        email: 'teacher@mayaschool.et',
        phone: '0911000001',
        fullName: 'Miss Belen',
        schoolId: 'TB-001',
        linkedTeacherId: 'TCH-1001',
      ),
      'parent': RegisteredUser(
        username: 'parent',
        password: demoPassword,
        roleKey: roleParent,
        email: 'parent@mayaschool.et',
        phone: '0911000002',
        fullName: 'Mr. Bekele',
        schoolId: 'TB-001',
        linkedStudentIds: ['STU-1001', 'STU-1002'],
      ),
      'admin': RegisteredUser(
        username: 'admin',
        password: demoPassword,
        roleKey: roleAdmin,
        email: 'admin@mayaschool.et',
        phone: '0911000003',
        fullName: 'School Admin',
        schoolId: 'TB-001',
      ),
      'driver': RegisteredUser(
        username: 'driver',
        password: demoPassword,
        roleKey: roleDriver,
        email: 'driver@mayaschool.et',
        phone: '0911667788',
        fullName: 'Alemayehu T.',
        schoolId: 'TB-001',
        linkedDriverId: 'DRV-1001',
      ),
    },
  };

  /// Phone logins for registry staff + demo aliases (`transport` = driver).
  static void ensureRegistryLoginAccounts() {
    for (final driver in DriverRegistryService.instance.getAllDrivers()) {
      _upsertDriverLoginFromRegistry(driver);
    }

    for (final teacher in TeacherRegistryService.instance.getAllTeachers()) {
      final phone = teacher.phone?.trim();
      if (phone == null || phone.isEmpty) continue;
      final key = PhoneUtils.loginKey(phone);
      if (_users.containsKey(key) && _users[key]!.roleKey != roleTeacher) {
        continue;
      }
      final pass = (teacher.initialPassword?.trim().isNotEmpty ?? false)
          ? teacher.initialPassword!.trim()
          : (kDebugMode ? demoPassword : passwordRedactedMarker);
      _users[key] = RegisteredUser(
        username: key,
        password: pass,
        roleKey: roleTeacher,
        email: teacher.email,
        phone: PhoneUtils.normalizeLocal(phone),
        schoolId: teacher.schoolId,
        fullName: teacher.fullName,
        linkedTeacherId: teacher.teacherId,
      );
    }

    if (kDebugMode) {
      const adminPhone = '0911000003';
      final adminKey = PhoneUtils.loginKey(adminPhone);
      _users[adminKey] = RegisteredUser(
        username: adminKey,
        password: demoPassword,
        roleKey: roleAdmin,
        email: 'admin@mayaschool.et',
        phone: adminPhone,
        fullName: 'School Admin',
        schoolId: 'TB-001',
      );

      final demoDriver = _users['driver'];
      if (demoDriver != null) {
        _users['transport'] = RegisteredUser(
          username: 'transport',
          password: demoDriver.password,
          roleKey: roleDriver,
          email: demoDriver.email,
          phone: demoDriver.phone,
          schoolId: demoDriver.schoolId,
          fullName: demoDriver.fullName,
          linkedDriverId: demoDriver.linkedDriverId,
        );
      }
    }
  }

  static const _demoOnlyUsernames = {
    'teacher',
    'parent',
    'admin',
    'driver',
    'transport',
  };

  /// Rebuilds phone logins from staff registries, saves locally, and pushes to Firestore.
  static Future<void> persistRegistryLoginAccounts() async {
    ensureRegistryLoginAccounts();
    await AuthPersistenceService.instance.saveAll();
    if (!SupabaseBootstrap.isInitialized) return;
    for (final user in _users.values) {
      final key = user.username.toLowerCase();
      if (_demoOnlyUsernames.contains(key)) continue;
      await AuthPersistenceService.instance.syncUserToCloud(user);
    }
  }

  static String? _pendingOtp;
  static String? _pendingOtpUser;
  static RegisteredUser? currentUser;
  static String? sessionSchoolId;

  /// Access-scope claims from Cloud login (used for Firestore query constraints).
  static List<String> cloudLinkedClassNames = const [];
  static List<String> cloudLinkedStudentNames = const [];
  static List<String> cloudAssignedClassNames = const [];

  static Map<String, RegisteredUser> get allUsers => _users;

  static void applyCloudAccessScope({
    List<String>? linkedClassNames,
    List<String>? linkedStudentNames,
    List<String>? assignedClassNames,
    List<String>? linkedStudentIds,
  }) {
    if (linkedClassNames != null) {
      cloudLinkedClassNames = List<String>.from(linkedClassNames);
    }
    if (linkedStudentNames != null) {
      cloudLinkedStudentNames = List<String>.from(linkedStudentNames);
    }
    if (assignedClassNames != null) {
      cloudAssignedClassNames = List<String>.from(assignedClassNames);
    }
    if (linkedStudentIds != null && currentUser?.roleKey == roleParent) {
      currentUser!.linkedStudentIds = List<String>.from(linkedStudentIds);
      final key = currentUser!.username.toLowerCase();
      _users[key]?.linkedStudentIds = List<String>.from(linkedStudentIds);
    }
  }

  static void clearCloudAccessScope() {
    cloudLinkedClassNames = const [];
    cloudLinkedStudentNames = const [];
    cloudAssignedClassNames = const [];
  }

  /// Class names the signed-in parent/teacher may sync from Firestore.
  static List<String> accessClassNamesForSync() {
    final user = currentUser;
    if (user == null) return const [];
    if (user.roleKey == roleParent) {
      final fromKids = <String>{};
      for (final id in activeLinkedStudentIds()) {
        final student = StudentRegistryService.instance.lookupById(id);
        final className = student?.className.trim();
        if (className != null && className.isNotEmpty) {
          fromKids.add(className);
        }
      }
      if (fromKids.isNotEmpty) return fromKids.toList();
      return List<String>.from(cloudLinkedClassNames);
    }
    if (user.roleKey == roleTeacher) {
      final fromRegistry = <String>{};
      final record = TeacherRegistryService.instance.resolveForAuthUser(
        linkedTeacherId: user.linkedTeacherId,
        username: user.username,
        phone: user.phone,
        schoolId: activeSchoolId ?? user.schoolId,
      );
      if (record != null) {
        fromRegistry.addAll(record.assignedClassNames);
      }
      if (fromRegistry.isNotEmpty) return fromRegistry.toList();
      return List<String>.from(cloudAssignedClassNames);
    }
    return const [];
  }

  static bool get usesScopedCloudReads {
    final role = currentUser?.roleKey;
    return role == roleParent || role == roleTeacher || role == roleStudent;
  }

  static void mergePersistedUser(RegisteredUser incoming) {
    final key = incoming.username.toLowerCase();
    final existing = _users[key];

    var linkedDriverId = incoming.linkedDriverId;
    if (incoming.roleKey == roleDriver &&
        (linkedDriverId == null || linkedDriverId.trim().isEmpty)) {
      linkedDriverId = existing?.linkedDriverId ??
          DriverRegistryService.instance
              .resolveForAuthUser(
                username: incoming.username,
                phone: incoming.phone ?? existing?.phone,
                schoolId: incoming.schoolId ?? existing?.schoolId,
              )
              ?.driverId;
    }

    var linkedTeacherId = incoming.linkedTeacherId;
    if (incoming.roleKey == roleTeacher &&
        (linkedTeacherId == null || linkedTeacherId.trim().isEmpty)) {
      linkedTeacherId = existing?.linkedTeacherId ??
          TeacherRegistryService.instance
              .resolveForAuthUser(
                username: incoming.username,
                phone: incoming.phone ?? existing?.phone,
                schoolId: incoming.schoolId ?? existing?.schoolId,
              )
              ?.teacherId;
    }

    var linkedStudentId = incoming.linkedStudentId;
    if (incoming.roleKey == roleStudent &&
        (linkedStudentId == null || linkedStudentId.trim().isEmpty)) {
      linkedStudentId = existing?.linkedStudentId ??
          StudentRegistryService.instance
              .lookupByLoginUsername(incoming.username)
              ?.studentId;
    }

    final incomingPassword = incoming.password;
    final keepExistingPassword = incomingPassword == passwordRedactedMarker ||
        incomingPassword.isEmpty;
    final merged = RegisteredUser(
      username: incoming.username,
      password: keepExistingPassword
          ? (existing?.password ?? passwordRedactedMarker)
          : incomingPassword,
      roleKey: incoming.roleKey,
      email: incoming.email ?? existing?.email,
      phone: incoming.phone ?? existing?.phone,
      schoolId: incoming.schoolId ?? existing?.schoolId,
      fullName: incoming.fullName ?? existing?.fullName,
      linkedStudentIds: incoming.linkedStudentIds.isNotEmpty
          ? incoming.linkedStudentIds
          : (existing?.linkedStudentIds ?? const []),
      linkedTeacherId: linkedTeacherId,
      linkedAdminId: incoming.linkedAdminId ?? existing?.linkedAdminId,
      linkedDriverId: linkedDriverId,
      linkedStudentId: linkedStudentId,
      mustChangePassword:
          incoming.mustChangePassword || (existing?.mustChangePassword ?? false),
      staffRoles: incoming.staffRoles.isNotEmpty
          ? incoming.staffRoles
          : (existing?.staffRoles ?? const []),
      staffPermissions: incoming.staffPermissions.isNotEmpty
          ? incoming.staffPermissions
          : (existing?.staffPermissions ?? const []),
    );

    _users[key] = merged;

    if (currentUser?.username.toLowerCase() == key) {
      currentUser = merged;
      alignTeacherSessionWithRegistry();
      alignDriverSessionWithRegistry();
    }
  }

  static Future<void> _persistUser(RegisteredUser user) async {
    await AuthPersistenceService.instance.saveAll();
    await AuthPersistenceService.instance.syncUserToCloud(user);
  }

  static final ValueNotifier<int> sessionListenable = ValueNotifier<int>(0);

  static void setSession(RegisteredUser user) {
    currentUser = user;
    sessionListenable.value++;
  }

  // —— RBAC (staff role templates + combined permissions) ——

  /// Whether the signed-in user holds [permission].
  ///
  /// The school owner (roleKey 'admin') implicitly holds every permission,
  /// as does anyone granted the Full Access staff role. Staff members get
  /// the union of their role templates. This mirrors the server-side
  /// enforcement in the write-guard; UI gating only.
  static bool hasPermission(String permission) {
    final user = currentUser;
    if (user == null) return false;
    if (user.roleKey == roleAdmin) return true;
    if (user.staffRoles.contains(StaffRoles.fullAccess)) return true;
    // Prefer live role catalog over stamped staffPermissions (stamped lists
    // often still include removed "always-on" ERP extras from older creates).
    final fromRoles = SchoolRoleCatalogService.instance
        .permissionsForRoles(user.staffRoles);
    if (fromRoles.isNotEmpty) return fromRoles.contains(permission);
    return user.staffPermissions.contains(permission);
  }

  /// Whether the signed-in user holds any of [permissions].
  static bool hasAnyPermission(Iterable<String> permissions) =>
      permissions.any(hasPermission);

  /// Combined permission set of the signed-in user (empty when logged out).
  static Set<String> get currentPermissions {
    final user = currentUser;
    if (user == null) return const {};
    if (user.roleKey == roleAdmin ||
        user.staffRoles.contains(StaffRoles.fullAccess)) {
      return SchoolPermissions.all;
    }
    final fromRoles =
        SchoolRoleCatalogService.instance.permissionsForRoles(user.staffRoles);
    if (fromRoles.isNotEmpty) return fromRoles;
    return user.staffPermissions.toSet();
  }

  /// Only the school owner may grant/revoke owner-only roles (Full Access).
  static bool get canAssignFullAccess => currentUser?.roleKey == roleAdmin;

  /// Whether the signed-in user may open the role-assignment UI at all.
  static bool get canAssignStaffRoles =>
      currentUser?.roleKey == roleAdmin ||
      hasPermission(SchoolPermissions.assignRoles);

  static void applySchoolContext(String loginSchoolId) {
    final trimmed = loginSchoolId.trim();
    sessionSchoolId = trimmed.isNotEmpty ? trimmed : currentUser?.schoolId;
  }

  static String? get activeSchoolId => sessionSchoolId ?? currentUser?.schoolId;

  static String get schoolDisplayName =>
      SchoolRegistryService.instance.displayName(activeSchoolId);

  static bool get hasValidSchoolContext =>
      SchoolRegistryService.instance.isValid(activeSchoolId);

  /// Login/signup error code for blocked schools, or null if OK.
  static String? schoolAccessError(String? schoolId) {
    return switch (SchoolRegistryService.instance.accessBlockFor(schoolId)) {
      SchoolAccessBlock.notFound => 'school_not_found',
      SchoolAccessBlock.inactive => 'school_inactive',
      SchoolAccessBlock.suspended => 'school_suspended',
      SchoolAccessBlock.expired => 'school_expired',
      null => null,
    };
  }

  static bool restoreSession(String username, {String? schoolId}) {
    final user = _findUser(username);
    if (user == null) return false;

    setSession(user);
    applySchoolContext(schoolId ?? user.schoolId ?? '');
    if (!hasValidSchoolContext) {
      currentUser = null;
      sessionSchoolId = null;
      sessionListenable.value++;
      unawaited(SessionPrefsService.instance.clearActiveSession());
      return false;
    }

    alignTeacherSessionWithRegistry();
    alignDriverSessionWithRegistry();
    EnrollmentService.instance.ensureSeeded();
    return true;
  }

  static void clearSession() {
    RoleCloudLiveSync.stop();
    unawaited(RealtimeMessagingBootstrap.onSessionEnded());
    currentUser = null;
    sessionSchoolId = null;
    clearCloudAccessScope();
    MaterialAccessService.instance.reset();
    unawaited(SessionPrefsService.instance.clearActiveSession());
    unawaited(SchoolAuthCloudService.instance.signOutCloud());
    AppLockService.instance.handleLogout();
    CloudSyncProgressService.instance.reset();
    sessionListenable.value++;
  }

  static List<String> activeLinkedStudentIds() {
    final user = currentUser;
    if (user == null) return [];
    if (user.roleKey == roleStudent) {
      final linked = user.linkedStudentId?.trim().toUpperCase();
      if (linked != null && linked.isNotEmpty) return [linked];
      return const [];
    }
    if (user.roleKey == roleParent) {
      EnrollmentService.instance.ensureSeeded();
      final approved = EnrollmentService.instance
          .approvedStudentIdsForParent(user.username);
      if (approved.isNotEmpty) return approved;
    }
    return user.linkedStudentIds;
  }

  static bool isParentAccessApproved() {
    final user = currentUser;
    if (user == null || user.roleKey != roleParent) return true;
    EnrollmentService.instance.ensureSeeded();
    return EnrollmentService.instance.hasApprovedAccess(user.username);
  }

  static bool isParentPendingApproval() {
    final user = currentUser;
    if (user == null || user.roleKey != roleParent) return false;
    EnrollmentService.instance.ensureSeeded();
    return EnrollmentService.instance.hasPendingOnly(user.username) ||
        (!EnrollmentService.instance.hasApprovedAccess(user.username) &&
            EnrollmentService.instance.linksForParent(user.username).any(
              (l) => l.status == ParentLinkStatus.pending,
            ));
  }

  static void updateParentLinks(String username, List<String> studentIds) {
    final user = _users[username.toLowerCase()];
    if (user != null) {
      user.linkedStudentIds = List.from(studentIds);
      unawaited(_persistUser(user));
    }
  }

  static String displayNameForRole(String roleKey) {
    if (roleKey == roleTeacher || roleKey == roleStaff) {
      final record = TeacherRegistryService.instance.resolveForAuthUser(
        linkedTeacherId: currentUser?.linkedTeacherId,
        username: currentUser?.username,
        phone: currentUser?.phone,
        schoolId: activeSchoolId ?? currentUser?.schoolId,
      );
      if (record != null && record.fullName.isNotEmpty) {
        return record.fullName;
      }
    }
    if (roleKey == roleDriver) {
      final record = DriverRegistryService.instance.resolveForAuthUser(
        linkedDriverId: currentUser?.linkedDriverId,
        username: currentUser?.username,
        phone: currentUser?.phone,
        schoolId: activeSchoolId ?? currentUser?.schoolId,
      );
      if (record != null && record.fullName.isNotEmpty) {
        return record.fullName;
      }
    }
    if (roleKey == roleStudent) {
      final record = StudentAccountService.instance.recordForCurrentUser();
      if (record != null && record.fullName.isNotEmpty) {
        return record.fullName;
      }
    }
    final user = currentUser;
    if (user?.fullName != null && user!.fullName!.isNotEmpty) {
      return user.fullName!;
    }
    return switch (roleKey) {
      roleTeacher => 'Administration Staff',
      roleParent => 'Parent',
      roleAdmin => 'Admin',
      roleDriver => 'Transport',
      roleStudent => 'Student',
      _ => 'User',
    };
  }

  /// Keeps login session aligned with the teacher staff registry.
  static void alignTeacherSessionWithRegistry() {
    final user = currentUser;
    if (user == null || user.roleKey != roleTeacher) return;

    final record = TeacherRegistryService.instance.resolveForAuthUser(
      linkedTeacherId: user.linkedTeacherId,
      username: user.username,
      phone: user.phone,
      schoolId: activeSchoolId ?? user.schoolId,
    );
    if (record == null) return;

    user.linkedTeacherId = record.teacherId;
    user.fullName = record.fullName;
    _users[user.username] = user;
  }

  /// Updates stored login profile after admin edits a teacher record.
  static void syncTeacherAuthProfile(AdminTeacherRecord teacher) {
    for (final user in _users.values) {
      if (user.roleKey != roleTeacher) continue;
      final matchesId =
          user.linkedTeacherId?.toUpperCase() == teacher.teacherId.toUpperCase();
      final matchesPhone = PhoneUtils.matches(user.phone, teacher.phone ?? '');
      if (!matchesId && !matchesPhone) continue;
      user.linkedTeacherId = teacher.teacherId;
      user.fullName = teacher.fullName;
      _users[user.username] = user;
      if (currentUser?.username == user.username) {
        alignTeacherSessionWithRegistry();
      }
    }
  }

  /// Keeps login session aligned with the driver transport registry.
  static void alignDriverSessionWithRegistry() {
    final user = currentUser;
    if (user == null || user.roleKey != roleDriver) return;

    final record = DriverRegistryService.instance.resolveForAuthUser(
      linkedDriverId: user.linkedDriverId,
      username: user.username,
      phone: user.phone,
      schoolId: activeSchoolId ?? user.schoolId,
    );
    if (record == null) return;

    user.linkedDriverId = record.driverId;
    user.fullName = record.fullName;
    _users[user.username] = user;
  }

  /// Driver ID for the signed-in transport account, resolved from registry.
  static String? get resolvedLinkedDriverId {
    alignDriverSessionWithRegistry();
    return currentUser?.linkedDriverId;
  }

  static void _upsertDriverLoginFromRegistry(AdminDriverRecord driver) {
    final phone = driver.phone?.trim();
    if (phone == null || phone.isEmpty) return;
    final key = PhoneUtils.loginKey(phone);
    final existing = _users[key];
    final pass = (driver.initialPassword?.trim().isNotEmpty ?? false)
        ? driver.initialPassword!.trim()
        : (existing?.password ??
            driverPasswordFallback(debugMode: kDebugMode));
    _users[key] = RegisteredUser(
      username: key,
      password: pass,
      roleKey: roleDriver,
      email: driver.email ?? existing?.email,
      phone: PhoneUtils.normalizeLocal(phone),
      schoolId: driver.schoolId,
      fullName: driver.fullName,
      linkedDriverId: driver.driverId,
      mustChangePassword: existing?.mustChangePassword ?? false,
    );

    final loginAlias = driver.loginUsername?.trim().toLowerCase();
    for (final user in _users.values.toList()) {
      if (user.roleKey != roleDriver) continue;
      final matchesPhone = PhoneUtils.matches(user.phone, phone);
      final matchesAlias =
          loginAlias != null &&
          loginAlias.isNotEmpty &&
          user.username.toLowerCase() == loginAlias;
      if (!matchesPhone && !matchesAlias) continue;
      user.linkedDriverId = driver.driverId;
      user.fullName = driver.fullName;
      _users[user.username] = user;
    }
  }

  /// Updates stored login profile after admin edits a driver record.
  static void syncDriverAuthProfile(AdminDriverRecord driver) {
    _upsertDriverLoginFromRegistry(driver);
    for (final user in _users.values) {
      if (user.roleKey != roleDriver) continue;
      final matchesId =
          user.linkedDriverId?.toUpperCase() == driver.driverId.toUpperCase();
      final matchesPhone = PhoneUtils.matches(user.phone, driver.phone ?? '');
      if (!matchesId && !matchesPhone) continue;
      user.linkedDriverId = driver.driverId;
      user.fullName = driver.fullName;
      _users[user.username] = user;
      if (currentUser?.username == user.username) {
        alignDriverSessionWithRegistry();
      }
    }
  }

  /// Preferred login path: Cloud Function + custom token (release).
  /// Falls back to local validation only in debug when cloud is unavailable.
  static Future<String?> validateLoginAsync({
    required String roleKey,
    required String username,
    required String password,
    String? schoolId,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return 'empty';
    }

    var cloudUsername = username.trim();
    if (roleKey == roleParent ||
        roleKey == roleDriver ||
        roleKey == roleTeacher ||
        roleKey == roleAdmin) {
      final phone = PhoneUtils.normalizeLocal(cloudUsername);
      if (phone != null) cloudUsername = phone;
    }

    if (SupabaseBootstrap.isInitialized ||
        await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true)) {
      final cloud = await SchoolAuthCloudService.instance.login(
        roleKey: roleKey,
        username: cloudUsername,
        password: password,
        schoolId: schoolId,
      );
      if (cloud.ok) {
        alignTeacherSessionWithRegistry();
        alignDriverSessionWithRegistry();
        EnrollmentService.instance.ensureSeeded();
        if (roleKey == roleStudent) {
          final user = currentUser;
          unawaited(
            StudentPortalAuditService.instance.log(
              action: StudentPortalAuditAction.login,
              schoolId: user?.schoolId ?? schoolId ?? '',
              studentId: user?.linkedStudentId,
              username: user?.username ?? username,
            ),
          );
        }
        unawaited(SessionPrefsService.instance.saveActiveSession());
        return null;
      }

      // Supabase school-login unreachable → allow local accounts in debug /
      // when a matching offline profile already exists on this device.
      final cloudError = cloud.errorCode ?? 'invalid';
      if (cloudError == 'cloud_required') {
        final localError = validateLogin(
          roleKey: roleKey,
          username: username,
          password: password,
        );
        if (localError == null) return null;
        return 'cloud_required';
      }
      if (!kDebugMode) {
        return cloudError;
      }
    } else if (!kDebugMode) {
      return 'cloud_required';
    }

    return validateLogin(
      roleKey: roleKey,
      username: username,
      password: password,
    );
  }

  static String? validateLogin({
    required String roleKey,
    required String username,
    required String password,
  }) {
    if (username.trim().isEmpty || password.isEmpty) {
      return 'empty';
    }

    var identifier = username.trim();
    if (roleKey == roleParent ||
        roleKey == roleDriver ||
        roleKey == roleTeacher ||
        roleKey == roleAdmin) {
      final phone = PhoneUtils.normalizeLocal(identifier);
      if (phone != null) identifier = phone;
    }

    final user = _findUser(identifier, roleKey: roleKey);
    if (user == null || !_passwordMatches(user, password)) {
      if (roleKey == roleStudent) {
        unawaited(
          StudentPortalAuditService.instance.log(
            action: StudentPortalAuditAction.loginFailed,
            schoolId: sessionSchoolId ?? activeSchoolId ?? '',
            studentId: identifier.toUpperCase().startsWith('STU-')
                ? identifier.toUpperCase()
                : null,
            username: identifier,
            detail: 'Invalid credentials',
          ),
        );
      }
      return 'invalid';
    }
    if (user.roleKey != roleKey) {
      return 'role_mismatch';
    }

    if (roleKey == roleStudent) {
      final student = _studentRecordForUser(user);
      if (student == null || !StudentAccountService.instance.canLogin(student)) {
        return 'account_inactive';
      }
      if (!StudentAccountService.instance.isPortalEnabled(student.schoolId)) {
        return 'portal_disabled';
      }
    }

    setSession(user);
    alignTeacherSessionWithRegistry();
    alignDriverSessionWithRegistry();
    EnrollmentService.instance.ensureSeeded();

    if (roleKey == roleStudent) {
      unawaited(
        StudentPortalAuditService.instance.log(
          action: StudentPortalAuditAction.login,
          schoolId: user.schoolId ?? '',
          studentId: user.linkedStudentId,
          username: user.username,
        ),
      );
    }
    return null;
  }

  static bool isUsernameTaken(String username) {
    return _findUser(username) != null;
  }

  static bool _passwordMatches(RegisteredUser user, String password) {
    return PasswordHashService.instance.verifyPassword(password, user.password);
  }

  static AdminStudentRecord? _studentRecordForUser(RegisteredUser user) {
    final linked = user.linkedStudentId?.trim().toUpperCase();
    if (linked != null && linked.isNotEmpty) {
      return StudentRegistryService.instance.lookupAnyById(linked);
    }
    return StudentRegistryService.instance.lookupByLoginUsername(user.username);
  }

  static RegisteredUser? findUser(String identifier) => _findUser(identifier);

  static RegisteredUser? _findUser(String identifier, {String? roleKey}) {
    final trimmed = identifier.trim();
    final lower = trimmed.toLowerCase();
    if (lower == 'transport') {
      return _users['transport'] ?? _users['driver'];
    }

    if (roleKey == roleStudent || trimmed.toUpperCase().startsWith('STU-')) {
      final studentId = trimmed.toUpperCase();
      for (final user in _users.values) {
        if (user.roleKey == roleStudent &&
            user.linkedStudentId?.toUpperCase() == studentId) {
          return user;
        }
      }
    }

    for (final user in _users.values) {
      if (user.username.toLowerCase() == lower) return user;
      final email = user.email;
      if (email != null && email.isNotEmpty && email.toLowerCase() == lower) {
        return user;
      }
      if (PhoneUtils.matches(user.phone, trimmed)) return user;
    }
    return null;
  }

  static bool _accountExists(String identifier) => _findUser(identifier) != null;

  static bool accountExists(String phoneOrUsername) {
    final key = PhoneUtils.loginKey(phoneOrUsername);
    return _accountExists(key);
  }

  /// First admin account registered for a school (platform onboarding).
  static RegisteredUser? adminUserForSchool(String? schoolId) {
    if (schoolId == null || schoolId.trim().isEmpty) return null;
    final id = schoolId.trim().toUpperCase();
    for (final user in _users.values) {
      if (user.roleKey == roleAdmin && (user.schoolId?.toUpperCase() ?? '') == id) {
        return user;
      }
    }
    return null;
  }

  static void updateAdminPasswordForSchool(String schoolId, String newPassword) {
    final admin = adminUserForSchool(schoolId);
    if (admin != null) admin.password = newPassword;
  }

  static String? registerSchoolAdmin({
    required String schoolName,
    required String city,
    required String adminFullName,
    required String adminPhone,
    required String password,
    required String schoolId,
    String? adminEmail,
  }) {
    if (!PhoneUtils.isValidLoginPhone(adminPhone)) return 'invalid_phone';
    final emailError = _requireEmail(adminEmail);
    if (emailError != null) return emailError;
    final key = PhoneUtils.loginKey(adminPhone);
    if (_accountExists(key)) return 'exists';

    _users[key] = RegisteredUser(
      username: key,
      password: password,
      roleKey: roleAdmin,
      email: _normalizedEmail(adminEmail),
      phone: PhoneUtils.normalizeLocal(adminPhone),
      schoolId: schoolId,
      fullName: adminFullName.trim(),
    );
    unawaited(_persistUser(_users[key]!));
    return null;
  }

  /// Permanently removes a login locally and in the cloud (account + password secret)
  /// so the phone number can be registered again after staff is deleted.
  static Future<void> revokeRegisteredAccount(
    String phoneOrUsername, {
    String? schoolId,
  }) async {
    final key = PhoneUtils.loginKey(phoneOrUsername).trim().toLowerCase();
    final sid = (schoolId ?? _findUser(phoneOrUsername)?.schoolId ?? activeSchoolId ?? '')
        .trim()
        .toUpperCase();

    // Remove every local profile that matches this phone/username.
    final toRemove = <RegisteredUser>[];
    for (final user in _users.values) {
      if (user.username.toLowerCase() == key) {
        toRemove.add(user);
        continue;
      }
      if (PhoneUtils.matches(user.phone, phoneOrUsername) ||
          PhoneUtils.matches(user.phone, key)) {
        toRemove.add(user);
      }
    }
    for (final user in toRemove) {
      _removeUserAccount(user);
    }
    if (toRemove.isNotEmpty) {
      await AuthPersistenceService.instance.saveAll();
    }

    if (key.isEmpty || sid.isEmpty) return;
    if (SchoolAuthCloudService.instance.isAvailable) {
      await SchoolAuthCloudService.instance.deleteAccount(
        username: key,
        schoolId: sid,
      );
    }
  }

  /// Frees [phone] when it only belongs to deactivated/removed staff (or an
  /// orphaned teacher login). Returns `null` if the number can be used, or
  /// `'exists'` when an active account still holds it.
  static Future<String?> preparePhoneForStaffRegistration(
    String phone, {
    required String schoolId,
  }) async {
    if (!PhoneUtils.isValidLoginPhone(phone)) return 'invalid_phone';
    final key = PhoneUtils.loginKey(phone);
    final sid = schoolId.trim().toUpperCase();

    final matches = TeacherRegistryService.instance
        .allTeachersIncludingInactive()
        .where((t) => t.schoolId.toUpperCase() == sid)
        .where(
          (t) =>
              PhoneUtils.matches(t.phone, key) ||
              (t.loginUsername?.trim().toLowerCase() == key),
        )
        .toList();
    final hasActive = matches.any((t) => t.isActive);
    if (hasActive) return 'exists';

    final existing = _findUser(key);
    if (existing != null) {
      // Only reclaim teacher logins. Never steal parent/driver/admin numbers.
      if (existing.roleKey != roleTeacher) return 'exists';
    }

    // Remove inactive staff + cloud login so the number is fully free.
    for (final teacher in matches.where((t) => !t.isActive)) {
      await TeacherPersistenceService.instance.deleteStaffAndFreePhone(teacher);
    }
    if (matches.isEmpty && existing != null) {
      await revokeRegisteredAccount(key, schoolId: sid);
    }

    return _accountExists(key) ? 'exists' : null;
  }

  static String? registerDriverAccount({
    required String fullName,
    required String schoolId,
    required String phone,
    required String linkedDriverId,
    String? email,
    String password = tempPassword,
  }) {
    if (!PhoneUtils.isValidLoginPhone(phone)) return 'invalid_phone';
    final emailError = _requireEmail(email);
    if (emailError != null) return emailError;
    final key = PhoneUtils.loginKey(phone);
    if (_accountExists(key)) return 'exists';

    _users[key] = RegisteredUser(
      username: key,
      password: password,
      roleKey: roleDriver,
      email: _normalizedEmail(email),
      phone: PhoneUtils.normalizeLocal(phone),
      schoolId: schoolId,
      fullName: fullName.trim(),
      linkedDriverId: linkedDriverId,
      mustChangePassword: true,
    );
    unawaited(_persistUser(_users[key]!));
    return null;
  }

  static String? registerTeacherAccount({
    required String fullName,
    required String schoolId,
    required String phone,
    required String linkedTeacherId,
    String? email,
    String password = tempPassword,
  }) {
    if (!PhoneUtils.isValidLoginPhone(phone)) return 'invalid_phone';
    final emailError = _requireEmail(email);
    if (emailError != null) return emailError;
    final key = PhoneUtils.loginKey(phone);
    if (_accountExists(key)) return 'exists';

    _users[key] = RegisteredUser(
      username: key,
      password: password,
      roleKey: roleTeacher,
      email: _normalizedEmail(email),
      phone: PhoneUtils.normalizeLocal(phone),
      schoolId: schoolId,
      fullName: fullName.trim(),
      linkedTeacherId: linkedTeacherId,
      mustChangePassword: true,
    );
    unawaited(_persistUser(_users[key]!));
    return null;
  }

  static String? registerStudentAccount({
    required String fullName,
    required String schoolId,
    required String username,
    required String linkedStudentId,
    String password = tempPassword,
    bool mustChangePassword = true,
  }) {
    final key = username.trim().toLowerCase();
    if (key.isEmpty) return 'invalid_username';
    if (_accountExists(key)) return 'exists';

    _users[key] = RegisteredUser(
      username: key,
      password: PasswordHashService.instance.hashPassword(password),
      roleKey: roleStudent,
      schoolId: schoolId.trim().toUpperCase(),
      fullName: fullName.trim(),
      linkedStudentId: linkedStudentId.trim().toUpperCase(),
      mustChangePassword: mustChangePassword,
    );
    unawaited(_persistUser(_users[key]!));
    return null;
  }

  static void updateStudentPassword({
    required String username,
    required String plainPassword,
    bool mustChangePassword = true,
  }) {
    final user = _findUser(username);
    if (user == null || user.roleKey != roleStudent) return;
    user.password = PasswordHashService.instance.hashPassword(plainPassword);
    user.mustChangePassword = mustChangePassword;
    unawaited(_persistUser(user));
  }

  static String? registerParent({
    required String fullName,
    required String schoolId,
    required String phone,
    required String password,
    required String studentId,
    required DateTime studentDob,
    required ParentRelationship relationship,
    String? email,
  }) {
    return registerParentAccount(
      fullName: fullName,
      schoolId: schoolId,
      phone: phone,
      password: password,
      email: email,
      children: [
        ParentChildRegistration(
          studentId: studentId,
          dateOfBirth: studentDob,
          relationship: relationship,
        ),
      ],
    );
  }

  static String? registerParentAccount({
    required String fullName,
    required String schoolId,
    required String phone,
    required String password,
    String? email,
    required List<ParentChildRegistration> children,
  }) {
    if (children.isEmpty) return 'no_children';
    if (schoolAccessError(schoolId) != null) return 'school_blocked';
    if (!PhoneUtils.isValidLoginPhone(phone)) return 'invalid_phone';
    final emailError = _requireEmail(email);
    if (emailError != null) return emailError;
    final key = PhoneUtils.loginKey(phone);
    final phoneError = _preparePhoneForParentRegistration(key, children);
    if (phoneError != null) return phoneError;

    for (final child in children) {
      final linkError = EnrollmentService.instance.verifyAndCreateParentLink(
        schoolId: schoolId,
        studentId: child.studentId,
        dateOfBirth: child.dateOfBirth,
        parentUsername: key,
        parentFullName: fullName.trim(),
        relationship: child.relationship,
        hasMedicalCondition: child.hasMedicalCondition,
        medicalConditionDetails: child.medicalConditionDetails,
        otherMedicalInfo: child.otherMedicalInfo,
      );
      if (linkError != null) return linkError;
    }

    final user = RegisteredUser(
      username: key,
      password: password,
      roleKey: roleParent,
      email: _normalizedEmail(email),
      phone: PhoneUtils.normalizeLocal(phone),
      schoolId: schoolId.trim(),
      fullName: fullName.trim(),
      linkedStudentIds: const [],
    );
    _users[key] = user;
    unawaited(() async {
      final cloud = await SchoolAuthCloudService.instance.registerParent(
        user: user,
        password: password,
      );
      if (cloud.ok) {
        user.password = passwordRedactedMarker;
      }
      await _persistUser(user);
    }());
    return null;
  }

  static const _demoLoginUsernames = {
    'teacher',
    'parent',
    'admin',
    'driver',
    'transport',
  };

  static bool _isDemoLoginAccount(RegisteredUser user) =>
      _demoLoginUsernames.contains(user.username.toLowerCase());

  static bool _phoneAuthorizedForStudentLink(
    String phoneKey,
    List<ParentChildRegistration> children,
  ) {
    for (final child in children) {
      final record =
          StudentRegistryService.instance.lookupById(child.studentId);
      if (record == null) continue;
      final relationshipPhone = record.phoneForRelationship(child.relationship);
      if (relationshipPhone != null &&
          PhoneUtils.loginKey(relationshipPhone) == phoneKey) {
        return true;
      }
      if (record.hasParentContactPhone(phoneKey)) return true;
    }
    return false;
  }

  static void _removeUserAccount(RegisteredUser user) {
    _users.remove(user.username.toLowerCase());
    final phoneKey =
        user.phone != null ? PhoneUtils.loginKey(user.phone!) : null;
    if (phoneKey != null && _users[phoneKey]?.username == user.username) {
      _users.remove(phoneKey);
    }
  }

  /// Allows student contact phones to register even when a demo login blocks the number.
  static String? _preparePhoneForParentRegistration(
    String phoneKey,
    List<ParentChildRegistration> children,
  ) {
    final existing = _findUser(phoneKey);
    if (existing == null) return null;

    if (existing.roleKey == roleParent) {
      if (_isDemoLoginAccount(existing) &&
          _phoneAuthorizedForStudentLink(phoneKey, children)) {
        _removeUserAccount(existing);
        return null;
      }
      return 'exists';
    }

    if (!_phoneAuthorizedForStudentLink(phoneKey, children)) {
      return 'exists';
    }

    if (existing.roleKey == roleTeacher ||
        existing.roleKey == roleDriver ||
        existing.roleKey == roleAdmin) {
      return 'phone_used_by_staff';
    }

    _removeUserAccount(existing);
    return null;
  }

  static String? registerUser({
    required String roleKey,
    required String fullName,
    required String schoolId,
    required String email,
    required String phone,
    required String password,
    required String username,
    List<String> linkedStudentIds = const [],
    String? linkedTeacherId,
    String? linkedAdminId,
    String? linkedDriverId,
  }) {
    if (_users.containsKey(username.toLowerCase())) {
      return 'exists';
    }
    final emailError = _requireEmail(email);
    if (emailError != null) return emailError;

    _users[username.toLowerCase()] = RegisteredUser(
      username: username.toLowerCase(),
      password: password,
      roleKey: roleKey,
      email: _normalizedEmail(email),
      phone: phone.trim(),
      schoolId: schoolId.trim(),
      fullName: fullName.trim(),
      linkedStudentIds: List.from(linkedStudentIds),
      linkedTeacherId: linkedTeacherId,
      linkedAdminId: linkedAdminId,
      linkedDriverId: linkedDriverId,
    );
    setSession(_users[username.toLowerCase()]!);
    unawaited(_persistUser(_users[username.toLowerCase()]!));
    return null;
  }

  static String? sendOtp(String phoneOrUsername) {
    // Demo OTP is debug-only. Release must use Firebase Phone Auth.
    if (!kDebugMode) return 'demo_disabled';

    final user = _findUser(phoneOrUsername.trim());
    if (user == null) return 'not_found';

    _pendingOtpUser = user.username;
    final random = Random.secure();
    _pendingOtp = (100000 + random.nextInt(900000)).toString();
    return _pendingOtp;
  }

  static void preparePasswordReset(String username) {
    _pendingOtpUser = username.toLowerCase();
  }

  static bool verifyOtp(String otp) {
    return otp.trim() == _pendingOtp;
  }

  static bool resetPassword(String otp, String newPassword) {
    if (!verifyOtp(otp) || _pendingOtpUser == null) return false;
    return resetPasswordWithoutOtpCheck(newPassword);
  }

  static bool resetPasswordWithoutOtpCheck(String newPassword) {
    if (_pendingOtpUser == null && currentUser != null) {
      _pendingOtpUser = currentUser!.username;
    }
    if (_pendingOtpUser == null) return false;
    if (newPassword.length < minPasswordLength) return false;

    final user = _users[_pendingOtpUser!];
    if (user == null) return false;

    user.password = PasswordHashService.instance.hashPassword(newPassword);
    user.mustChangePassword = false;
    _pendingOtp = null;
    _pendingOtpUser = null;
    unawaited(_persistUser(user));
    unawaited(
      SchoolAuthCloudService.instance.changePassword(
        newPassword: newPassword,
        username: user.username,
      ),
    );
    return true;
  }

  static void changePassword(String newPassword) {
    final user = currentUser;
    if (user == null || newPassword.length < minPasswordLength) return;
    user.password = PasswordHashService.instance.hashPassword(newPassword);
    user.mustChangePassword = false;
    _users[user.username]!.password = user.password;
    _users[user.username]!.mustChangePassword = false;
    unawaited(_persistUser(_users[user.username]!));
    unawaited(
      SchoolAuthCloudService.instance.changePassword(newPassword: newPassword),
    );

    if (user.roleKey == roleStudent) {
      final studentId = user.linkedStudentId;
      if (studentId != null) {
        unawaited(StudentAccountService.instance.markFirstLoginComplete(studentId));
      }
      unawaited(
        StudentPortalAuditService.instance.log(
          action: StudentPortalAuditAction.passwordChange,
          schoolId: user.schoolId ?? '',
          studentId: studentId,
          username: user.username,
        ),
      );
    }
  }

  static bool requiresPasswordChange() {
    final user = currentUser;
    return user?.mustChangePassword ?? false;
  }

  /// Clears forced first-login password-change (after a successful change only).
  static void clearMustChangePasswordRequirement() {
    final user = currentUser;
    if (user == null || !user.mustChangePassword) return;
    user.mustChangePassword = false;
    final stored = _users[user.username];
    if (stored != null) stored.mustChangePassword = false;
    unawaited(_persistUser(user));
  }
}
