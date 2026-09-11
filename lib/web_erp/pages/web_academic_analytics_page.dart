import 'package:flutter/material.dart';

import 'package:mayabela/models/attendance_intelligence_models.dart';
import 'package:mayabela/services/attendance_intelligence_service.dart';
import 'package:mayabela/services/grade_analytics_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_report_export_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// In-app analytics desk: at-risk rules, grade lists, spreadsheet exports.
/// Not a BI suite and not predictive ML.
class WebAcademicAnalyticsPage extends StatefulWidget {
  const WebAcademicAnalyticsPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebAcademicAnalyticsPage> createState() =>
      _WebAcademicAnalyticsPageState();
}

class _WebAcademicAnalyticsPageState extends State<WebAcademicAnalyticsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  String? _busy;

  bool get _canView => ModuleAccess.canView('analytics');

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    if (!_canView) {
      return const Center(child: Text('You do not have access to analytics.'));
    }
    final intel = AttendanceIntelligenceService.instance;
    final atRisk = intel.profiles().where((p) => p.isAtRisk).toList();
    final grades = GradeAnalyticsService.instance.buildSnapshot();
    var lowMarkCount = 0;
    for (final grade in grades.underperformers) {
      lowMarkCount += grade.totalCount;
    }
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
                'Academic analytics',
                style: WebErpTheme.sectionTitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                'Exports and rule-based at-risk flags. A student is at-risk when '
                'low marks combine with high absence. This is not a replacement '
                'for Excel BI and it does not run predictive ML.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  TextButton(
                    onPressed: () => widget.onNavigate?.call('at_risk'),
                    child: const Text('Attendance intelligence'),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigate?.call('reports'),
                    child: const Text('Spreadsheet reports'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabs: [
                  Tab(text: 'At-risk (${atRisk.length})'),
                  Tab(text: 'Low marks ($lowMarkCount)'),
                  const Tab(text: 'Breakdown'),
                  const Tab(text: 'Exports'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _riskTab(atRisk),
              _gradesTab(grades),
              _breakdownTab(),
              _exportTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _riskTab(List<StudentRiskProfile> atRisk) {
    if (atRisk.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No students currently meet the low-grades + high-absence rule.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final p in atRisk)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DecoratedBox(
              decoration: WebErpTheme.cardDecoration(context),
              child: ListTile(
                title: Text(p.studentName),
                subtitle: Text(
                  '${p.className} · attendance '
                  '${(p.attendanceRate * 100).round()}%'
                  '${p.hasGrades && p.gradeAverage != null ? ' · marks ${p.gradeAverage!.toStringAsFixed(0)}%' : ''}',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _gradesTab(GradeAnalyticsSnapshot snapshot) {
    if (snapshot.underperformers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No students are below the 50% markbook average rule.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final grade in snapshot.underperformers)
          for (final section in grade.sections)
            for (final student in section.students)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DecoratedBox(
                  decoration: WebErpTheme.cardDecoration(context),
                  child: ListTile(
                    title: Text(student.studentName),
                    subtitle: Text(
                      '${section.className} · average '
                      '${student.average.toStringAsFixed(0)}%',
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _breakdownTab() {
    final categories = GradeAnalyticsService.instance.categoryAverages();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Assessment-type averages from the existing markbook. '
          'This is not a new grade store.',
        ),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          const Text('No category marks entered yet.')
        else
          for (final row in categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DecoratedBox(
                decoration: WebErpTheme.cardDecoration(context),
                child: ListTile(
                  title: Text(row.label),
                  subtitle: Text(
                    '${row.average.toStringAsFixed(1)}% · ${row.count} mark'
                    '${row.count == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _exportTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Download CSV or Excel of the existing registers. These files are '
          'for staff review — they are not a live BI dashboard.',
        ),
        const SizedBox(height: 16),
        _exportButton(
          'Academic CSV',
          SchoolReportKind.academic,
          'csv',
        ),
        _exportButton(
          'Academic Excel',
          SchoolReportKind.academic,
          'excel',
        ),
        _exportButton(
          'Attendance CSV',
          SchoolReportKind.attendance,
          'csv',
        ),
        _exportButton(
          'Student register CSV',
          SchoolReportKind.students,
          'csv',
        ),
      ],
    );
  }

  Widget _exportButton(String label, SchoolReportKind kind, String format) {
    final key = '$label-$format';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: _busy != null
              ? null
              : () async {
                  setState(() => _busy = key);
                  try {
                    await SchoolReportExportService.instance.export(
                      kind: kind,
                      format: format,
                    );
                  } finally {
                    if (mounted) setState(() => _busy = null);
                  }
                },
          icon: _busy == key
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          label: Text(label),
        ),
      ),
    );
  }
}
