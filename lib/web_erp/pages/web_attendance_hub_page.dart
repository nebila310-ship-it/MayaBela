import 'package:flutter/material.dart';

import 'package:mayabela/screens/admin_attendance_screens.dart';
import 'package:mayabela/screens/attendance_screen.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// Teacher take-roll plus the existing daily reports, on the same register.
class WebAttendanceHubPage extends StatefulWidget {
  const WebAttendanceHubPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebAttendanceHubPage> createState() => _WebAttendanceHubPageState();
}

class _WebAttendanceHubPageState extends State<WebAttendanceHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  bool get _canView => ModuleAccess.canView('attendance');

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    if (!_canView) {
      return const Center(child: Text('You do not have access to attendance.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            narrow ? 12 : 20,
            narrow ? 12 : 20,
            narrow ? 12 : 20,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance',
                style: WebErpTheme.sectionTitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                'Teachers mark the same daily register used on mobile. '
                'Reports and absence patterns stay on this store — this is not '
                'a second attendance ledger.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              if (widget.onNavigate != null)
                TextButton(
                  onPressed: () => widget.onNavigate!('at_risk'),
                  child: const Text('Absence patterns & at-risk'),
                ),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Take attendance'),
                  Tab(text: 'Daily reports'),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              AttendanceScreen(embedded: true),
              AdminAttendanceReportsScreen(embedded: true),
            ],
          ),
        ),
      ],
    );
  }
}
