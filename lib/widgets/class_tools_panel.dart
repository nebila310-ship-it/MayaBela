import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/screens/attendance_screen.dart';
import 'package:mayabela/screens/calendar_screen.dart';
import 'package:mayabela/screens/class_daily_activities_screen.dart';
import 'package:mayabela/screens/gallery_screen.dart';
import 'package:mayabela/screens/grade_reports_screen.dart';
import 'package:mayabela/screens/homework_screen.dart';
import 'package:mayabela/screens/messages_screen.dart';
import 'package:mayabela/screens/qr_entry_exit_screen.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';

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

    void open(Widget screen) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    final tools = <Widget>[
      if (access.canTakeAttendance(className))
        ClassToolChip(
          icon: Icons.check_circle,
          label: s.attendanceTitle,
          color: Colors.green,
          onTap: () => open(AttendanceScreen(initialClass: className)),
        ),
      ClassToolChip(
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
      ClassToolChip(
        icon: Icons.assignment,
        label: s.homeworkTitle,
        color: Colors.cyan,
        onTap: () => open(HomeworkScreen(initialClass: className)),
      ),
      if (access.canMessageInClass(className))
        ClassToolChip(
          icon: Icons.message,
          label: s.dashboardTitle('messages'),
          color: Colors.orange,
          onTap: () => open(const MessagesScreen()),
        ),
      ClassToolChip(
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
      ClassToolChip(
        icon: Icons.calendar_month,
        label: isHomeroom ? s.dashboardTitle('calendar') : s.calendarReadOnly,
        color: Colors.teal,
        onTap: () => open(const CalendarScreen()),
      ),
      if (isHomeroom) ...[
        ClassToolChip(
          icon: Icons.today,
          label: s.dailyActivities,
          color: Colors.teal.shade700,
          onTap: () => open(ClassDailyActivitiesScreen(className: className)),
        ),
        ClassToolChip(
          icon: Icons.photo_library,
          label: s.dashboardTitle('gallery'),
          color: Colors.purple,
          onTap: () => open(const GalleryScreen()),
        ),
      ],
    ];

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
          isHomeroom ? s.classToolsFullAccess : s.classToolsSubjectAccess,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.95,
          children: tools,
        ),
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
