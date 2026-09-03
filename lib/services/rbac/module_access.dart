import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';

/// Per-module access rule used by the shared ERP sidebar/router (web and APK).
/// Module ids match the ERP route ids.
class ModuleRule {
  const ModuleRule({
    this.view = const [],
    this.manage = const [],
    this.departmental = true,
    this.adminOnly = false,
    this.open = false,
  });

  /// Holding any of these permissions makes the module visible.
  final List<String> view;

  /// Holding any of these permissions allows mutations inside the module.
  /// The school owner (admin) can always manage.
  final List<String> manage;

  /// Departmental modules are visible (read-only) to holders of
  /// `view_all_departments` (e.g. the Vice President).
  final bool departmental;

  /// Only the school owner sees this module (system/owner console pages).
  final bool adminOnly;

  /// Visible to everyone who can enter the shell (dashboard, profile, ...).
  final bool open;
}

/// Explicit per-module role allocation (EDUABA dashboard matrix).
///
/// When a module has an allocation, ONLY the listed staff roles see it —
/// permissions and departmental oversight no longer grant visibility. The
/// school owner (admin) and Full Access delegates always bypass allocations.
class ModuleRoleAllocation {
  const ModuleRoleAllocation({required this.visibleTo, this.manageBy});

  /// Canonical staff role keys that see this module on their dashboard.
  final Set<String> visibleTo;

  /// Roles allowed to mutate. Null falls back to permission-based manage;
  /// roles in [visibleTo] but not here get the module read-only.
  final Set<String>? manageBy;
}

/// Single source of truth mapping ERP modules to the RBAC permission catalog.
///
/// `canView` decides whether a module appears in the sidebar / dashboard and
/// whether its route may be opened; `canManage` decides whether the module's
/// mutating actions are enabled (VP-style observers get read-only views).
abstract final class ModuleAccess {
  static const Map<String, ModuleRule> rules = {
    'dashboard': ModuleRule(open: true),
    'profile': ModuleRule(open: true),
    'logout': ModuleRule(open: true),
    'maya_assistant': ModuleRule(open: true),

    // Organization
    'institution': ModuleRule(adminOnly: true),
    'school': ModuleRule(
      view: [SchoolPermissions.manageSchoolSettings],
      manage: [SchoolPermissions.manageSchoolSettings],
      departmental: false,
    ),
    'campus': ModuleRule(
      view: [SchoolPermissions.manageCampuses],
      manage: [SchoolPermissions.manageCampuses],
    ),
    'cctv': ModuleRule(
      view: [SchoolPermissions.manageSchoolSettings],
      manage: [SchoolPermissions.manageSchoolSettings],
      departmental: false,
    ),

    // Academics
    'academic': ModuleRule(
      view: [
        SchoolPermissions.manageClasses,
        SchoolPermissions.manageSubjects,
        SchoolPermissions.assignTeachers,
        SchoolPermissions.manageTimetables,
      ],
      manage: [
        SchoolPermissions.manageClasses,
        SchoolPermissions.manageSubjects,
        SchoolPermissions.assignTeachers,
        SchoolPermissions.manageTimetables,
      ],
    ),
    'examinations': ModuleRule(
      view: [SchoolPermissions.viewAllGrades],
      manage: [SchoolPermissions.approveGrades],
    ),

    // People
    'students': ModuleRule(
      view: [SchoolPermissions.viewStudents],
      manage: [SchoolPermissions.manageStudents],
    ),
    'admissions': ModuleRule(
      view: [SchoolPermissions.viewStudents],
      manage: [SchoolPermissions.manageStudents],
    ),
    'alumni': ModuleRule(
      view: [SchoolPermissions.viewStudents],
      manage: [SchoolPermissions.manageStudents],
    ),
    'transfers': ModuleRule(
      view: [
        SchoolPermissions.createTransfers,
        SchoolPermissions.approveTransfers,
        SchoolPermissions.promoteStudents,
        SchoolPermissions.viewStudents,
      ],
      manage: [
        SchoolPermissions.createTransfers,
        SchoolPermissions.approveTransfers,
        SchoolPermissions.promoteStudents,
      ],
    ),
    'parents': ModuleRule(
      view: [SchoolPermissions.manageParentLinks],
      manage: [SchoolPermissions.manageParentLinks],
    ),
    // EDUABA Student Affairs: discipline cases + leave requests.
    'student_affairs': ModuleRule(
      view: [SchoolPermissions.viewStudents],
      manage: [SchoolPermissions.manageStudents],
    ),
    // Owner ERP accounts (VP, Student Affairs, HR itself, …).
    'teachers': ModuleRule(
      view: [
        SchoolPermissions.viewStaff,
        SchoolPermissions.assignRoles,
      ],
      manage: [SchoolPermissions.assignRoles],
    ),
    // Classroom teachers directory (VP / HR / Section Director).
    'classroom_teachers': ModuleRule(
      view: [SchoolPermissions.viewStaff],
      manage: [
        SchoolPermissions.manageStaffAccounts,
        SchoolPermissions.assignTeachers,
      ],
    ),
    // Human Resource hub: teachers + record-only staff + transport.
    'hr': ModuleRule(
      view: [
        SchoolPermissions.viewStaff,
        SchoolPermissions.viewTransport,
        SchoolPermissions.manageStaffAccounts,
      ],
      manage: [
        SchoolPermissions.manageStaffAccounts,
        SchoolPermissions.manageBuses,
        SchoolPermissions.manageDrivers,
      ],
    ),
    // Operations
    'finance': ModuleRule(
      view: [SchoolPermissions.viewFinanceReports],
      manage: [
        SchoolPermissions.manageFees,
        SchoolPermissions.recordPayments,
      ],
    ),
    'transport': ModuleRule(
      view: [SchoolPermissions.viewTransport],
      manage: [
        SchoolPermissions.manageBuses,
        SchoolPermissions.manageDrivers,
        SchoolPermissions.assignStudentTransport,
      ],
    ),
    'attendance': ModuleRule(
      view: [SchoolPermissions.viewStudents],
      manage: [SchoolPermissions.manageStudents],
    ),

    // Resources
    'library': ModuleRule(
      view: [SchoolPermissions.manageLearningMaterials],
      manage: [SchoolPermissions.manageLearningMaterials],
    ),
    'learning_materials': ModuleRule(
      view: [
        SchoolPermissions.manageLearningMaterials,
        SchoolPermissions.manageMaterialAccess,
      ],
      manage: [
        SchoolPermissions.manageLearningMaterials,
        SchoolPermissions.manageMaterialAccess,
      ],
    ),
    'inventory': ModuleRule(
      view: [SchoolPermissions.viewInventory],
      manage: [
        SchoolPermissions.receiveStock,
        SchoolPermissions.issueStock,
        SchoolPermissions.adjustStock,
        SchoolPermissions.createIssueRequests,
        SchoolPermissions.enterPurchasedItems,
        SchoolPermissions.manageSuppliers,
        SchoolPermissions.createPurchaseRequests,
        SchoolPermissions.approvePurchaseRequests,
        SchoolPermissions.approveIssueRequests,
      ],
    ),

    // Communication
    'announcements': ModuleRule(
      view: [SchoolPermissions.sendAnnouncements],
      manage: [SchoolPermissions.sendAnnouncements],
    ),
    'events': ModuleRule(
      view: [SchoolPermissions.sendAnnouncements],
      manage: [SchoolPermissions.sendAnnouncements],
    ),
    'calendar': ModuleRule(
      view: [
        SchoolPermissions.sendAnnouncements,
        SchoolPermissions.manageTimetables,
      ],
      manage: [SchoolPermissions.sendAnnouncements],
    ),

    // Insights & system
    // EDUABA §2: QA logs findings & improvement plans; GM/DGM/VP/Board read
    // the register via view_all_departments (departmental: true).
    'quality_assurance': ModuleRule(
      view: [SchoolPermissions.manageQaFindings],
      manage: [SchoolPermissions.manageQaFindings],
    ),
    'reports': ModuleRule(
      view: [SchoolPermissions.viewReports],
      departmental: false,
    ),
    'audit_log': ModuleRule(
      view: [SchoolPermissions.viewAuditLog],
      manage: [],
      departmental: false,
    ),
    'support': ModuleRule(
      view: [SchoolPermissions.accessSupport],
      manage: [SchoolPermissions.accessSupport],
      departmental: false,
    ),
    'system_health': ModuleRule(
      view: [SchoolPermissions.viewSystemHealth],
      manage: [],
      departmental: false,
    ),
    // School owner configures role → module checkboxes.
    'staff_roles': ModuleRule(adminOnly: true),
    // Personal app settings (language, security, appearance) — shared screen,
    // available to everyone in the shell. School-level settings are gated
    // separately via manage_school_settings inside their own pages.
    'settings': ModuleRule(open: true),
  };

  /// Route ids that reuse another module's rule.
  static const Map<String, String> _aliases = {
    'staff': 'hr',
    'employees': 'hr',
    'add_teacher': 'hr',
    'add_staff': 'teachers',
    'grades': 'examinations',
    'grade_approvals': 'examinations',
    'transport_buses': 'transport',
    'transport_live_gps': 'transport',
    'add_driver': 'transport',
    'add_student': 'students',
    'timetable': 'academic',
    'student_portal_settings': 'school',
    'student_password_resets': 'students',
    'grade_workflow_settings': 'examinations',
    'markbook': 'examinations',
    'report_cards': 'examinations',
    'exam_bank': 'examinations',
    'exam_papers': 'examinations',
    'exam_desk': 'examinations',
  };

  /// Every built-in staff role (used for "wire with all roles" modules).
  static const Set<String> _everyStaffRole = {
    StaffRoles.schoolBoard,
    StaffRoles.generalManager,
    StaffRoles.deputyGeneralManager,
    StaffRoles.principal,
    StaffRoles.vicePresident,
    StaffRoles.qualityAssurance,
    StaffRoles.sectionDirector,
    StaffRoles.studentAffairs,
    StaffRoles.registrar,
    StaffRoles.accountant,
    StaffRoles.humanResource,
    StaffRoles.librarian,
    StaffRoles.procurement,
    StaffRoles.storekeeper,
    StaffRoles.transportAdmin,
    StaffRoles.staffs,
  };

  /// Executive oversight — read-only on operational modules (not in manageBy).
  static const Set<String> _executiveOversight = {
    StaffRoles.schoolBoard,
    StaffRoles.generalManager,
    StaffRoles.deputyGeneralManager,
    StaffRoles.principal,
  };

  /// EDUABA dashboard allocation — each role's login dashboard shows ONLY the
  /// modules allocated to it here (owner / Full Access see everything).
  ///
  /// 1 AI assistant → everyone (staff chrome). 2 Examinations → VP + Section
  /// Director. 3 Academic management → VP + SD. 4 Students → Registrar
  /// (enroll) + SD (assign), VP + Student Affairs read-only. 5 Transfers →
  /// SD requests, VP approves. 6 HR & admin directory → VP + HR.
  /// 7 Classroom teachers → VP + HR + SD. 8 Finance → Finance Manager + VP.
  /// 9 Transport & buses → VP + HR (+ Transport Head, the unit operator).
  /// 10 Attendance → VP + SD, QA read-only. 11 Parent link approvals → VP +
  /// SD (+ homeroom teachers on their own dashboard). 12 Inventory →
  /// Procurement + VP (+ Store Keeper, the counter side). 13–14 Library &
  /// e-books → VP + SD (+ Librarian); teachers/students/parents use their
  /// own dashboard tiles. 15 Announcements → all roles. 16 Events & calendar
  /// → SD (staff side). 17 QA findings → QA + VP. 18 Messages → all roles.
  /// 19–20 Settings & profile → everyone (open chrome).
  static const Map<String, ModuleRoleAllocation> roleAllocations = {
    'examinations': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.vicePresident,
        StaffRoles.sectionDirector,
        ..._executiveOversight,
      },
      manageBy: {StaffRoles.vicePresident, StaffRoles.sectionDirector},
    ),
    'academic': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.vicePresident,
        StaffRoles.sectionDirector,
        ..._executiveOversight,
      },
      manageBy: {StaffRoles.vicePresident, StaffRoles.sectionDirector},
    ),
    'students': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.registrar,
        StaffRoles.sectionDirector,
        StaffRoles.vicePresident,
        StaffRoles.studentAffairs,
        ..._executiveOversight,
      },
      manageBy: {StaffRoles.registrar, StaffRoles.sectionDirector},
    ),
    'admissions': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.registrar,
        StaffRoles.sectionDirector,
        StaffRoles.vicePresident,
        StaffRoles.studentAffairs,
        ..._executiveOversight,
      },
      manageBy: {
        StaffRoles.registrar,
        StaffRoles.sectionDirector,
        StaffRoles.vicePresident,
      },
    ),
    'alumni': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.registrar,
        StaffRoles.sectionDirector,
        StaffRoles.vicePresident,
        StaffRoles.studentAffairs,
        ..._executiveOversight,
      },
      manageBy: {StaffRoles.registrar},
    ),
    'student_affairs': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.studentAffairs,
        StaffRoles.vicePresident,
        ..._executiveOversight,
      },
      manageBy: {StaffRoles.studentAffairs, StaffRoles.vicePresident},
    ),
    'transfers': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.vicePresident,
        StaffRoles.sectionDirector,
        ..._executiveOversight,
      },
      manageBy: {StaffRoles.vicePresident, StaffRoles.sectionDirector},
    ),
    'hr': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.vicePresident,
        StaffRoles.humanResource,
        ..._executiveOversight,
      },
      manageBy: {StaffRoles.vicePresident, StaffRoles.humanResource},
    ),
    'teachers': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.vicePresident,
        StaffRoles.humanResource,
        ..._executiveOversight,
      },
      manageBy: {StaffRoles.vicePresident, StaffRoles.humanResource},
    ),
    'classroom_teachers': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.vicePresident,
        StaffRoles.humanResource,
        StaffRoles.sectionDirector,
        ..._executiveOversight,
      },
      manageBy: {
        StaffRoles.vicePresident,
        StaffRoles.humanResource,
        StaffRoles.sectionDirector,
      },
    ),
    'finance': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.accountant,
        StaffRoles.vicePresident,
        ..._executiveOversight,
      },
      manageBy: {StaffRoles.accountant, StaffRoles.vicePresident},
    ),
    'transport': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.vicePresident,
        StaffRoles.humanResource,
        StaffRoles.transportAdmin,
        ..._executiveOversight,
      },
      manageBy: {
        StaffRoles.vicePresident,
        StaffRoles.humanResource,
        StaffRoles.transportAdmin,
      },
    ),
    'cctv': ModuleRoleAllocation(
      visibleTo: {
        ..._executiveOversight,
      },
      manageBy: {
        StaffRoles.generalManager,
        StaffRoles.principal,
      },
    ),
    'attendance': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.vicePresident,
        StaffRoles.sectionDirector,
        StaffRoles.qualityAssurance,
        ..._executiveOversight,
      },
      manageBy: {StaffRoles.vicePresident, StaffRoles.sectionDirector},
    ),
    'parents': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.vicePresident,
        StaffRoles.sectionDirector,
        ..._executiveOversight,
      },
      manageBy: {StaffRoles.vicePresident, StaffRoles.sectionDirector},
    ),
    'inventory': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.procurement,
        StaffRoles.storekeeper,
        StaffRoles.vicePresident,
        ..._executiveOversight,
      },
      manageBy: {
        StaffRoles.procurement,
        StaffRoles.storekeeper,
        StaffRoles.vicePresident,
      },
    ),
    'library': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.vicePresident,
        StaffRoles.sectionDirector,
        StaffRoles.librarian,
        ..._executiveOversight,
      },
      manageBy: {
        StaffRoles.vicePresident,
        StaffRoles.sectionDirector,
        StaffRoles.librarian,
      },
    ),
    'learning_materials': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.vicePresident,
        StaffRoles.sectionDirector,
        StaffRoles.librarian,
        ..._executiveOversight,
      },
      manageBy: {
        StaffRoles.vicePresident,
        StaffRoles.sectionDirector,
        StaffRoles.librarian,
      },
    ),
    'announcements': ModuleRoleAllocation(visibleTo: _everyStaffRole),
    'events': ModuleRoleAllocation(
      visibleTo: {StaffRoles.sectionDirector, ..._executiveOversight},
      manageBy: {StaffRoles.sectionDirector},
    ),
    'calendar': ModuleRoleAllocation(
      visibleTo: {StaffRoles.sectionDirector, ..._executiveOversight},
      manageBy: {StaffRoles.sectionDirector},
    ),
    'quality_assurance': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.qualityAssurance,
        StaffRoles.vicePresident,
        ..._executiveOversight,
      },
      manageBy: {StaffRoles.qualityAssurance, StaffRoles.vicePresident},
    ),
    // Oversight executives + VP/QA can open reports (export is read-only).
    'reports': ModuleRoleAllocation(
      visibleTo: {
        ..._executiveOversight,
        StaffRoles.vicePresident,
        StaffRoles.qualityAssurance,
      },
      manageBy: <String>{},
    ),
    'audit_log': ModuleRoleAllocation(
      visibleTo: {
        StaffRoles.schoolBoard,
        StaffRoles.generalManager,
        StaffRoles.deputyGeneralManager,
      },
      manageBy: <String>{},
    ),
    'system_health': ModuleRoleAllocation(visibleTo: <String>{}),
  };

  static String normalize(String moduleId) => _aliases[moduleId] ?? moduleId;

  static ModuleRule? ruleFor(String moduleId) => rules[normalize(moduleId)];

  static bool get _isAdmin =>
      AuthService.currentUser?.roleKey == AuthService.roleAdmin;

  /// Whether the signed-in user may open [moduleId] at all.
  static bool canView(String moduleId) {
    if (_isAdmin) return true;
    final id = normalize(moduleId);
    final rule = ruleFor(moduleId);
    if (rule == null || rule.adminOnly) return false;

    // Administration staff: only modules granted by their staff role(s),
    // plus minimal chrome (home / profile / settings / logout / Maya — the
    // AI assistant is allocated to every role).
    if (AuthService.isAdministrationStaff) {
      const staffChrome = {
        'dashboard',
        'profile',
        'settings',
        'logout',
        'maya_assistant',
      };
      if (staffChrome.contains(id)) return true;
      // EDUABA dashboard matrix: allocated modules show only for their roles.
      final myRoles = _currentStaffRoleKeys();
      if (!myRoles.contains(StaffRoles.fullAccess)) {
        final allocation = roleAllocations[id];
        if (allocation != null) {
          return myRoles.intersection(allocation.visibleTo).isNotEmpty;
        }
      }
      if (rule.open) return false;
      if (AuthService.hasAnyPermission(rule.view) ||
          AuthService.hasAnyPermission(rule.manage)) {
        return true;
      }
      return rule.departmental &&
          AuthService.hasPermission(SchoolPermissions.viewAllDepartments);
    }

    if (rule.open) return true;
    if (AuthService.hasAnyPermission(rule.view) ||
        AuthService.hasAnyPermission(rule.manage)) {
      return true;
    }
    return rule.departmental &&
        AuthService.hasPermission(SchoolPermissions.viewAllDepartments);
  }

  /// Whether the signed-in user may perform mutations inside [moduleId].
  static bool canManage(String moduleId) {
    if (_isAdmin) return true;
    final id = normalize(moduleId);
    final rule = ruleFor(moduleId);
    if (rule == null || rule.adminOnly) return false;
    if (AuthService.isAdministrationStaff && rule.open) {
      if (id == 'profile' || id == 'settings' || id == 'logout') return true;
      if (id == 'dashboard') return false;
    }
    if (AuthService.isAdministrationStaff) {
      final myRoles = _currentStaffRoleKeys();
      if (!myRoles.contains(StaffRoles.fullAccess)) {
        final allocation = roleAllocations[id];
        if (allocation != null) {
          if (myRoles.intersection(allocation.visibleTo).isEmpty) return false;
          final managers = allocation.manageBy;
          if (managers != null) {
            return myRoles.intersection(managers).isNotEmpty;
          }
          return AuthService.hasAnyPermission(rule.manage);
        }
      }
    }
    if (rule.open) return true;
    return AuthService.hasAnyPermission(rule.manage);
  }

  /// Signed-in staff roles, canonicalized (legacy keys → current catalog).
  static Set<String> _currentStaffRoleKeys() {
    final roles = AuthService.currentUser?.staffRoles ?? const <String>[];
    return roles.map(StaffRoles.canonicalize).toSet();
  }

  /// True when the user can see the module but not change anything in it
  /// (drives the read-only banner in the web ERP shell).
  static bool isReadOnly(String moduleId) {
    final rule = ruleFor(moduleId);
    if (rule == null || rule.open) return false;
    return canView(moduleId) && !canManage(moduleId);
  }

  /// Whether the account should land in the web ERP shell on web: any staff
  /// permission at all (admins always do).
  static bool get hasErpAccess =>
      _isAdmin || AuthService.currentPermissions.isNotEmpty;

  /// Human Resource (or owner): create / edit / deactivate staff & teachers.
  static bool get canHireStaff =>
      _isAdmin ||
      AuthService.hasPermission(SchoolPermissions.manageStaffAccounts);

  /// Section Director (or owner): assign / transfer teachers to classes.
  static bool get canAssignTeachers =>
      _isAdmin || AuthService.hasPermission(SchoolPermissions.assignTeachers);

  /// Link a student to a bus (HR, Transport Admin, Section Director, owner).
  static bool get canLinkStudentTransport =>
      _isAdmin ||
      AuthService.hasPermission(SchoolPermissions.assignStudentTransport);
}
