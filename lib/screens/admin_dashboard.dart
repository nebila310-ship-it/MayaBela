import 'package:flutter/material.dart';

import 'package:mayabela/web_erp/shell/web_erp_shell.dart';

/// School Admin home — same ERP modules on web and on the APK.
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebErpAdminShell();
  }
}
