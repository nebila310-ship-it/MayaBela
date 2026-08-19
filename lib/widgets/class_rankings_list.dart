import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/student_conduct.dart';
import 'package:mayabela/services/grade_analytics_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

class ClassRankVisualStyle {
  const ClassRankVisualStyle({
    required this.accent,
    required this.background,
    required this.border,
    required this.badgeText,
  });

  final Color accent;
  final Color background;
  final Color border;
  final Color badgeText;
}

ClassRankVisualStyle rankVisualStyle(int rank, double average) {
  if (average < 50) {
    return ClassRankVisualStyle(
      accent: const Color(0xFFDC2626),
      background: const Color(0xFFFEF2F2),
      border: const Color(0xFFFECACA),
      badgeText: Colors.white,
    );
  }
  if (rank <= 3) {
    return ClassRankVisualStyle(
      accent: const Color(0xFF15803D),
      background: const Color(0xFFF0FDF4),
      border: const Color(0xFFBBF7D0),
      badgeText: Colors.white,
    );
  }
  if (rank <= 10) {
    return ClassRankVisualStyle(
      accent: const Color(0xFFCA8A04),
      background: const Color(0xFFFEFCE8),
      border: const Color(0xFFFEF08A),
      badgeText: const Color(0xFF713F12),
    );
  }
  return ClassRankVisualStyle(
    accent: const Color(0xFF475569),
    background: Colors.white,
    border: const Color(0xFFE2E8F0),
    badgeText: Colors.white,
  );
}

class ClassRankingsList extends StatefulWidget {
  const ClassRankingsList({
    super.key,
    required this.className,
    required this.rankings,
    required this.onOpenStudent,
  });

  final String className;
  final List<RankedStudentReport> rankings;
  final void Function(RankedStudentReport entry) onOpenStudent;

  @override
  State<ClassRankingsList> createState() => _ClassRankingsListState();
}

class _ClassRankingsListState extends State<ClassRankingsList> {
  final _data = SchoolDataService.instance;

  String _studentIdFor(RankedStudentReport entry) {
    final ref = _data.findStudentInClass(
      className: widget.className,
      studentName: entry.report.studentName,
    );
    return ref?.id ?? entry.report.studentName;
  }

  void _setConduct(RankedStudentReport entry, StudentConductRating rating) {
    setState(() {
      _data.setStudentConduct(
        className: widget.className,
        studentId: _studentIdFor(entry),
        rating: rating,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return ListView(
          padding: listPagePadding(context),
          children: [
            _RankLegendCard(s: s, rankings: widget.rankings),
            const SizedBox(height: 12),
            ...widget.rankings.map(
              (entry) => _RankStudentCard(
                entry: entry,
                className: widget.className,
                studentId: _studentIdFor(entry),
                onOpen: () => widget.onOpenStudent(entry),
                onConductChanged: (rating) => _setConduct(entry, rating),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RankLegendCard extends StatelessWidget {
  const _RankLegendCard({required this.s, required this.rankings});

  final AppStrings s;
  final List<RankedStudentReport> rankings;

  int _countFor(bool Function(RankedStudentReport entry) test) =>
      rankings.where(test).length;

  @override
  Widget build(BuildContext context) {
    final top3 = _countFor((e) => e.average >= 50 && e.rank <= 3);
    final top10 = _countFor((e) => e.average >= 50 && e.rank >= 4 && e.rank <= 10);
    final standard = _countFor((e) => e.average >= 50 && e.rank >= 11);
    final below50 = _countFor((e) => e.average < 50);

    return Card(
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.rankLegendTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _LegendChip(
                  color: const Color(0xFF15803D),
                  label: s.rankLegendTop3,
                  count: top3,
                ),
                _LegendChip(
                  color: const Color(0xFFCA8A04),
                  label: s.rankLegendTop10,
                  count: top10,
                ),
                _LegendChip(
                  color: const Color(0xFF475569),
                  label: s.rankLegendStandard,
                  count: standard,
                ),
                _LegendChip(
                  color: const Color(0xFFDC2626),
                  label: s.rankLegendBelow50,
                  count: below50,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    required this.count,
  });

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankStudentCard extends StatelessWidget {
  const _RankStudentCard({
    required this.entry,
    required this.className,
    required this.studentId,
    required this.onOpen,
    required this.onConductChanged,
  });

  final RankedStudentReport entry;
  final String className;
  final String studentId;
  final VoidCallback onOpen;
  final ValueChanged<StudentConductRating> onConductChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final style = rankVisualStyle(entry.rank, entry.average);
    final conduct = SchoolDataService.instance.getStudentConduct(
      className: className,
      studentId: studentId,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: style.background,
        elevation: 1,
        shadowColor: style.accent.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: style.border, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onOpen,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: style.accent,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: style.accent.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          '${entry.rank}',
                          style: TextStyle(
                            color: style.badgeText,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
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
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              s.averageLabel(entry.average),
                              style: TextStyle(
                                color: style.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: style.accent),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.studentConductLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              ConductRatingSelector(
                selected: conduct,
                compact: true,
                onChanged: onConductChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConductRatingSelector extends StatelessWidget {
  const ConductRatingSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  final StudentConductRating? selected;
  final ValueChanged<StudentConductRating> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final options = [
      (StudentConductRating.excellent, s.conductExcellent, Icons.star_rounded, const Color(0xFF15803D)),
      (StudentConductRating.satisfactory, s.conductSatisfactory, Icons.thumb_up_alt_outlined, const Color(0xFFCA8A04)),
      (StudentConductRating.needsAttention, s.conductNeedsAttention, Icons.warning_amber_rounded, const Color(0xFFDC2626)),
    ];

    return Wrap(
      spacing: compact ? 6 : 10,
      runSpacing: compact ? 6 : 10,
      children: options.map((option) {
        final (rating, label, icon, color) = option;
        final isSelected = selected == rating;
        return Material(
          color: isSelected ? color.withValues(alpha: 0.14) : Colors.white,
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          child: InkWell(
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            onTap: () => onChanged(rating),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 12,
                vertical: compact ? 6 : 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(compact ? 12 : 14),
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade300,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: compact ? 16 : 18, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: compact ? 11 : 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
