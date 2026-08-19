import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/grade_analytics_service.dart';
import 'package:mayabela/services/grade_outreach_service.dart';
import 'package:mayabela/services/grade_report_export_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

class GradesOverviewPalette {
  GradesOverviewPalette._();

  static const primary = Color(0xFF4338CA);
  static const secondary = Color(0xFF6366F1);
  static const accent = Color(0xFFA5B4FC);
  static const deep = Color(0xFF312E81);
  static const top = Color(0xFF15803D);
  static const low = Color(0xFFDC2626);
  static const surface = Color(0xFFEEF2FF);

  static const gradient = [deep, primary, secondary];

  static LinearGradient get pageGradient => LinearGradient(
        colors: [surface, const Color(0xFFF5F3FF), const Color(0xFFFAFAFA)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}

class AdminGradeOverviewScreen extends StatefulWidget {
  const AdminGradeOverviewScreen({super.key});

  @override
  State<AdminGradeOverviewScreen> createState() =>
      _AdminGradeOverviewScreenState();
}

class _AdminGradeOverviewScreenState extends State<AdminGradeOverviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late GradeAnalyticsSnapshot _snapshot;
  final _outreach = GradeOutreachService.instance;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    _refresh();
  }

  int get _topPerformerCount {
    final names = <String>{};
    for (final grade in _snapshot.topScorers) {
      for (final entry in grade.gradeTopTen) {
        names.add(entry.report.studentName);
      }
    }
    return names.length;
  }

  int get _underperformingCount =>
      _snapshot.underperformers.fold(0, (sum, g) => sum + g.totalCount);

  void _refresh() {
    setState(() {
      _snapshot = GradeAnalyticsService.instance.buildSnapshot();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Color _scoreColor(double average) {
    if (average >= 90) return GradesOverviewPalette.top;
    if (average >= 80) return const Color(0xFF16A34A);
    if (average >= 70) return Colors.orange.shade700;
    if (average >= 50) return Colors.deepOrange;
    return GradesOverviewPalette.low;
  }

  void _showSnack(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF15803D) : Colors.orange.shade800,
      ),
    );
  }

  Future<void> _sendCongrats({
    required RankedStudentReport entry,
    required GradeRankScope scope,
    required String gradeLevel,
    required String sectionLabel,
  }) async {
    final s = AppLocale.instance.strings;
    final ok = _outreach.sendCongratsToParent(
      report: entry.report,
      rank: entry.rank,
      scope: scope,
      gradeLevel: gradeLevel,
      sectionLabel: sectionLabel,
    );
    _refresh();
    _showSnack(ok ? s.congratsSent : s.noParentOnFile, success: ok);
  }

  Future<void> _sendBulkCongrats({
    required List<RankedStudentReport> students,
    required GradeRankScope scope,
    required String gradeLevel,
    required String sectionLabel,
  }) async {
    final s = AppLocale.instance.strings;
    if (students.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.sendAllCongrats),
        content: Text(s.confirmSendAllCongrats(students.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.send),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final count = _outreach.sendBulkCongrats(
      entries: [
        for (final entry in students)
          (report: entry.report, rank: entry.rank),
      ],
      scope: scope,
      gradeLevel: gradeLevel,
      sectionLabel: sectionLabel,
    );
    _refresh();
    _showSnack(s.bulkCongratsSent(count), success: count > 0);
  }

  Future<void> _askHomeroom({required StudentGradeReport report}) async {
    final s = AppLocale.instance.strings;
    final ok = _outreach.requestHomeroomRecommendation(report: report);
    _refresh();
    _showSnack(
      ok ? s.recommendationRequested : s.noHomeroomTeacher,
      success: ok,
    );
  }

  Future<void> _askAllHomeroom({required List<StudentGradeReport> reports}) async {
    final s = AppLocale.instance.strings;
    if (reports.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.askAllHomeroomRecommendations),
        content: Text(s.confirmAskAllRecommendations(reports.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.send),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final count = _outreach.sendBulkHomeroomRequests(reports: reports);
    _refresh();
    _showSnack(s.bulkRecommendationsSent(count), success: count > 0);
  }

  Future<void> _exportReport() async {
    final s = AppLocale.instance.strings;
    try {
      final export = await GradeReportExportService.instance.buildExcelExport(
        labels: GradeReportExportLabels.fromStrings(s),
      );
      await GradeReportExportService.instance.shareExport(export);
      if (!mounted) return;
      _showSnack(s.exportGradeReportSuccess);
    } catch (_) {
      if (!mounted) return;
      _showSnack(s.exportGradeReportFailed, success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          backgroundColor: GradesOverviewPalette.surface,
          body: Column(
            children: [
              _GradeReportsHeroHeader(
                title: s.gradeReports,
                subtitle: s.adminGradeOverviewSubtitle,
                topScorersLabel: s.topScorersTab,
                underperformingLabel: s.underperformingTab,
                topCount: _topPerformerCount,
                underCount: _underperformingCount,
                topCountCaption: s.adminGradeTopPerformersCaption,
                underCountCaption: s.adminGradeNeedsSupportCaption,
                selectedIndex: _tabs.index,
                onTabSelected: _tabs.animateTo,
                exportLabel: s.exportGradeReport,
                onExport: _exportReport,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _TopScorersTab(
                      grades: _snapshot.topScorers,
                      scoreColor: _scoreColor,
                      emptyLabel: s.noTopScorersData,
                      outreach: _outreach,
                      onSendCongrats: _sendCongrats,
                      onSendBulkCongrats: _sendBulkCongrats,
                    ),
                    _UnderperformingTab(
                      grades: _snapshot.underperformers,
                      scoreColor: _scoreColor,
                      emptyLabel: s.noUnderperformingStudents,
                      outreach: _outreach,
                      onAskHomeroom: _askHomeroom,
                      onAskAllHomeroom: _askAllHomeroom,
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
}

class _GradeReportsHeroHeader extends StatelessWidget {
  const _GradeReportsHeroHeader({
    required this.title,
    required this.subtitle,
    required this.topScorersLabel,
    required this.underperformingLabel,
    required this.topCount,
    required this.underCount,
    required this.topCountCaption,
    required this.underCountCaption,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.exportLabel,
    required this.onExport,
  });

  final String title;
  final String subtitle;
  final String topScorersLabel;
  final String underperformingLabel;
  final int topCount;
  final int underCount;
  final String topCountCaption;
  final String underCountCaption;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final String exportLabel;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: GradesOverviewPalette.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x334338CA),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: -28,
              right: -18,
              child: Icon(
                Icons.insights_rounded,
                size: 140,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              top: 36,
              left: -24,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Analytics',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onExport,
                        icon: const Icon(Icons.file_download_outlined,
                            color: Colors.white, size: 18),
                        label: Text(
                          exportLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            height: 1.15,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _HeaderStatChip(
                                icon: Icons.emoji_events_outlined,
                                value: '$topCount',
                                label: topCountCaption,
                                accent: GradesOverviewPalette.top,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _HeaderStatChip(
                                icon: Icons.trending_down_rounded,
                                value: '$underCount',
                                label: underCountCaption,
                                accent: const Color(0xFFFCA5A5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _HeaderSegmentedTabs(
                          selectedIndex: selectedIndex,
                          onSelected: onTabSelected,
                          tabs: [
                            _HeaderTabSpec(
                              icon: Icons.emoji_events_rounded,
                              label: topScorersLabel,
                            ),
                            _HeaderTabSpec(
                              icon: Icons.arrow_downward_rounded,
                              label: underperformingLabel,
                            ),
                          ],
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
    );
  }
}

class _HeaderTabSpec {
  const _HeaderTabSpec({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _HeaderStatChip extends StatelessWidget {
  const _HeaderStatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
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

class _HeaderSegmentedTabs extends StatelessWidget {
  const _HeaderSegmentedTabs({
    required this.selectedIndex,
    required this.onSelected,
    required this.tabs,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<_HeaderTabSpec> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _HeaderTabButton(
                spec: tabs[i],
                selected: selectedIndex == i,
                onTap: () => onSelected(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderTabButton extends StatelessWidget {
  const _HeaderTabButton({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _HeaderTabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                spec.icon,
                size: 18,
                color: selected
                    ? GradesOverviewPalette.primary
                    : Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  spec.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    color: selected
                        ? GradesOverviewPalette.deep
                        : Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopScorersTab extends StatelessWidget {
  const _TopScorersTab({
    required this.grades,
    required this.scoreColor,
    required this.emptyLabel,
    required this.outreach,
    required this.onSendCongrats,
    required this.onSendBulkCongrats,
  });

  final List<GradeTopScorers> grades;
  final Color Function(double) scoreColor;
  final String emptyLabel;
  final GradeOutreachService outreach;
  final Future<void> Function({
    required RankedStudentReport entry,
    required GradeRankScope scope,
    required String gradeLevel,
    required String sectionLabel,
  }) onSendCongrats;
  final Future<void> Function({
    required List<RankedStudentReport> students,
    required GradeRankScope scope,
    required String gradeLevel,
    required String sectionLabel,
  }) onSendBulkCongrats;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    if (grades.every(
      (g) => g.gradeTopTen.isEmpty && g.sections.every((sec) => sec.students.isEmpty),
    )) {
      return _EmptyAnalyticsState(message: emptyLabel);
    }

    return ListView(
      padding: listPagePadding(context),
      children: [
        for (final grade in grades) ...[
          if (grade.gradeTopTen.isNotEmpty ||
              grade.sections.any((sec) => sec.students.isNotEmpty))
            _GradeExpansionCard(
              title: grade.gradeLevel,
              subtitle: s.adminGradeTopTenSummary,
              accent: GradesOverviewPalette.primary,
              initiallyExpanded: grades.length <= 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (grade.gradeTopTen.isNotEmpty) ...[
                    _SectionHeaderRow(
                      icon: Icons.military_tech_rounded,
                      label: s.gradeWideTopTen,
                      color: GradesOverviewPalette.top,
                      actionLabel: s.sendAllCongrats,
                      onAction: () => onSendBulkCongrats(
                        students: grade.gradeTopTen,
                        scope: GradeRankScope.gradeWide,
                        gradeLevel: grade.gradeLevel,
                        sectionLabel: '',
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StudentRankList(
                      students: grade.gradeTopTen,
                      scoreColor: scoreColor,
                      highlightTopThree: true,
                      scope: GradeRankScope.gradeWide,
                      gradeLevel: grade.gradeLevel,
                      outreach: outreach,
                      onSendCongrats: onSendCongrats,
                    ),
                    const SizedBox(height: 18),
                  ],
                  for (final section in grade.sections) ...[
                    _SectionHeaderRow(
                      icon: Icons.class_outlined,
                      label: s.sectionTopTen(section.section, section.className),
                      color: GradesOverviewPalette.secondary,
                      actionLabel: section.students.isEmpty
                          ? null
                          : s.sendAllCongrats,
                      onAction: section.students.isEmpty
                          ? null
                          : () => onSendBulkCongrats(
                                students: section.students,
                                scope: GradeRankScope.section,
                                gradeLevel: grade.gradeLevel,
                                sectionLabel: section.section,
                              ),
                    ),
                    const SizedBox(height: 8),
                    if (section.students.isEmpty)
                      _InlineEmptyNote(message: s.noSectionGradeData)
                    else
                      _StudentRankList(
                        students: section.students,
                        scoreColor: scoreColor,
                        scope: GradeRankScope.section,
                        gradeLevel: grade.gradeLevel,
                        sectionLabel: section.section,
                        outreach: outreach,
                        onSendCongrats: onSendCongrats,
                      ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _UnderperformingTab extends StatelessWidget {
  const _UnderperformingTab({
    required this.grades,
    required this.scoreColor,
    required this.emptyLabel,
    required this.outreach,
    required this.onAskHomeroom,
    required this.onAskAllHomeroom,
  });

  final List<GradeUnderperformers> grades;
  final Color Function(double) scoreColor;
  final String emptyLabel;
  final GradeOutreachService outreach;
  final Future<void> Function({required StudentGradeReport report}) onAskHomeroom;
  final Future<void> Function({required List<StudentGradeReport> reports})
      onAskAllHomeroom;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    if (grades.isEmpty) {
      return _EmptyAnalyticsState(message: emptyLabel);
    }

    return ListView(
      padding: listPagePadding(context),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: GradesOverviewPalette.low.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: GradesOverviewPalette.low.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: GradesOverviewPalette.low, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.underperformingThresholdNote,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade800,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final grade in grades)
          _GradeExpansionCard(
            title: grade.gradeLevel,
            subtitle: s.underperformingCount(grade.totalCount),
            accent: GradesOverviewPalette.low,
            initiallyExpanded: grades.length <= 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final section in grade.sections) ...[
                  _SectionHeaderRow(
                    icon: Icons.class_outlined,
                    label: s.sectionUnderperforming(
                      section.section,
                      section.className,
                      section.students.length,
                    ),
                    color: GradesOverviewPalette.low,
                    actionLabel: s.askAllHomeroomRecommendations,
                    onAction: () => onAskAllHomeroom(reports: section.students),
                  ),
                  const SizedBox(height: 8),
                  ...section.students.map(
                    (report) => _UnderperformerTile(
                      report: report,
                      scoreColor: scoreColor,
                      sent: outreach.wasRecommendationRequested(report),
                      onAskHomeroom: () => onAskHomeroom(report: report),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  const _SectionHeaderRow({
    required this.icon,
    required this.label,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: Icon(Icons.send_rounded, size: 16, color: color),
            label: Text(
              actionLabel!,
              style: TextStyle(fontSize: 11, color: color),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }
}

class _GradeExpansionCard extends StatelessWidget {
  const _GradeExpansionCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.school_outlined, color: accent, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          iconColor: accent,
          collapsedIconColor: accent,
          children: [child],
        ),
      ),
    );
  }
}

class _StudentRankList extends StatelessWidget {
  const _StudentRankList({
    required this.students,
    required this.scoreColor,
    required this.scope,
    required this.gradeLevel,
    required this.outreach,
    required this.onSendCongrats,
    this.sectionLabel = '',
    this.highlightTopThree = false,
  });

  final List<RankedStudentReport> students;
  final Color Function(double) scoreColor;
  final GradeRankScope scope;
  final String gradeLevel;
  final String sectionLabel;
  final GradeOutreachService outreach;
  final Future<void> Function({
    required RankedStudentReport entry,
    required GradeRankScope scope,
    required String gradeLevel,
    required String sectionLabel,
  }) onSendCongrats;
  final bool highlightTopThree;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in students)
          _RankedStudentTile(
            entry: entry,
            scoreColor: scoreColor,
            highlight: highlightTopThree && entry.rank <= 3,
            sent: outreach.wasCongratsSent(entry.report, scope, entry.rank),
            onSendCongrats: () => onSendCongrats(
              entry: entry,
              scope: scope,
              gradeLevel: gradeLevel,
              sectionLabel: sectionLabel,
            ),
          ),
      ],
    );
  }
}

class _RankedStudentTile extends StatelessWidget {
  const _RankedStudentTile({
    required this.entry,
    required this.scoreColor,
    required this.onSendCongrats,
    this.highlight = false,
    this.sent = false,
  });

  final RankedStudentReport entry;
  final Color Function(double) scoreColor;
  final VoidCallback onSendCongrats;
  final bool highlight;
  final bool sent;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final color = scoreColor(entry.average);
    final medal = switch (entry.rank) {
      1 => Icons.looks_one_rounded,
      2 => Icons.looks_two_rounded,
      3 => Icons.looks_3_rounded,
      _ => null,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: highlight
            ? GradesOverviewPalette.top.withValues(alpha: 0.06)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? GradesOverviewPalette.top.withValues(alpha: 0.25)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: highlight
                  ? GradesOverviewPalette.top.withValues(alpha: 0.15)
                  : GradesOverviewPalette.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: medal != null
                ? Icon(medal, color: GradesOverviewPalette.top, size: 22)
                : Text(
                    '${entry.rank}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: GradesOverviewPalette.primary,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.report.studentName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  entry.report.className,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.average.toStringAsFixed(1)}%',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              if (sent)
                Text(
                  s.sentLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: GradesOverviewPalette.top,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: s.sendCongratsToParent,
            onPressed: sent ? null : onSendCongrats,
            icon: Icon(
              sent ? Icons.check_circle : Icons.celebration_outlined,
              color: sent ? GradesOverviewPalette.top : GradesOverviewPalette.secondary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnderperformerTile extends StatelessWidget {
  const _UnderperformerTile({
    required this.report,
    required this.scoreColor,
    required this.onAskHomeroom,
    this.sent = false,
  });

  final StudentGradeReport report;
  final Color Function(double) scoreColor;
  final VoidCallback onAskHomeroom;
  final bool sent;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final color = scoreColor(report.average);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: GradesOverviewPalette.low.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: GradesOverviewPalette.low.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_down_rounded, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.studentName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  report.className,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            '${report.average.toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          IconButton(
            tooltip: s.askHomeroomRecommendation,
            onPressed: sent ? null : onAskHomeroom,
            icon: Icon(
              sent ? Icons.check_circle : Icons.lightbulb_outline_rounded,
              color: sent ? GradesOverviewPalette.top : GradesOverviewPalette.low,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineEmptyNote extends StatelessWidget {
  const _InlineEmptyNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _EmptyAnalyticsState extends StatelessWidget {
  const _EmptyAnalyticsState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 56,
              color: GradesOverviewPalette.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
