import 'package:flutter/material.dart';

import 'package:mayabela/web_erp/shell/web_erp_shell.dart';

/// Administration staff home — same ERP sidebar/catalog as web, filtered by
/// [ModuleAccess]. Phone layout uses the ERP drawer instead of a second tile list.
class StaffDashboard extends StatelessWidget {
  const StaffDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebErpAdminShell();
  }
}
