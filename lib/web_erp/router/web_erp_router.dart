import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/screens/admin_attendance_screens.dart';
import 'package:mayabela/screens/admin_classes_screens.dart';
import 'package:mayabela/screens/admin_enrollment_screens.dart';
import 'package:mayabela/screens/admin_grade_overview_screen.dart';
import 'package:mayabela/screens/admin_grade_workflow_settings_screen.dart';
import 'package:mayabela/screens/admin_student_password_reset_screen.dart';
import 'package:mayabela/screens/admin_student_portal_settings_screen.dart';
import 'package:mayabela/screens/class_timetable_screen.dart';
import 'package:mayabela/screens/grade_approval_queue_screen.dart';
import 'package:mayabela/screens/maya_assistant_screen.dart';
import 'package:mayabela/screens/messages_screen.dart';
import 'package:mayabela/screens/settings_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/web_erp/pages/inventory/web_inventory_shell_page.dart';
import 'package:mayabela/web_erp/pages/staff_role_home_page.dart';
import 'package:mayabela/web_erp/pages/web_admissions_page.dart';
import 'package:mayabela/web_erp/pages/web_markbook_page.dart';
import 'package:mayabela/web_erp/pages/web_report_cards_page.dart';
import 'package:mayabela/web_erp/pages/web_exam_desk_page.dart';
import 'package:mayabela/web_erp/pages/web_lesson_plans_page.dart';
import 'package:mayabela/web_erp/pages/web_curriculum_page.dart';
import 'package:mayabela/web_erp/pages/web_attendance_intelligence_page.dart';
import 'package:mayabela/web_erp/pages/web_alumni_page.dart';
import 'package:mayabela/web_erp/pages/web_admin_overview_page.dart';
import 'package:mayabela/web_erp/pages/web_announcements_page.dart';
import 'package:mayabela/web_erp/pages/web_audit_log_page.dart';
import 'package:mayabela/web_erp/pages/web_buses_page.dart';
import 'package:mayabela/web_erp/pages/web_calendar_page.dart';
import 'package:mayabela/web_erp/pages/web_campus_management_page.dart';
import 'package:mayabela/web_erp/pages/web_erp_placeholder_page.dart';
import 'package:mayabela/web_erp/pages/web_finance_dashboard_page.dart';
import 'package:mayabela/web_erp/pages/web_institution_page.dart';
import 'package:mayabela/web_erp/pages/web_learning_materials_page.dart';
import 'package:mayabela/web_erp/pages/web_library_page.dart';
import 'package:mayabela/web_erp/pages/web_reports_page.dart';
import 'package:mayabela/web_erp/pages/web_school_management_page.dart';
import 'package:mayabela/web_erp/pages/staff_role_config_page.dart';
import 'package:mayabela/web_erp/pages/web_students_table_page.dart';
import 'package:mayabela/web_erp/pages/web_system_health_page.dart';
import 'package:mayabela/web_erp/pages/web_hr_hub_page.dart';
import 'package:mayabela/web_erp/pages/web_qa_page.dart';
import 'package:mayabela/web_erp/pages/web_student_affairs_page.dart';
import 'package:mayabela/web_erp/pages/web_student_support_page.dart';
import 'package:mayabela/web_erp/pages/web_student_programs_page.dart';
import 'package:mayabela/web_erp/pages/web_teachers_table_page.dart';
import 'package:mayabela/web_erp/pages/web_transfers_page.dart';
import 'package:mayabela/web_erp/pages/web_hr_register_driver_page.dart';
import 'package:mayabela/web_erp/pages/web_transport_dashboard_page.dart';
import 'package:mayabela/web_erp/pages/web_cctv_page.dart';
import 'package:mayabela/web_erp/pages/web_transport_live_gps_page.dart';

/// Maps ERP route ids to page widgets (web shell content area).
class WebErpRouter {
  static Widget pageFor(String routeId, {ValueChanged<String>? onNavigate}) {
    // Safety net behind the sidebar filter: stale favorites, search results
    // or manual navigation can still request modules the user cannot open.
    const mutationRoutes = {
      'add_student',
      'add_teacher',
      'add_staff',
      'add_driver',
    };
    if (!ModuleAccess.canView(routeId) ||
        (mutationRoutes.contains(routeId) &&
            !ModuleAccess.canManage(routeId))) {
      final s = AppLocale.instance.strings;
      return WebErpPlaceholderPage(
        title: s.moduleAccessDeniedTitle,
        description: s.moduleAccessDeniedBody,
        icon: Icons.lock_outline,
      );
    }
    switch (routeId) {
      case 'dashboard':
        if (AuthService.isAdministrationStaff) {
          return StaffRoleHomePage(onNavigate: onNavigate);
        }
        return _safePage(
          () => WebAdminOverviewPage(onNavigate: onNavigate),
          title: 'Dashboard',
        );
      case 'students':
        return WebStudentsTablePage(onNavigate: onNavigate);
      case 'admissions':
        return WebAdmissionsPage(onNavigate: onNavigate);
      case 'alumni':
        return const WebAlumniPage();
      case 'transfers':
        return const WebTransfersPage();
      case 'hr':
      case 'employees':
      case 'staff':
        return WebHrHubPage(onNavigate: onNavigate);
      case 'teachers':
        return WebTeachersTablePage(
          onNavigate: onNavigate,
          directoryMode: WebTeachersDirectoryMode.administrationStaff,
        );
      case 'classroom_teachers':
        return WebTeachersTablePage(
          onNavigate: onNavigate,
          directoryMode: WebTeachersDirectoryMode.classroomTeachers,
        );
      case 'parents':
        return const ParentApprovalsScreen();
      case 'student_affairs':
        return const WebStudentAffairsPage();
      case 'student_support':
      case 'health':
      case 'counseling':
      case 'iep':
      case 'college_guidance':
        return WebStudentSupportPage(onNavigate: onNavigate);
      case 'safeguarding':
        return WebStudentSupportPage(
          safeguardingOnly: true,
          onNavigate: onNavigate,
        );
      case 'student_programs':
      case 'clubs':
      case 'gojo':
      case 'scholarships':
      case 'grievances':
      case 'internships':
      case 'leadership_meetings':
      case 'dosa':
        return WebStudentProgramsPage(onNavigate: onNavigate);
      case 'quality_assurance':
      case 'surveys':
      case 'qa_surveys':
      case 'observations':
      case 'academic_audits':
      case 'action_research':
      case 'academic_monitoring':
        return const WebQaPage();
      case 'finance':
        return const WebFinanceDashboardPage();
      case 'transport':
        return WebTransportDashboardPage(onNavigate: onNavigate);
      case 'attendance':
        return const AdminAttendanceReportsScreen();
      case 'at_risk':
      case 'attendance_insights':
        return WebAttendanceIntelligencePage(onNavigate: onNavigate);
      case 'examinations':
      case 'grade_approvals':
        return const GradeApprovalQueueScreen();
      case 'markbook':
        return WebMarkbookPage(onNavigate: onNavigate);
      case 'report_cards':
        return WebReportCardsPage(onNavigate: onNavigate);
      case 'exam_bank':
      case 'exam_papers':
      case 'exam_desk':
        return WebExamDeskPage(onNavigate: onNavigate);
      case 'grades':
        return const AdminGradeOverviewScreen();
      case 'academic':
        return const AdminGradesScreen();
      case 'learning_materials':
        return const WebLearningMaterialsPage();
      case 'announcements':
        return const WebAnnouncementsPage();
      case 'events':
      case 'calendar':
        return const WebCalendarPage();
      case 'reports':
        return const WebReportsPage();
      case 'support':
        return const MessagesScreen(canCompose: true);
      case 'maya_assistant':
        return MayaAssistantScreen(
          roleKey: AuthService.currentUser?.roleKey ?? AuthService.roleAdmin,
        );
      case 'audit_log':
        return const WebAuditLogPage();
      case 'staff_roles':
        return const StaffRoleConfigPage();
      case 'system_health':
        return const WebSystemHealthPage();
      case 'settings':
      case 'profile':
        return const SettingsScreen();
      case 'add_student':
        return const AdminAddStudentScreen();
      case 'add_staff':
        return const AdminAddTeacherScreen(
          kind: AdminPersonKind.administrationStaff,
        );
      case 'add_teacher':
        return const AdminAddTeacherScreen(
          kind: AdminPersonKind.classroomTeacher,
        );
      case 'institution':
        return const WebInstitutionPage();
      case 'school':
        return const WebSchoolManagementPage();
      case 'campus':
        return const WebCampusManagementPage();
      case 'cctv':
        return const WebCctvPage();
      case 'library':
        return const WebLibraryPage();
      case 'inventory':
        return const WebInventoryShellPage();
      case 'transport_buses':
        return const WebBusesPage();
      case 'transport_live_gps':
        return WebTransportLiveGpsPage(onNavigate: onNavigate);
      case 'add_driver':
        return WebHrRegisterDriverPage(onNavigate: onNavigate);
      case 'student_portal_settings':
        return const AdminStudentPortalSettingsScreen();
      case 'student_password_resets':
        return const AdminStudentPasswordResetScreen();
      case 'grade_workflow_settings':
        return const AdminGradeWorkflowSettingsScreen();
      case 'timetable':
        return const AdminTimetablesScreen();
      case 'lesson_plans':
      case 'lessons':
        return WebLessonPlansPage(onNavigate: onNavigate);
      case 'curriculum':
      case 'academic_meetings':
        return WebCurriculumPage(onNavigate: onNavigate);
      default:
        return WebErpPlaceholderPage(
          title: routeId,
          description: 'This module is not yet configured.',
          icon: Icons.construction_outlined,
        );
    }
  }

  /// Prevents a single page layout/build crash from wiping the whole ERP shell.
  static Widget _safePage(Widget Function() build, {required String title}) {
    try {
      return build();
    } catch (e, st) {
      assert(() {
        debugPrint('[WebErpRouter] $title failed: $e\n$st');
        return true;
      }());
      return WebErpPlaceholderPage(
        title: title,
        description: 'This page failed to load. Try another module from the sidebar.\n$e',
        icon: Icons.error_outline,
      );
    }
  }
}
