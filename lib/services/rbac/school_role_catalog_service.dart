import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/rbac/module_right.dart';
import 'package:mayabela/services/rbac/role_module_catalog.dart';
import 'package:mayabela/services/rbac/staff_dashboard_modules.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_audit_log_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// Per-school role catalog: built-in defaults + module checkbox overrides +
/// custom roles the school owner adds.
class SchoolRoleCatalogService {
  SchoolRoleCatalogService._();
  static final instance = SchoolRoleCatalogService._();

  static const _prefsPrefix = 'school_role_catalog_v1_';
  static const _collection = 'school_role_catalogs';

  final Map<String, _SchoolRoleCatalog> _bySchool = {};
  final Map<String, Future<void>> _loads = {};
  DocumentStore get _crud => DocumentStore();

  String? get _activeSchoolId =>
      AuthService.activeSchoolId ?? AuthService.sessionSchoolId;

  /// Roles the school owner may allow to edit other roles' permissions.
  static const List<String> delegatableRoleKeys = [
    StaffRoles.fullAccess,
    StaffRoles.generalManager,
  ];

  /// True when the signed-in staff member holds a role on the owner's list.
  bool get currentUserIsRolePermissionDelegate {
    if (AuthService.currentUser?.roleKey == AuthService.roleAdmin) return false;
    final roles = AuthService.currentUser?.staffRoles ?? const <String>[];
    if (roles.isEmpty) return false;
    final allowed = rolePermissionDelegates().toSet();
    if (allowed.isEmpty) return false;
    return roles.any((role) {
      final key = StaffRoles.canonicalize(role);
      if (allowed.contains(key)) return true;
      final source = sourceKeyFor(role);
      return source != null && allowed.contains(source);
    });
  }

  List<String> rolePermissionDelegates({String? schoolId}) {
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    final catalog = _bySchool[sid];
    if (catalog == null) return const [];
    return List<String>.from(catalog.rolePermissionDelegates);
  }

  String? _requireRoleCatalogEditor({bool delegatesList = false}) {
    if (AuthService.currentUser?.roleKey == AuthService.roleAdmin) return null;
    if (delegatesList) return 'not_allowed';
    if (currentUserIsRolePermissionDelegate) return null;
    return 'not_allowed';
  }

  Future<void> ensureLoaded([String? schoolId]) =>
      _ensureLoaded(schoolId, forceRefresh: false);

  /// Re-read cloud/prefs so a staff login picks up the owner's latest grants.
  Future<void> reload([String? schoolId]) =>
      _ensureLoaded(schoolId, forceRefresh: true);

  Future<void> _ensureLoaded(
    String? schoolId, {
    required bool forceRefresh,
  }) async {
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    if (sid.isEmpty) return;
    if (!forceRefresh && _bySchool.containsKey(sid)) return;
    final pending = _loads[sid];
    if (pending != null && !forceRefresh) {
      await pending;
      return;
    }
    final future = _loadAndUpgrade(sid);
    _loads[sid] = future;
    try {
      await future;
    } finally {
      if (identical(_loads[sid], future)) _loads.remove(sid);
    }
  }

  Future<void> _loadAndUpgrade(String sid) async {
    await _load(sid);
    _upgradeVicePresidentOverride(sid);
  }

  /// Schools with stale role overrides get newly added default permissions.
  void _upgradeVicePresidentOverride(String sid) {
    final catalog = _bySchool[sid];
    if (catalog == null) return;
    var changed = false;
    changed =
        _mergeOverrideExtras(catalog, StaffRoles.vicePresident, const {
          SchoolPermissions.sendAnnouncements,
          SchoolPermissions.manageLearningMaterials,
          SchoolPermissions.manageMaterialAccess,
          SchoolPermissions.accessSupport,
          SchoolPermissions.messageParents,
          SchoolPermissions.manageStudents,
          SchoolPermissions.manageParentLinks,
          SchoolPermissions.manageFees,
          SchoolPermissions.recordPayments,
          SchoolPermissions.manageStaffAccounts,
          SchoolPermissions.manageBuses,
          SchoolPermissions.manageDrivers,
          SchoolPermissions.assignStudentTransport,
          SchoolPermissions.manageQaFindings,
          SchoolPermissions.manageDigitalOps,
        }) ||
        changed;
    changed =
        _mergeOverrideExtras(catalog, StaffRoles.humanResource, const {
          SchoolPermissions.accessSupport,
          SchoolPermissions.messageParents,
          SchoolPermissions.viewTransport,
          SchoolPermissions.manageBuses,
          SchoolPermissions.manageDrivers,
          SchoolPermissions.assignStudentTransport,
          SchoolPermissions.viewStudents,
          SchoolPermissions.viewAllSchoolData,
        }) ||
        changed;
    changed =
        _mergeOverrideExtras(catalog, StaffRoles.sectionDirector, const {
          SchoolPermissions.accessSupport,
          SchoolPermissions.messageParents,
          SchoolPermissions.viewTransport,
          SchoolPermissions.assignStudentTransport,
          SchoolPermissions.manageParentLinks,
          SchoolPermissions.viewAllGrades,
          SchoolPermissions.viewAllSchoolData,
          SchoolPermissions.approveGrades,
          SchoolPermissions.sendAnnouncements,
        }) ||
        changed;
    changed =
        _mergeOverrideExtras(catalog, StaffRoles.principal, const {
          SchoolPermissions.viewAllSchoolData,
          SchoolPermissions.manageDigitalOps,
        }) ||
        changed;
    changed =
        _mergeOverrideExtras(catalog, StaffRoles.generalManager, const {
          SchoolPermissions.manageDigitalOps,
        }) ||
        changed;
    changed =
        _mergeOverrideExtras(catalog, StaffRoles.studentAffairs, const {
          SchoolPermissions.viewAllSchoolData,
        }) ||
        changed;
    changed =
        _mergeOverrideExtras(catalog, StaffRoles.registrar, const {
          SchoolPermissions.viewAllSchoolData,
          SchoolPermissions.manageDigitalOps,
        }) ||
        changed;
    changed =
        _mergeOverrideExtras(catalog, StaffRoles.accountant, const {
          SchoolPermissions.viewAllSchoolData,
        }) ||
        changed;
    changed =
        _mergeOverrideExtras(catalog, StaffRoles.transportAdmin, const {
          SchoolPermissions.viewAllSchoolData,
        }) ||
        changed;
    if (changed) unawaited(_persist(sid, catalog));
  }

  bool _mergeOverrideExtras(
    _SchoolRoleCatalog catalog,
    String roleKey,
    Set<String> extras,
  ) {
    final override = catalog.overrides[roleKey];
    if (override == null) return false;
    if (extras.every(override.contains)) return false;
    catalog.overrides[roleKey] = {...override, ...extras};
    return true;
  }

  /// Roles available when assigning to staff (built-in + custom, with overrides).
  List<StaffRole> rolesForAssign({String? schoolId}) {
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    final catalog = _bySchool[sid];
    final out = <StaffRole>[];
    for (final base in StaffRoles.templates) {
      out.add(_applyOverride(base, catalog));
    }
    if (catalog != null) {
      for (final custom in catalog.customRoles) {
        out.add(custom);
      }
    }
    return out;
  }

  StaffRole? lookup(String key, {String? schoolId}) {
    final canonical = StaffRoles.canonicalize(key);
    for (final role in rolesForAssign(schoolId: schoolId)) {
      if (role.key == canonical || role.key == key.trim().toLowerCase()) {
        return role;
      }
    }
    return StaffRoles.lookup(key);
  }

  Set<String> permissionsForRoles(
    Iterable<String> roleKeys, {
    String? schoolId,
  }) {
    final out = <String>{};
    for (final key in roleKeys) {
      final role = lookup(key, schoolId: schoolId);
      if (role == null) continue;
      out.addAll(role.permissions);
    }
    return out;
  }

  bool hasModuleRights(String roleKey, {String? schoolId}) {
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    final catalog = _bySchool[sid];
    if (catalog == null) return false;
    final key = StaffRoles.canonicalize(roleKey);
    return catalog.moduleRights.containsKey(key) ||
        catalog.moduleRights.containsKey(roleKey.trim().toLowerCase());
  }

  ModuleRight? moduleRightFor(
    String roleKey,
    String moduleId, {
    String? schoolId,
  }) {
    final map = moduleRightsFor(roleKey, schoolId: schoolId);
    if (map == null) return null;
    final id = moduleId.trim();
    if (id.isEmpty) return null;
    final stored = map[id];
    return stored;
  }

  Map<String, ModuleRight>? moduleRightsFor(
    String roleKey, {
    String? schoolId,
  }) {
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    final catalog = _bySchool[sid];
    if (catalog == null) return null;
    final key = StaffRoles.canonicalize(roleKey);
    final raw =
        catalog.moduleRights[key] ??
        catalog.moduleRights[roleKey.trim().toLowerCase()];
    if (raw == null) return null;
    return {
      for (final entry in raw.entries)
        entry.key: ModuleRight.parse(entry.value),
    };
  }

  Future<String?> saveRoleModules({
    required String roleKey,
    required Set<String> permissions,
    Map<String, ModuleRight>? moduleRights,
    String? schoolId,
  }) async {
    final denied = _requireRoleCatalogEditor();
    if (denied != null) return denied;
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    if (sid.isEmpty) return 'no_school';

    final key = StaffRoles.canonicalize(roleKey);
    final base = StaffRoles.lookup(key);
    if (base != null && (base.ownerOnly || !base.customizable)) {
      return 'not_customizable';
    }

    await ensureLoaded(sid);
    final catalog = _bySchool.putIfAbsent(sid, _SchoolRoleCatalog.new);
    final next = StaffDashboardModules.withBaseline(permissions);
    if (base != null) {
      catalog.overrides[key] = next;
    } else {
      final existing = catalog.customRoles.indexWhere((r) => r.key == key);
      if (existing < 0) return 'unknown_role';
      catalog.customRoles[existing] = catalog.customRoles[existing].copyWith(
        permissions: next,
      );
    }
    if (moduleRights != null) {
      catalog.moduleRights[key] = {
        for (final entry in moduleRights.entries) entry.key: entry.value.name,
      };
    }
    final cloudErr = await _persist(sid, catalog);
    unawaited(_restampHolders(sid, key));
    await SchoolAuditLogService.instance.log(
      action: 'staff_role_modules_updated',
      schoolId: sid,
      entityType: 'staff_role',
      entityId: key,
      detail: 'Updated modules/permissions for $key',
      after: {
        'permissions': next.toList()..sort(),
        if (moduleRights != null)
          'moduleRights': {
            for (final entry in moduleRights.entries)
              entry.key: entry.value.name,
          },
      },
    );
    return cloudErr;
  }

  Future<String?> addCustomRole({
    required String label,
    required Set<String> permissions,
    String? schoolId,
  }) async {
    if (AuthService.currentUser?.roleKey != AuthService.roleAdmin) {
      return 'not_allowed';
    }
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    if (sid.isEmpty) return 'no_school';
    final cleanLabel = label.trim();
    if (cleanLabel.isEmpty) return 'empty_label';

    await ensureLoaded(sid);
    final catalog = _bySchool.putIfAbsent(sid, _SchoolRoleCatalog.new);
    final key =
        'custom_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    catalog.customRoles.add(
      StaffRole(
        key: key,
        labelEn: cleanLabel,
        labelAm: cleanLabel,
        labelOm: cleanLabel,
        permissions: StaffDashboardModules.withBaseline(permissions),
        builtIn: false,
      ),
    );
    catalog.moduleRights[key] = {};
    final cloudErr = await _persist(sid, catalog);
    await SchoolAuditLogService.instance.log(
      action: 'staff_role_created',
      schoolId: sid,
      entityType: 'staff_role',
      entityId: key,
      detail: 'Custom role "$cleanLabel"',
    );
    return cloudErr;
  }

  String? sourceKeyFor(String roleKey, {String? schoolId}) {
    final role = lookup(roleKey, schoolId: schoolId);
    final stored = role?.basedOn?.trim();
    if (stored != null && stored.isNotEmpty) {
      return StaffRoles.canonicalize(stored);
    }
    return StaffRoles.sourceKeyOf(roleKey);
  }

  StaffRole? findTitledRole({
    required String sourceRoleKey,
    required String label,
    String? schoolId,
  }) {
    final source = StaffRoles.canonicalize(sourceRoleKey);
    final want = label.trim().toLowerCase();
    if (source.isEmpty || want.isEmpty) return null;
    for (final role in rolesForAssign(schoolId: schoolId)) {
      if (role.builtIn) continue;
      if ((sourceKeyFor(role.key, schoolId: schoolId) ?? '') != source) {
        continue;
      }
      if (role.labelEn.trim().toLowerCase() == want) return role;
    }
    return null;
  }

  int holderCount(String roleKey, {String? schoolId}) {
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    if (sid.isEmpty) return 0;
    final want = StaffRoles.canonicalize(roleKey);
    var n = 0;
    for (final teacher in TeacherRegistryService.instance.teachersForSchool(
      sid,
    )) {
      if (teacher.staffRoles.map(StaffRoles.canonicalize).contains(want)) {
        n++;
      }
    }
    return n;
  }

  /// Copy a built-in (or titled) position into its own title and module map.
  /// Two Principals — "Principal 1-8" and "Principal KG" — stay independent.
  Future<TitledRoleResult> ensureTitledRole({
    required String sourceRoleKey,
    required String label,
    String? schoolId,
  }) async {
    final denied = _requireRoleCatalogEditor();
    if (denied != null) return TitledRoleResult.error(denied);
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    if (sid.isEmpty) return TitledRoleResult.error('no_school');
    final cleanLabel = label.trim();
    if (cleanLabel.isEmpty) return TitledRoleResult.error('empty_label');

    final source = StaffRoles.canonicalize(sourceRoleKey);
    final sourceRole = lookup(source, schoolId: sid);
    if (sourceRole == null) return TitledRoleResult.error('unknown_role');
    if (sourceRole.ownerOnly || !sourceRole.customizable) {
      return TitledRoleResult.error('not_customizable');
    }
    final basedOn = sourceKeyFor(source, schoolId: sid) ?? source;
    if (StaffRoles.lookup(basedOn)?.ownerOnly == true) {
      return TitledRoleResult.error('not_customizable');
    }

    await ensureLoaded(sid);
    final existing = findTitledRole(
      sourceRoleKey: basedOn,
      label: cleanLabel,
      schoolId: sid,
    );
    if (existing != null) return TitledRoleResult.ok(existing.key);

    final catalog = _bySchool.putIfAbsent(sid, _SchoolRoleCatalog.new);
    final key = _nextInstanceKey(catalog, basedOn, cleanLabel);
    final seedRights =
        moduleRightsFor(source, schoolId: sid) ??
        RoleModuleCatalog.defaultsForRole(
          StaffRoles.lookup(basedOn) ?? sourceRole,
        );
    catalog.customRoles.add(
      StaffRole(
        key: key,
        labelEn: cleanLabel,
        labelAm: cleanLabel,
        labelOm: cleanLabel,
        permissions: Set<String>.from(sourceRole.permissions),
        builtIn: false,
        basedOn: basedOn,
      ),
    );
    catalog.moduleRights[key] = {
      for (final entry in seedRights.entries) entry.key: entry.value.name,
    };
    final cloudErr = await _persist(sid, catalog);
    await SchoolAuditLogService.instance.log(
      action: 'staff_role_titled_instance_created',
      schoolId: sid,
      entityType: 'staff_role',
      entityId: key,
      detail: 'Titled $basedOn as "$cleanLabel"',
    );
    if (cloudErr != null &&
        cloudErr != 'cloud_failed' &&
        cloudErr != 'cloud_session') {
      return TitledRoleResult.error(cloudErr);
    }
    return TitledRoleResult.ok(key, error: cloudErr);
  }

  String _nextInstanceKey(
    _SchoolRoleCatalog catalog,
    String source,
    String label,
  ) {
    final slug = label
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final base = 'custom_${source}_${slug.isEmpty ? 'role' : slug}';
    if (!catalog.customRoles.any((role) => role.key == base) &&
        !catalog.moduleRights.containsKey(base)) {
      return base;
    }
    var i = 2;
    while (catalog.customRoles.any((role) => role.key == '${base}_$i') ||
        catalog.moduleRights.containsKey('${base}_$i')) {
      i++;
    }
    return '${base}_$i';
  }

  /// Remove a titled copy nobody holds so a person-specific rename does not
  /// leave the old title in Role Permissions.
  Future<String?> dropUnusedTitledRole(
    String roleKey, {
    String? schoolId,
  }) async {
    final denied = _requireRoleCatalogEditor();
    if (denied != null) return denied;
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    if (sid.isEmpty) return 'no_school';
    final key = StaffRoles.canonicalize(roleKey);
    if (!key.startsWith('custom_')) return 'not_custom';
    if (holderCount(key, schoolId: sid) > 0) return 'in_use';
    await ensureLoaded(sid);
    final catalog = _bySchool[sid];
    if (catalog == null) return 'unknown_role';
    final before = catalog.customRoles.length;
    catalog.customRoles.removeWhere((r) => r.key == key);
    if (catalog.customRoles.length == before) return 'unknown_role';
    catalog.moduleRights.remove(key);
    return _persist(sid, catalog);
  }

  Future<String?> deleteCustomRole(String roleKey, {String? schoolId}) async {
    if (AuthService.currentUser?.roleKey != AuthService.roleAdmin) {
      return 'not_allowed';
    }
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    if (sid.isEmpty) return 'no_school';
    final key = roleKey.trim().toLowerCase();
    if (!key.startsWith('custom_')) return 'not_custom';
    if (holderCount(key, schoolId: sid) > 0) return 'in_use';

    await ensureLoaded(sid);
    final catalog = _bySchool[sid];
    if (catalog == null) return 'unknown_role';
    final before = catalog.customRoles.length;
    catalog.customRoles.removeWhere((r) => r.key == key);
    if (catalog.customRoles.length == before) return 'unknown_role';
    catalog.moduleRights.remove(key);
    return _persist(sid, catalog);
  }

  Future<String?> setRolePermissionDelegates(
    Iterable<String> roleKeys, {
    String? schoolId,
  }) async {
    final denied = _requireRoleCatalogEditor(delegatesList: true);
    if (denied != null) return denied;
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    if (sid.isEmpty) return 'no_school';
    await ensureLoaded(sid);
    final catalog = _bySchool.putIfAbsent(sid, _SchoolRoleCatalog.new);
    final allowed = <String>{};
    for (final raw in roleKeys) {
      final key = StaffRoles.canonicalize(raw);
      if (delegatableRoleKeys.contains(key)) allowed.add(key);
    }
    catalog.rolePermissionDelegates
      ..clear()
      ..addAll(allowed);
    final cloudErr = await _persist(sid, catalog);
    await SchoolAuditLogService.instance.log(
      action: 'staff_role_permission_delegates_updated',
      schoolId: sid,
      entityType: 'staff_role',
      entityId: sid,
      detail:
          'Role-permission delegates: ${allowed.isEmpty ? 'none' : allowed.join(', ')}',
      after: {'rolePermissionDelegates': allowed.toList()..sort()},
    );
    return cloudErr;
  }

  /// Rename a built-in or custom role. The key stays the same so permissions
  /// and logins keep working; staff see the new title after next sign-in.
  ///
  /// Same editor gate as creating a titled copy: the school owner, or Full
  /// Access / General Manager after the owner delegates Role Permissions.
  Future<String?> renameRole({
    required String roleKey,
    required String label,
    String? schoolId,
  }) async {
    final denied = _requireRoleCatalogEditor();
    if (denied != null) return denied;
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    if (sid.isEmpty) return 'no_school';
    final cleanLabel = label.trim();
    if (cleanLabel.isEmpty) return 'empty_label';

    await ensureLoaded(sid);
    final catalog = _bySchool.putIfAbsent(sid, _SchoolRoleCatalog.new);
    final key = StaffRoles.canonicalize(roleKey);
    final customIdx = catalog.customRoles.indexWhere((r) => r.key == key);
    if (customIdx >= 0) {
      catalog.customRoles[customIdx] = catalog.customRoles[customIdx].copyWith(
        labelEn: cleanLabel,
        labelAm: cleanLabel,
        labelOm: cleanLabel,
      );
    } else {
      final base = StaffRoles.lookup(key);
      if (base == null) return 'unknown_role';
      catalog.labelOverrides[key] = cleanLabel;
    }
    final cloudErr = await _persist(sid, catalog);
    await SchoolAuditLogService.instance.log(
      action: 'staff_role_renamed',
      schoolId: sid,
      entityType: 'staff_role',
      entityId: key,
      detail: 'Role title set to "$cleanLabel"',
    );
    return cloudErr;
  }

  StaffRole _applyOverride(StaffRole base, _SchoolRoleCatalog? catalog) {
    final override = catalog?.overrides[base.key];
    final label = catalog?.labelOverrides[base.key];
    if (override == null && (label == null || label.isEmpty)) return base;
    return base.copyWith(
      permissions: override == null
          ? null
          : StaffDashboardModules.withBaseline(override),
      labelEn: label,
      labelAm: label,
      labelOm: label,
    );
  }

  Future<void> _load(String sid) async {
    if (_crud.available) {
      try {
        await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
        final data = await _readCloudCatalog(sid);
        if (data != null) {
          _bySchool[sid] = _SchoolRoleCatalog.fromJson(data);
          await _savePrefs(sid, _bySchool[sid]!);
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('SchoolRoleCatalogService cloud load: $e');
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString('$_prefsPrefix$sid') ??
          prefs.getString('$_prefsPrefix${sid.toUpperCase()}') ??
          prefs.getString('$_prefsPrefix${sid.toLowerCase()}');
      if (raw != null && raw.isNotEmpty) {
        _bySchool[sid] = _SchoolRoleCatalog.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SchoolRoleCatalogService prefs load: $e');
    }

    _bySchool[sid] = _SchoolRoleCatalog();
  }

  Future<Map<String, dynamic>?> _readCloudCatalog(String sid) async {
    final jwtSchool =
        (SupabaseBootstrap.isInitialized
            ? (SupabaseBootstrap
                          .client
                          .auth
                          .currentUser
                          ?.appMetadata['schoolId']
                      as String?)
                  ?.trim()
            : null) ??
        '';
    final ids = <String>{
      sid,
      sid.toUpperCase(),
      sid.toLowerCase(),
      if (jwtSchool.isNotEmpty) jwtSchool,
    };
    for (final id in ids) {
      final data = await _crud.readDoc(collection: _collection, docId: id);
      if (data != null) return data;
    }
    return null;
  }

  Future<void> _restampHolders(String sid, String roleKey) async {
    final canonical = StaffRoles.canonicalize(roleKey);
    for (final teacher in TeacherRegistryService.instance.teachersForSchool(
      sid,
    )) {
      final roles = [
        for (final raw in teacher.staffRoles) StaffRoles.canonicalize(raw),
      ];
      if (!roles.contains(canonical)) continue;
      final username = teacher.loginUsername?.trim().toLowerCase() ?? '';
      if (username.isEmpty) continue;
      final combined = permissionsForRoles(roles, schoolId: sid).toList()
        ..sort();
      final account = AuthService.findUser(username);
      if (account == null) continue;
      account.staffRoles = List<String>.from(roles);
      account.staffPermissions = List<String>.from(combined);
      AuthService.mergePersistedUser(account);
      try {
        await SchoolAuthCloudService.instance.upsertAccount(
          user: account,
          staffRoles: roles,
          staffPermissions: combined,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('SchoolRoleCatalogService restamp $username: $e');
        }
      }
    }
  }

  Future<String?> _persist(String sid, _SchoolRoleCatalog catalog) async {
    await _savePrefs(sid, catalog);
    if (!_crud.available) return null;
    Future<String?> write({required bool forceRefresh}) async {
      try {
        await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
        // Do not refreshSession() on every save: that can drop school claims
        // and make the follow-up title / tile edit fail RLS. Reuse the same
        // JWT helper staff create already uses for school-upsert-account.
        if (!await SchoolAuthCloudService.instance.ensureValidSchoolJwt(
          forceRefresh: forceRefresh,
        )) {
          return 'cloud_session';
        }
        final jwtSchool =
            (SchoolAuthCloudService.accessTokenSchoolId() ??
                    (SupabaseBootstrap
                                .client
                                .auth
                                .currentUser
                                ?.appMetadata['schoolId']
                            as String?)
                        ?.trim() ??
                    sid)
                .trim();
        if (jwtSchool.isEmpty) return 'cloud_session';
        // Use the JWT school id exactly — RLS compares case-sensitively.
        final docId = jwtSchool.toUpperCase() == sid.toUpperCase()
            ? jwtSchool
            : sid;
        await _crud.createOrUpdate(
          collection: _collection,
          docId: docId,
          merge: false,
          data: {...catalog.toJson(), 'schoolId': jwtSchool},
        );
        return null;
      } catch (e) {
        if (kDebugMode) debugPrint('SchoolRoleCatalogService cloud save: $e');
        return 'cloud_failed';
      }
    }

    final first = await write(forceRefresh: false);
    if (first == null) return null;
    return write(forceRefresh: true);
  }

  Future<void> _savePrefs(String sid, _SchoolRoleCatalog catalog) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefsPrefix$sid', jsonEncode(catalog.toJson()));
    } catch (_) {}
  }

  @visibleForTesting
  void resetForTests() {
    _bySchool.clear();
    _loads.clear();
  }

  @visibleForTesting
  void putEmptyForTests(String schoolId) {
    final sid = schoolId.trim();
    if (sid.isEmpty) return;
    _bySchool[sid] = _SchoolRoleCatalog();
  }

  @visibleForTesting
  void seedRolePermissionDelegatesForTests({
    required String schoolId,
    required Iterable<String> roleKeys,
  }) {
    final sid = schoolId.trim();
    if (sid.isEmpty) return;
    final catalog = _bySchool.putIfAbsent(sid, _SchoolRoleCatalog.new);
    catalog.rolePermissionDelegates
      ..clear()
      ..addAll(
        {
          for (final raw in roleKeys) StaffRoles.canonicalize(raw),
        }.where(delegatableRoleKeys.contains),
      );
  }

  @visibleForTesting
  void seedModuleRightsForTests({
    required String schoolId,
    required String roleKey,
    required Map<String, ModuleRight> rights,
    Set<String>? permissions,
  }) {
    final sid = schoolId.trim();
    if (sid.isEmpty) return;
    final catalog = _bySchool.putIfAbsent(sid, _SchoolRoleCatalog.new);
    final key = StaffRoles.canonicalize(roleKey);
    catalog.moduleRights[key] = {
      for (final entry in rights.entries) entry.key: entry.value.name,
    };
    if (permissions != null) {
      catalog.overrides[key] = StaffDashboardModules.withBaseline(permissions);
    }
  }
}

class _SchoolRoleCatalog {
  _SchoolRoleCatalog({
    Map<String, Set<String>>? overrides,
    Map<String, String>? labelOverrides,
    List<StaffRole>? customRoles,
    Map<String, Map<String, String>>? moduleRights,
    List<String>? rolePermissionDelegates,
  }) : overrides = overrides ?? {},
       labelOverrides = labelOverrides ?? {},
       customRoles = customRoles ?? [],
       moduleRights = moduleRights ?? {},
       rolePermissionDelegates = rolePermissionDelegates ?? [];

  final Map<String, Set<String>> overrides;
  final Map<String, String> labelOverrides;
  final List<StaffRole> customRoles;

  /// roleKey → moduleId → none|read|edit. Presence of the role key means the
  /// owner saved an explicit map (missing module ids count as none).
  final Map<String, Map<String, String>> moduleRights;

  /// Built-in role keys allowed to open Role Permissions (besides admin).
  final List<String> rolePermissionDelegates;

  Map<String, dynamic> toJson() => {
    'overrides': {
      for (final e in overrides.entries) e.key: e.value.toList()..sort(),
    },
    'moduleRights': {
      for (final e in moduleRights.entries)
        e.key: Map<String, String>.from(e.value),
    },
    'labelOverrides': Map<String, String>.from(labelOverrides),
    'rolePermissionDelegates': List<String>.from(rolePermissionDelegates)
      ..sort(),
    'customRoles': [
      for (final r in customRoles)
        {
          'key': r.key,
          'labelEn': r.labelEn,
          'labelAm': r.labelAm,
          'labelOm': r.labelOm,
          'permissions': r.permissions.toList()..sort(),
          if (r.basedOn != null && r.basedOn!.isNotEmpty) 'basedOn': r.basedOn,
        },
    ],
  };

  factory _SchoolRoleCatalog.fromJson(Map<String, dynamic> json) {
    final overridesRaw = json['overrides'];
    final overrides = <String, Set<String>>{};
    if (overridesRaw is Map) {
      for (final e in overridesRaw.entries) {
        final perms = e.value;
        overrides[e.key.toString()] = {
          if (perms is List)
            for (final p in perms) p.toString(),
        };
      }
    }
    final moduleRights = <String, Map<String, String>>{};
    final rightsRaw = json['moduleRights'];
    if (rightsRaw is Map) {
      for (final e in rightsRaw.entries) {
        final value = e.value;
        if (value is! Map) continue;
        moduleRights[e.key.toString()] = {
          for (final inner in value.entries)
            inner.key.toString(): inner.value.toString(),
        };
      }
    }
    final custom = <StaffRole>[];
    final customRaw = json['customRoles'];
    if (customRaw is List) {
      for (final row in customRaw) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final key = (map['key'] as String?)?.trim().toLowerCase() ?? '';
        if (key.isEmpty) continue;
        final label = (map['labelEn'] as String?)?.trim() ?? key;
        final perms = <String>{
          if (map['permissions'] is List)
            for (final p in map['permissions'] as List) p.toString(),
        };
        final basedOnRaw = (map['basedOn'] as String?)?.trim();
        custom.add(
          StaffRole(
            key: key,
            labelEn: label,
            labelAm: (map['labelAm'] as String?)?.trim() ?? label,
            labelOm: (map['labelOm'] as String?)?.trim() ?? label,
            permissions: StaffDashboardModules.withBaseline(perms),
            builtIn: false,
            basedOn: basedOnRaw == null || basedOnRaw.isEmpty
                ? StaffRoles.sourceKeyOf(key)
                : StaffRoles.canonicalize(basedOnRaw),
          ),
        );
      }
    }
    final labels = <String, String>{};
    final labelsRaw = json['labelOverrides'];
    if (labelsRaw is Map) {
      for (final e in labelsRaw.entries) {
        final value = e.value?.toString().trim() ?? '';
        if (value.isEmpty) continue;
        labels[e.key.toString()] = value;
      }
    }
    final delegates = <String>[];
    final delegatesRaw = json['rolePermissionDelegates'];
    if (delegatesRaw is List) {
      for (final raw in delegatesRaw) {
        final key = StaffRoles.canonicalize(raw.toString());
        if (SchoolRoleCatalogService.delegatableRoleKeys.contains(key) &&
            !delegates.contains(key)) {
          delegates.add(key);
        }
      }
    }
    return _SchoolRoleCatalog(
      overrides: overrides,
      labelOverrides: labels,
      customRoles: custom,
      moduleRights: moduleRights,
      rolePermissionDelegates: delegates,
    );
  }
}

class TitledRoleResult {
  const TitledRoleResult._({this.error, this.roleKey});

  factory TitledRoleResult.ok(String roleKey, {String? error}) =>
      TitledRoleResult._(roleKey: roleKey, error: error);
  factory TitledRoleResult.error(String error) =>
      TitledRoleResult._(error: error);

  final String? error;
  final String? roleKey;
}
