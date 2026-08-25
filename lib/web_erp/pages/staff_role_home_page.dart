import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/leave_request.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/discipline_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/inventory_service.dart';
import 'package:mayabela/services/leave_request_service.dart';
import 'package:mayabela/services/procurement_service.dart';
import 'package:mayabela/services/qa_findings_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/cloud/conversation_realtime_sync.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/services/transfer_workflow_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/theme/classroom_palette.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/widgets/staff_role_labels.dart';

/// Role-aware home for administration staff.
///
/// Every card is gated by the same [ModuleAccess] allocation that drives the
/// sidebar, so each role lands on a dashboard of exactly its own duties:
/// stats at a glance, a "needs attention" work queue, latest announcements,
/// and quick links into the allocated modules.
class StaffRoleHomePage extends StatefulWidget {
  const StaffRoleHomePage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<StaffRoleHomePage> createState() => _StaffRoleHomePageState();
}

class _StatCard {
  const _StatCard({
    required this.moduleId,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.sub = '',
  });

  final String moduleId;
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String sub;
}

class _WorkItem {
  const _WorkItem({
    required this.moduleId,
    required this.icon,
    required this.label,
    required this.count,
  });

  final String moduleId;
  final IconData icon;
  final String label;
  final int count;
}

class _StaffRoleHomePageState extends State<StaffRoleHomePage> {
  @override
  void initState() {
    super.initState();
    DisciplineService.instance.ensureLoaded();
    LeaveRequestService.instance.ensureLoaded();
    QaFindingsService.instance.ensureLoaded();
  }

  String? get _schoolId => AuthService.activeSchoolId;

  void _open(String moduleId) => widget.onNavigate?.call(moduleId);

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        DisciplineService.instance,
        LeaveRequestService.instance,
        QaFindingsService.instance,
        TransferWorkflowService.instance,
        ProcurementService.instance,
        InventoryService.instance,
        DashboardBadgeService.instance,
        EnrollmentService.instance,
        SchoolContentSyncService.instance,
        ConversationRealtimeSync.instance,
      ]),
      builder: (context, _) {
        final stats = _buildStats();
        final work = _buildWorkQueue();
        return SingleChildScrollView(
          padding: EdgeInsets.all(narrow ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _greetingHeader(context, narrow),
              if (ModuleAccess.canView('add_driver') ||
                  ModuleAccess.canView('transport_live_gps')) ...[
                const SizedBox(height: 12),
                _schoolBusBanner(context),
              ],
              const SizedBox(height: 16),
              if (stats.isNotEmpty) ...[
                Text('Today at a glance',
                    style: WebErpTheme.sectionTitle(context)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final s in stats) _statCard(context, s, narrow),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              _workQueueCard(context, work),
              const SizedBox(height: 18),
              if (narrow) ...[
                _announcementsCard(context),
                const SizedBox(height: 18),
                if (_showEvents) _eventsCard(context),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _announcementsCard(context)),
                    if (_showEvents) ...[
                      const SizedBox(width: 16),
                      Expanded(child: _eventsCard(context)),
                    ],
                  ],
                ),
              const SizedBox(height: 18),
              _quickActions(context),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _greetingHeader(BuildContext context, bool narrow) {
    final s = AppLocale.instance.strings;
    final user = AuthService.currentUser;
    final name = user?.fullName?.trim().isNotEmpty == true
        ? user!.fullName!
        : (user?.username ?? 'Staff');
    final roleKeys = user?.staffRoles ?? const <String>[];
    final displayRoles = <String>[
      for (final key in roleKeys)
        () {
          final role = SchoolRoleCatalogService.instance.lookup(key);
          return role != null
              ? staffRoleLabel(role, s)
              : key.replaceAll('_', ' ');
        }(),
    ];
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday',
    ];
    final dateLabel =
        '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(narrow ? 18 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            WebErpTheme.primary,
            WebErpTheme.primary.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $name',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: narrow ? 20 : 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dateLabel +
                      (_schoolId == null ? '' : '  ·  ${_schoolId!}'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                if (displayRoles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final label in displayRoles)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!narrow)
            const Icon(Icons.insights_rounded, color: Colors.white70, size: 64),
        ],
      ),
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────

  List<_StatCard> _buildStats() {
    final out = <_StatCard>[];
    final sid = _schoolId;
    final today = DateTime.now();

    if (ModuleAccess.canView('students')) {
      final students = sid == null
          ? StudentRegistryService.instance.getAllStudents()
          : StudentRegistryService.instance.studentsForSchool(sid);
      final active = students.where((s) => s.isActive).length;
      out.add(_StatCard(
        moduleId: 'students',
        icon: Icons.groups_outlined,
        color: Colors.indigo,
        value: '$active',
        label: 'Active students',
      ));
    }

    if (ModuleAccess.canView('attendance')) {
      final report = SchoolDataService.instance.buildDailyAttendanceReport(
        DateTime(today.year, today.month, today.day),
      );
      out.add(_StatCard(
        moduleId: 'attendance',
        icon: Icons.check_circle_outline,
        color: Colors.green,
        value: '${report.presentCount}',
        label: 'Present today',
        sub: '${report.absentCount} absent · ${report.lateCount} late',
      ));
    }

    if (ModuleAccess.canView('examinations')) {
      final pending = SchoolDataService.instance
          .pendingGradeApprovalCount(schoolId: sid);
      out.add(_StatCard(
        moduleId: 'examinations',
        icon: Icons.fact_check_outlined,
        color: Colors.deepPurple,
        value: '$pending',
        label: 'Grade approvals waiting',
      ));
    }

    if (ModuleAccess.canView('student_affairs')) {
      final cases = DisciplineService.instance.forSchool(sid);
      final open = cases.where((c) => c.isOpen).length;
      final leave = LeaveRequestService.instance
          .forSchool(sid)
          .where((r) => r.status == LeaveRequestStatus.pending)
          .length;
      out.add(_StatCard(
        moduleId: 'student_affairs',
        icon: Icons.balance_outlined,
        color: const Color(0xFF8E24AA),
        value: '$open',
        label: 'Open discipline cases',
        sub: '$leave leave requests pending',
      ));
    }

    if (ModuleAccess.canView('quality_assurance')) {
      final qa = QaFindingsService.instance.metricsForSchool(sid);
      out.add(_StatCard(
        moduleId: 'quality_assurance',
        icon: Icons.verified_outlined,
        color: const Color(0xFF00897B),
        value: '${qa.open}',
        label: 'Open QA findings',
        sub: '${qa.critical} critical · ${qa.overdue} overdue',
      ));
    }

    if (ModuleAccess.canView('finance')) {
      final pay = SchoolDataService.instance.getPaymentSummary(
        parentOnly: false,
      );
      out.add(_StatCard(
        moduleId: 'finance',
        icon: Icons.payments_outlined,
        color: Colors.teal,
        value: 'ETB ${_money(pay.totalPaid)}',
        label: 'Fees collected',
        sub: 'ETB ${_money(pay.totalDue)} outstanding',
      ));
    }

    if (ModuleAccess.canView('hr')) {
      final teachers = sid == null
          ? TeacherRegistryService.instance.getAllTeachers().length
          : TeacherRegistryService.instance.teachersForSchool(sid).length;
      final staff =
          SchoolDataService.instance.getStaffForActiveSchool().length;
      out.add(_StatCard(
        moduleId: 'hr',
        icon: Icons.badge_outlined,
        color: Colors.deepOrange,
        value: '$teachers',
        label: 'Teachers on record',
        sub: '$staff staff accounts',
      ));
    }

    if (ModuleAccess.canView('transport')) {
      final buses = BusRegistryService.instance.busesForSchool(sid).length;
      final drivers = sid == null
          ? DriverRegistryService.instance.getAllDrivers().length
          : DriverRegistryService.instance.driversForSchool(sid).length;
      out.add(_StatCard(
        moduleId: 'transport',
        icon: Icons.directions_bus_outlined,
        color: Colors.blue,
        value: '$buses',
        label: 'Buses in fleet',
        sub: '$drivers drivers',
      ));
    }

    if (ModuleAccess.canView('inventory')) {
      final inv = InventoryService.instance.dashboardStats();
      out.add(_StatCard(
        moduleId: 'inventory',
        icon: Icons.inventory_2_outlined,
        color: Colors.brown,
        value: '${inv.totalItems}',
        label: 'Inventory items',
        sub: '${inv.lowStockCount} low stock · '
            '${inv.outOfStockCount} out of stock',
      ));
    }

    if (ModuleAccess.canView('learning_materials')) {
      final materials =
          SchoolDataService.instance.learningMaterialsSnapshot().length;
      out.add(_StatCard(
        moduleId: 'learning_materials',
        icon: Icons.auto_stories_outlined,
        color: ClassroomPalette.purple,
        value: '$materials',
        label: 'e-Books & materials',
      ));
    }

    return out;
  }

  Widget _statCard(BuildContext context, _StatCard s, bool narrow) {
    return InkWell(
      onTap: () => _open(s.moduleId),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: narrow ? 165 : 210,
        padding: const EdgeInsets.all(14),
        decoration: WebErpTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(s.icon, color: s.color, size: 20),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              s.value,
              style: TextStyle(
                fontSize: narrow ? 18 : 21,
                fontWeight: FontWeight.w800,
                color: s.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              s.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (s.sub.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                s.sub,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Work queue ────────────────────────────────────────────────────────

  List<_WorkItem> _buildWorkQueue() {
    final out = <_WorkItem>[];
    final sid = _schoolId;

    void add(String moduleId, IconData icon, String label, int count) {
      if (count > 0 && ModuleAccess.canView(moduleId)) {
        out.add(_WorkItem(
          moduleId: moduleId,
          icon: icon,
          label: label,
          count: count,
        ));
      }
    }

    add(
      'examinations',
      Icons.fact_check_outlined,
      'Grade reports waiting for approval',
      SchoolDataService.instance.pendingGradeApprovalCount(schoolId: sid),
    );
    add(
      'transfers',
      Icons.swap_horiz_rounded,
      'Transfer requests pending review',
      TransferWorkflowService.instance.pendingCount,
    );
    add(
      'parents',
      Icons.family_restroom_outlined,
      'Parent link requests to approve',
      DashboardBadgeService.instance.countFor('parent_approvals'),
    );
    add(
      'student_affairs',
      Icons.balance_outlined,
      'Discipline cases still open',
      DisciplineService.instance.forSchool(sid).where((c) => c.isOpen).length,
    );
    add(
      'student_affairs',
      Icons.event_busy_outlined,
      'Leave requests awaiting decision',
      LeaveRequestService.instance
          .forSchool(sid)
          .where((r) => r.status == LeaveRequestStatus.pending)
          .length,
    );
    final qa = QaFindingsService.instance.metricsForSchool(sid);
    add(
      'quality_assurance',
      Icons.verified_outlined,
      'QA findings without resolution',
      qa.open,
    );
    add(
      'inventory',
      Icons.shopping_cart_checkout_outlined,
      'Purchase requests pending approval',
      ProcurementService.instance.pendingPurchaseCount,
    );
    add(
      'inventory',
      Icons.outbox_outlined,
      'Store issue requests pending',
      ProcurementService.instance.pendingIssueCount,
    );
    add(
      'support',
      Icons.forum_outlined,
      'Unread messages',
      DashboardBadgeService.instance.countFor('messages'),
    );
    return out;
  }

  Widget _workQueueCard(BuildContext context, List<_WorkItem> items) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pending_actions_outlined, color: WebErpTheme.primary),
              const SizedBox(width: 8),
              Text('Needs your attention',
                  style: WebErpTheme.sectionTitle(context)),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Row(
              children: [
                Icon(Icons.task_alt, color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'All clear — nothing is waiting on you right now.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            )
          else
            for (final item in items)
              InkWell(
                onTap: () => _open(item.moduleId),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(item.icon, size: 20, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item.label)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${item.count}',
                          style: TextStyle(
                            color: scheme.onErrorContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: scheme.outline,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  // ── Announcements & events ────────────────────────────────────────────

  Widget _announcementsCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final role = AuthService.currentUser?.roleKey;
    final items = SchoolDataService.instance.getAnnouncementsForRole(role);
    final latest = [...items]..sort((a, b) => b.date.compareTo(a.date));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_outlined, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Latest announcements',
                  style: WebErpTheme.sectionTitle(context),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => _open('announcements'),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (latest.isEmpty)
            Text(
              'No announcements yet.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            for (final Announcement a in latest.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      a.isPinned
                          ? Icons.push_pin
                          : Icons.notifications_none_rounded,
                      size: 18,
                      color: a.isPinned ? Colors.orange : scheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _dateLabel(a.date),
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  bool get _showEvents =>
      ModuleAccess.canView('events') || ModuleAccess.canView('calendar');

  Widget _eventsCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final upcoming = SchoolDataService.instance
        .getCalendarEvents()
        .where((e) => !e.date.isBefore(DateTime(today.year, today.month,
            today.day)))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_outlined, color: Colors.blue),
              const SizedBox(width: 8),
              Text('Upcoming events', style: WebErpTheme.sectionTitle(context)),
              const Spacer(),
              TextButton(
                onPressed: () => _open('calendar'),
                child: const Text('Calendar'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (upcoming.isEmpty)
            Text(
              'No upcoming events scheduled.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            for (final CalendarEvent e in upcoming.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _dateLabel(e.date),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _schoolBusBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            ClassroomPalette.green,
            Color.lerp(ClassroomPalette.green, ClassroomPalette.teal, 0.4)!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SCHOOL BUS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (ModuleAccess.canView('add_driver'))
                FilledButton.icon(
                  onPressed: () => _open('add_driver'),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Register Driver'),
                ),
              if (ModuleAccess.canView('transport_live_gps'))
                FilledButton.tonalIcon(
                  onPressed: () => _open('transport_live_gps'),
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('Live GPS'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Quick actions ─────────────────────────────────────────────────────

  Widget _quickActions(BuildContext context) {
    const skip = {
      'dashboard',
      'settings',
      'profile',
      'logout',
      'maya_assistant',
      'announcements',
    };
    final preferred = ['add_driver', 'transport_live_gps', 'transport', 'hr'];
    final visible = webErpNavItemsForCurrentUser()
        .where((i) => !i.isLogout && !skip.contains(i.id))
        .toList();
    visible.sort((a, b) {
      final ai = preferred.indexOf(a.id);
      final bi = preferred.indexOf(b.id);
      if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
      if (ai >= 0) return -1;
      if (bi >= 0) return 1;
      return 0;
    });
    final items = visible.take(8).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick actions', style: WebErpTheme.sectionTitle(context)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              ActionChip(
                avatar: Icon(item.icon, size: 18, color: WebErpTheme.primary),
                label: Text(item.label),
                onPressed: () => _open(item.id),
              ),
          ],
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  static String _money(double v) {
    final text = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buf.write(',');
      buf.write(text[i]);
    }
    return buf.toString();
  }

  static String _dateLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}
