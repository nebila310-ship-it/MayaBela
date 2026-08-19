import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/screens/daily_activities_screen.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/class_picker_bar.dart';

/// Homeroom hub — pick a student to log or review today's daily activity.
class ClassDailyActivitiesScreen extends StatelessWidget {
  const ClassDailyActivitiesScreen({
    super.key,
    required this.className,
  });

  final String className;

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final data = SchoolDataService.instance;
    final students = data.getStudentsForClass(className);
    final today = DateTime.now();
    const accent = Color(0xFF00796B);

    return Scaffold(
      backgroundColor: const Color(0xFFCFDBEA),
      appBar: AppBar(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        title: Text(s.dailyActivities),
      ),
      body: WarmScreenBody(
        accentColor: accent,
        child: students.isEmpty
            ? Center(child: Text(s.noStudentsInClass))
            : ListView.separated(
                padding: listPagePadding(context),
                itemCount: students.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '$className · ${_formatDate(today)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: accent,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }
                  final student = students[index - 1];
                  final studentKey = student.inviteStudentId;
                  final report = data.getDailyActivityForStudent(
                    studentKey,
                    today,
                    studentName: student.name,
                  );
                  return _StudentActivityTile(
                    student: student,
                    className: className,
                    accent: accent,
                    report: report,
                  );
                },
              ),
      ),
    );
  }
}

class _StudentActivityTile extends StatelessWidget {
  const _StudentActivityTile({
    required this.student,
    required this.className,
    required this.accent,
    required this.report,
  });

  final StudentRef student;
  final String className;
  final Color accent;
  final DailyActivityReport? report;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final hasReportToday = report != null;
    final parentSeen = report?.parentHasSeen ?? false;

    String subtitle;
    Color subtitleColor;
    if (!hasReportToday) {
      subtitle = s.noReportForDay;
      subtitleColor = Colors.grey.shade600;
    } else if (parentSeen) {
      subtitle = s.parentSeenReport;
      subtitleColor = Colors.green.shade700;
    } else {
      subtitle = s.waitingForParentView;
      subtitleColor = Colors.orange.shade800;
    }

    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: accent.withValues(alpha: 0.12)),
        ),
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.12),
          child: Text(
            student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: subtitleColor,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          parentSeen
              ? Icons.check_circle
              : hasReportToday
                  ? Icons.schedule
                  : Icons.chevron_right,
          color: parentSeen
              ? Colors.green.shade700
              : hasReportToday
                  ? Colors.orange
                  : accent,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DailyActivitiesScreen(
                studentId: student.inviteStudentId,
                studentName: student.name,
                className: className,
              ),
            ),
          );
        },
      ),
    );
  }
}
