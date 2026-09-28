import 'package:flutter/material.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

/// Term report card used by parents, students, and the staff desk.
class TermReportCardView extends StatelessWidget {
  const TermReportCardView({
    super.key,
    required this.report,
    this.schoolName,
    this.compact = false,
  });

  final StudentGradeReport report;
  final String? schoolName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final snap = report.attendanceSnapshot;
    final ink = WebErpTheme.paperInk;
    return Container(
      decoration: WebErpTheme.cardDecoration(context),
      padding: EdgeInsets.all(compact ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            schoolName ?? 'Report card',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 16 : 20,
              color: ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              report.studentName,
              report.className,
              report.term,
              if (report.academicYear != null && report.academicYear!.isNotEmpty)
                report.academicYear!,
            ].join(' · '),
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _stat('Average', '${report.average.toStringAsFixed(1)}%'),
              _stat('GPA', report.gpa.toStringAsFixed(2)),
              _stat(
                'Attendance',
                snap.sessions == 0
                    ? '—'
                    : '${(snap.rate * 100).round()}%  (${snap.present}P ${snap.late}L ${snap.absent}A)',
              ),
              if (report.reportCardPublished)
                _stat('Status', 'Published to parents'),
            ],
          ),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(0.7),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Subject', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Score', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Grade', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              for (final subject in report.subjects)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subject.subject,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (subject.hasMarkbook)
                            Text(
                              subject.assessments
                                  .where((m) => m.isEntered)
                                  .map((m) =>
                                      '${m.label} ${m.score!.toStringAsFixed(0)} (${m.weightPercent.toStringAsFixed(0)}%)')
                                  .join(' · '),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${subject.score.toStringAsFixed(1)} / ${subject.maxScore.toStringAsFixed(0)}',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        subject.letterGrade,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (report.homeroomComment?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text('Homeroom comment',
                style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
            const SizedBox(height: 4),
            Text(report.homeroomComment!.trim()),
          ],
          if (report.principalComment?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text('Principal comment',
                style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
            const SizedBox(height: 4),
            Text(report.principalComment!.trim()),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: WebErpTheme.sidebarActive,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
