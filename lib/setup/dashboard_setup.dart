import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/admin_enrollment_screens.dart';
import 'package:mayabela/screens/admin_classes_screens.dart';
import 'package:mayabela/screens/admin_list_screens.dart';
import 'package:mayabela/screens/announcements_screen.dart';
import 'package:mayabela/screens/admin_attendance_screens.dart';
import 'package:mayabela/screens/attendance_screen.dart';
import 'package:mayabela/screens/bus_tracking_screen.dart';
import 'package:mayabela/screens/transport_live_map_screen.dart';
import 'package:mayabela/models/transport_passenger.dart';
import 'package:mayabela/screens/transport_screens.dart';
import 'package:mayabela/screens/transport_qr_scanner_screen.dart';
import 'package:mayabela/screens/calendar_screen.dart';
import 'package:mayabela/screens/class_timetable_screen.dart';
import 'package:mayabela/screens/fees_payments_screen.dart';
import 'package:mayabela/screens/gallery_screen.dart';
import 'package:mayabela/screens/admin_grade_overview_screen.dart';
import 'package:mayabela/screens/admin_grade_workflow_settings_screen.dart';
import 'package:mayabela/screens/grade_approval_queue_screen.dart';
import 'package:mayabela/screens/grade_reports_screen.dart';
import 'package:mayabela/screens/homework_screen.dart';
import 'package:mayabela/screens/learning_materials_screen.dart';
import 'package:mayabela/screens/messages_screen.dart';
import 'package:mayabela/screens/parent_student_affairs_screen.dart';
import 'package:mayabela/screens/teacher_student_affairs_screen.dart';
import 'package:mayabela/screens/maya_assistant_screen.dart';
import 'package:mayabela/widgets/parent_child_picker.dart';
import 'package:mayabela/screens/my_classes_screen.dart';
import 'package:mayabela/screens/qr_entry_exit_screen.dart';
import 'package:mayabela/screens/settings_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/dashboard_navigation_store.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/screens/admin_student_portal_settings_screen.dart';
import 'package:mayabela/screens/admin_student_password_reset_screen.dart';
import 'package:mayabela/screens/student_profile_screen.dart';
import 'package:mayabela/services/student_account_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/widgets/parent_bus_link_card.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/widgets/report_issue_dialog.dart';
import 'package:mayabela/models/school_class.dart';
import 'package:mayabela/widgets/dashboard_card.dart';
import 'package:mayabela/widgets/mobile_erp_host.dart';
import 'package:mayabela/web_erp/pages/inventory/web_inventory_shell_page.dart';
import 'package:mayabela/web_erp/pages/web_audit_log_page.dart';
import 'package:mayabela/web_erp/pages/web_buses_page.dart';
import 'package:mayabela/web_erp/pages/web_campus_management_page.dart';
import 'package:mayabela/web_erp/pages/web_finance_dashboard_page.dart';
import 'package:mayabela/web_erp/pages/web_learning_materials_page.dart';
import 'package:mayabela/web_erp/pages/web_library_page.dart';
import 'package:mayabela/web_erp/pages/web_reports_page.dart';
import 'package:mayabela/web_erp/pages/web_announcements_page.dart';
import 'package:mayabela/web_erp/pages/web_qa_page.dart';
import 'package:mayabela/web_erp/pages/web_student_affairs_page.dart';
import 'package:mayabela/web_erp/pages/web_system_health_page.dart';
import 'package:mayabela/web_erp/pages/web_transfers_page.dart';
import 'package:mayabela/web_erp/pages/web_transport_dashboard_page.dart';

String _t(String id, String roleKey) =>
    AppLocale.instance.strings.dashboardTitle(id, roleKey: roleKey);

int _badge(String tileId) => DashboardBadgeService.instance.countFor(tileId);

void _openTile(String tileId, VoidCallback action) {
  DashboardBadgeService.instance.markReadForTile(tileId);
  action();
}

DashboardEntry _mayaAssistantEntry(
  String role, {
  bool Function()? isVisible,
}) {
  const color = Color(0xFF0F766E);
  return DashboardEntry(
    id: 'maya_assistant',
    icon: Icons.auto_awesome,
    color: color,
    isVisible: isVisible,
    builder: (context) => DashboardCard(
      icon: Icons.auto_awesome,
      title: _t('maya_assistant', role),
      color: color,
      onTap: () => _openTile('maya_assistant', () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MayaAssistantScreen(roleKey: role),
          ),
        );
      }),
    ),
  );
}

void registerAllDashboards() {
  DashboardRegistry.registerTeacherEntries(_teacherEntries());
  DashboardRegistry.registerStaffEntries(_staffHomeEntries());
  DashboardRegistry.registerParentEntries(_parentEntries());
  DashboardRegistry.registerStudentEntries(_studentEntries());
  DashboardRegistry.registerAdminEntries(_adminEntries());
  DashboardRegistry.registerDriverEntries(_driverEntries());
}

List<DashboardEntry> _teacherEntries() {
  final access = TeacherAccessService.instance;
  final teacherName = AuthService.displayNameForRole(AuthService.roleTeacher);
  const role = AuthService.roleTeacher;

  void openMessages(BuildContext context) {
    _openTile('messages', () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const MessagesScreen(
            canCompose: true,
            composeScope: MessageComposeScope.teacher,
          ),
        ),
      );
    });
  }

  return [
    DashboardEntry(
      id: 'classes',
      icon: Icons.class_,
      color: Colors.blue,
      isVisible: () => access.canAccessTeacherDashboardTile('classes'),
      builder: (context) => DashboardCard(
        icon: Icons.class_,
        title: _t('classes', role),
        color: Colors.blue,
        badgeCount: _badge('classes'),
        onTap: () => _openTile('classes', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyClassesScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'attendance',
      icon: Icons.check_circle,
      color: Colors.green,
      isVisible: () => access.canAccessTeacherDashboardTile('attendance'),
      builder: (context) => DashboardCard(
        icon: Icons.check_circle,
        title: _t('attendance', role),
        color: Colors.green,
        badgeCount: _badge('attendance'),
        onTap: () => _openTile('attendance', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AttendanceScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'messages',
      icon: Icons.message,
      color: Colors.orange,
      isVisible: () => access.canAccessTeacherDashboardTile('messages'),
      builder: (context) => DashboardCard(
        icon: Icons.message,
        title: _t('messages', role),
        color: Colors.orange,
        badgeCount: _badge('messages'),
        onTap: () => openMessages(context),
      ),
    ),
    DashboardEntry(
      id: 'announcements',
      icon: Icons.campaign,
      color: Colors.red,
      isVisible: () => access.canAccessTeacherDashboardTile('announcements'),
      builder: (context) => DashboardCard(
        icon: Icons.campaign,
        title: _t('announcements', role),
        color: Colors.red,
        badgeCount: _badge('announcements'),
        onTap: () => _openTile('announcements', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnnouncementsScreen(
                canCreate: access.canCreateAnnouncements,
                authorName: teacherName,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'homework',
      icon: Icons.assignment,
      color: Colors.cyan,
      isVisible: () => access.canAccessTeacherDashboardTile('homework'),
      builder: (context) => DashboardCard(
        icon: Icons.assignment,
        title: _t('homework', role),
        color: Colors.cyan,
        badgeCount: _badge('homework'),
        onTap: () => _openTile('homework', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HomeworkScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'learning_materials',
      icon: Icons.menu_book,
      color: const Color(0xFF4527A0),
      isVisible: () =>
          access.canAccessTeacherDashboardTile('learning_materials'),
      builder: (context) => DashboardCard(
        icon: Icons.menu_book,
        title: _t('learning_materials', role),
        color: const Color(0xFF4527A0),
        badgeCount: _badge('learning_materials'),
        onTap: () => _openTile('learning_materials', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LearningMaterialsScreen(),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'gallery',
      icon: Icons.photo_library,
      color: Colors.purple,
      isVisible: () => access.canAccessTeacherDashboardTile('gallery'),
      builder: (context) => DashboardCard(
        icon: Icons.photo_library,
        title: _t('gallery', role),
        color: Colors.purple,
        badgeCount: _badge('gallery'),
        onTap: () => _openTile('gallery', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GalleryScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'grades',
      icon: Icons.bar_chart,
      color: Colors.deepOrange,
      isVisible: () => access.canAccessTeacherDashboardTile('grades'),
      builder: (context) => DashboardCard(
        icon: Icons.bar_chart,
        title: _t('grades', role),
        color: Colors.deepOrange,
        badgeCount: _badge('grades'),
        onTap: () => _openTile('grades', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GradeReportsScreen(
                view: GradeReportView.teacher,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'qr',
      icon: Icons.qr_code_scanner,
      color: Colors.black,
      isVisible: () => access.canAccessTeacherDashboardTile('qr'),
      builder: (context) => DashboardCard(
        icon: Icons.qr_code_scanner,
        title: _t('qr', role),
        color: Colors.black,
        badgeCount: _badge('qr'),
        onTap: () => _openTile('qr', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const QrEntryExitScreen(role: QrScreenRole.teacher),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'calendar',
      icon: Icons.calendar_month,
      color: Colors.teal,
      isVisible: () => access.canAccessTeacherDashboardTile('calendar'),
      builder: (context) => DashboardCard(
        icon: Icons.calendar_month,
        title: _t('calendar', role),
        color: Colors.teal,
        badgeCount: _badge('calendar'),
        onTap: () => _openTile('calendar', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CalendarScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'timetable',
      icon: Icons.calendar_view_week,
      color: Colors.brown,
      isVisible: () => access.canAccessTeacherDashboardTile('timetable'),
      builder: (context) => DashboardCard(
        icon: Icons.calendar_view_week,
        title: _t('timetable', role),
        color: Colors.brown,
        badgeCount: _badge('timetable'),
        onTap: () => _openTile('timetable', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClassTimetableScreen(
                mode: TimetableViewMode.teacher,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'parent_approvals',
      icon: Icons.how_to_reg,
      color: Colors.orange,
      isVisible: () =>
          access.hasAnyHomeroomClass ||
          ModuleAccess.canManage('parents'),
      builder: (context) => DashboardCard(
        icon: Icons.how_to_reg,
        title: _t('parent_approvals', role),
        color: Colors.orange,
        badgeCount: _badge('parent_approvals'),
        onTap: () => _openTile('parent_approvals', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ParentApprovalsScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'student_affairs',
      icon: Icons.balance_outlined,
      color: const Color(0xFF8E24AA),
      builder: (context) => DashboardCard(
        icon: Icons.balance_outlined,
        title: _t('student_affairs', role),
        color: const Color(0xFF8E24AA),
        badgeCount: _badge('student_affairs'),
        onTap: () => _openTile('student_affairs', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TeacherStudentAffairsScreen(),
            ),
          );
        }),
      ),
    ),
    _mayaAssistantEntry(
      role,
      isVisible: () => access.canAccessTeacherDashboardTile('maya_assistant'),
    ),
    DashboardEntry(
      id: 'settings',
      icon: Icons.settings,
      color: Colors.grey,
      builder: (context) => DashboardCard(
        icon: Icons.settings,
        title: _t('settings', role),
        color: Colors.grey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
    ),
  ];
}

/// Mobile home tiles for administration / custom staff roles (not classroom).
List<DashboardEntry> _staffHomeEntries() {
  return [
    ..._staffModuleEntries(),
    DashboardEntry(
      id: 'settings',
      icon: Icons.settings,
      color: Colors.grey,
      isVisible: () => ModuleAccess.canView('settings'),
      builder: (context) => DashboardCard(
        icon: Icons.settings,
        title: _t('settings', AuthService.roleAdmin),
        color: Colors.grey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
    ),
  ];
}

/// Staff-duty tiles driven by RBAC permissions (union of granted staff roles).
List<DashboardEntry> _staffModuleEntries() {
  // Reuse the admin translations so module names match the web ERP.
  const adminRole = AuthService.roleAdmin;

  DashboardEntry entry({
    required String id,
    required String titleId,
    required IconData icon,
    required Color color,
    required String moduleId,
    required Widget Function() screenBuilder,
    bool requireManage = false,
  }) {
    return DashboardEntry(
      id: id,
      icon: icon,
      color: color,
      isVisible: () => requireManage
          ? ModuleAccess.canManage(moduleId)
          : ModuleAccess.canView(moduleId),
      builder: (context) => DashboardCard(
        icon: icon,
        title: _t(titleId, adminRole),
        color: color,
        badgeCount: _badge(id),
        onTap: () => _openTile(id, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screenBuilder()),
          );
        }),
      ),
    );
  }

  return [
    entry(
      id: 'staff_students',
      titleId: 'students',
      icon: Icons.groups,
      color: Colors.indigo,
      moduleId: 'students',
      screenBuilder: () => const AdminStudentsScreen(),
    ),
    entry(
      id: 'staff_directory',
      titleId: 'staff',
      icon: Icons.badge,
      color: Colors.deepPurple,
      moduleId: 'employees',
      screenBuilder: () => const AdminStaffScreen(),
    ),
    entry(
      id: 'staff_classes',
      titleId: 'classes',
      icon: Icons.class_,
      color: Colors.blueGrey,
      moduleId: 'academic',
      screenBuilder: () => const AdminGradesScreen(),
    ),
    entry(
      id: 'staff_attendance',
      titleId: 'attendance',
      icon: Icons.fact_check,
      color: Colors.green,
      moduleId: 'attendance',
      screenBuilder: () => const AdminAttendanceReportsScreen(),
    ),
    entry(
      id: 'staff_parent_approvals',
      titleId: 'parent_approvals',
      icon: Icons.family_restroom,
      color: Colors.brown,
      moduleId: 'parents',
      requireManage: true,
      screenBuilder: () => const ParentApprovalsScreen(),
    ),
    entry(
      id: 'staff_student_affairs',
      titleId: 'student_affairs',
      icon: Icons.balance_outlined,
      color: const Color(0xFF8E24AA),
      moduleId: 'student_affairs',
      screenBuilder: () => MobileErpHost(
        title: _t('student_affairs', adminRole),
        child: const WebStudentAffairsPage(),
      ),
    ),
    entry(
      id: 'staff_qa',
      titleId: 'quality_assurance',
      icon: Icons.verified_outlined,
      color: const Color(0xFF00897B),
      moduleId: 'quality_assurance',
      screenBuilder: () => MobileErpHost(
        title: _t('quality_assurance', adminRole),
        child: const WebQaPage(),
      ),
    ),
    entry(
      id: 'staff_grades',
      titleId: 'grades',
      icon: Icons.grading,
      color: Colors.teal,
      moduleId: 'examinations',
      screenBuilder: () => const AdminGradeOverviewScreen(),
    ),
    entry(
      id: 'staff_grade_approvals',
      titleId: 'grade_approvals',
      icon: Icons.approval,
      color: Colors.deepOrange,
      moduleId: 'examinations',
      requireManage: true,
      screenBuilder: () => const GradeApprovalQueueScreen(),
    ),
    entry(
      id: 'staff_transport',
      titleId: 'transport',
      icon: Icons.directions_bus,
      color: const Color(0xFFFF8F00),
      moduleId: 'transport',
      screenBuilder: () => MobileErpHost(
        title: _t('transport', adminRole),
        child: const WebTransportDashboardPage(),
      ),
    ),
    entry(
      id: 'staff_buses',
      titleId: 'buses',
      icon: Icons.airport_shuttle_outlined,
      color: const Color(0xFFF57C00),
      moduleId: 'transport_buses',
      screenBuilder: () => MobileErpHost(
        title: _t('buses', adminRole),
        child: const WebBusesPage(),
      ),
    ),
    entry(
      id: 'staff_transfers',
      titleId: 'transfer',
      icon: Icons.swap_horiz_rounded,
      color: Colors.indigo,
      moduleId: 'transfers',
      screenBuilder: () => MobileErpHost(
        title: _t('transfer', adminRole),
        child: const WebTransfersPage(),
      ),
    ),
    entry(
      id: 'staff_finance',
      titleId: 'finance',
      icon: Icons.payments,
      color: Colors.pink,
      moduleId: 'finance',
      screenBuilder: () => MobileErpHost(
        title: _t('finance', adminRole),
        child: const WebFinanceDashboardPage(),
      ),
    ),
    entry(
      id: 'staff_campus',
      titleId: 'campus',
      icon: Icons.location_city_outlined,
      color: Colors.blueGrey,
      moduleId: 'campus',
      screenBuilder: () => MobileErpHost(
        title: _t('campus', adminRole),
        child: const WebCampusManagementPage(),
      ),
    ),
    entry(
      id: 'staff_inventory',
      titleId: 'inventory',
      icon: Icons.inventory_2_outlined,
      color: const Color(0xFF5D4037),
      moduleId: 'inventory',
      screenBuilder: () => MobileErpHost(
        title: _t('inventory', adminRole),
        child: const WebInventoryShellPage(),
      ),
    ),
    entry(
      id: 'staff_library',
      titleId: 'library',
      icon: Icons.local_library_outlined,
      color: const Color(0xFF6A1B9A),
      moduleId: 'library',
      screenBuilder: () => MobileErpHost(
        title: _t('library', adminRole),
        child: const WebLibraryPage(),
      ),
    ),
    entry(
      id: 'staff_learning_materials',
      titleId: 'learning_materials_admin',
      icon: Icons.auto_stories_outlined,
      color: const Color(0xFF4527A0),
      moduleId: 'learning_materials',
      screenBuilder: () => MobileErpHost(
        title: _t('learning_materials_admin', adminRole),
        child: const WebLearningMaterialsPage(),
      ),
    ),
    entry(
      id: 'staff_announcements',
      titleId: 'announcements',
      icon: Icons.campaign_outlined,
      color: Colors.orange,
      moduleId: 'announcements',
      screenBuilder: () => MobileErpHost(
        title: _t('announcements', adminRole),
        child: const WebAnnouncementsPage(),
      ),
    ),
    entry(
      id: 'staff_reports',
      titleId: 'reports',
      icon: Icons.analytics_outlined,
      color: Colors.teal,
      moduleId: 'reports',
      screenBuilder: () => MobileErpHost(
        title: _t('reports', adminRole),
        child: const WebReportsPage(),
      ),
    ),
    entry(
      id: 'staff_audit_log',
      titleId: 'audit_log',
      icon: Icons.history_outlined,
      color: Colors.blueGrey,
      moduleId: 'audit_log',
      screenBuilder: () => MobileErpHost(
        title: _t('audit_log', adminRole),
        child: const WebAuditLogPage(),
      ),
    ),
  ];
}

List<DashboardEntry> _parentEntries() {
  const role = AuthService.roleParent;

  void openMessages(BuildContext context) {
    _openTile('messages', () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MessagesScreen()),
      );
    });
  }

  return [
    DashboardEntry(
      id: 'children',
      icon: Icons.child_care,
      color: Colors.teal,
      builder: (context) => DashboardCard(
        icon: Icons.child_care,
        title: _t('children', role),
        color: Colors.teal,
        badgeCount: _badge('children'),
        onTap: () => _openTile('children', () => openParentChildHub(context)),
      ),
    ),
    DashboardEntry(
      id: 'attendance',
      icon: Icons.check_circle,
      color: Colors.green,
      builder: (context) => DashboardCard(
        icon: Icons.check_circle,
        title: _t('attendance', role),
        color: Colors.green,
        badgeCount: _badge('attendance'),
        onTap: () => _openTile('attendance', () => openParentAttendance(context)),
      ),
    ),
    DashboardEntry(
      id: 'homework',
      icon: Icons.assignment,
      color: Colors.cyan,
      builder: (context) => DashboardCard(
        icon: Icons.assignment,
        title: _t('homework', role),
        color: Colors.cyan,
        badgeCount: _badge('homework'),
        onTap: () => _openTile('homework', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const HomeworkScreen(mode: HomeworkViewMode.parent),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'learning_materials',
      icon: Icons.menu_book,
      color: const Color(0xFF4527A0),
      builder: (context) => DashboardCard(
        icon: Icons.menu_book,
        title: _t('learning_materials', role),
        color: const Color(0xFF4527A0),
        badgeCount: _badge('learning_materials'),
        onTap: () => _openTile('learning_materials', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LearningMaterialsScreen(
                mode: LearningMaterialsViewMode.parent,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'messages',
      icon: Icons.message,
      color: Colors.orange,
      builder: (context) => DashboardCard(
        icon: Icons.message,
        title: _t('messages', role),
        color: Colors.orange,
        badgeCount: _badge('messages'),
        onTap: () => openMessages(context),
      ),
    ),
    DashboardEntry(
      id: 'announcements',
      icon: Icons.campaign,
      color: Colors.red,
      builder: (context) => DashboardCard(
        icon: Icons.campaign,
        title: _t('announcements', role),
        color: Colors.red,
        badgeCount: _badge('announcements'),
        onTap: () => _openTile('announcements', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'student_affairs',
      icon: Icons.balance_outlined,
      color: const Color(0xFF8E24AA),
      builder: (context) => DashboardCard(
        icon: Icons.balance_outlined,
        title: _t('student_affairs', role),
        color: const Color(0xFF8E24AA),
        badgeCount: _badge('student_affairs'),
        onTap: () => _openTile('student_affairs', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ParentStudentAffairsScreen(),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'fees',
      icon: Icons.payment,
      color: Colors.indigo,
      builder: (context) => DashboardCard(
        icon: Icons.payment,
        title: _t('fees', role),
        color: Colors.indigo,
        badgeCount: _badge('fees'),
        onTap: () => _openTile('fees', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const FeesPaymentsScreen(view: FeesView.parent),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'bus',
      icon: Icons.directions_bus,
      color: Colors.blue,
      builder: (context) => DashboardCard(
        icon: Icons.directions_bus,
        title: _t('bus', role),
        color: Colors.blue,
        badgeCount: _badge('bus'),
        onTap: () => _openTile('bus', () async {
          final child = await showParentChildPicker(
            context,
            title: AppLocale.instance.strings.busTracking,
            subtitle: AppLocale.instance.strings.chooseChildSubtitle,
          );
          if (child == null || !context.mounted) return;
          final driverId = child.studentId != null
              ? TransportService.instance.driverIdForStudent(child.studentId!)
              : TransportService.instance.driverIdForChildName(child.name);
          if (driverId == null) {
            final resolvedStudentId = child.studentId ??
                StudentRegistryService.instance
                    .lookupByName(child.name)
                    ?.studentId;
            if (resolvedStudentId != null && context.mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ParentBusLinkScreen(
                    studentId: resolvedStudentId,
                    childName: child.name,
                  ),
                ),
              );
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocale.instance.strings.inviteParentNoRecord),
                ),
              );
            }
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransportLiveMapScreen(
                driverId: driverId,
                childName: child.name,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'grades',
      icon: Icons.bar_chart,
      color: Colors.deepOrange,
      builder: (context) => DashboardCard(
        icon: Icons.bar_chart,
        title: _t('grades', role),
        color: Colors.deepOrange,
        badgeCount: _badge('grades'),
        onTap: () => _openTile('grades', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GradeReportsScreen(view: GradeReportView.parent),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'calendar',
      icon: Icons.calendar_month,
      color: Colors.purple,
      builder: (context) => DashboardCard(
        icon: Icons.calendar_month,
        title: _t('calendar', role),
        color: Colors.purple,
        badgeCount: _badge('calendar'),
        onTap: () => _openTile('calendar', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CalendarScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'timetable',
      icon: Icons.calendar_view_week,
      color: Colors.brown,
      builder: (context) => DashboardCard(
        icon: Icons.calendar_view_week,
        title: _t('timetable', role),
        color: Colors.brown,
        badgeCount: _badge('timetable'),
        onTap: () => _openTile('timetable', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClassTimetableScreen(
                mode: TimetableViewMode.parent,
              ),
            ),
          );
        }),
      ),
    ),
    _mayaAssistantEntry(role),
    DashboardEntry(
      id: 'settings',
      icon: Icons.settings,
      color: Colors.grey,
      builder: (context) => DashboardCard(
        icon: Icons.settings,
        title: _t('settings', role),
        color: Colors.grey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
    ),
  ];
}

List<DashboardEntry> _studentEntries() {
  const role = AuthService.roleStudent;
  final settings = StudentAccountService.instance.settingsForSchool(
    AuthService.activeSchoolId,
  );

  return [
    DashboardEntry(
      id: 'profile',
      icon: Icons.person_outline,
      color: Colors.blueGrey,
      builder: (context) => DashboardCard(
        icon: Icons.person_outline,
        title: _t('profile', role),
        color: Colors.blueGrey,
        onTap: () => _openTile('profile', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentProfileScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'grades',
      icon: Icons.bar_chart,
      color: Colors.deepOrange,
      builder: (context) => DashboardCard(
        icon: Icons.bar_chart,
        title: _t('grades', role),
        color: Colors.deepOrange,
        badgeCount: _badge('grades'),
        onTap: () => _openTile('grades', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GradeReportsScreen(view: GradeReportView.student),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'homework',
      icon: Icons.assignment,
      color: Colors.cyan,
      builder: (context) => DashboardCard(
        icon: Icons.assignment,
        title: _t('homework', role),
        color: Colors.cyan,
        badgeCount: _badge('homework'),
        onTap: () => _openTile('homework', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const HomeworkScreen(mode: HomeworkViewMode.student),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'learning_materials',
      icon: Icons.menu_book,
      color: const Color(0xFF4527A0),
      builder: (context) => DashboardCard(
        icon: Icons.menu_book,
        title: _t('learning_materials', role),
        color: const Color(0xFF4527A0),
        onTap: () => _openTile('learning_materials', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LearningMaterialsScreen(
                mode: LearningMaterialsViewMode.student,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'attendance',
      icon: Icons.check_circle,
      color: Colors.green,
      builder: (context) => DashboardCard(
        icon: Icons.check_circle,
        title: _t('attendance', role),
        color: Colors.green,
        badgeCount: _badge('attendance'),
        onTap: () => _openTile('attendance', () => openStudentAttendance(context)),
      ),
    ),
    DashboardEntry(
      id: 'timetable',
      icon: Icons.schedule,
      color: Colors.indigo,
      builder: (context) => DashboardCard(
        icon: Icons.schedule,
        title: _t('timetable', role),
        color: Colors.indigo,
        onTap: () => _openTile('timetable', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClassTimetableScreen(
                mode: TimetableViewMode.student,
                readOnly: true,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'calendar',
      icon: Icons.calendar_month,
      color: Colors.purple,
      builder: (context) => DashboardCard(
        icon: Icons.calendar_month,
        title: _t('calendar', role),
        color: Colors.purple,
        badgeCount: _badge('calendar'),
        onTap: () => _openTile('calendar', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CalendarScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'announcements',
      icon: Icons.campaign,
      color: Colors.red,
      builder: (context) => DashboardCard(
        icon: Icons.campaign,
        title: _t('announcements', role),
        color: Colors.red,
        badgeCount: _badge('announcements'),
        onTap: () => _openTile('announcements', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'messages',
      icon: Icons.message,
      color: Colors.orange,
      isVisible: () => settings.allowStudentMessaging,
      builder: (context) => DashboardCard(
        icon: Icons.message,
        title: _t('messages', role),
        color: Colors.orange,
        badgeCount: _badge('messages'),
        onTap: () => _openTile('messages', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MessagesScreen()),
          );
        }),
      ),
    ),
    _mayaAssistantEntry(role),
    DashboardEntry(
      id: 'settings',
      icon: Icons.settings,
      color: Colors.blueGrey,
      builder: (context) => DashboardCard(
        icon: Icons.settings,
        title: _t('settings', role),
        color: Colors.blueGrey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
    ),
  ];
}

List<DashboardEntry> _adminEntries() {
  final adminName = AuthService.displayNameForRole(AuthService.roleAdmin);
  const role = AuthService.roleAdmin;

  void openMessages(BuildContext context) {
    _openTile('messages', () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const MessagesScreen(canCompose: true),
        ),
      );
    });
  }

  return [
    DashboardEntry(
      id: 'add_staff',
      icon: Icons.badge_outlined,
      color: Colors.deepPurple,
      isVisible: () => ModuleAccess.canManage('add_staff'),
      builder: (context) => DashboardCard(
        icon: Icons.badge_outlined,
        title: 'Add Administration Staff',
        color: Colors.deepPurple,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminAddTeacherScreen(
              kind: AdminPersonKind.administrationStaff,
            ),
          ),
        ),
      ),
    ),
    DashboardEntry(
      id: 'add_teacher',
      icon: Icons.person_add,
      color: Colors.indigo,
      isVisible: () => ModuleAccess.canHireStaff,
      builder: (context) => DashboardCard(
        icon: Icons.person_add,
        title: 'Add Teacher',
        color: Colors.indigo,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminAddTeacherScreen(
              kind: AdminPersonKind.classroomTeacher,
            ),
          ),
        ),
      ),
    ),
    DashboardEntry(
      id: 'add_student',
      icon: Icons.person_add_alt_1,
      color: Colors.blue,
      builder: (context) => DashboardCard(
        icon: Icons.person_add_alt_1,
        title: _t('add_student', role),
        color: Colors.blue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminAddStudentScreen()),
        ),
      ),
    ),
    DashboardEntry(
      id: 'parent_approvals',
      icon: Icons.how_to_reg,
      color: Colors.orange,
      builder: (context) => DashboardCard(
        icon: Icons.how_to_reg,
        title: _t('parent_approvals', role),
        color: Colors.orange,
        badgeCount: _badge('parent_approvals'),
        onTap: () => _openTile('parent_approvals', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ParentApprovalsScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'student_portal_settings',
      icon: Icons.school_outlined,
      color: const Color(0xFF1565C0),
      builder: (context) => DashboardCard(
        icon: Icons.school_outlined,
        title: _t('student_portal_settings', role),
        color: const Color(0xFF1565C0),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminStudentPortalSettingsScreen(),
          ),
        ),
      ),
    ),
    DashboardEntry(
      id: 'student_password_resets',
      icon: Icons.lock_reset,
      color: Colors.blueGrey,
      builder: (context) => DashboardCard(
        icon: Icons.lock_reset,
        title: _t('student_password_resets', role),
        color: Colors.blueGrey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminStudentPasswordResetScreen(),
          ),
        ),
      ),
    ),
    DashboardEntry(
      id: 'transfer',
      icon: Icons.swap_horiz_rounded,
      color: const Color(0xFF3949AB),
      builder: (context) => DashboardCard(
        icon: Icons.swap_horiz_rounded,
        title: _t('transfer', role),
        color: const Color(0xFF3949AB),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MobileErpHost(
              title: _t('transfer', role),
              child: const WebTransfersPage(),
            ),
          ),
        ),
      ),
    ),
    DashboardEntry(
      id: 'campus',
      icon: Icons.location_city_outlined,
      color: Colors.blueGrey,
      builder: (context) => DashboardCard(
        icon: Icons.location_city_outlined,
        title: _t('campus', role),
        color: Colors.blueGrey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MobileErpHost(
              title: _t('campus', role),
              child: const WebCampusManagementPage(),
            ),
          ),
        ),
      ),
    ),
    DashboardEntry(
      id: 'staff',
      icon: Icons.badge,
      color: Colors.indigo,
      builder: (context) => DashboardCard(
        icon: Icons.badge,
        title: _t('staff', role),
        color: Colors.indigo,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminStaffScreen()),
        ),
      ),
    ),
    DashboardEntry(
      id: 'students',
      icon: Icons.groups_outlined,
      color: Colors.blue,
      builder: (context) => DashboardCard(
        icon: Icons.groups_outlined,
        title: _t('students', role),
        color: Colors.blue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminStudentsScreen()),
        ),
      ),
    ),
    DashboardEntry(
      id: 'classes',
      icon: Icons.class_,
      color: Colors.teal,
      builder: (context) => DashboardCard(
        icon: Icons.class_,
        title: _t('classes', role),
        color: Colors.teal,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminGradesScreen()),
        ),
      ),
    ),
    DashboardEntry(
      id: 'attendance',
      icon: Icons.check_circle,
      color: Colors.green,
      builder: (context) => DashboardCard(
        icon: Icons.check_circle,
        title: _t('attendance', role),
        color: Colors.green,
        badgeCount: _badge('attendance'),
        onTap: () => _openTile('attendance', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminAttendanceReportsScreen(),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'messages',
      icon: Icons.message,
      color: Colors.orange,
      builder: (context) => DashboardCard(
        icon: Icons.message,
        title: _t('messages', role),
        color: Colors.orange,
        badgeCount: _badge('messages'),
        onTap: () => openMessages(context),
      ),
    ),
    DashboardEntry(
      id: 'announcements',
      icon: Icons.campaign,
      color: Colors.red,
      builder: (context) => DashboardCard(
        icon: Icons.campaign,
        title: _t('announcements', role),
        color: Colors.red,
        badgeCount: _badge('announcements'),
        onTap: () => _openTile('announcements', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnnouncementsScreen(
                canCreate: true,
                authorName: adminName,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'finance',
      icon: Icons.payment,
      color: Colors.orange,
      builder: (context) => DashboardCard(
        icon: Icons.payment,
        title: _t('finance', role),
        color: Colors.orange,
        badgeCount: _badge('finance'),
        onTap: () => _openTile('finance', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MobileErpHost(
                title: _t('finance', role),
                child: const WebFinanceDashboardPage(),
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'transport',
      icon: Icons.directions_bus,
      color: Colors.black,
      builder: (context) => DashboardCard(
        icon: Icons.directions_bus,
        title: _t('transport', role),
        color: Colors.black,
        badgeCount: _badge('transport'),
        onTap: () => _openTile('transport', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MobileErpHost(
                title: _t('transport', role),
                child: const WebTransportDashboardPage(),
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'buses',
      icon: Icons.airport_shuttle_outlined,
      color: const Color(0xFFF57C00),
      builder: (context) => DashboardCard(
        icon: Icons.airport_shuttle_outlined,
        title: _t('buses', role),
        color: const Color(0xFFF57C00),
        onTap: () => _openTile('buses', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MobileErpHost(
                title: _t('buses', role),
                child: const WebBusesPage(),
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'inventory',
      icon: Icons.inventory_2_outlined,
      color: const Color(0xFF5D4037),
      builder: (context) => DashboardCard(
        icon: Icons.inventory_2_outlined,
        title: _t('inventory', role),
        color: const Color(0xFF5D4037),
        onTap: () => _openTile('inventory', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MobileErpHost(
                title: _t('inventory', role),
                child: const WebInventoryShellPage(),
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'library',
      icon: Icons.local_library_outlined,
      color: const Color(0xFF6A1B9A),
      builder: (context) => DashboardCard(
        icon: Icons.local_library_outlined,
        title: _t('library', role),
        color: const Color(0xFF6A1B9A),
        onTap: () => _openTile('library', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MobileErpHost(
                title: _t('library', role),
                child: const WebLibraryPage(),
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'learning_materials_admin',
      icon: Icons.auto_stories_outlined,
      color: const Color(0xFF4527A0),
      builder: (context) => DashboardCard(
        icon: Icons.auto_stories_outlined,
        title: _t('learning_materials_admin', role),
        color: const Color(0xFF4527A0),
        badgeCount: _badge('learning_materials_admin'),
        onTap: () => _openTile('learning_materials_admin', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MobileErpHost(
                title: _t('learning_materials_admin', role),
                child: const WebLearningMaterialsPage(),
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'reports',
      icon: Icons.analytics_outlined,
      color: Colors.teal,
      builder: (context) => DashboardCard(
        icon: Icons.analytics_outlined,
        title: _t('reports', role),
        color: Colors.teal,
        onTap: () => _openTile('reports', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MobileErpHost(
                title: _t('reports', role),
                child: const WebReportsPage(),
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'audit_log',
      icon: Icons.history_outlined,
      color: Colors.blueGrey,
      builder: (context) => DashboardCard(
        icon: Icons.history_outlined,
        title: _t('audit_log', role),
        color: Colors.blueGrey,
        onTap: () => _openTile('audit_log', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MobileErpHost(
                title: _t('audit_log', role),
                child: const WebAuditLogPage(),
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'system_health',
      icon: Icons.monitor_heart_outlined,
      color: Colors.redAccent,
      builder: (context) => DashboardCard(
        icon: Icons.monitor_heart_outlined,
        title: _t('system_health', role),
        color: Colors.redAccent,
        onTap: () => _openTile('system_health', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MobileErpHost(
                title: _t('system_health', role),
                child: const WebSystemHealthPage(),
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'grades',
      icon: Icons.bar_chart,
      color: Colors.deepOrange,
      builder: (context) => DashboardCard(
        icon: Icons.bar_chart,
        title: _t('grades', role),
        color: Colors.deepOrange,
        badgeCount: _badge('grades'),
        onTap: () => _openTile('grades', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminGradeOverviewScreen(),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'grade_approvals',
      icon: Icons.fact_check_outlined,
      color: Colors.deepPurple,
      builder: (context) => ListenableBuilder(
        listenable: SchoolContentSyncService.instance,
        builder: (context, _) {
          final pending = SchoolDataService.instance.pendingGradeApprovalCount(
            schoolId: AuthService.activeSchoolId,
            roleKey: role,
          );
          return DashboardCard(
            icon: Icons.fact_check_outlined,
            title: _t('grade_approvals', role),
            color: Colors.deepPurple,
            badgeCount: pending,
            onTap: () => _openTile('grade_approvals', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GradeApprovalQueueScreen(),
                ),
              );
            }),
          );
        },
      ),
    ),
    DashboardEntry(
      id: 'grade_workflow_settings',
      icon: Icons.rule,
      color: Colors.blueGrey,
      builder: (context) => DashboardCard(
        icon: Icons.rule,
        title: 'Grade workflow',
        color: Colors.blueGrey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminGradeWorkflowSettingsScreen(),
          ),
        ),
      ),
    ),
    DashboardEntry(
      id: 'calendar',
      icon: Icons.calendar_month,
      color: Colors.purple,
      builder: (context) => DashboardCard(
        icon: Icons.calendar_month,
        title: _t('calendar', role),
        color: Colors.purple,
        badgeCount: _badge('calendar'),
        onTap: () => _openTile('calendar', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CalendarScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'timetable',
      icon: Icons.calendar_view_week,
      color: Colors.brown,
      builder: (context) => DashboardCard(
        icon: Icons.calendar_view_week,
        title: _t('timetable', role),
        color: Colors.brown,
        badgeCount: _badge('timetable'),
        onTap: () => _openTile('timetable', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminTimetablesScreen()),
          );
        }),
      ),
    ),
    _mayaAssistantEntry(role),
    DashboardEntry(
      id: 'settings',
      icon: Icons.settings,
      color: Colors.grey,
      builder: (context) => DashboardCard(
        icon: Icons.settings,
        title: _t('settings', role),
        color: Colors.grey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
    ),
  ];
}

List<DashboardEntry> _driverEntries() {
  const role = AuthService.roleDriver;

  void openMessages(BuildContext context) {
    _openTile('messages', () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MessagesScreen()),
      );
    });
  }

  void openRoute(BuildContext context) {
    _openTile('route', () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const BusTrackingScreen(view: BusTrackingView.driver),
        ),
      );
    });
  }

  void openPassengers(BuildContext context) {
    _openTile('passengers', () {
      final driverId = TransportService.instance.linkedDriverId;
      if (driverId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.instance.strings.transportNoAssignedBus),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransportPassengerListScreen(driverId: driverId),
        ),
      );
    });
  }

  void openTransportScan(BuildContext context, {bool discharge = false}) {
    _openTile(discharge ? 'pickup' : 'scan', () {
      final driverId = TransportService.instance.linkedDriverId;
      if (driverId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.instance.strings.transportNoAssignedBus),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransportQrScannerScreen(
            driverId: driverId,
            initialMode: discharge
                ? TransportScanMode.discharge
                : TransportScanMode.onboard,
          ),
        ),
      );
    });
  }

  void openQr(BuildContext context) {
    _openTile('qr', () => openTransportScan(context));
  }

  void openLiveMap(BuildContext context) {
    _openTile('map', () {
      final driverId = TransportService.instance.linkedDriverId;
      if (driverId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.instance.strings.transportNoAssignedBus),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransportLiveMapScreen(
            driverId: driverId,
            autoStartDriverSharing: true,
          ),
        ),
      );
    });
  }

  return [
    DashboardEntry(
      id: 'route',
      icon: Icons.route,
      color: Colors.orange,
      builder: (context) => DashboardCard(
        icon: Icons.route,
        title: _t('route', role),
        color: Colors.orange,
        badgeCount: _badge('route'),
        onTap: () => openRoute(context),
      ),
    ),
    DashboardEntry(
      id: 'passengers',
      icon: Icons.people,
      color: Colors.blue,
      builder: (context) => DashboardCard(
        icon: Icons.people,
        title: _t('passengers', role),
        color: Colors.blue,
        badgeCount: _badge('passengers'),
        onTap: () => openPassengers(context),
      ),
    ),
    DashboardEntry(
      id: 'scan',
      icon: Icons.qr_code_scanner,
      color: Colors.black,
      builder: (context) => DashboardCard(
        icon: Icons.qr_code_scanner,
        title: _t('scan', role),
        color: Colors.black,
        badgeCount: _badge('scan'),
        onTap: () => openTransportScan(context),
      ),
    ),
    DashboardEntry(
      id: 'qr',
      icon: Icons.qr_code_2,
      color: Colors.blueGrey,
      builder: (context) => DashboardCard(
        icon: Icons.qr_code_2,
        title: _t('qr', role),
        color: Colors.blueGrey,
        badgeCount: _badge('qr'),
        onTap: () => openQr(context),
      ),
    ),
    DashboardEntry(
      id: 'pickup',
      icon: Icons.check_circle,
      color: Colors.green,
      builder: (context) => DashboardCard(
        icon: Icons.check_circle,
        title: _t('pickup', role),
        color: Colors.green,
        badgeCount: _badge('pickup'),
        onTap: () => openTransportScan(context, discharge: true),
      ),
    ),
    DashboardEntry(
      id: 'messages',
      icon: Icons.message,
      color: Colors.indigo,
      builder: (context) => DashboardCard(
        icon: Icons.message,
        title: _t('messages', role),
        color: Colors.indigo,
        badgeCount: _badge('messages'),
        onTap: () => openMessages(context),
      ),
    ),
    DashboardEntry(
      id: 'announcements',
      icon: Icons.campaign,
      color: Colors.red,
      builder: (context) => DashboardCard(
        icon: Icons.campaign,
        title: _t('announcements', role),
        color: Colors.red,
        badgeCount: _badge('announcements'),
        onTap: () => _openTile('announcements', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AnnouncementsScreen(canCreate: false),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'issue',
      icon: Icons.warning,
      color: Colors.red,
      builder: (context) => DashboardCard(
        icon: Icons.warning,
        title: _t('issue', role),
        color: Colors.red,
        badgeCount: _badge('issue'),
        onTap: () => _openTile('issue', () => ReportIssueDialog.showTransport(context)),
      ),
    ),
    DashboardEntry(
      id: 'map',
      icon: Icons.map,
      color: Colors.teal,
      builder: (context) => DashboardCard(
        icon: Icons.map,
        title: _t('map', role),
        color: Colors.teal,
        badgeCount: _badge('map'),
        onTap: () => openLiveMap(context),
      ),
    ),
    DashboardEntry(
      id: 'calendar',
      icon: Icons.calendar_month,
      color: Colors.purple,
      builder: (context) => DashboardCard(
        icon: Icons.calendar_month,
        title: _t('calendar', role),
        color: Colors.purple,
        badgeCount: _badge('calendar'),
        onTap: () => _openTile('calendar', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CalendarScreen()),
          );
        }),
      ),
    ),
    _mayaAssistantEntry(role),
    DashboardEntry(
      id: 'settings',
      icon: Icons.settings,
      color: Colors.grey,
      builder: (context) => DashboardCard(
        icon: Icons.settings,
        title: _t('settings', role),
        color: Colors.grey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
    ),
  ];
}

List<Widget> buildOrderedDashboardCards(String roleKey, BuildContext context) {
  DashboardNavigationStore.instance.clearRole(roleKey);
  final defaults = DashboardRegistry.defaultOrderFor(roleKey);
  final order = UserPreferencesService.instance.getOrder(roleKey, defaults);
  return order
      .map((id) => DashboardRegistry.find(roleKey, id))
      .whereType<DashboardEntry>()
      .where(DashboardRegistry.shouldShow)
      .map(
        (entry) => DashboardNavigationStore.instance.wrapTile(
          roleKey: roleKey,
          entryId: entry.id,
          child: entry.builder(context),
        ),
      )
      .toList();
}

List<DashboardSectionDefinition> sectionDefinitionsFor(String roleKey) {
  return switch (roleKey) {
    AuthService.roleAdmin => const [
        DashboardSectionDefinition(
          title: 'Quick actions',
          icon: Icons.flash_on,
          entryIds: ['add_staff', 'add_teacher', 'add_student', 'parent_approvals', 'student_portal_settings', 'student_password_resets'],
        ),
        DashboardSectionDefinition(
          title: 'People & enrollment',
          icon: Icons.people,
          entryIds: ['staff', 'students', 'classes', 'transfer', 'campus'],
        ),
        DashboardSectionDefinition(
          title: 'Operations',
          icon: Icons.settings_suggest,
          entryIds: [
            'attendance',
            'transport',
            'buses',
            'inventory',
            'announcements',
            'messages',
            'timetable',
          ],
        ),
        DashboardSectionDefinition(
          title: 'Resources',
          icon: Icons.menu_book_outlined,
          entryIds: ['library', 'learning_materials_admin'],
        ),
        DashboardSectionDefinition(
          title: 'Finance & reports',
          icon: Icons.insights,
          entryIds: ['finance', 'grades', 'grade_approvals', 'reports', 'calendar'],
        ),
        DashboardSectionDefinition(
          title: 'System',
          icon: Icons.shield_outlined,
          entryIds: ['audit_log', 'system_health', 'grade_workflow_settings'],
        ),
        DashboardSectionDefinition(
          title: 'Assistant',
          icon: Icons.auto_awesome,
          entryIds: ['maya_assistant'],
        ),
        DashboardSectionDefinition(
          title: 'Account',
          icon: Icons.tune,
          entryIds: ['settings'],
        ),
      ],
    AuthService.roleTeacher => [
        const DashboardSectionDefinition(
          title: 'My classroom',
          icon: Icons.class_,
          entryIds: ['classes', 'attendance', 'parent_approvals', 'student_affairs'],
        ),
        const DashboardSectionDefinition(
          title: 'Teaching tools',
          icon: Icons.menu_book,
          entryIds: ['homework', 'grades', 'timetable', 'learning_materials', 'gallery', 'qr'],
        ),
        const DashboardSectionDefinition(
          title: 'Communication',
          icon: Icons.forum,
          entryIds: ['messages', 'announcements', 'calendar'],
        ),
        const DashboardSectionDefinition(
          title: 'Assistant',
          icon: Icons.auto_awesome,
          entryIds: ['maya_assistant'],
        ),
        const DashboardSectionDefinition(
          title: 'Account',
          icon: Icons.tune,
          entryIds: ['settings'],
        ),
      ],
    AuthService.roleStaff => [
        DashboardSectionDefinition(
          title: AppLocale.instance.strings.staffDutiesSection,
          icon: Icons.admin_panel_settings,
          entryIds: const [
            'staff_students',
            'staff_directory',
            'staff_classes',
            'staff_attendance',
            'staff_parent_approvals',
            'staff_student_affairs',
            'staff_qa',
            'staff_grades',
            'staff_grade_approvals',
            'staff_transport',
            'staff_buses',
            'staff_transfers',
            'staff_finance',
            'staff_campus',
            'staff_inventory',
            'staff_library',
            'staff_learning_materials',
            'staff_announcements',
            'staff_reports',
            'staff_audit_log',
          ],
        ),
        const DashboardSectionDefinition(
          title: 'Assistant',
          icon: Icons.auto_awesome,
          entryIds: ['maya_assistant'],
        ),
        const DashboardSectionDefinition(
          title: 'Account',
          icon: Icons.tune,
          entryIds: ['settings'],
        ),
      ],
    AuthService.roleParent => const [
        DashboardSectionDefinition(
          title: 'My children',
          icon: Icons.child_care,
          entryIds: ['children', 'attendance', 'homework', 'learning_materials', 'grades', 'timetable'],
        ),
        DashboardSectionDefinition(
          title: 'School updates',
          icon: Icons.campaign,
          entryIds: ['messages', 'announcements', 'calendar'],
        ),
        DashboardSectionDefinition(
          title: 'Services',
          icon: Icons.miscellaneous_services,
          entryIds: ['student_affairs', 'fees', 'bus'],
        ),
        DashboardSectionDefinition(
          title: 'Assistant',
          icon: Icons.auto_awesome,
          entryIds: ['maya_assistant'],
        ),
        DashboardSectionDefinition(
          title: 'Account',
          icon: Icons.tune,
          entryIds: ['settings'],
        ),
      ],
    AuthService.roleDriver => const [
        DashboardSectionDefinition(
          title: 'On the road',
          icon: Icons.route,
          entryIds: ['route', 'map', 'passengers'],
        ),
        DashboardSectionDefinition(
          title: 'Student check-in',
          icon: Icons.qr_code_scanner,
          entryIds: ['scan', 'pickup', 'qr'],
        ),
        DashboardSectionDefinition(
          title: 'Communication',
          icon: Icons.forum,
          entryIds: ['messages', 'announcements', 'issue', 'calendar'],
        ),
        DashboardSectionDefinition(
          title: 'Assistant',
          icon: Icons.auto_awesome,
          entryIds: ['maya_assistant'],
        ),
        DashboardSectionDefinition(
          title: 'Account',
          icon: Icons.tune,
          entryIds: ['settings'],
        ),
      ],
    AuthService.roleStudent => const [
        DashboardSectionDefinition(
          title: 'My school',
          icon: Icons.school_outlined,
          entryIds: ['profile', 'grades', 'homework', 'learning_materials', 'attendance', 'timetable'],
        ),
        DashboardSectionDefinition(
          title: 'Updates',
          icon: Icons.campaign,
          entryIds: ['announcements', 'calendar', 'messages'],
        ),
        DashboardSectionDefinition(
          title: 'Assistant',
          icon: Icons.auto_awesome,
          entryIds: ['maya_assistant'],
        ),
        DashboardSectionDefinition(
          title: 'Account',
          icon: Icons.tune,
          entryIds: ['settings'],
        ),
      ],
    _ => const [],
  };
}

List<BuiltDashboardSection> buildGroupedDashboardSections(
  String roleKey,
  BuildContext context,
) {
  final defaults = DashboardRegistry.defaultOrderFor(roleKey);
  final order = UserPreferencesService.instance.getOrder(roleKey, defaults);
  final widgetsById = <String, Widget>{};
  DashboardNavigationStore.instance.clearRole(roleKey);
  for (final id in order) {
    final entry = DashboardRegistry.find(roleKey, id);
    if (entry != null && DashboardRegistry.shouldShow(entry)) {
      widgetsById[id] = DashboardNavigationStore.instance.wrapTile(
        roleKey: roleKey,
        entryId: entry.id,
        child: entry.builder(context),
      );
    }
  }

  final built = <BuiltDashboardSection>[];
  for (final section in sectionDefinitionsFor(roleKey)) {
    final cards = section.entryIds
        .where(widgetsById.containsKey)
        .map((id) => widgetsById[id]!)
        .toList();
    if (cards.isEmpty) continue;
    built.add(
      BuiltDashboardSection(
        title: section.title,
        icon: section.icon,
        cards: cards,
      ),
    );
  }
  return built;
}

Future<void> openParentAttendance(BuildContext context) async {
  final children = SchoolDataService.instance.getChildren();
  if (children.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No linked children found')),
    );
    return;
  }

  ChildProfile selected;
  if (children.length == 1) {
    selected = children.first;
  } else {
    final picked = await showModalBottomSheet<ChildProfile>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocale.instance.strings.dashboardTitle('attendance', roleKey: 'parent'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a child',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...children.map(
                (child) => ListTile(
                  leading: CircleAvatar(
                    child: Text(child.name.isNotEmpty ? child.name[0] : '?'),
                  ),
                  title: Text(child.name),
                  subtitle: Text('${child.className} · ${child.grade}'),
                  onTap: () => Navigator.pop(context, child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    selected = picked;
  }

  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AttendanceScreen(
        readOnly: true,
        childName: selected.name,
        initialClass: selected.className,
      ),
    ),
  );
}

Future<void> openStudentAttendance(BuildContext context) async {
  final children = SchoolDataService.instance.getChildren();
  if (children.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your attendance record is not available yet.'),
      ),
    );
    return;
  }

  final selected = children.first;
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AttendanceScreen(
        readOnly: true,
        childName: selected.name,
        initialClass: selected.className,
      ),
    ),
  );
}
