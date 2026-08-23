import 'package:flutter/material.dart';

import 'package:mayabela/web_erp/shell/web_erp_shell.dart';

/// Home for administration / custom staff roles (`staffRoles` on a teacher
/// account). Classroom teachers use [TeacherDashboard] instead.
///
/// Same ERP sidebar as web. [ModuleAccess] hides modules the role cannot open.
class StaffDashboard extends StatelessWidget {
  const StaffDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebErpAdminShell();
  }
}
