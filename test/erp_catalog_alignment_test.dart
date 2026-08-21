import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/screens/admin_dashboard.dart';
import 'package:mayabela/screens/staff_dashboard.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/setup/dashboard_setup.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/web_erp/router/web_erp_router.dart';
import 'package:mayabela/web_erp/shell/web_erp_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    registerAllDashboards();
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  void signInAdmin() {
    AuthService.currentUser = RegisteredUser(
      username: 'erp.owner',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
  }

  void signInStaff(List<String> staffRoles) {
    AuthService.currentUser = RegisteredUser(
      username: 'erp.staff',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: staffRoles,
    );
  }

  List<String> visibleTileIds(String roleKey) =>
      DashboardRegistry.visibleEntriesFor(roleKey).map((e) => e.id).toList();

  List<String> sidebarModuleIds() =>
      webErpModuleNavItemsForCurrentUser().map((e) => e.id).toList();

  group('APK admin/staff home uses ERP shell', () {
    testWidgets('owner and staff dashboards return the ERP shell', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(
                const AdminDashboard().build(context),
                isA<WebErpAdminShell>(),
              );
              expect(
                const StaffDashboard().build(context),
                isA<WebErpAdminShell>(),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  group('Admin/staff tiles match the web ERP catalog', () {
    test('owner tiles use the same module ids as the sidebar', () {
      signInAdmin();
      expect(visibleTileIds(AuthService.roleAdmin), sidebarModuleIds());
      expect(visibleTileIds(AuthService.roleStaff), sidebarModuleIds());
    });

    test('staff tiles follow ModuleAccess, not a shorter APK catalog', () {
      signInStaff(const [StaffRoles.registrar]);
      final ids = visibleTileIds(AuthService.roleStaff).toSet();
      expect(ids, sidebarModuleIds().toSet());
      expect(ids, isNot(contains('staff_students')));
      expect(ids, contains('students'));
      expect(ids, isNot(contains('add_student')));
    });

    test('APK-only tools stay inside parent ERP modules', () {
      signInAdmin();
      final sidebar = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
      for (final extra in [
        'student_portal_settings',
        'student_password_resets',
        'grade_workflow_settings',
        'timetable',
        'add_staff',
        'add_teacher',
        'add_student',
      ]) {
        expect(sidebar.contains(extra), isFalse, reason: extra);
        expect(WebErpRouter.pageFor(extra), isA<Widget>(), reason: extra);
      }
    });
  });
}
