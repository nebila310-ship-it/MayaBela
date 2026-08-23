import 'package:flutter/material.dart';

import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/web_erp/services/web_admin_stats_service.dart';
import 'package:mayabela/theme/classroom_palette.dart';
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
          _classroomWelcome(context),
          const SizedBox(height: 16),
          _schoolBusBanner(context),
          const SizedBox(height: 20),
          _statGrid(stats),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 1100;
              final left = Column(
                children: [
                  _tappablePanel(
                    routeId: 'attendance',
                    child: WebLineChartPanel(
                      title: 'Attendance Trends (%)',
                      values: stats.attendanceTrend,
                      ySuffix: '%',
                      color: Colors.green.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _tappablePanel(
                    routeId: 'finance',
                    child: WebLineChartPanel(
                      title: 'Revenue Graph',
                      values: stats.revenueTrend,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              );
              final right = Column(
                children: [
                  _tappablePanel(
                    routeId: 'students',
                    child: WebBarChartPanel(
                      title: 'Students by Grade',
                      data: stats.gradeBreakdown,
                    ),
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

  VoidCallback? _go(String routeId) {
    if (onNavigate == null) return null;
    if (!ModuleAccess.canView(routeId)) return null;
    return () => onNavigate!(routeId);
  }

  Widget _tappablePanel({required String routeId, required Widget child}) {
    final tap = _go(routeId);
    if (tap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(16),
        child: child,
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
            onTap: _go('students'),
          ),
          WebStatCard(
            label: 'Present Today',
            value: '${stats.studentsPresentToday}',
            icon: Icons.check_circle_outline,
            color: Colors.green,
            onTap: _go('attendance'),
          ),
          WebStatCard(
            label: 'Absent',
            value: '${stats.studentsAbsent}',
            icon: Icons.person_off_outlined,
            color: Colors.red,
            onTap: _go('attendance'),
          ),
          WebStatCard(
            label: 'Teachers',
            value: '${stats.totalTeachers}',
            icon: Icons.school_outlined,
            color: Colors.indigo,
            onTap: _go('hr'),
          ),
          WebStatCard(
            label: 'Buses Active',
            value: '${stats.busesActive}',
            icon: Icons.directions_bus_outlined,
            onTap: _go('transport'),
          ),
          WebStatCard(
            label: 'Outstanding Fees',
            value: '${stats.outstandingFees.toStringAsFixed(0)} ETB',
            icon: Icons.account_balance_wallet_outlined,
            color: Colors.orange,
            onTap: _go('finance'),
          ),
          WebStatCard(
            label: 'Revenue (Month)',
            value: '${stats.revenueThisMonth.toStringAsFixed(0)} ETB',
            icon: Icons.payments_outlined,
            color: Colors.teal,
            onTap: _go('finance'),
          ),
          WebStatCard(
            label: 'Pending Approvals',
            value: '${stats.pendingApprovals}',
            icon: Icons.pending_actions_outlined,
            color: Colors.deepPurple,
            onTap: _go('examinations') ?? _go('parents'),
          ),
          WebStatCard(
            label: 'Unread Announcements',
            value: '${stats.unreadAnnouncements}',
            icon: Icons.campaign_outlined,
            onTap: _go('announcements'),
          ),
          WebStatCard(
            label: 'Birthdays Today',
            value: '${stats.birthdaysToday}',
            icon: Icons.cake_outlined,
            color: Colors.pink,
            onTap: _go('students'),
          ),
          WebStatCard(
            label: 'Recent Admissions',
            value: '${stats.recentAdmissions}',
            icon: Icons.person_add_alt_1_outlined,
            onTap: _go('students'),
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

  Widget _classroomWelcome(BuildContext context) {
    final name = AuthService.displayNameForRole(AuthService.roleAdmin);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            ClassroomPalette.teal,
            ClassroomPalette.blue,
            ClassroomPalette.purple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: ClassroomPalette.teal.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: -18,
            child: Icon(
              Icons.school,
              size: 88,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, $name',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Today's summary — attendance, fees, transport, and pending approvals.",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _schoolBusBanner(BuildContext context) {
    final canDriver = ModuleAccess.canView('add_driver');
    final canGps = ModuleAccess.canView('transport_live_gps');
    if (!canDriver && !canGps) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            ClassroomPalette.green,
            Color.lerp(ClassroomPalette.green, ClassroomPalette.teal, 0.45)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: ClassroomPalette.green.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SCHOOL BUS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Register a driver, link the bus and students, then open Live GPS. '
            'The same links sit at the top of the left menu.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canDriver)
                FilledButton.icon(
                  onPressed:
                      onNavigate == null ? null : () => onNavigate!('add_driver'),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Register Driver'),
                ),
              if (canGps)
                FilledButton.tonalIcon(
                  onPressed: onNavigate == null
                      ? null
                      : () => onNavigate!('transport_live_gps'),
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('Live GPS'),
                ),
            ],
          ),
        ],
      ),
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
      if (ModuleAccess.canView('add_driver'))
        ('Register Driver', Icons.person_add_alt_1, 'add_driver'),
      if (ModuleAccess.canView('transport_live_gps'))
        ('Live GPS', Icons.gps_fixed, 'transport_live_gps'),
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
            _summaryRow(
              context,
              'Attendance rate',
              '${stats.studentsPresentToday} present',
              routeId: 'attendance',
            ),
            _summaryRow(
              context,
              'Fee collection',
              '${stats.revenueToday.toStringAsFixed(0)} ETB today',
              routeId: 'finance',
            ),
            _summaryRow(
              context,
              'Transport',
              '${stats.busesActive} buses active',
              routeId: 'transport',
            ),
            _summaryRow(
              context,
              'Approvals',
              '${stats.pendingApprovals} pending',
              routeId: 'examinations',
            ),
            _summaryRow(
              context,
              'Exams',
              '${stats.upcomingExams} upcoming',
              routeId: 'examinations',
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    String? routeId,
  }) {
    final tap = routeId == null ? null : _go(routeId);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (tap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
          ],
        ],
      ),
    );
    if (tap == null) return row;
    return InkWell(onTap: tap, child: row);
  }

  Widget _linkedTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String routeId,
  }) {
    final tap = _go(routeId);
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: tap == null ? null : const Icon(Icons.chevron_right),
        onTap: tap,
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
          _linkedTile(
            icon: Icons.person_add,
            title: 'New student enrollment',
            subtitle: 'Review admissions in Students module',
            routeId: 'students',
          ),
          _linkedTile(
            icon: Icons.payment,
            title: 'Fee payment received',
            subtitle: 'Check Finance dashboard',
            routeId: 'finance',
          ),
          _linkedTile(
            icon: Icons.directions_bus,
            title: 'Transport check-in',
            subtitle: 'Driver completed morning route',
            routeId: 'transport',
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
            InkWell(
              onTap: _go('calendar'),
              child: Text(
                'Upcoming Events',
                style: WebErpTheme.sectionTitle(context),
              ),
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              const Text('No upcoming events')
            else
              for (final e in events)
                _linkedTile(
                  icon: Icons.event,
                  title: e.title,
                  subtitle: '${e.date.day}/${e.date.month}/${e.date.year}',
                  routeId: 'calendar',
                ),
          ],
        ),
      ),
    );
  }
}
