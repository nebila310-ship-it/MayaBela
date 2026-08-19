import 'package:flutter/material.dart';

import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/web_erp/services/web_admin_stats_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/widgets/web_chart_widgets.dart';
import 'package:mayabela/web_erp/widgets/web_stat_card.dart';

class WebAdminOverviewPage extends StatelessWidget {
  const WebAdminOverviewPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final stats = WebAdminStatsService.instance.load();
    final events = SchoolDataService.instance.getCalendarEvents().take(5);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${AuthService.displayNameForRole(AuthService.roleAdmin)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            "Today's summary — attendance, fees, transport, and pending approvals.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          _statGrid(stats),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 1100;
              final left = Column(
                children: [
                  WebLineChartPanel(
                    title: 'Attendance Trends (%)',
                    values: stats.attendanceTrend,
                    ySuffix: '%',
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(height: 16),
                  WebLineChartPanel(
                    title: 'Revenue Graph',
                    values: stats.revenueTrend,
                    color: Colors.orange.shade700,
                  ),
                ],
              );
              final right = Column(
                children: [
                  WebBarChartPanel(
                    title: 'Students by Grade',
                    data: stats.gradeBreakdown,
                  ),
                  const SizedBox(height: 16),
                  _quickActions(context),
                  const SizedBox(height: 16),
                  _todaySummary(stats),
                ],
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: left),
                    const SizedBox(width: 16),
                    Expanded(child: right),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  left,
                  const SizedBox(height: 16),
                  right,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final stacked = c.maxWidth < 700;
              final activity = _recentActivity(context);
              final upcoming = _upcoming(events.toList());
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    activity,
                    const SizedBox(height: 16),
                    upcoming,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: activity),
                  const SizedBox(width: 16),
                  Expanded(child: upcoming),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statGrid(WebAdminStats stats) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 1200
            ? 6
            : c.maxWidth > 900
                ? 4
                : c.maxWidth > 600
                    ? 3
                    : 2;
        final cards = [
          WebStatCard(
            label: 'Total Students',
            value: '${stats.totalStudents}',
            icon: Icons.groups_outlined,
            color: Colors.blue,
          ),
          WebStatCard(
            label: 'Present Today',
            value: '${stats.studentsPresentToday}',
            icon: Icons.check_circle_outline,
            color: Colors.green,
          ),
          WebStatCard(
            label: 'Absent',
            value: '${stats.studentsAbsent}',
            icon: Icons.person_off_outlined,
            color: Colors.red,
          ),
          WebStatCard(
            label: 'Teachers',
            value: '${stats.totalTeachers}',
            icon: Icons.school_outlined,
            color: Colors.indigo,
          ),
          WebStatCard(
            label: 'Buses Active',
            value: '${stats.busesActive}',
            icon: Icons.directions_bus_outlined,
          ),
          WebStatCard(
            label: 'Outstanding Fees',
            value: '${stats.outstandingFees.toStringAsFixed(0)} ETB',
            icon: Icons.account_balance_wallet_outlined,
            color: Colors.orange,
          ),
          WebStatCard(
            label: 'Revenue (Month)',
            value: '${stats.revenueThisMonth.toStringAsFixed(0)} ETB',
            icon: Icons.payments_outlined,
            color: Colors.teal,
          ),
          WebStatCard(
            label: 'Pending Approvals',
            value: '${stats.pendingApprovals}',
            icon: Icons.pending_actions_outlined,
            color: Colors.deepPurple,
          ),
          WebStatCard(
            label: 'Unread Announcements',
            value: '${stats.unreadAnnouncements}',
            icon: Icons.campaign_outlined,
          ),
          WebStatCard(
            label: 'Birthdays Today',
            value: '${stats.birthdaysToday}',
            icon: Icons.cake_outlined,
            color: Colors.pink,
          ),
          WebStatCard(
            label: 'Recent Admissions',
            value: '${stats.recentAdmissions}',
            icon: Icons.person_add_alt_1_outlined,
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 84,
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) => cards[i],
        );
      },
    );
  }

  Widget _quickActions(BuildContext context) {
    final actions = <(String, IconData, String)>[
      if (ModuleAccess.canManage('add_student'))
        ('Add Student', Icons.person_add_alt_1, 'add_student'),
      if (ModuleAccess.canManage('add_staff'))
        ('Add Administration Staff', Icons.badge, 'add_staff'),
      if (ModuleAccess.canHireStaff)
        ('Add Teacher', Icons.person_add, 'add_teacher'),
      if (ModuleAccess.canView('attendance'))
        ('Attendance', Icons.check_circle, 'attendance'),
      if (ModuleAccess.canManage('finance'))
        ('Collect Fees', Icons.payments, 'finance'),
      if (ModuleAccess.canManage('announcements'))
        ('Announcement', Icons.campaign, 'announcements'),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: WebErpTheme.sectionTitle(context)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, icon, route) in actions)
                ActionChip(
                  avatar: Icon(icon, size: 18),
                  label: Text(label),
                  onPressed:
                      onNavigate == null ? null : () => onNavigate!(route),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _todaySummary(WebAdminStats stats) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: WebErpTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Summary", style: WebErpTheme.sectionTitle(context)),
            const SizedBox(height: 12),
            _summaryRow(context, 'Attendance rate',
                '${stats.studentsPresentToday} present'),
            _summaryRow(context, 'Fee collection',
                '${stats.revenueToday.toStringAsFixed(0)} ETB today'),
            _summaryRow(
                context, 'Transport', '${stats.busesActive} buses active'),
            _summaryRow(context, 'Approvals',
                '${stats.pendingApprovals} pending'),
            _summaryRow(context, 'Exams', '${stats.upcomingExams} upcoming'),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _recentActivity(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activities', style: WebErpTheme.sectionTitle(context)),
          const SizedBox(height: 12),
          const ListTile(
            leading: Icon(Icons.person_add),
            title: Text('New student enrollment'),
            subtitle: Text('Review admissions in Students module'),
          ),
          const ListTile(
            leading: Icon(Icons.payment),
            title: Text('Fee payment received'),
            subtitle: Text('Check Finance dashboard'),
          ),
          const ListTile(
            leading: Icon(Icons.directions_bus),
            title: Text('Transport check-in'),
            subtitle: Text('Driver completed morning route'),
          ),
        ],
      ),
    );
  }

  Widget _upcoming(List<CalendarEvent> events) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: WebErpTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upcoming Events', style: WebErpTheme.sectionTitle(context)),
            const SizedBox(height: 12),
            if (events.isEmpty)
              const Text('No upcoming events')
            else
              for (final e in events)
                ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(e.title),
                  subtitle: Text('${e.date.day}/${e.date.month}/${e.date.year}'),
                ),
          ],
        ),
      ),
    );
  }
}
