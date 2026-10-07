import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/grade_report_certificate_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/widgets/school_logo_display.dart';

/// On-screen official grade report certificate.
class GradeReportCertificateView extends StatelessWidget {
  const GradeReportCertificateView({super.key, required this.certificate});

  final GradeReportCertificateSnapshot certificate;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final school = SchoolRegistryService.instance.lookup(certificate.schoolId);
    const navy = Color(0xFF312E81);
    const gold = Color(0xFFC9A227);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: navy, width: 2.4),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: gold, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SchoolLogoDisplay(
                      schoolId:
                          certificate.schoolId ?? AuthService.activeSchoolId,
                      style: school?.logoStyle ?? SchoolLogoStyle.rectangular,
                      height: 56,
                      width: 56,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            certificate.schoolName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: navy,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.gradeReportCertificateTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: navy, thickness: 1),
                const SizedBox(height: 10),
                _infoTable(s),
                const SizedBox(height: 16),
                Text(
                  s.approvedSubjectsThatMakeAverage,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 8),
                if (certificate.subjects.isEmpty)
                  Text(
                    s.noApprovedSubjectsForAverage,
                    style: TextStyle(color: Colors.grey.shade700),
                  )
                else
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.2),
                      1: FlexColumnWidth(0.9),
                      2: FlexColumnWidth(0.7),
                      3: FlexColumnWidth(0.7),
                      4: FlexColumnWidth(0.7),
                    },
                    border: TableBorder.all(color: Colors.grey.shade300),
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: navy),
                        children: [
                          for (final label in [
                            s.subjectNameLabel,
                            s.exportScoreColumn,
                            s.exportMaxScoreColumn,
                            s.exportPercentageColumn,
                            s.exportLetterGradeColumn,
                          ])
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      for (final subject in certificate.subjects)
                        TableRow(
                          children: [
                            _cell(subject.subject, bold: true),
                            _cell(subject.score.toStringAsFixed(1)),
                            _cell(subject.maxScore.toStringAsFixed(0)),
                            _cell('${subject.percentage.toStringAsFixed(1)}%'),
                            _cell(subject.letterGrade, bold: true),
                          ],
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _chip(
                      s.exportAverageColumn,
                      '${certificate.average.toStringAsFixed(1)}%',
                    ),
                    _chip('GPA', certificate.gpa.toStringAsFixed(2)),
                    _chip(
                      s.attendanceTitle,
                      certificate.attendance.sessions == 0
                          ? '—'
                          : '${(certificate.attendance.rate * 100).round()}%',
                    ),
                  ],
                ),
                if ((certificate.homeroomComment ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    s.homeroomTeacher,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(certificate.homeroomComment!.trim()),
                ],
                if ((certificate.principalComment ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    s.principalCommentLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(certificate.principalComment!.trim()),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _signLine(
                        s.homeroomTeacher,
                        certificate.homeroomTeacher,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _signLine(s.principalSignatureLabel, null),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoTable(AppStrings s) {
    Widget cell(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF312E81),
              ),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    String dash(String? value) {
      final trimmed = value?.trim() ?? '';
      return trimmed.isEmpty ? '—' : trimmed;
    }

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        TableRow(
          children: [
            cell(s.fullName, certificate.studentName),
            cell(s.studentId, dash(certificate.studentId)),
          ],
        ),
        TableRow(
          children: [
            cell(s.className, certificate.className),
            cell(s.grade, dash(certificate.gradeLevel)),
          ],
        ),
        TableRow(
          children: [
            cell(s.termLabel, certificate.term),
            cell(s.academicYear, dash(certificate.academicYear)),
          ],
        ),
        TableRow(
          children: [
            cell(s.gender, dash(certificate.gender)),
            cell(s.campus, dash(certificate.campus)),
          ],
        ),
      ],
    );
  }

  Widget _cell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Chip(
      label: Text('$label  $value'),
      backgroundColor: const Color(0xFFEEF2FF),
    );
  }

  Widget _signLine(String title, String? name) {
    return Column(
      children: [
        Container(
          height: 36,
          alignment: Alignment.bottomCenter,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.black54)),
          ),
          child: Text(name?.trim() ?? ''),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
