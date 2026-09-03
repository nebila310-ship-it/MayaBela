import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/screens/admin_dashboard.dart';
import 'package:mayabela/screens/staff_dashboard.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/web_erp/router/web_erp_router.dart';
import 'package:mayabela/web_erp/shell/web_erp_shell.dart';

void main() {
  tearDown(() {
    AuthService.currentUser = null;
  });

  void signInAdmin() {
    AuthService.currentUser = RegisteredUser(
      username: 'parity.admin',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
  }

  testWidgets('Admin dashboard is the ERP shell on every platform', (tester) async {
    signInAdmin();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(const AdminDashboard().build(context), isA<WebErpAdminShell>());
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('Staff dashboard is the same ERP shell', (tester) async {
    AuthService.currentUser = RegisteredUser(
      username: 'parity.staff',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const ['human_resource'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(const StaffDashboard().build(context), isA<WebErpAdminShell>());
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  test('admin nav includes the APK admin modules', () {
    signInAdmin();
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    for (final id in [
      'add_driver',
      'transport_live_gps',
      'transport',
      'hr',
      'students',
      'add_student',
      'add_teacher',
      'add_staff',
      'student_affairs',
      'student_portal_settings',
      'student_password_resets',
      'grade_workflow_settings',
      'timetable',
      'quality_assurance',
      'classroom_teachers',
      'staff_roles',
      'cctv',
    ]) {
      expect(ids.contains(id), isTrue, reason: 'missing shared module $id');
    }
    expect(ids.contains('admissions'), isTrue);
    expect(ids.contains('alumni'), isTrue);
    expect(ids.contains('markbook'), isTrue);
    expect(ids.contains('report_cards'), isTrue);
    expect(ids.contains('exam_bank'), isTrue);
    expect(ids.contains('lesson_plans'), isTrue);
    expect(ids.contains('curriculum'), isTrue);
    expect(ids.contains('at_risk'), isTrue);
    expect(ids.contains('student_support'), isTrue);
    expect(ids.contains('safeguarding'), isTrue);
    expect(ids.contains('student_programs'), isTrue);
    expect(ids.contains('go_live'), isTrue);
  });

  test('router opens every admin nav item', () {
    signInAdmin();
    for (final item in webErpNavItemsForCurrentUser()) {
      if (item.isLogout) continue;
      expect(
        WebErpRouter.pageFor(item.id),
        isA<Widget>(),
        reason: 'unresolved ${item.id}',
      );
    }
  });
}
