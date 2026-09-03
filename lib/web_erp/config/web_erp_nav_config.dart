import 'package:flutter/material.dart';

import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/web_erp/models/web_erp_nav_item.dart';

/// Full ERP sidebar catalog. Item ids double as module ids in [ModuleAccess],
/// which decides per-user visibility (owner sees everything, staff see the
/// modules their combined roles grant, VP sees departments read-only).
///
/// Sections mirror the EDUABA org chart: Owner/GM level, the Principal branch
/// (academics + student services), Quality Assurance oversight, the Finance
/// branch, and the HR branch (staff + transport).
const List<WebErpNavItem> _allNavItems = [
    WebErpNavItem(id: 'dashboard', label: 'Dashboard', icon: Icons.dashboard_outlined),

    // Owner / Board / General Manager level.
    WebErpNavItem(
      id: 'institution',
      label: 'Institution Management',
      icon: Icons.account_balance_outlined,
      section: 'Organization',
    ),
    WebErpNavItem(
      id: 'school',
      label: 'School Management',
      icon: Icons.school_outlined,
      section: 'Organization',
    ),
    WebErpNavItem(
      id: 'campus',
      label: 'Campus Management',
      icon: Icons.location_city_outlined,
      section: 'Organization',
    ),
    WebErpNavItem(
      id: 'cctv',
      label: 'CCTV',
      icon: Icons.videocam_outlined,
      section: 'Organization',
    ),

    // Principal branch — academic leadership (VP, Section Director).
    WebErpNavItem(
      id: 'academic',
      label: 'Academic Management',
      icon: Icons.menu_book_outlined,
      section: 'Academics',
    ),
    WebErpNavItem(
      id: 'examinations',
      label: 'Examinations & Grade Approvals',
      icon: Icons.fact_check_outlined,
      section: 'Academics',
      badgeId: 'grades',
    ),
    WebErpNavItem(
      id: 'attendance',
      label: 'Attendance',
      icon: Icons.check_circle_outline,
      section: 'Academics',
      badgeId: 'attendance',
    ),
    WebErpNavItem(
      id: 'classroom_teachers',
      label: 'Classroom Teachers',
      icon: Icons.school_outlined,
      section: 'Academics',
    ),
    WebErpNavItem(
      id: 'add_teacher',
      label: 'Add Teacher',
      icon: Icons.person_add_outlined,
      section: 'Academics',
    ),
    WebErpNavItem(
      id: 'timetable',
      label: 'Timetable',
      icon: Icons.calendar_view_week_outlined,
      section: 'Academics',
    ),
    WebErpNavItem(
      id: 'grade_workflow_settings',
      label: 'Grade Workflow',
      icon: Icons.rule_outlined,
      section: 'Academics',
    ),

    // Student services — Students, Registrar duties, Student Affairs.
    WebErpNavItem(
      id: 'students',
      label: 'Students',
      icon: Icons.groups_outlined,
      section: 'Student Services',
    ),
    WebErpNavItem(
      id: 'admissions',
      label: 'Admissions',
      icon: Icons.how_to_reg_outlined,
      section: 'Student Services',
    ),
    WebErpNavItem(
      id: 'alumni',
      label: 'Alumni',
      icon: Icons.school_outlined,
      section: 'Student Services',
    ),
    WebErpNavItem(
      id: 'add_student',
      label: 'Add Student',
      icon: Icons.person_add_alt_1_outlined,
      section: 'Student Services',
    ),
    WebErpNavItem(
      id: 'student_portal_settings',
      label: 'Student Portal Settings',
      icon: Icons.school_outlined,
      section: 'Student Services',
    ),
    WebErpNavItem(
      id: 'student_password_resets',
      label: 'Student Password Resets',
      icon: Icons.lock_reset_outlined,
      section: 'Student Services',
    ),
    WebErpNavItem(
      id: 'student_affairs',
      label: 'Student Affairs & Discipline',
      icon: Icons.balance_outlined,
      section: 'Student Services',
    ),
    WebErpNavItem(
      id: 'parents',
      label: 'Parents & Link Approvals',
      icon: Icons.family_restroom_outlined,
      section: 'Student Services',
      badgeId: 'parent_approvals',
    ),
    WebErpNavItem(
      id: 'transfers',
      label: 'Transfers & Promotion',
      icon: Icons.swap_horiz_rounded,
      section: 'Student Services',
    ),

    // Finance branch — fees, payments, procurement, store.
    WebErpNavItem(
      id: 'finance',
      label: 'Finance',
      icon: Icons.payments_outlined,
      section: 'Finance Branch',
      badgeId: 'finance',
    ),
    WebErpNavItem(
      id: 'inventory',
      label: 'Inventory, Procurement & Store',
      icon: Icons.inventory_2_outlined,
      section: 'Finance Branch',
    ),

    // Human Resources branch — staff records + transport unit.
    WebErpNavItem(
      id: 'hr',
      label: 'Human Resource',
      icon: Icons.groups_outlined,
      section: 'HR Branch',
    ),
    WebErpNavItem(
      id: 'teachers',
      label: 'Administration Staff Directory',
      icon: Icons.badge_outlined,
      section: 'HR Branch',
    ),
    WebErpNavItem(
      id: 'add_staff',
      label: 'Add Administration Staff',
      icon: Icons.badge_outlined,
      section: 'HR Branch',
    ),
    WebErpNavItem(
      id: 'transport',
      label: 'Transport',
      icon: Icons.directions_bus_outlined,
      section: 'HR Branch',
      badgeId: 'transport',
    ),
    WebErpNavItem(
      id: 'transport_buses',
      label: 'Buses',
      icon: Icons.airport_shuttle_outlined,
      section: 'HR Branch',
    ),
    WebErpNavItem(
      id: 'transport_live_gps',
      label: 'Live GPS',
      icon: Icons.gps_fixed,
      section: 'HR Branch',
    ),
    WebErpNavItem(
      id: 'add_driver',
      label: 'Register Driver',
      icon: Icons.person_add_alt_1_outlined,
      section: 'HR Branch',
    ),

    // Learning resources wired to students & parents.
    WebErpNavItem(
      id: 'library',
      label: 'Library',
      icon: Icons.local_library_outlined,
      section: 'Learning Resources',
    ),
    WebErpNavItem(
      id: 'learning_materials',
      label: 'e-Books & Materials',
      icon: Icons.auto_stories_outlined,
      section: 'Learning Resources',
    ),

    // Communication to parents & students.
    WebErpNavItem(
      id: 'announcements',
      label: 'Announcements',
      icon: Icons.campaign_outlined,
      section: 'Communication',
      badgeId: 'announcements',
    ),
    WebErpNavItem(
      id: 'events',
      label: 'Events & Gallery',
      icon: Icons.event_outlined,
      section: 'Communication',
    ),
    WebErpNavItem(
      id: 'calendar',
      label: 'Calendar',
      icon: Icons.calendar_month_outlined,
      section: 'Communication',
      badgeId: 'calendar',
    ),

    // Quality Assurance & leadership insight.
    WebErpNavItem(
      id: 'quality_assurance',
      label: 'QA Findings & Plans',
      icon: Icons.verified_outlined,
      section: 'Quality & Insights',
    ),
    WebErpNavItem(
      id: 'reports',
      label: 'Reports & Analytics',
      icon: Icons.analytics_outlined,
      section: 'Quality & Insights',
    ),
    WebErpNavItem(
      id: 'support',
      label: 'Messages',
      icon: Icons.forum_outlined,
      section: 'Communication',
      badgeId: 'messages',
    ),
    WebErpNavItem(
      id: 'maya_assistant',
      label: 'Maya Assistant',
      icon: Icons.auto_awesome,
      section: 'Quality & Insights',
    ),

    WebErpNavItem(
      id: 'staff_roles',
      label: 'Role Permissions',
      icon: Icons.rule_folder_outlined,
      section: 'System',
    ),
    WebErpNavItem(
      id: 'audit_log',
      label: 'Audit Log',
      icon: Icons.history_outlined,
      section: 'System',
    ),
    WebErpNavItem(
      id: 'system_health',
      label: 'System Health',
      icon: Icons.monitor_heart_outlined,
      section: 'System',
    ),
    WebErpNavItem(
      id: 'settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      section: 'System',
    ),
    WebErpNavItem(
      id: 'profile',
      label: 'Profile',
      icon: Icons.person_outlined,
      section: 'Account',
    ),
    WebErpNavItem(
      id: 'logout',
      label: 'Logout',
      icon: Icons.logout,
      isLogout: true,
    ),
];

/// Sidebar items the signed-in user may see.
List<WebErpNavItem> webErpNavItemsForCurrentUser() {
  return _allNavItems
      .where((item) => item.isLogout || ModuleAccess.canView(item.id))
      .toList();
}

WebErpNavItem? webErpNavItemById(String id) {
  for (final item in _allNavItems) {
    if (item.id == id) return item;
  }
  return null;
}

String webErpLabelForId(String id) => webErpNavItemById(id)?.label ?? id;
