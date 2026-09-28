import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/attendance_intelligence_models.dart';
import 'package:mayabela/services/attendance_intelligence_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/class_picker_bar.dart';

/// Teacher view of class at-risk flags and academic/attendance insights.
class TeacherAttendanceInsightsScreen extends StatefulWidget {
  const TeacherAttendanceInsightsScreen({super.key});

  @override
  State<TeacherAttendanceInsightsScreen> createState() =>
      _TeacherAttendanceInsightsScreenState();
}

class _TeacherAttendanceInsightsScreenState
    extends State<TeacherAttendanceInsightsScreen> {
  final _intel = AttendanceIntelligenceService.instance;
  final _access = TeacherAccessService.instance;
  String? _selectedClass;

  List<String> get _classOptions =>
      _access.myClasses.map((a) => a.className).toSet().toList()..sort();

  @override
  void initState() {
    super.initState();
    if (_classOptions.isNotEmpty) _selectedClass = _classOptions.first;
  }

  @override
  Widget build(BuildContext context) {
    const accent = TeacherTheme.primaryDark;
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final className = _selectedClass;
        final profiles = className == null
            ? const <StudentRiskProfile>[]
            : _intel.profiles(className: className);
        final insights = className == null
            ? const <TeacherClassInsight>[]
            : _intel.teacherInsights(className: className);
        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: accent,
            title: Text(AppLocale.instance.strings.dashboardTitle('at_risk')),
          ),
          body: Column(
            children: [
              if (_classOptions.isNotEmpty)
                ClassPickerBar(
                  label: AppLocale.instance.strings.className,
                  options: _classOptions,
                  selected: _selectedClass,
                  accent: accent,
                  onSelected: (value) => setState(() => _selectedClass = value),
                )
              else
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No classes assigned.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              if (_classOptions.isNotEmpty)
                Expanded(
                  child: ListView(
                    padding: listPagePadding(context),
                    children: [
                      const Text(
                        'At-risk means low marks and high absence together. '
                        'This does not change grades.',
                      ),
                      const SizedBox(height: 10),
                      for (final insight in insights)
                        Card(
                          child: ListTile(
                            title: Text(insight.className),
                            subtitle: Text(insight.note),
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (profiles.isEmpty)
                        const Card(
                          child: ListTile(
                            title: Text('No students to review for this class.'),
                          ),
                        )
                      else
                        for (final p in profiles.where(
                          (p) => p.level != RiskLevel.clear || p.patterns.isNotEmpty,
                        ))
                          Card(
                            child: ListTile(
                              title: Text(p.studentName),
                              subtitle: Text(
                                '${_level(p.level)} · absent ${p.absent}/${p.sessions}'
                                '${p.hasGrades ? ' · marks ${p.gradeAverage!.toStringAsFixed(0)}%' : ''}'
                                '${p.patterns.isEmpty ? '' : '\n${p.patterns.map((x) => x.label).join(' · ')}'}',
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _level(RiskLevel level) => switch (level) {
        RiskLevel.atRisk => 'At-risk',
        RiskLevel.attendanceWatch => 'Attendance watch',
        RiskLevel.academicWatch => 'Academic watch',
        RiskLevel.clear => 'Clear',
      };
}
