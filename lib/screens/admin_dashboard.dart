import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/web_erp/shell/web_erp_shell.dart';
import 'package:mayabela/widgets/role_dashboard_shell.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WebErpAdminShell();
    }

    return const RoleDashboardShell(
      roleKey: AuthService.roleAdmin,
      portalKind: 'admin',
      welcomeEmoji: '🏫',
      groupedLayout: true,
      gradientColors: [
        Color(0xFF4527A0),
        Color(0xFF5E35B1),
        Color(0xFF7E57C2),
      ],
    );
  }
}
