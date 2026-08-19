import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/rbac/staff_dashboard_modules.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_audit_log_service.dart';

/// Per-school role catalog: built-in defaults + module checkbox overrides +
/// custom roles the school owner adds.
class SchoolRoleCatalogService {
  SchoolRoleCatalogService._();
  static final instance = SchoolRoleCatalogService._();

  static const _prefsPrefix = 'school_role_catalog_v1_';
  static const _collection = 'school_role_catalogs';

  final Map<String, _SchoolRoleCatalog> _bySchool = {};
  DocumentStore get _crud => DocumentStore();

  String? get _activeSchoolId =>
      AuthService.activeSchoolId ?? AuthService.sessionSchoolId;

  Future<void> ensureLoaded([String? schoolId]) async {
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    if (sid.isEmpty || _bySchool.containsKey(sid)) return;
    await _load(sid);
    _upgradeVicePresidentOverride(sid);
  }

  /// Schools with stale role overrides get newly added default permissions.
  void _upgradeVicePresidentOverride(String sid) {
    final catalog = _bySchool[sid];
    if (catalog == null) return;
    var changed = false;
    changed = _mergeOverrideExtras(
          catalog,
          StaffRoles.vicePresident,
          const {
            SchoolPermissions.sendAnnouncements,
            SchoolPermissions.manageLearningMaterials,
            SchoolPermissions.manageMaterialAccess,
            SchoolPermissions.accessSupport,
            SchoolPermissions.messageParents,
          },
        ) ||
        changed;
    changed = _mergeOverrideExtras(
          catalog,
          StaffRoles.humanResource,
          const {
            SchoolPermissions.accessSupport,
            SchoolPermissions.messageParents,
            SchoolPermissions.viewTransport,
            SchoolPermissions.manageBuses,
            SchoolPermissions.manageDrivers,
            SchoolPermissions.assignStudentTransport,
            SchoolPermissions.viewStudents,
            SchoolPermissions.viewAllSchoolData,
          },
        ) ||
        changed;
    changed = _mergeOverrideExtras(
          catalog,
          StaffRoles.sectionDirector,
          const {
            SchoolPermissions.accessSupport,
            SchoolPermissions.messageParents,
            SchoolPermissions.viewTransport,
            SchoolPermissions.assignStudentTransport,
            SchoolPermissions.manageParentLinks,
            SchoolPermissions.viewAllGrades,
            SchoolPermissions.viewAllSchoolData,
            SchoolPermissions.approveGrades,
          },
        ) ||
        changed;
    changed = _mergeOverrideExtras(
          catalog,
          StaffRoles.principal,
          const {SchoolPermissions.viewAllSchoolData},
        ) ||
        changed;
    changed = _mergeOverrideExtras(
          catalog,
          StaffRoles.studentAffairs,
          const {SchoolPermissions.viewAllSchoolData},
        ) ||
        changed;
    changed = _mergeOverrideExtras(
          catalog,
          StaffRoles.registrar,
          const {SchoolPermissions.viewAllSchoolData},
        ) ||
        changed;
    changed = _mergeOverrideExtras(
          catalog,
          StaffRoles.accountant,
          const {SchoolPermissions.viewAllSchoolData},
        ) ||
        changed;
    changed = _mergeOverrideExtras(
          catalog,
          StaffRoles.transportAdmin,
          const {SchoolPermissions.viewAllSchoolData},
        ) ||
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

  Future<String?> saveRoleModules({
    required String roleKey,
    required Set<String> permissions,
    String? schoolId,
  }) async {
    if (AuthService.currentUser?.roleKey != AuthService.roleAdmin) {
      return 'not_allowed';
    }
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
      catalog.customRoles[existing] =
          catalog.customRoles[existing].copyWith(permissions: next);
    }
    final cloudErr = await _persist(sid, catalog);
    await SchoolAuditLogService.instance.log(
      action: 'staff_role_modules_updated',
      schoolId: sid,
      entityType: 'staff_role',
      entityId: key,
      detail: 'Updated modules/permissions for $key',
      after: {'permissions': next.toList()..sort()},
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

  Future<String?> deleteCustomRole(String roleKey, {String? schoolId}) async {
    if (AuthService.currentUser?.roleKey != AuthService.roleAdmin) {
      return 'not_allowed';
    }
    final sid = (schoolId ?? _activeSchoolId ?? '').trim();
    if (sid.isEmpty) return 'no_school';
    final key = roleKey.trim().toLowerCase();
    if (!key.startsWith('custom_')) return 'not_custom';

    await ensureLoaded(sid);
    final catalog = _bySchool[sid];
    if (catalog == null) return 'unknown_role';
    final before = catalog.customRoles.length;
    catalog.customRoles.removeWhere((r) => r.key == key);
    if (catalog.customRoles.length == before) return 'unknown_role';
    return _persist(sid, catalog);
  }

  StaffRole _applyOverride(StaffRole base, _SchoolRoleCatalog? catalog) {
    final override = catalog?.overrides[base.key];
    if (override == null) return base;
    return base.copyWith(permissions: StaffDashboardModules.withBaseline(override));
  }

  Future<void> _load(String sid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefsPrefix$sid');
      if (raw != null && raw.isNotEmpty) {
        _bySchool[sid] = _SchoolRoleCatalog.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SchoolRoleCatalogService prefs load: $e');
    }

    if (_crud.available) {
      try {
        final data = await _crud.readDoc(collection: _collection, docId: sid);
        if (data != null) {
          _bySchool[sid] = _SchoolRoleCatalog.fromJson(data);
          await _savePrefs(sid, _bySchool[sid]!);
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('SchoolRoleCatalogService cloud load: $e');
      }
    }
    _bySchool[sid] = _SchoolRoleCatalog();
  }

  Future<String?> _persist(String sid, _SchoolRoleCatalog catalog) async {
    await _savePrefs(sid, catalog);
    if (!_crud.available) return null;
    try {
      await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
      try {
        await SupabaseBootstrap.client.auth.refreshSession();
      } catch (_) {}
      if (!await SupabaseBootstrap.ensureAnonymousAuthReady()) {
        return 'cloud_session';
      }
      // Use the JWT school id exactly — RLS compares case-sensitively.
      final jwtSchool = (SupabaseBootstrap.client.auth.currentUser
                  ?.appMetadata['schoolId'] as String?)
              ?.trim() ??
          sid;
      final docId =
          jwtSchool.toUpperCase() == sid.toUpperCase() ? jwtSchool : sid;
      await _crud.createOrUpdate(
        collection: _collection,
        docId: docId,
        data: {
          ...catalog.toJson(),
          'schoolId': jwtSchool,
        },
      );
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('SchoolRoleCatalogService cloud save: $e');
      return 'cloud_failed';
    }
  }

  Future<void> _savePrefs(String sid, _SchoolRoleCatalog catalog) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefsPrefix$sid', jsonEncode(catalog.toJson()));
    } catch (_) {}
  }
}

class _SchoolRoleCatalog {
  _SchoolRoleCatalog({
    Map<String, Set<String>>? overrides,
    List<StaffRole>? customRoles,
  })  : overrides = overrides ?? {},
        customRoles = customRoles ?? [];

  final Map<String, Set<String>> overrides;
  final List<StaffRole> customRoles;

  Map<String, dynamic> toJson() => {
        'overrides': {
          for (final e in overrides.entries)
            e.key: e.value.toList()..sort(),
        },
        'customRoles': [
          for (final r in customRoles)
            {
              'key': r.key,
              'labelEn': r.labelEn,
              'labelAm': r.labelAm,
              'labelOm': r.labelOm,
              'permissions': r.permissions.toList()..sort(),
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
          if (perms is List) for (final p in perms) p.toString(),
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
        custom.add(
          StaffRole(
            key: key,
            labelEn: label,
            labelAm: (map['labelAm'] as String?)?.trim() ?? label,
            labelOm: (map['labelOm'] as String?)?.trim() ?? label,
            permissions: StaffDashboardModules.withBaseline(perms),
            builtIn: false,
          ),
        );
      }
    }
    return _SchoolRoleCatalog(overrides: overrides, customRoles: custom);
  }
}
