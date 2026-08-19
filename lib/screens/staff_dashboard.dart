import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/web_erp/shell/web_erp_shell.dart';
import 'package:mayabela/widgets/role_dashboard_shell.dart';

/// Home for administration / custom staff roles (`staffRoles` on a teacher
/// account). Classroom teachers use [TeacherDashboard] instead.
class StaffDashboard extends StatelessWidget {
  const StaffDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Web ERP sidebar is already filtered by ModuleAccess / staffPermissions.
    if (kIsWeb) {
      return const WebErpAdminShell();
    }

    return const RoleDashboardShell(
      roleKey: AuthService.roleStaff,
      portalKind: 'staff',
      welcomeEmoji: '🗂️',
      groupedLayout: true,
      gradientColors: [
        Color(0xFF1B4F72),
        Color(0xFF2874A6),
        Color(0xFF5DADE2),
      ],
    );
  }
}
