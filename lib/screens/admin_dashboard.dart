import 'package:flutter/material.dart';

import 'package:mayabela/web_erp/shell/web_erp_shell.dart';

/// School owner home — same ERP catalog as the web app (phone uses a drawer).
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebErpAdminShell();
  }
}
