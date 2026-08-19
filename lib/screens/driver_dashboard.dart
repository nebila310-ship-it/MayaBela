import 'package:flutter/material.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/widgets/role_dashboard_shell.dart';

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleDashboardShell(
      roleKey: AuthService.roleDriver,
      portalKind: 'driver',
      welcomeEmoji: '🚌',
      groupedLayout: true,
      gradientColors: [
        Color(0xFFE65100),
        Color(0xFFF57C00),
        Color(0xFFFFB74D),
      ],
    );
  }
}
