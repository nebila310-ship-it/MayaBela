import 'package:mayabela/models/announcement.dart';

/// One official report-card row. The table shows the subject only.
/// Assessment detail and the teacher comment stay in [remark], printed
/// under the table.
class ReportCardSubjectLine {
  const ReportCardSubjectLine({
    required this.subject,
    required this.scoreLabel,
    required this.grade,
    this.remark,
  });

  final String subject;
  final String scoreLabel;
  final String grade;
  final String? remark;
}

abstract final class ReportCardLayout {
  static List<ReportCardSubjectLine> lines(StudentGradeReport report) {
    return [
      for (final subject in report.subjects)
        ReportCardSubjectLine(
          subject: subject.subject,
          scoreLabel:
              '${subject.score.toStringAsFixed(1)} / ${subject.maxScore.toStringAsFixed(0)}',
          grade: subject.letterGrade,
          remark: remarkFor(subject),
        ),
    ];
  }

  static String? remarkFor(SubjectGrade subject) {
    final parts = <String>[];
    if (subject.hasMarkbook) {
      final breakdown = subject.assessments
          .where((mark) => mark.isEntered)
          .map(
            (mark) =>
                '${mark.label} ${mark.score!.toStringAsFixed(0)} (${mark.weightPercent.toStringAsFixed(0)}%)',
          )
          .join(' · ');
      if (breakdown.isNotEmpty) parts.add(breakdown);
    }
    final comment = subject.comment?.trim();
    if (comment != null && comment.isNotEmpty) parts.add(comment);
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  static String fileToken(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'student' : cleaned;
  }
}
