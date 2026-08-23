import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/models/school_class.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/screens/parent_link_child_screen.dart';
import 'package:mayabela/screens/my_children_screen.dart';
import 'package:mayabela/widgets/student_dashboard_summary.dart';
import 'package:mayabela/widgets/teacher_profile_avatar.dart';

/// Shared welcome card shell used on every role dashboard home screen.
class DashboardWelcomeCard extends StatelessWidget {
  const DashboardWelcomeCard({
    super.key,
    required this.name,
    required this.accent,
    required this.accentLight,
    required this.schoolLine,
    required this.statsSectionTitle,
    required this.chips,
    this.leading,
    this.detailLines = const [],
    this.footerLine,
    this.footer,
  });

  final String name;
  final Color accent;
  final Color accentLight;
  final String schoolLine;
  final String statsSectionTitle;
  final List<Widget> chips;
  final Widget? leading;
  final List<String> detailLines;
  final String? footerLine;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDADCE0)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accentLight],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading ??
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: accent.withValues(alpha: 0.12),
                      child: Icon(Icons.person_outline, color: accent, size: 32),
                    ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.welcomeBack,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: accentLight,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        schoolLine,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                      for (final line in detailLines) ...[
                        const SizedBox(height: 4),
                        Text(
                          line,
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        statsSectionTitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: chips),
                      if (footer != null) ...[
                        const SizedBox(height: 12),
                        footer!,
                      ] else if (footerLine != null &&
                          footerLine!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          footerLine!,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
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
}

class DashboardStatChip extends StatelessWidget {
  const DashboardStatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class TeacherDashboardSummary extends StatelessWidget {
  const TeacherDashboardSummary({super.key});

  static const _accent = TeacherTheme.primaryDark;
  static const _accentLight = TeacherTheme.primary;

  @override
  Widget build(BuildContext context) {
    final access = TeacherAccessService.instance;
    final classes = access.myClasses;
    final homerooms = classes.where((c) => c.isHomeroom).toList();
    final studentTotal =
        classes.fold<int>(0, (sum, c) => sum + c.studentCount);
    final pending = EnrollmentService.instance.pendingCountForCurrentUser();
    final s = AppLocale.instance.strings;
    final name = access.teacherName;
    final teacherId = access.teacherId;
    final subject = access.teacherSubject;
    final schoolName = s.schoolName(AuthService.activeSchoolId);
    final schoolId = AuthService.activeSchoolId;
    final schoolLine =
        schoolId != null ? '$schoolName · $schoolId' : schoolName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardWelcomeCard(
          name: name,
          accent: _accent,
          accentLight: _accentLight,
          schoolLine: schoolLine,
          statsSectionTitle: s.dashboardTitle('classes', roleKey: 'teacher'),
          leading: TeacherProfileAvatar(
            name: name,
            radius: 36,
            borderColor: _accentLight,
            borderWidth: 2,
            backgroundColor: TeacherTheme.surface,
            initialTextColor: _accent,
          ),
          detailLines: [
            if (subject.isNotEmpty) subject,
            if (teacherId.isNotEmpty) '${s.teacherId}: $teacherId',
          ],
          chips: [
            DashboardStatChip(
              icon: Icons.class_,
              label: s.dashboardStatClasses(classes.length),
              color: Colors.blue,
            ),
            DashboardStatChip(
              icon: Icons.groups,
              label: s.dashboardStatStudents(studentTotal),
              color: Colors.teal,
            ),
            if (homerooms.isNotEmpty)
              DashboardStatChip(
                icon: Icons.home_work_outlined,
                label: s.dashboardStatHomerooms(homerooms.length),
                color: Colors.deepPurple,
              ),
            if (pending > 0)
              DashboardStatChip(
                icon: Icons.how_to_reg,
                label: s.dashboardStatApprovals(pending),
                color: Colors.orange,
              ),
          ],
          footerLine: homerooms.isNotEmpty
              ? homerooms.map((c) => c.className).join(' · ')
              : null,
        ),
      ],
    );
  }
}

class AdminDashboardSummary extends StatelessWidget {
  const AdminDashboardSummary({super.key});

  static const _accent = Color(0xFF00897B);
  static const _accentLight = Color(0xFF12B5CB);

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final schoolId = AuthService.activeSchoolId;
    final schoolName = s.schoolName(schoolId);
    final schoolLine =
        schoolId != null ? '$schoolName · $schoolId' : schoolName;
    final name = AuthService.displayNameForRole(AuthService.roleAdmin);

    final teacherCount = TeacherRegistryService.instance
        .staffTeachersForSchool(schoolId)
        .length;
    final transportCount =
        DriverRegistryService.instance.driversForSchool(schoolId).length;
    final staffCount = teacherCount + transportCount;
    final studentCount = StudentRegistryService.instance
        .getAllStudents()
        .where((student) =>
            student.isActive &&
            (schoolId == null || student.schoolId == schoolId))
        .length;

    return DashboardWelcomeCard(
      name: name,
      accent: _accent,
      accentLight: _accentLight,
      schoolLine: schoolLine,
      statsSectionTitle: s.dashboardWelcomeSchoolOverview,
      leading: CircleAvatar(
        radius: 36,
        backgroundColor: _accent.withValues(alpha: 0.12),
        child: const Icon(Icons.admin_panel_settings_outlined,
            color: _accent, size: 32),
      ),
      chips: [
        DashboardStatChip(
          icon: Icons.badge_outlined,
          label: s.dashboardStatStaff(staffCount),
          color: Colors.deepPurple,
        ),
        DashboardStatChip(
          icon: Icons.school_outlined,
          label: s.dashboardStatStudents(studentCount),
          color: Colors.teal,
        ),
      ],
    );
  }
}

class ParentDashboardSummary extends StatelessWidget {
  const ParentDashboardSummary({super.key});

  static const _accent = Color(0xFF00695C);
  static const _accentLight = Color(0xFF26A69A);

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final schoolId = AuthService.activeSchoolId;
    final schoolName = s.schoolName(schoolId);
    final schoolLine =
        schoolId != null ? '$schoolName · $schoolId' : schoolName;
    final name = AuthService.displayNameForRole(AuthService.roleParent);
    final children = SchoolDataService.instance.getChildren();
    final childCount = children.length;

    return DashboardWelcomeCard(
      name: name,
      accent: _accent,
      accentLight: _accentLight,
      schoolLine: schoolLine,
      statsSectionTitle: s.dashboardTitle('children', roleKey: 'parent'),
      leading: CircleAvatar(
        radius: 36,
        backgroundColor: _accent.withValues(alpha: 0.12),
        child: const Icon(Icons.family_restroom, color: _accent, size: 32),
      ),
      chips: [
        DashboardStatChip(
          icon: Icons.child_care,
          label: s.dashboardStatChildren(childCount),
          color: Colors.teal,
        ),
      ],
      footer: _ParentChildrenFooter(children: children),
    );
  }
}

class _ParentChildrenFooter extends StatelessWidget {
  const _ParentChildrenFooter({required this.children});

  final List<ChildProfile> children;

  void _openAddChild(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ParentLinkChildScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final accent = ParentDashboardSummary._accent;
    final displayed = children.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (displayed.isEmpty)
          _AddChildSlot(
            accent: accent,
            onTap: () => _openAddChild(context),
            expanded: true,
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final child in displayed)
                Expanded(
                  child: _ParentChildSlot(
                    name: child.name,
                    subtitle: '${child.grade} · ${child.displaySection}',
                    filled: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChildDetailScreen(child: child),
                      ),
                    ),
                  ),
                ),
              if (displayed.length == 1)
                Expanded(
                  child: _AddChildSlot(
                    accent: accent,
                    onTap: () => _openAddChild(context),
                  ),
                ),
            ],
          ),
        if (displayed.length >= 2) ...[
          const SizedBox(height: 10),
          _AddChildSlot(
            accent: accent,
            onTap: () => _openAddChild(context),
            expanded: true,
          ),
        ],
        if (children.length > 2) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children.skip(2).map((child) {
              return ActionChip(
                avatar: CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.15),
                  child: Text(
                    child.name.isNotEmpty ? child.name[0] : '?',
                    style: TextStyle(
                      fontSize: 11,
                      color: accent,
                    ),
                  ),
                ),
                label: Text(child.name),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChildDetailScreen(child: child),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyChildrenScreen()),
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(s.viewAllChildren),
        ),
      ],
    );
  }
}

/// Always-visible slot to link another child.
class _AddChildSlot extends StatelessWidget {
  const _AddChildSlot({
    required this.accent,
    required this.onTap,
    this.expanded = false,
  });

  final Color accent;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: expanded ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 16 : 12,
            vertical: expanded ? 14 : 12,
          ),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_add_alt_1_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: expanded
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.addNewChild,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: expanded ? TextAlign.center : TextAlign.start,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: accent,
                      ),
                    ),
                    if (expanded) ...[
                      const SizedBox(height: 2),
                      Text(
                        s.linkAnotherChildShort,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (expanded)
                Icon(Icons.arrow_forward_rounded, color: accent, size: 18),
            ],
          ),
        ),
      ),
    );

    if (expanded) return content;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: content,
    );
  }
}

class _ParentChildSlot extends StatelessWidget {
  const _ParentChildSlot({
    required this.name,
    required this.subtitle,
    required this.filled,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = ParentDashboardSummary._accent;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: filled ? accent.withValues(alpha: 0.08) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: filled
                    ? accent.withValues(alpha: 0.25)
                    : Colors.grey.shade300,
                style: filled ? BorderStyle.solid : BorderStyle.solid,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      filled ? Icons.person_rounded : Icons.add_circle_outline,
                      size: 18,
                      color: filled ? accent : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: filled ? accent : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DriverDashboardSummary extends StatelessWidget {
  const DriverDashboardSummary({super.key});

  static const _accent = Color(0xFFE65100);
  static const _accentLight = Color(0xFFFFB74D);

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final schoolId = AuthService.activeSchoolId;
    final schoolName = s.schoolName(schoolId);
    final schoolLine =
        schoolId != null ? '$schoolName · $schoolId' : schoolName;

    final driverId = AuthService.resolvedLinkedDriverId ?? '';
    final driver = driverId.isNotEmpty
        ? DriverRegistryService.instance.lookupById(driverId)
        : null;
    final name = driver?.fullName ??
        AuthService.displayNameForRole(AuthService.roleDriver);
    final passengers = driverId.isNotEmpty
        ? TransportService.instance.passengersForDriver(driverId)
        : const [];

    return DashboardWelcomeCard(
      name: name,
      accent: _accent,
      accentLight: _accentLight,
      schoolLine: schoolLine,
      statsSectionTitle: s.dashboardWelcomeTransportOverview,
      leading: CircleAvatar(
        radius: 36,
        backgroundColor: _accent.withValues(alpha: 0.12),
        child: const Icon(Icons.directions_bus_filled, color: _accent, size: 32),
      ),
      detailLines: [
        if (driverId.isNotEmpty) '${s.driverIdLabel}: $driverId',
        if (driver?.routeName.isNotEmpty == true)
          '${s.routeLabel}: ${driver!.routeName}',
      ],
      chips: [
        DashboardStatChip(
          icon: Icons.groups_outlined,
          label: s.dashboardStatStudents(passengers.length),
          color: Colors.teal,
        ),
        if (driver != null) ...[
          DashboardStatChip(
            icon: Icons.directions_bus,
            label: s.dashboardStatBus(driver.busNumber),
            color: Colors.orange,
          ),
          DashboardStatChip(
            icon: Icons.confirmation_number_outlined,
            label: s.dashboardStatPlate(driver.plateNumber),
            color: Colors.blueGrey,
          ),
        ],
      ],
    );
  }
}

/// Resolves the welcome summary card for a dashboard role.
Widget? dashboardSummaryForRole(String roleKey) {
  return switch (roleKey) {
    AuthService.roleTeacher => const TeacherDashboardSummary(),
    AuthService.roleStaff => const AdminDashboardSummary(),
    AuthService.roleAdmin => const AdminDashboardSummary(),
    AuthService.roleParent => const ParentDashboardSummary(),
    AuthService.roleDriver => const DriverDashboardSummary(),
    AuthService.roleStudent => const StudentDashboardSummary(),
    _ => null,
  };
}
