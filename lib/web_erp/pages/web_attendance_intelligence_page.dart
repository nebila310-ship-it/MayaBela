import 'package:flutter/material.dart';

import 'package:mayabela/models/attendance_intelligence_models.dart';
import 'package:mayabela/services/attendance_intelligence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// Staff desk: absence patterns, grades vs attendance, rule-based at-risk.
class WebAttendanceIntelligencePage extends StatefulWidget {
  const WebAttendanceIntelligencePage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebAttendanceIntelligencePage> createState() =>
      _WebAttendanceIntelligencePageState();
}

class _WebAttendanceIntelligencePageState
    extends State<WebAttendanceIntelligencePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _intel = AttendanceIntelligenceService.instance;
  String? _className;

  bool get _canView => ModuleAccess.canView('at_risk');

  List<String> get _classes {
    final names = <String>{};
    for (final session in SchoolDataService.instance.attendanceSnapshot()) {
      names.add(session.className);
    }
    for (final report in SchoolDataService.instance.getAllGradeReports()) {
      names.add(report.className);
    }
    return names.where((n) => n.trim().isNotEmpty).toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    if (!_canView) {
      return const Center(child: Text('You do not have access to at-risk flags.'));
    }
    final profiles = _intel.profiles(className: _className);
    final atRisk = profiles.where((p) => p.isAtRisk).toList();
    final patterned = profiles.where((p) => p.patterns.isNotEmpty).toList();
    final insights = _intel.teacherInsights(className: _className);
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
                'Attendance intelligence',
                style: WebErpTheme.sectionTitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                'Rules first: a student is at-risk when low marks '
                '(below ${AttendanceIntelligenceThresholds.lowGradeThreshold.toStringAsFixed(0)}%) '
                'combine with high absence '
                '(${(AttendanceIntelligenceThresholds.highAbsenceRate * 100).round()}%+ '
                'or ${AttendanceIntelligenceThresholds.consecutiveAbsenceThreshold}+ consecutive days). '
                'This reads the existing attendance register and markbook — it does not enter grades. '
                'Predictive / ML scoring comes later.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey('ai-class-$_className'),
                      initialValue: _className,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All classes'),
                        ),
                        for (final name in _classes)
                          DropdownMenuItem(value: name, child: Text(name)),
                      ],
                      onChanged: (v) => setState(() => _className = v),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigate?.call('attendance'),
                    child: const Text('Daily attendance'),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigate?.call('grades'),
                    child: const Text('Grade overview'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabs: [
                  Tab(text: 'At-risk (${atRisk.length})'),
                  Tab(text: 'Patterns (${patterned.length})'),
                  Tab(text: 'Attendance vs grades'),
                  Tab(text: 'Teacher insights (${insights.length})'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _list(atRisk, empty: 'No students currently meet the low-grades + high-absence rule.'),
              _list(patterned, empty: 'No absence patterns detected yet. Take attendance for a few days.'),
              _compareTab(profiles),
              _insightsTab(insights),
            ],
          ),
        ),
      ],
    );
  }

  Widget _list(List<StudentRiskProfile> items, {required String empty}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: WebErpTheme.cardDecoration(context),
            child: Text(empty),
          )
        else
          for (final p in items) _profileCard(p),
      ],
    );
  }

  Widget _profileCard(StudentRiskProfile p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: WebErpTheme.cardDecoration(context),
        child: ListTile(
          title: Text(p.studentName),
          subtitle: Text(
            '${p.className} · ${_levelLabel(p.level)}\n'
            'Attendance ${(p.attendanceRate * 100).round()}% · '
            'absent ${p.absent}/${p.sessions}'
            '${p.hasGrades ? ' · marks ${p.gradeAverage!.toStringAsFixed(0)}%' : ' · no marks yet'}'
            '${p.patterns.isEmpty ? '' : '\n${p.patterns.map((x) => x.label).join(' · ')}'}',
          ),
          isThreeLine: true,
        ),
      ),
    );
  }

  Widget _compareTab(List<StudentRiskProfile> profiles) {
    final both = profiles.where((p) => p.hasGrades && p.sessions > 0).toList()
      ..sort((a, b) => (a.gradeAverage ?? 0).compareTo(b.gradeAverage ?? 0));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Each row is one student: absence rate from the live register, '
          'average from the Phase B markbook. Nothing here writes a score.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (both.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: WebErpTheme.cardDecoration(context),
            child: const Text(
              'Need both attendance sessions and subject marks to compare.',
            ),
          )
        else
          for (final p in both)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DecoratedBox(
                decoration: WebErpTheme.cardDecoration(context),
                child: ListTile(
                  dense: true,
                  title: Text(p.studentName),
                  subtitle: Text(
                    '${p.className} · absence ${(p.absenceRate * 100).round()}% · '
                    'marks ${p.gradeAverage!.toStringAsFixed(0)}% · ${_levelLabel(p.level)}',
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _insightsTab(List<TeacherClassInsight> insights) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Class-level picture from the same attendance and markbook rows. '
          'Use this for academic check-ins, not HR or payroll.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (insights.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: WebErpTheme.cardDecoration(context),
            child: const Text('No class insights yet.'),
          )
        else
          for (final item in insights)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DecoratedBox(
                decoration: WebErpTheme.cardDecoration(context),
                child: ListTile(
                  title: Text(item.className),
                  subtitle: Text(
                    'Attendance ${(item.attendanceRate * 100).round()}% · '
                    '${item.gradeAverage == null ? 'no marks' : 'marks ${item.gradeAverage!.toStringAsFixed(0)}%'} · '
                    '${item.atRiskCount} at-risk · '
                    '${item.highAbsenceCount} high absence · '
                    '${item.lowGradeCount} low marks\n${item.note}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
      ],
    );
  }

  static String _levelLabel(RiskLevel level) => switch (level) {
        RiskLevel.atRisk => 'At-risk (low marks + high absence)',
        RiskLevel.attendanceWatch => 'Attendance watch',
        RiskLevel.academicWatch => 'Academic watch',
        RiskLevel.clear => 'Clear',
      };
}
