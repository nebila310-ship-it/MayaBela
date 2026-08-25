import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/session_cloud_sync.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/widgets/role_dashboard_shell.dart';

/// Classroom teacher home. Administration staff use [StaffDashboard].
class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(SessionCloudSync.awaitRoleCloudSync());
    });
  }

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
