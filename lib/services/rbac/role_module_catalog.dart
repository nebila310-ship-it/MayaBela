import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/module_right.dart';
import 'package:mayabela/services/rbac/staff_dashboard_modules.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_items.dart';

/// One ERP module or sub-module the school owner can grant per staff role.
class RoleModuleSpec {
  const RoleModuleSpec({
    required this.id,
    required this.label,
    required this.section,
    this.alwaysOn = false,
    this.ownerOnly = false,
    this.lockedRight,
  });

  final String id;
  final String label;
  final String section;

  /// Forced onto every staff role (Messages, dashboard chrome, …).
  final bool alwaysOn;

  /// School-owner console only; staff roles cannot receive this desk.
  final bool ownerOnly;

  /// When set, the role editor cannot change this module's right.
  final ModuleRight? lockedRight;

  bool get configurable => !alwaysOn && !ownerOnly && lockedRight == null;
}

/// Full ERP module / sub-module catalog for the role-permission editor.
///
/// Sidebar ids stay distinct so an owner can grant Weighted Markbook without
/// Examinations, or Buses without the rest of Transport.
abstract final class RoleModuleCatalog {
  static const _alwaysOnIds = {
    'dashboard',
    'profile',
    'settings',
    'logout',
    'support',
    'messages',
  };

  static const _ownerOnlyIds = {
    'institution',
    'staff_roles',
  };

  static const _preserveIfPresent = {
    SchoolPermissions.messageParents,
    SchoolPermissions.viewAllDepartments,
  };

  static ModuleRight? _lockedRight(String id) {
    switch (id) {
      case 'dashboard':
        return ModuleRight.read;
      case 'profile':
      case 'settings':
      case 'logout':
      case 'support':
      case 'messages':
        return ModuleRight.edit;
      default:
        return null;
    }
  }

  static final List<RoleModuleSpec> items = [
    for (final nav in webErpAllNavItems)
      if (!nav.isLogout)
        RoleModuleSpec(
          id: nav.id,
          label: nav.label,
          section: (nav.section == null || nav.section!.isEmpty)
              ? 'General'
              : nav.section!,
          alwaysOn: _alwaysOnIds.contains(nav.id),
          ownerOnly: _ownerOnlyIds.contains(nav.id),
          lockedRight: _lockedRight(nav.id),
        ),
    const RoleModuleSpec(
      id: 'school_wide_data',
      label: 'See all school student data',
      section: 'Student Services',
    ),
  ];

  static final Map<String, RoleModuleSpec> byId = {
    for (final spec in items) spec.id: spec,
  };

  static List<RoleModuleSpec> get configurableItems =>
      items.where((spec) => spec.configurable).toList(growable: false);

  /// Sidebar sections in catalog order, plus any extra grants.
  static List<String> get sections {
    final out = <String>[];
    for (final spec in items) {
      if (!out.contains(spec.section)) out.add(spec.section);
    }
    return out;
  }

  static List<RoleModuleSpec> itemsInSection(String section) =>
      items.where((spec) => spec.section == section).toList(growable: false);

  /// EDUABA defaults (or permission-inferred rights) for a role that has not
  /// been customized yet.
  static Map<String, ModuleRight> defaultsForRole(StaffRole role) {
    final out = <String, ModuleRight>{};
    for (final spec in items) {
      out[spec.id] = defaultRightFor(spec, role);
    }
    return out;
  }

  static ModuleRight defaultRightFor(RoleModuleSpec spec, StaffRole role) {
    if (spec.lockedRight != null) return spec.lockedRight!;
    if (spec.ownerOnly || role.ownerOnly) return ModuleRight.none;
    if (spec.id == 'school_wide_data') {
      return role.permissions.contains(SchoolPermissions.viewAllSchoolData)
          ? ModuleRight.edit
          : ModuleRight.none;
    }
    return ModuleAccess.matrixRightForRole(
      role.key,
      spec.id,
      permissions: role.permissions,
    );
  }

  /// Fill every catalog id. Saved maps win; missing keys stay off except
  /// locked chrome.
  static Map<String, ModuleRight> hydrate(
    Map<String, ModuleRight>? stored, {
    required StaffRole role,
  }) {
    if (stored == null) return defaultsForRole(role);
    final out = <String, ModuleRight>{};
    for (final spec in items) {
      out[spec.id] = stored[spec.id] ??
          spec.lockedRight ??
          (spec.alwaysOn ? ModuleRight.edit : ModuleRight.none);
    }
    return out;
  }

  static SectionRight sectionSummary(
    String section,
    Map<String, ModuleRight> rights,
  ) {
    final children = itemsInSection(section).where((spec) => spec.configurable);
    return SectionRight.fromChildren(
      children.map((spec) => rights[spec.id] ?? ModuleRight.none),
    );
  }

  static Map<String, ModuleRight> applySectionRight({
    required Map<String, ModuleRight> current,
    required String section,
    required ModuleRight right,
  }) {
    final next = Map<String, ModuleRight>.from(current);
    for (final spec in itemsInSection(section)) {
      if (!spec.configurable) continue;
      next[spec.id] = right;
    }
    return next;
  }

  static Map<String, ModuleRight> applyAllConfigurable(
    Map<String, ModuleRight> current,
    ModuleRight right,
  ) {
    final next = Map<String, ModuleRight>.from(current);
    for (final spec in items) {
      if (!spec.configurable) continue;
      next[spec.id] = right;
    }
    return next;
  }

  /// JWT / RLS permission keys implied by the module-right map.
  static Set<String> permissionsFor(
    Map<String, ModuleRight> rights, {
    Set<String>? previous,
  }) {
    final derived = <String>{};
    for (final entry in rights.entries) {
      derived.addAll(_permissionsForModule(entry.key, entry.value));
    }
    final out = StaffDashboardModules.withBaseline(derived);
    if (previous != null) {
      for (final perm in _preserveIfPresent) {
        if (previous.contains(perm)) out.add(perm);
      }
    }
    return out;
  }

  static Set<String> _permissionsForModule(String moduleId, ModuleRight right) {
    if (right == ModuleRight.none) return const {};
    if (moduleId == 'school_wide_data') {
      return {SchoolPermissions.viewAllSchoolData};
    }
    final rule = ModuleAccess.ruleFor(moduleId);
    if (rule == null) return const {};
    final out = <String>{...rule.view};
    if (right == ModuleRight.edit) out.addAll(rule.manage);
    return out;
  }
}
