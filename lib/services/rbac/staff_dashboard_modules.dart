import 'package:mayabela/services/rbac/staff_permissions.dart';

/// Dashboard / ERP features the school owner can tick per staff role.
///
/// Checking a module grants its [permissions]. Always-on modules are forced
/// onto every non–Full Access role so staff can report, communicate, and
/// manage their profile without extra grants.
class StaffDashboardModule {
  const StaffDashboardModule({
    required this.id,
    required this.labelEn,
    required this.permissions,
    this.alwaysOn = false,
    this.ownerOnly = false,
  });

  final String id;
  final String labelEn;
  final Set<String> permissions;

  /// Included for every staff role; cannot be unchecked in the role editor.
  final bool alwaysOn;

  /// Only the school owner account may use this module (not staff roles).
  final bool ownerOnly;
}

/// Catalog of assignable dashboard features (matches web ERP nav where possible).
abstract final class StaffDashboardModules {
  static const sharedBaseline = <String>{
    'profile',
    'logout',
    'dashboard',
    'settings',
  };

  static final List<StaffDashboardModule> all = [
    const StaffDashboardModule(
      id: 'dashboard',
      labelEn: 'Dashboard',
      permissions: {},
    ),
    const StaffDashboardModule(
      id: 'institution',
      labelEn: 'Institution Management',
      permissions: {},
      ownerOnly: true,
    ),
    const StaffDashboardModule(
      id: 'school',
      labelEn: 'School Management',
      permissions: {SchoolPermissions.manageSchoolSettings},
    ),
    const StaffDashboardModule(
      id: 'campus',
      labelEn: 'Campus Management',
      permissions: {SchoolPermissions.manageCampuses},
    ),
    const StaffDashboardModule(
      id: 'academic',
      labelEn: 'Academic Management',
      permissions: {
        SchoolPermissions.manageClasses,
        SchoolPermissions.manageSubjects,
        SchoolPermissions.assignTeachers,
        SchoolPermissions.manageTimetables,
      },
    ),
    const StaffDashboardModule(
      id: 'students',
      labelEn: 'Students',
      permissions: {
        SchoolPermissions.viewStudents,
        SchoolPermissions.manageStudents,
      },
    ),
    const StaffDashboardModule(
      id: 'school_wide_data',
      labelEn: 'See all school student data',
      permissions: {SchoolPermissions.viewAllSchoolData},
    ),
    const StaffDashboardModule(
      id: 'transfers',
      labelEn: 'Transfers',
      permissions: {
        SchoolPermissions.viewStudents,
        SchoolPermissions.createTransfers,
        SchoolPermissions.approveTransfers,
        SchoolPermissions.promoteStudents,
      },
    ),
    const StaffDashboardModule(
      id: 'parents',
      labelEn: 'Parents',
      permissions: {SchoolPermissions.manageParentLinks},
    ),
    const StaffDashboardModule(
      id: 'hr',
      labelEn: 'Human Resource',
      permissions: {
        SchoolPermissions.viewStaff,
        SchoolPermissions.manageStaffAccounts,
        SchoolPermissions.viewTransport,
        SchoolPermissions.manageBuses,
        SchoolPermissions.manageDrivers,
        SchoolPermissions.assignStudentTransport,
        SchoolPermissions.viewStudents,
      },
    ),
    const StaffDashboardModule(
      id: 'teachers',
      labelEn: 'Administration Staff Directory',
      permissions: {
        SchoolPermissions.viewStaff,
        SchoolPermissions.assignRoles,
      },
      ownerOnly: true,
    ),
    const StaffDashboardModule(
      id: 'finance',
      labelEn: 'Finance',
      permissions: {
        SchoolPermissions.manageFees,
        SchoolPermissions.recordPayments,
        SchoolPermissions.viewFinanceReports,
        SchoolPermissions.viewStudents,
      },
    ),
    const StaffDashboardModule(
      id: 'transport',
      labelEn: 'Transport',
      permissions: {
        SchoolPermissions.manageBuses,
        SchoolPermissions.manageDrivers,
        SchoolPermissions.assignStudentTransport,
        SchoolPermissions.viewTransport,
        SchoolPermissions.viewStudents,
      },
    ),
    const StaffDashboardModule(
      id: 'attendance',
      labelEn: 'Attendance',
      permissions: {
        SchoolPermissions.viewStudents,
        SchoolPermissions.manageStudents,
      },
    ),
    const StaffDashboardModule(
      id: 'examinations',
      labelEn: 'Examinations',
      permissions: {
        SchoolPermissions.viewAllGrades,
        SchoolPermissions.approveGrades,
      },
    ),
    const StaffDashboardModule(
      id: 'library',
      labelEn: 'Library',
      permissions: {SchoolPermissions.manageLearningMaterials},
    ),
    const StaffDashboardModule(
      id: 'learning_materials',
      labelEn: 'e-Book and Material',
      permissions: {
        SchoolPermissions.manageLearningMaterials,
        SchoolPermissions.manageMaterialAccess,
      },
    ),
    const StaffDashboardModule(
      id: 'inventory',
      labelEn: 'Inventory / Procurement / Store',
      permissions: {
        SchoolPermissions.viewInventory,
        SchoolPermissions.createPurchaseRequests,
        SchoolPermissions.approvePurchaseRequests,
        SchoolPermissions.manageSuppliers,
        SchoolPermissions.enterPurchasedItems,
        SchoolPermissions.approveIssueRequests,
        SchoolPermissions.receiveStock,
        SchoolPermissions.issueStock,
        SchoolPermissions.adjustStock,
        SchoolPermissions.createIssueRequests,
      },
    ),
    const StaffDashboardModule(
      id: 'announcements',
      labelEn: 'Announcements',
      permissions: {SchoolPermissions.sendAnnouncements},
    ),
    const StaffDashboardModule(
      id: 'events',
      labelEn: 'Events',
      permissions: {SchoolPermissions.sendAnnouncements},
    ),
    const StaffDashboardModule(
      id: 'calendar',
      labelEn: 'Calendar',
      permissions: {
        SchoolPermissions.sendAnnouncements,
        SchoolPermissions.manageTimetables,
      },
    ),
    const StaffDashboardModule(
      id: 'reports',
      labelEn: 'Reports & Analytics',
      permissions: {SchoolPermissions.viewReports},
    ),
    const StaffDashboardModule(
      id: 'support',
      labelEn: 'Messages',
      permissions: {SchoolPermissions.accessSupport},
    ),
    const StaffDashboardModule(
      id: 'maya_assistant',
      labelEn: 'Maya Assistant',
      permissions: {},
    ),
    const StaffDashboardModule(
      id: 'audit_log',
      labelEn: 'Audit Log',
      permissions: {SchoolPermissions.viewAuditLog},
    ),
    const StaffDashboardModule(
      id: 'system_health',
      labelEn: 'System Health',
      permissions: {SchoolPermissions.viewSystemHealth},
    ),
    const StaffDashboardModule(
      id: 'settings',
      labelEn: 'Settings',
      permissions: {},
    ),
    const StaffDashboardModule(
      id: 'profile',
      labelEn: 'Profile',
      permissions: {},
    ),
    const StaffDashboardModule(
      id: 'logout',
      labelEn: 'Logout',
      permissions: {},
    ),
  ];

  static final Map<String, StaffDashboardModule> byId = {
    for (final m in all) m.id: m,
  };

  static Set<String> alwaysOnPermissions() {
    final out = <String>{};
    for (final m in all) {
      if (m.alwaysOn) out.addAll(m.permissions);
    }
    return out;
  }

  /// Modules an owner may tick when editing a role (excludes owner-only).
  static List<StaffDashboardModule> configurableModules() =>
      all.where((m) => !m.ownerOnly).toList();

  /// Whether [permissions] imply the module should show as checked.
  static bool isModuleEnabled(String moduleId, Set<String> permissions) {
    final m = byId[moduleId];
    if (m == null) return false;
    if (m.alwaysOn) return true;
    if (m.permissions.isEmpty) return false;
    return m.permissions.any(permissions.contains);
  }

  /// Apply checkbox toggle: add or remove that module's permission bundle.
  static Set<String> toggleModule({
    required Set<String> current,
    required String moduleId,
    required bool enabled,
  }) {
    final m = byId[moduleId];
    if (m == null || m.alwaysOn || m.ownerOnly) {
      return {...current, ...alwaysOnPermissions()};
    }
    final next = Set<String>.from(current);
    if (enabled) {
      next.addAll(m.permissions);
    } else {
      next.removeAll(m.permissions);
    }
    next.addAll(alwaysOnPermissions());
    return next;
  }

  static Set<String> withBaseline(Set<String> permissions) =>
      {...permissions, ...alwaysOnPermissions()};
}
