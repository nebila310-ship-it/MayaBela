import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/screens/attendance_screen.dart';
import 'package:mayabela/screens/calendar_screen.dart';
import 'package:mayabela/screens/class_daily_activities_screen.dart';
import 'package:mayabela/screens/gallery_screen.dart';
import 'package:mayabela/screens/grade_reports_screen.dart';
import 'package:mayabela/screens/homework_screen.dart';
import 'package:mayabela/screens/teacher_lesson_plans_screen.dart';
import 'package:mayabela/screens/messages_screen.dart';
import 'package:mayabela/screens/qr_entry_exit_screen.dart';
import 'package:mayabela/services/lms_classroom_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/utils/adaptive_breakpoints.dart';
import 'package:mayabela/widgets/dashboard_card.dart';
import 'package:mayabela/widgets/dashboard_module_section.dart';

class _ClassTool {
  const _ClassTool({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// Quick-action grid for a class (homeroom gets full tools including daily activities).
class ClassToolsPanel extends StatelessWidget {
  const ClassToolsPanel({
    super.key,
    required this.className,
    required this.isHomeroom,
    this.accent = TeacherTheme.primaryDark,
    this.showClassName = false,
  });

  factory ClassToolsPanel.fromAssignment(
    ClassAssignment assignment, {
    Color accent = TeacherTheme.primaryDark,
  }) {
    return ClassToolsPanel(
      className: assignment.className,
      isHomeroom: assignment.isHomeroom,
      accent: accent,
    );
  }

  final String className;
  final bool isHomeroom;
  final Color accent;
  final bool showClassName;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final access = TeacherAccessService.instance;
    final desktop = AdaptiveBreakpoints.isDesktop(context);

    void open(Widget screen) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    final tools = <_ClassTool>[
      if (access.canTakeAttendance(className))
        _ClassTool(
          icon: Icons.check_circle,
          label: s.attendanceTitle,
          color: Colors.green,
          onTap: () => open(AttendanceScreen(initialClass: className)),
        ),
      _ClassTool(
        icon: Icons.bar_chart,
        label: s.gradesBtn,
        color: Colors.deepOrange,
        onTap: () => open(
          GradeReportsScreen(
            view: GradeReportView.teacher,
            initialClass: className,
          ),
        ),
      ),
      _ClassTool(
        icon: Icons.assignment,
        label: s.homeworkTitle,
        color: Colors.cyan,
        onTap: () => open(HomeworkScreen(initialClass: className)),
      ),
      _ClassTool(
        icon: Icons.event_note_outlined,
        label: s.dashboardTitle('lesson_plans'),
        color: const Color(0xFF5D4037),
        onTap: () => open(TeacherLessonPlansScreen(initialClass: className)),
      ),
      if (access.canMessageInClass(className)) ...[
        _ClassTool(
          icon: Icons.message,
          label: s.dashboardTitle('messages'),
          color: Colors.orange,
          onTap: () => open(const MessagesScreen()),
        ),
        _ClassTool(
          icon: Icons.forum_outlined,
          label: 'Class discussion',
          color: Colors.indigo,
          onTap: () {
            final id = LmsClassroomService.instance.ensureClassDiscussion(
              className,
            );
            open(
              ChatScreen(
                conversationId: id,
                contactName: LmsClassroomService.discussionTitle(className),
                isGroup: true,
              ),
            );
          },
        ),
      ],
      _ClassTool(
        icon: Icons.qr_code_scanner,
        label: s.dashboardTitle('qr'),
        color: Colors.black87,
        onTap: () => open(
          QrEntryExitScreen(
            role: QrScreenRole.teacher,
            scopedClassName: className,
          ),
        ),
      ),
      _ClassTool(
        icon: Icons.calendar_month,
        label: isHomeroom ? s.dashboardTitle('calendar') : s.calendarReadOnly,
        color: Colors.teal,
        onTap: () => open(const CalendarScreen()),
      ),
      if (isHomeroom) ...[
        _ClassTool(
          icon: Icons.today,
          label: s.dailyActivities,
          color: Colors.teal.shade700,
          onTap: () => open(ClassDailyActivitiesScreen(className: className)),
        ),
        _ClassTool(
          icon: Icons.photo_library,
          label: s.dashboardTitle('gallery'),
          color: Colors.purple,
          onTap: () => open(const GalleryScreen()),
        ),
      ],
    ];

    final title = isHomeroom
        ? s.classToolsFullAccess
        : s.classToolsSubjectAccess;
    final crossAxis = desktop
        ? AdaptiveBreakpoints.dashboardCrossAxisCount(context)
        : 3;
    final grid = GridView.count(
      key: const Key('class-tools-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxis,
      crossAxisSpacing: desktop ? 16 : 10,
      mainAxisSpacing: desktop ? 16 : 10,
      childAspectRatio: desktop ? 1.15 : 0.95,
      children: [
        for (final tool in tools)
          desktop
              ? DashboardCard(
                  icon: tool.icon,
                  title: tool.label,
                  color: tool.color,
                  onTap: tool.onTap,
                )
              : ClassToolChip(
                  icon: tool.icon,
                  label: tool.label,
                  color: tool.color,
                  onTap: tool.onTap,
                ),
      ],
    );

    if (desktop) {
      return DashboardModuleSection(
        title: showClassName ? className : title,
        icon: Icons.grid_view_rounded,
        accent: accent,
        child: grid,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showClassName) ...[
          Text(
            className,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
        const SizedBox(height: 10),
        grid,
      ],
    );
  }
}

class ClassToolChip extends StatelessWidget {
  const ClassToolChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
