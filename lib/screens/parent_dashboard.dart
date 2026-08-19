import 'package:flutter/material.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/widgets/role_dashboard_shell.dart';

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleDashboardShell(
      roleKey: AuthService.roleParent,
      portalKind: 'parent',
      welcomeEmoji: '👨‍👩‍👧',
      groupedLayout: true,
      gradientColors: [
        Color(0xFF00695C),
        Color(0xFF00897B),
        Color(0xFF26A69A),
      ],
    );
  }
}
