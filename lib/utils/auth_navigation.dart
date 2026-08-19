import 'package:flutter/material.dart';

import 'package:mayabela/screens/admin_dashboard.dart';
import 'package:mayabela/screens/admin_enrollment_screens.dart';
import 'package:mayabela/screens/driver_dashboard.dart';
import 'package:mayabela/screens/login_screen.dart';
import 'package:mayabela/screens/parent_dashboard.dart';
import 'package:mayabela/screens/staff_dashboard.dart';
import 'package:mayabela/screens/student_dashboard.dart';
import 'package:mayabela/screens/teacher_dashboard.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/utils/app_navigator.dart';
import 'package:mayabela/widgets/app_floating_chrome.dart';

class AuthNavigation {
  static Widget homeForCurrentUser() {
    final user = AuthService.currentUser;
    if (user == null) return const LoginScreen();
    // Administration staff share cloud roleKey "teacher" but must not land on
    // the classroom teacher shell — route by staffRoles instead.
    if (AuthService.isAdministrationStaff) {
      return const AppFloatingChrome(child: StaffDashboard());
    }
    return AppFloatingChrome(child: dashboardForRole(user.roleKey));
  }

  /// Ends the session and returns the user to the login screen.
  static void performLogout() {
    if (AuthService.currentUser == null) return;
    AuthService.clearSession();
    NotificationService.instance.clearForLogout();
    DashboardBadgeService.instance.clearForLogout();

    final navigator = rootNavigatorKey.currentState;
    if (navigator != null) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  static Widget dashboardForRole(String roleKey) {
    switch (roleKey) {
      case AuthService.roleStaff:
        return const StaffDashboard();
      case AuthService.roleTeacher:
        if (AuthService.isAdministrationStaff) {
          return const StaffDashboard();
        }
        return const TeacherDashboard();
      case AuthService.roleParent:
        return AuthService.isParentAccessApproved()
            ? const ParentDashboard()
            : const ParentPendingScreen();
      case AuthService.roleAdmin:
        return const AdminDashboard();
      case AuthService.roleDriver:
        return const DriverDashboard();
      case AuthService.roleStudent:
        return const StudentDashboard();
      default:
        return const LoginScreen();
    }
  }
}
