import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/school_class.dart';
import 'package:mayabela/screens/attendance_screen.dart';
import 'package:mayabela/screens/calendar_screen.dart';
import 'package:mayabela/screens/daily_activities_screen.dart';
import 'package:mayabela/screens/fees_payments_screen.dart';
import 'package:mayabela/screens/gallery_screen.dart';
import 'package:mayabela/screens/grade_reports_screen.dart';
import 'package:mayabela/screens/homework_screen.dart';
import 'package:mayabela/screens/parent_compose_message_screen.dart';
import 'package:mayabela/screens/transport_live_map_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_student_qr_actions.dart';
import 'package:mayabela/widgets/parent_bus_link_card.dart';
import 'package:mayabela/widgets/parent_child_picker.dart';

class MyChildrenScreen extends StatelessWidget {
  const MyChildrenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final children = SchoolDataService.instance.getChildren();

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          backgroundColor: ParentChildPalette.surface,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 140,
                pinned: true,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    s.myChildrenScreen,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: ParentChildPalette.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: listPagePadding(context),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final child = children[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ChildListCard(
                          child: child,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChildDetailScreen(child: child),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: children.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChildListCard extends StatelessWidget {
  const _ChildListCard({required this.child, required this.onTap});

  final ChildProfile child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final data = SchoolDataService.instance;
    final rank = child.studentId != null
        ? data.rankForStudentId(child.studentId!, child.className)
        : data.rankForStudent(child.name, child.className);
    final attendance = (child.attendanceRate * 100).round();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      shadowColor: ParentChildPalette.primary.withValues(alpha: 0.15),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ParentChildPalette.secondary.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: ParentChildPalette.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _ChildAvatar(name: child.name, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.childSummaryLine(
                        child.grade,
                        child.displaySection,
                        child.teacher,
                      ),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    s.attendanceThisTerm(attendance),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                      fontSize: 13,
                    ),
                  ),
                  if (rank != null)
                    Text(
                      s.rankNumber(rank),
                      style: const TextStyle(
                        fontSize: 11,
                        color: ParentChildPalette.deep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChildDetailScreen extends StatefulWidget {
  const ChildDetailScreen({super.key, required this.child});

  final ChildProfile child;

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  ChildProfile get child => widget.child;

  String? get _studentId => _resolveStudentId(child);

  void _refreshAfterBusLink() => setState(() {});

  String? _resolveStudentId(ChildProfile profile) {
    final sid = profile.studentId?.trim();
    if (sid != null && sid.isNotEmpty) return sid;

    final user = AuthService.currentUser;
    if (user?.roleKey == AuthService.roleParent) {
      EnrollmentService.instance.ensureSeeded();
      for (final id in AuthService.activeLinkedStudentIds()) {
        final record = StudentRegistryService.instance.lookupById(id);
        if (record == null) continue;
        if (record.fullName == profile.name) return record.studentId;
        if (record.className == profile.className &&
            record.fullName.contains(profile.name.split(' ').first)) {
          return record.studentId;
        }
      }
    }

    return StudentRegistryService.instance.lookupByName(profile.name)?.studentId;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final data = SchoolDataService.instance;
        final rank = child.studentId != null
        ? data.rankForStudentId(child.studentId!, child.className)
        : data.rankForStudent(child.name, child.className);
        final attendance = (child.attendanceRate * 100).round();

        return Scaffold(
          backgroundColor: ParentChildPalette.surface,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    child.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: ParentChildPalette.gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -20,
                        top: 40,
                        child: Icon(
                          Icons.star_rounded,
                          size: 120,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 56,
                        right: 20,
                        child: Row(
                          children: [
                            _ChildAvatar(name: child.name, size: 64),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _HeroChip(
                                        label: child.grade,
                                        icon: Icons.school_outlined,
                                      ),
                                      if (child.displaySection.isNotEmpty)
                                        _HeroChip(
                                          label: s.sectionLabel(
                                            child.displaySection,
                                          ),
                                          icon: Icons.class_outlined,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    s.homeroomTeacherOf(child.teacher),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.92),
                                      fontSize: 13,
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
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: listPagePadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatsRow(
                        attendanceLabel: s.attendanceThisTerm(attendance),
                        rankLabel: rank != null ? s.rankNumber(rank) : '—',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        s.childHubTools,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ChildToolsGrid(
                        child: child,
                        studentId: _studentId,
                        onBusLinkNeeded: _refreshAfterBusLink,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChildAvatar extends StatelessWidget {
  const _ChildAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: ParentChildPalette.primary.withValues(alpha: 0.15),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: ParentChildPalette.deep,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.attendanceLabel,
    required this.rankLabel,
  });

  final String attendanceLabel;
  final String rankLabel;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline,
            label: s.attendanceTitle,
            value: attendanceLabel,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.emoji_events_outlined,
            label: s.classRankLabel,
            value: rankLabel,
            color: ParentChildPalette.primary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildToolsGrid extends StatelessWidget {
  const _ChildToolsGrid({
    required this.child,
    this.studentId,
    this.onBusLinkNeeded,
  });

  final ChildProfile child;
  final String? studentId;
  final VoidCallback? onBusLinkNeeded;

  Future<void> _push(BuildContext context, Widget screen) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final transport = TransportService.instance;
    final resolvedStudentId = studentId ?? _studentIdFor(child);
    final driverId = resolvedStudentId != null
        ? transport.driverIdForStudent(resolvedStudentId)
        : transport.driverIdForChildName(child.name);

    final tools = <_ChildTool>[
      _ChildTool(
        icon: Icons.check_circle_rounded,
        label: s.viewAttendance,
        color: Colors.green,
        onTap: (ctx) => _push(
          ctx,
          AttendanceScreen(
            readOnly: true,
            childName: child.name,
            initialClass: child.className,
          ),
        ),
      ),
      _ChildTool(
        icon: Icons.bar_chart_rounded,
        label: s.viewGradeReport,
        color: Colors.deepOrange,
        onTap: (ctx) => _push(
          ctx,
          GradeReportsScreen(
            view: GradeReportView.parent,
            initialClass: child.className,
            initialStudentName: child.name,
          ),
        ),
      ),
      _ChildTool(
        icon: Icons.today_rounded,
        label: s.dailyActivities,
        color: ParentChildPalette.primary,
        onTap: (ctx) {
          final studentId = child.studentId ?? _studentIdFor(child);
          if (studentId == null) return;
          _push(
            ctx,
            DailyActivitiesScreen(
              studentId: studentId,
              studentName: child.name,
              className: child.className,
              mode: DailyActivityMode.parent,
            ),
          );
        },
      ),
      _ChildTool(
        icon: Icons.assignment_rounded,
        label: s.viewHomework,
        color: Colors.cyan,
        onTap: (ctx) => _push(
          ctx,
          HomeworkScreen(
            mode: HomeworkViewMode.parent,
            initialClass: child.className,
            initialChildName: child.name,
          ),
        ),
      ),
      _ChildTool(
        icon: Icons.photo_library_rounded,
        label: s.classGallery,
        color: Colors.purple,
        onTap: (ctx) => _push(
          ctx,
          GalleryScreen(
            mode: GalleryViewMode.parent,
            initialClass: child.className,
          ),
        ),
      ),
      _ChildTool(
        icon: Icons.message_rounded,
        label: s.composeMessage,
        color: Colors.orange,
        onTap: (ctx) => _push(
          ctx,
          ParentComposeMessageScreen(child: child),
        ),
      ),
      _ChildTool(
        icon: Icons.qr_code_2_rounded,
        label: s.generateStudentQr,
        color: Colors.teal,
        onTap: (ctx) {
          final studentId =
              child.studentId ?? _studentIdFor(child);
          if (studentId == null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(s.inviteParentNoRecord)),
            );
            return;
          }
          showStudentIdentificationQrSheet(
            ctx,
            studentId: studentId,
            studentName: child.name,
            className: child.className,
          );
        },
      ),
      _ChildTool(
        icon: Icons.calendar_month_rounded,
        label: s.dashboardTitle('calendar'),
        color: Colors.indigo,
        onTap: (ctx) => _push(ctx, const CalendarScreen()),
      ),
      _ChildTool(
        icon: Icons.payment_rounded,
        label: s.feesTitle,
        color: Colors.blueGrey,
        onTap: (ctx) => _push(
          ctx,
          const FeesPaymentsScreen(view: FeesView.parent),
        ),
      ),
      _ChildTool(
        icon: Icons.directions_bus_filled_rounded,
        label: s.schoolBusTool,
        color: Colors.blue.shade700,
        onTap: (ctx) {
          if (resolvedStudentId == null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(s.inviteParentNoRecord)),
            );
            return;
          }
          _push(
            ctx,
            ParentBusLinkScreen(
              studentId: resolvedStudentId,
              childName: child.name,
            ),
          ).then((_) => onBusLinkNeeded?.call());
        },
      ),
      _ChildTool(
        icon: Icons.map_rounded,
        label: s.busTracking,
        color: Colors.blue,
        onTap: (ctx) {
          if (driverId == null) {
            if (resolvedStudentId == null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text(s.inviteParentNoRecord)),
              );
              return;
            }
            _push(
              ctx,
              ParentBusLinkScreen(
                studentId: resolvedStudentId,
                childName: child.name,
              ),
            ).then((_) => onBusLinkNeeded?.call());
            return;
          }
          _push(
            ctx,
            TransportLiveMapScreen(
              driverId: driverId,
              childName: child.name,
            ),
          );
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= 520 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final tool = tools[index];
            return _ChildToolTile(tool: tool);
          },
        );
      },
    );
  }

  String? _studentIdFor(ChildProfile child) {
    final sid = child.studentId?.trim();
    if (sid != null && sid.isNotEmpty) return sid;

    final user = AuthService.currentUser;
    if (user?.roleKey == AuthService.roleParent) {
      EnrollmentService.instance.ensureSeeded();
      for (final id in AuthService.activeLinkedStudentIds()) {
        final record = StudentRegistryService.instance.lookupById(id);
        if (record == null) continue;
        if (record.fullName == child.name) return record.studentId;
        if (record.className == child.className &&
            record.fullName.contains(child.name.split(' ').first)) {
          return record.studentId;
        }
      }
    }

    final fromRegistry = StudentRegistryService.instance.lookupByName(child.name);
    if (fromRegistry != null) return fromRegistry.studentId;

    final profiles = SchoolDataService.instance.getAllStudentQrProfiles();
    try {
      return profiles.firstWhere((profile) => profile.name == child.name).id;
    } catch (_) {
      return null;
    }
  }
}

class _ChildTool {
  const _ChildTool({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final void Function(BuildContext context) onTap;
}

class _ChildToolTile extends StatelessWidget {
  const _ChildToolTile({required this.tool});

  final _ChildTool tool;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => tool.onTap(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tool.color.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: tool.color.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(tool.icon, color: tool.color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                tool.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
