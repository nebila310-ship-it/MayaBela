import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/grade_analytics_service.dart';
import 'package:mayabela/services/grade_workflow_service.dart';
import 'package:mayabela/widgets/student_photo_avatar.dart';

Future<void> showGradeAverageBreakdownSheet(
  BuildContext context,
  StudentGradeReport report,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return GradeAverageBreakdownSheet(report: report);
    },
  );
}

/// Approved, entered subjects that produce a ranking average.
class GradeAverageBreakdownSheet extends StatelessWidget {
  const GradeAverageBreakdownSheet({super.key, required this.report});

  final StudentGradeReport report;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final approved = GradeAnalyticsService.approvedSubjectsForAverage(
          report,
        );
        final average = approved.isEmpty
            ? 0.0
            : approved.map((g) => g.percentage).reduce((a, b) => a + b) /
                  approved.length;
        final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      StudentPhotoAvatar(
                        studentId: report.studentId,
                        name: report.studentName,
                        radius: 28,
                        enableViewer: false,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.studentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              report.className,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.averageLabel(average),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF4338CA),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.approvedSubjectsThatMakeAverage,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: approved.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              s.noApprovedSubjectsForAverage,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          )
                        : ListView.separated(
                            itemCount: approved.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              return ApprovedSubjectAverageRow(
                                grade: approved[index],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ApprovedSubjectAverageRow extends StatelessWidget {
  const ApprovedSubjectAverageRow({super.key, required this.grade});

  final SubjectGrade grade;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final entered = [
      for (final mark in grade.assessments)
        if (mark.isEntered) mark,
    ];
    return DecoratedBox(
      key: ValueKey('approved-subject-${grade.subject}'),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    grade.subject,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${grade.percentage.toStringAsFixed(1)}%  ${grade.letterGrade}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4338CA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: const Icon(Icons.lock_outline, size: 14),
                  label: Text(s.gradeApprovedLockedLabel),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: const Color(
                    0xFF15803D,
                  ).withValues(alpha: 0.12),
                ),
                Chip(
                  label: Text(GradeWorkflowService.statusLabel(grade.status)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                if (entered.isEmpty)
                  Chip(
                    label: Text(
                      '${grade.score.toInt()}/${grade.maxScore.toInt()}',
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                for (final mark in entered)
                  Chip(
                    label: Text(
                      '${mark.label} ${mark.score!.toStringAsFixed(0)}',
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
