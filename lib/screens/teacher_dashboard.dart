import 'package:flutter/material.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/widgets/role_dashboard_shell.dart';

/// Classroom teacher home. Administration staff use [StaffDashboard].
class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleDashboardShell(
      roleKey: AuthService.roleTeacher,
      portalKind: 'teacher',
      welcomeEmoji: '👩‍🏫',
      groupedLayout: true,
      gradientColors: TeacherTheme.gradient,
    );
  }
}
