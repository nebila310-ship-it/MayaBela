/// RBAC catalog: permission keys and staff role templates.
///
/// This file is the single source of truth for the whole platform. The same
/// catalog is mirrored in:
///   - supabase/functions/_shared/school_auth.ts  (JWT claim stamping)
///   - supabase/migrations/*_rbac_foundation.sql  (write-guard checks)
/// When adding a permission or role, update all three together.
///
/// Hierarchy (per product spec):
///   Level 1  EduAba platform owner  — PIN-protected owner console, not RBAC.
///   Level 2  School owner / head admin — account roleKey 'admin', implicitly
///            holds every permission and is the only grantor of Full Access.
///   Level 3  School staff — accounts with roleKey 'teacher' that carry one or
///            more [StaffRole] grants. Permissions are the union of all roles.
library;

import 'package:mayabela/services/rbac/staff_dashboard_modules.dart';

/// All permission keys, grouped by module.
abstract final class SchoolPermissions {
  // Students & registrar
  static const viewStudents = 'view_students';
  static const manageStudents = 'manage_students';
  static const manageParentLinks = 'manage_parent_links';
  static const createTransfers = 'create_transfers';
  static const approveTransfers = 'approve_transfers';
  static const promoteStudents = 'promote_students';

  // Academic
  static const manageClasses = 'manage_classes';
  static const manageSubjects = 'manage_subjects';
  static const assignTeachers = 'assign_teachers';
  static const manageTimetables = 'manage_timetables';
  static const viewAllGrades = 'view_all_grades';
  /// School-wide student PII (registry, grades, fees, medical). Classroom
  /// teachers without this (or view_all_departments / full_access) are
  /// limited to assigned-class rows by RLS.
  static const viewAllSchoolData = 'view_all_school_data';
  static const approveGrades = 'approve_grades';
  static const manageLearningMaterials = 'manage_learning_materials';
  static const manageMaterialAccess = 'manage_material_access';

  // Staff / HR
  static const viewStaff = 'view_staff';
  static const manageStaffAccounts = 'manage_staff_accounts';
  static const assignRoles = 'assign_roles';

  // Procurement
  static const createPurchaseRequests = 'create_purchase_requests';
  static const approvePurchaseRequests = 'approve_purchase_requests';
  static const manageSuppliers = 'manage_suppliers';
  static const enterPurchasedItems = 'enter_purchased_items';
  static const approveIssueRequests = 'approve_issue_requests';
  static const viewInventory = 'view_inventory';

  // Store
  static const receiveStock = 'receive_stock';
  static const issueStock = 'issue_stock';
  static const adjustStock = 'adjust_stock';
  static const createIssueRequests = 'create_issue_requests';

  // Finance
  static const manageFees = 'manage_fees';
  static const recordPayments = 'record_payments';
  static const viewFinanceReports = 'view_finance_reports';

  // Transport
  static const manageBuses = 'manage_buses';
  static const manageDrivers = 'manage_drivers';
  static const assignStudentTransport = 'assign_student_transport';
  static const viewTransport = 'view_transport';

  // Communication
  static const sendAnnouncements = 'send_announcements';
  static const messageParents = 'message_parents';

  // Oversight & shared staff baseline
  static const viewAllDepartments = 'view_all_departments';
  static const viewReports = 'view_reports';
  static const viewAuditLog = 'view_audit_log';
  static const accessSupport = 'access_support';
  static const viewSystemHealth = 'view_system_health';

  // Quality Assurance (EDUABA §2): findings & improvement plans register.
  static const manageQaFindings = 'manage_qa_findings';

  // Settings
  static const manageSchoolSettings = 'manage_school_settings';
  static const manageCampuses = 'manage_campuses';

  /// Administration Staff digital-ops desk (devices, access help, go-live
  /// buttons, campus systems, Friday checklist). Not Full Access.
  static const manageDigitalOps = 'manage_digital_ops';

  static const Set<String> all = {
    viewStudents,
    manageStudents,
    manageParentLinks,
    createTransfers,
    approveTransfers,
    promoteStudents,
    manageClasses,
    manageSubjects,
    assignTeachers,
    manageTimetables,
    viewAllGrades,
    viewAllSchoolData,
    approveGrades,
    manageLearningMaterials,
    manageMaterialAccess,
    viewStaff,
    manageStaffAccounts,
    assignRoles,
    createPurchaseRequests,
    approvePurchaseRequests,
    manageSuppliers,
    enterPurchasedItems,
    approveIssueRequests,
    viewInventory,
    receiveStock,
    issueStock,
    adjustStock,
    createIssueRequests,
    manageFees,
    recordPayments,
    viewFinanceReports,
    manageBuses,
    manageDrivers,
    assignStudentTransport,
    viewTransport,
    sendAnnouncements,
    messageParents,
    viewAllDepartments,
    viewReports,
    viewAuditLog,
    accessSupport,
    viewSystemHealth,
    manageQaFindings,
    manageSchoolSettings,
    manageCampuses,
    manageDigitalOps,
  };
}

/// A staff role template: a named bundle of permissions.
class StaffRole {
  const StaffRole({
    required this.key,
    required this.labelEn,
    required this.labelAm,
    required this.labelOm,
    required this.permissions,
    this.ownerOnly = false,
    this.builtIn = true,
    this.customizable = true,
  });

  final String key;
  final String labelEn;
  final String labelAm;
  final String labelOm;
  final Set<String> permissions;

  /// Only the school owner (roleKey 'admin') may grant/revoke this role.
  final bool ownerOnly;

  /// Ships with the product (vs school-defined custom role).
  final bool builtIn;

  /// Owner may edit module checkboxes for this role at the school.
  final bool customizable;

  StaffRole copyWith({
    String? labelEn,
    String? labelAm,
    String? labelOm,
    Set<String>? permissions,
  }) {
    return StaffRole(
      key: key,
      labelEn: labelEn ?? this.labelEn,
      labelAm: labelAm ?? this.labelAm,
      labelOm: labelOm ?? this.labelOm,
      permissions: permissions ?? this.permissions,
      ownerOnly: ownerOnly,
      builtIn: builtIn,
      customizable: customizable,
    );
  }
}

/// The predefined staff role templates (EDUABA hierarchy §1–2).
abstract final class StaffRoles {
  static const fullAccess = 'full_access';
  static const schoolBoard = 'school_board';
  static const generalManager = 'general_manager';
  static const deputyGeneralManager = 'deputy_general_manager';
  static const principal = 'principal';
  static const vicePresident = 'vice_president'; // Vice Principal (legacy key)
  static const qualityAssurance = 'quality_assurance';
  static const sectionDirector = 'section_director';
  static const studentAffairs = 'student_affairs';
  static const registrar = 'registrar';
  static const accountant = 'accountant'; // Finance Manager (legacy key)
  static const humanResource = 'human_resource';
  static const librarian = 'librarian';
  static const procurement = 'procurement';
  static const storekeeper = 'storekeeper';
  static const transportAdmin = 'transport_admin'; // Transport Head (legacy key)
  static const staffs = 'staffs';

  // Legacy keys kept so existing grants keep working.
  static const academicAdmin = 'academic_admin';
  static const hrAdmin = 'hr_admin';
  static const finance = 'finance';
  static const vicePrincipal = 'vice_principal';
  static const financeManager = 'finance_manager';
  static const transportHead = 'transport_head';

  static Set<String> get _baseline => StaffDashboardModules.alwaysOnPermissions();

  static Set<String> _withBaseline(Set<String> perms) =>
      StaffDashboardModules.withBaseline(perms);

  static final List<StaffRole> templates = [
    StaffRole(
      key: fullAccess,
      labelEn: 'School Owner / Full Access',
      labelAm: 'የትምህርት ቤት ባለቤት',
      labelOm: 'Abbaa Mana Barumsaa',
      permissions: SchoolPermissions.all,
      ownerOnly: true,
      customizable: false,
    ),
    StaffRole(
      key: schoolBoard,
      labelEn: 'School Board',
      labelAm: 'ቦርድ',
      labelOm: 'Boordii',
      permissions: _withBaseline({
        SchoolPermissions.viewStudents,
        SchoolPermissions.viewStaff,
        SchoolPermissions.viewAllGrades,
        SchoolPermissions.viewAllSchoolData,
        SchoolPermissions.viewFinanceReports,
        SchoolPermissions.viewAllDepartments,
        SchoolPermissions.viewReports,
        SchoolPermissions.viewAuditLog,
      }),
    ),
    StaffRole(
      key: generalManager,
      labelEn: 'General Manager',
      labelAm: 'ጠቅላላ ሥራ አስኪያጅ',
      labelOm: 'Hooggana Waliigalaa',
      permissions: _withBaseline({
        SchoolPermissions.viewStudents,
        SchoolPermissions.viewStaff,
        SchoolPermissions.viewInventory,
        SchoolPermissions.viewTransport,
        SchoolPermissions.viewAllGrades,
        SchoolPermissions.viewAllSchoolData,
        SchoolPermissions.viewFinanceReports,
        SchoolPermissions.viewAllDepartments,
        SchoolPermissions.approveTransfers,
        SchoolPermissions.approveGrades,
        SchoolPermissions.approvePurchaseRequests,
        SchoolPermissions.approveIssueRequests,
        SchoolPermissions.sendAnnouncements,
        SchoolPermissions.accessSupport,
        SchoolPermissions.messageParents,
        SchoolPermissions.manageStaffAccounts,
      }),
    ),
    StaffRole(
      key: deputyGeneralManager,
      labelEn: 'Deputy General Manager',
      labelAm: 'ምክትል ጠቅላላ ሥራ አስኪያጅ',
      labelOm: 'Itti-aanaa Hooggana Waliigalaa',
      permissions: _withBaseline({
        SchoolPermissions.viewStudents,
        SchoolPermissions.viewStaff,
        SchoolPermissions.viewInventory,
        SchoolPermissions.viewTransport,
        SchoolPermissions.viewAllGrades,
        SchoolPermissions.viewAllSchoolData,
        SchoolPermissions.viewFinanceReports,
        SchoolPermissions.viewAllDepartments,
        SchoolPermissions.approveTransfers,
        SchoolPermissions.approveGrades,
        SchoolPermissions.approvePurchaseRequests,
        SchoolPermissions.approveIssueRequests,
        SchoolPermissions.sendAnnouncements,
        SchoolPermissions.accessSupport,
        SchoolPermissions.messageParents,
        SchoolPermissions.manageStaffAccounts,
        SchoolPermissions.assignTeachers,
        SchoolPermissions.manageClasses,
      }),
    ),
    StaffRole(
      key: principal,
      labelEn: 'Principal',
      labelAm: 'ርእሰ መምህር',
      labelOm: 'Durtaa Mana Barumsaa',
      permissions: _withBaseline({
        SchoolPermissions.viewStudents,
        SchoolPermissions.viewStaff,
        SchoolPermissions.viewAllGrades,
        SchoolPermissions.viewAllSchoolData,
        SchoolPermissions.approveGrades,
        SchoolPermissions.approveTransfers,
        SchoolPermissions.manageClasses,
        SchoolPermissions.manageSubjects,
        SchoolPermissions.manageTimetables,
        SchoolPermissions.sendAnnouncements,
        SchoolPermissions.messageParents,
        SchoolPermissions.accessSupport,
        SchoolPermissions.viewTransport,
      }),
    ),
    StaffRole(
      key: qualityAssurance,
      labelEn: 'Quality Assurance',
      labelAm: 'ጥራት ማረጋገጫ',
      labelOm: 'Mirkaneessa Qulqullina',
      permissions: _withBaseline({
        SchoolPermissions.viewStudents,
        SchoolPermissions.viewStaff,
        SchoolPermissions.viewAllGrades,
        SchoolPermissions.viewAllSchoolData,
        SchoolPermissions.viewAllDepartments,
        SchoolPermissions.viewAuditLog,
        SchoolPermissions.viewReports,
        SchoolPermissions.accessSupport,
        SchoolPermissions.manageQaFindings,
      }),
    ),
    StaffRole(
      key: vicePresident,
      labelEn: 'Vice Principal',
      labelAm: 'ምክትል ርእሰ መምህር',
      labelOm: 'Itti-aanaa Durtaa',
      permissions: _withBaseline({
        SchoolPermissions.viewStudents,
        SchoolPermissions.viewStaff,
        SchoolPermissions.viewInventory,
        SchoolPermissions.viewTransport,
        SchoolPermissions.viewAllGrades,
        SchoolPermissions.viewAllSchoolData,
        SchoolPermissions.viewFinanceReports,
        SchoolPermissions.viewAllDepartments,
        SchoolPermissions.approveTransfers,
        SchoolPermissions.approveGrades,
        SchoolPermissions.approvePurchaseRequests,
        SchoolPermissions.approveIssueRequests,
        // Communications & library operations
        SchoolPermissions.sendAnnouncements,
        SchoolPermissions.manageLearningMaterials,
        SchoolPermissions.manageMaterialAccess,
        SchoolPermissions.accessSupport,
        SchoolPermissions.messageParents,
        SchoolPermissions.assignTeachers,
        SchoolPermissions.manageClasses,
      }),
    ),
    StaffRole(
      key: sectionDirector,
      labelEn: 'Section Director',
      labelAm: 'የክፍል ዳይሬክተር',
      labelOm: 'Daayireektara Kutaa',
      permissions: _withBaseline({
        SchoolPermissions.manageClasses,
        SchoolPermissions.manageSubjects,
        SchoolPermissions.assignTeachers,
        SchoolPermissions.manageTimetables,
        SchoolPermissions.viewAllGrades,
        SchoolPermissions.viewAllSchoolData,
        SchoolPermissions.approveGrades,
        // EDUABA allocation: SD requests transfers, VP approves them.
        SchoolPermissions.createTransfers,
        SchoolPermissions.manageStudents,
        SchoolPermissions.manageLearningMaterials,
        SchoolPermissions.manageMaterialAccess,
        SchoolPermissions.viewStudents,
        SchoolPermissions.viewStaff,
        SchoolPermissions.viewTransport,
        SchoolPermissions.assignStudentTransport,
        SchoolPermissions.manageParentLinks,
        SchoolPermissions.accessSupport,
        SchoolPermissions.messageParents,
      }),
    ),
    StaffRole(
      key: studentAffairs,
      labelEn: 'Student Affairs',
      labelAm: 'የተማሪ ጉዳዮች',
      labelOm: 'Dhimma Barattootaa',
      permissions: _withBaseline({
        SchoolPermissions.viewStudents,
        SchoolPermissions.viewAllSchoolData,
        SchoolPermissions.manageStudents,
        SchoolPermissions.manageParentLinks,
        SchoolPermissions.createTransfers,
        SchoolPermissions.messageParents,
        SchoolPermissions.sendAnnouncements,
      }),
    ),
    StaffRole(
      key: registrar,
      labelEn: 'Registrar',
      labelAm: 'ሬጅስትራር',
      labelOm: 'Galmeessaa',
      permissions: _withBaseline({
        SchoolPermissions.viewStudents,
        SchoolPermissions.viewAllSchoolData,
        SchoolPermissions.manageStudents,
        SchoolPermissions.manageParentLinks,
        SchoolPermissions.createTransfers,
        SchoolPermissions.promoteStudents,
        SchoolPermissions.messageParents,
        SchoolPermissions.accessSupport,
      }),
    ),
    StaffRole(
      key: accountant,
      labelEn: 'Finance Manager',
      labelAm: 'የፋይናንስ ሥራ አስኪያጅ',
      labelOm: 'Hooggana Maallaqaa',
      permissions: _withBaseline({
        SchoolPermissions.manageFees,
        SchoolPermissions.recordPayments,
        SchoolPermissions.viewFinanceReports,
        SchoolPermissions.viewStudents,
        SchoolPermissions.viewAllSchoolData,
        SchoolPermissions.approvePurchaseRequests,
        SchoolPermissions.viewInventory,
        SchoolPermissions.viewTransport,
        SchoolPermissions.messageParents,
        SchoolPermissions.accessSupport,
      }),
    ),
    StaffRole(
      key: humanResource,
      labelEn: 'Human Resource',
      labelAm: 'የሰው ሀብት',
      labelOm: 'Humna Namaa',
      permissions: _withBaseline({
        SchoolPermissions.viewStaff,
        SchoolPermissions.manageStaffAccounts,
        SchoolPermissions.viewTransport,
        SchoolPermissions.manageBuses,
        SchoolPermissions.manageDrivers,
        SchoolPermissions.assignStudentTransport,
        SchoolPermissions.viewStudents,
        SchoolPermissions.viewAllSchoolData,
        SchoolPermissions.accessSupport,
        SchoolPermissions.messageParents,
      }),
    ),
    StaffRole(
      key: librarian,
      labelEn: 'Librarian',
      labelAm: 'ቤተ-መጻሕፍት',
      labelOm: 'Kutaa Kitaabaa',
      permissions: _withBaseline({
        SchoolPermissions.manageLearningMaterials,
        SchoolPermissions.manageMaterialAccess,
      }),
    ),
    StaffRole(
      key: procurement,
      labelEn: 'Procurement Manager',
      labelAm: 'የግዥ ሥራ አስኪያጅ',
      labelOm: 'Hooggana Bittaa',
      permissions: _withBaseline({
        SchoolPermissions.createPurchaseRequests,
        SchoolPermissions.manageSuppliers,
        SchoolPermissions.enterPurchasedItems,
        SchoolPermissions.approveIssueRequests,
        SchoolPermissions.viewInventory,
      }),
    ),
    StaffRole(
      key: storekeeper,
      labelEn: 'Store Keeper',
      labelAm: 'የመጋዘን ኃላፊ',
      labelOm: 'Eegduu Kuusaa',
      permissions: _withBaseline({
        SchoolPermissions.receiveStock,
        SchoolPermissions.issueStock,
        SchoolPermissions.adjustStock,
        SchoolPermissions.createIssueRequests,
        SchoolPermissions.viewInventory,
      }),
    ),
    // Kept so existing transport grants and workflows keep working.
    StaffRole(
      key: transportAdmin,
      labelEn: 'Transport Head',
      labelAm: 'የትራንስፖርት ኃላፊ',
      labelOm: 'Hooggana Geejjibaa',
      permissions: _withBaseline({
        SchoolPermissions.manageBuses,
        SchoolPermissions.manageDrivers,
        SchoolPermissions.assignStudentTransport,
        SchoolPermissions.viewTransport,
        SchoolPermissions.viewStudents,
        SchoolPermissions.viewAllSchoolData,
        SchoolPermissions.messageParents,
        SchoolPermissions.accessSupport,
      }),
    ),
    StaffRole(
      key: staffs,
      labelEn: 'Staff',
      labelAm: 'ሰራተኛ',
      labelOm: 'Hojjetaa',
      permissions: _withBaseline({
        SchoolPermissions.viewStaff,
        SchoolPermissions.accessSupport,
        SchoolPermissions.manageDigitalOps,
      }),
    ),
  ];

  /// Legacy / EDUABA alias → canonical key.
  static const Map<String, String> aliases = {
    academicAdmin: sectionDirector,
    hrAdmin: humanResource,
    finance: accountant,
    vicePrincipal: vicePresident,
    financeManager: accountant,
    transportHead: transportAdmin,
  };

  static String canonicalize(String key) {
    final k = key.trim().toLowerCase();
    return aliases[k] ?? k;
  }

  /// Enrolment id prefix per role (QA-1001, HR-1001, VP-1001, …).
  /// Multi-word roles use their initials; single-word roles a short stub.
  static const Map<String, String> _idPrefixes = {
    fullAccess: 'OWN',
    schoolBoard: 'SB',
    generalManager: 'GM',
    deputyGeneralManager: 'DGM',
    principal: 'PRI',
    vicePresident: 'VP',
    qualityAssurance: 'QA',
    sectionDirector: 'SD',
    studentAffairs: 'SA',
    registrar: 'REG',
    accountant: 'FM', // Finance Manager
    humanResource: 'HR',
    librarian: 'LIB',
    procurement: 'PRO',
    storekeeper: 'SK',
    transportAdmin: 'TH', // Transport Head
    staffs: 'STF',
  };

  static String idPrefixFor(String roleKey) {
    final k = canonicalize(roleKey);
    final mapped = _idPrefixes[k];
    if (mapped != null) return mapped;
    final words = k.split('_').where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return words.map((w) => w[0]).join().toUpperCase();
    }
    final word = words.isEmpty ? 'STF' : words.first;
    return word.substring(0, word.length < 3 ? word.length : 3).toUpperCase();
  }

  static final Map<String, StaffRole> byKey = {
    for (final role in templates) role.key: role,
    // Alias lookups resolve to the new template objects.
    academicAdmin: templates.firstWhere((r) => r.key == sectionDirector),
    hrAdmin: templates.firstWhere((r) => r.key == humanResource),
    finance: templates.firstWhere((r) => r.key == accountant),
    vicePrincipal: templates.firstWhere((r) => r.key == vicePresident),
    financeManager: templates.firstWhere((r) => r.key == accountant),
    transportHead: templates.firstWhere((r) => r.key == transportAdmin),
  };

  static StaffRole? lookup(String key) {
    final k = key.trim().toLowerCase();
    return byKey[k] ?? byKey[canonicalize(k)];
  }

  /// Combined permission set for a user holding [roleKeys].
  static Set<String> permissionsForRoles(Iterable<String> roleKeys) {
    final out = <String>{};
    for (final key in roleKeys) {
      final role = lookup(key);
      if (role == null) continue;
      out.addAll(role.permissions);
    }
    return out;
  }

  static Set<String> get baselinePermissions => _baseline;
}
