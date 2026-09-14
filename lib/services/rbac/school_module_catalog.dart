import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_id_aliases.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_items.dart';
import 'package:mayabela/web_erp/models/web_erp_nav_item.dart';

/// Per-school module pack: which ERP modules this school is allowed to use.
///
/// Role permissions still apply inside an enabled module. A missing or null
/// pack means every module is on (backward compatible). Dashboard, profile,
/// settings, and logout cannot be turned off.
abstract final class SchoolModuleCatalog {
  static const Set<String> alwaysOnModuleIds = {
    'dashboard',
    'profile',
    'settings',
    'logout',
  };

  /// Mobile dashboard tiles whose ids are not ERP nav ids.
  static const Map<String, String> dashboardTileToModule = {
    'fees': 'finance',
    'bus': 'transport',
    'buses': 'transport_buses',
    'staff': 'hr',
    'classes': 'academic',
    'staff_classes': 'academic',
    'staff_students': 'students',
    'staff_directory': 'hr',
    'staff_attendance': 'attendance',
    'staff_parent_approvals': 'parents',
    'staff_student_affairs': 'student_affairs',
    'staff_student_support': 'student_support',
    'staff_safeguarding': 'safeguarding',
    'staff_student_programs': 'student_programs',
    'staff_qa': 'quality_assurance',
    'staff_grades': 'examinations',
    'staff_grade_approvals': 'examinations',
    'staff_transport': 'transport',
    'staff_buses': 'transport_buses',
    'staff_transfers': 'transfers',
    'staff_finance': 'finance',
    'staff_campus': 'campus',
    'staff_inventory': 'inventory',
    'staff_library': 'library',
    'staff_learning_materials': 'learning_materials',
    'staff_announcements': 'announcements',
    'staff_reports': 'reports',
    'staff_audit_log': 'audit_log',
    'staff_go_live': 'go_live',
    'staff_digital_ops': 'digital_ops',
    'staff_cctv': 'cctv',
    'learning_materials_admin': 'learning_materials',
    'transfer': 'transfers',
    'messages': 'support',
    'grades': 'examinations',
    'exams': 'examinations',
    'parent_approvals': 'parents',
    'feedback': 'quality_assurance',
    'passengers': 'transport',
    'scan': 'transport',
    'pickup': 'transport',
    'map': 'transport',
    'route': 'transport',
    'issue': 'support',
  };

  static List<WebErpNavItem> togglableNavItems() {
    return webErpAllNavItems
        .where(
          (item) =>
              !item.isLogout && !alwaysOnModuleIds.contains(item.id),
        )
        .toList(growable: false);
  }

  static Set<String> togglableNavIds() =>
      togglableNavItems().map((item) => item.id).toSet();

  /// Persist `null` when every togglable module is on so later modules stay on.
  static Set<String>? packForPersistence(Set<String> enabledNavIds) {
    final all = togglableNavIds();
    if (enabledNavIds.length >= all.length && all.every(enabledNavIds.contains)) {
      return null;
    }
    return enabledNavIds.intersection(all);
  }

  static bool isEnabled(String moduleId) {
    final school = SchoolRegistryService.instance.lookup(
      AuthService.activeSchoolId,
    );
    return isEnabledFor(school?.enabledModules, moduleId);
  }

  /// [enabledModules] is the set of nav item ids the owner turned on.
  /// `null` means the school has no custom pack (everything on).
  static bool isEnabledFor(Set<String>? enabledModules, String moduleId) {
    final raw = moduleId.trim();
    if (raw.isEmpty) return true;
    if (alwaysOnModuleIds.contains(raw)) return true;

    final mapped = dashboardTileToModule[raw] ?? raw;
    if (alwaysOnModuleIds.contains(mapped)) return true;
    if (enabledModules == null) return true;

    if (enabledModules.contains(raw) || enabledModules.contains(mapped)) {
      return true;
    }

    final packaged = webErpAllNavItems.map((item) => item.id).toSet();
    if (packaged.contains(raw) || packaged.contains(mapped)) {
      return false;
    }

    final parent = normalizeModuleId(mapped);
    if (alwaysOnModuleIds.contains(parent)) return true;
    if (enabledModules.contains(parent)) return true;
    if (packaged.contains(parent)) return false;

    // Unknown chrome (parent "children", teacher QR, driver scan extras).
    return true;
  }
}
