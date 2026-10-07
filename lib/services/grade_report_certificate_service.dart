import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/platform/school_splash_brand.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/grade_analytics_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/web_file_utils.dart';

class GradeReportCertificateSnapshot {
  const GradeReportCertificateSnapshot({
    required this.schoolName,
    required this.studentName,
    required this.className,
    required this.term,
    required this.issuedAt,
    required this.subjects,
    required this.attendance,
    this.schoolId,
    this.schoolCity,
    this.schoolAddress,
    this.academicYear,
    this.studentId,
    this.gradeLevel,
    this.gender,
    this.campus,
    this.parentName,
    this.homeroomTeacher,
    this.homeroomComment,
    this.principalComment,
  });

  final String schoolName;
  final String? schoolId;
  final String? schoolCity;
  final String? schoolAddress;
  final String? academicYear;
  final String studentName;
  final String? studentId;
  final String className;
  final String? gradeLevel;
  final String? gender;
  final String? campus;
  final String? parentName;
  final String term;
  final DateTime issuedAt;
  final List<SubjectGrade> subjects;
  final StudentAttendanceSnapshot attendance;
  final String? homeroomTeacher;
  final String? homeroomComment;
  final String? principalComment;

  double get average {
    if (subjects.isEmpty) return 0;
    return subjects.map((s) => s.percentage).reduce((a, b) => a + b) /
        subjects.length;
  }

  double get gpa {
    if (subjects.isEmpty) return 0;
    return subjects.map((s) => s.gpaPoints).reduce((a, b) => a + b) /
        subjects.length;
  }

  String get fileName {
    final safe = studentName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final termSafe = term.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return 'grade_report_certificate_${safe}_$termSafe.pdf';
  }
}

/// Official per-student grade report certificate (PDF + on-screen data).
class GradeReportCertificateService {
  GradeReportCertificateService._();
  static final instance = GradeReportCertificateService._();

  GradeReportCertificateSnapshot buildSnapshot(StudentGradeReport report) {
    final schoolId = AuthService.activeSchoolId;
    final school = SchoolRegistryService.instance.lookup(schoolId);
    final schoolName = SchoolRegistryService.instance.displayName(schoolId);
    final student = _studentFor(report);
    final approved =
        GradeAnalyticsService.approvedSubjectsForAverage(report);
    final attendance = SchoolDataService.instance.attendanceSnapshotForStudent(
      studentName: report.studentName,
      className: report.className,
      studentId: report.studentId ?? student?.studentId,
    );
    return GradeReportCertificateSnapshot(
      schoolName: schoolName,
      schoolId: schoolId,
      schoolCity: school?.city,
      schoolAddress: school?.address,
      academicYear: report.academicYear ??
          student?.academicYear ??
          school?.academicYear,
      studentName: report.studentName,
      studentId: report.studentId ?? student?.studentId,
      className: report.className,
      gradeLevel: student?.grade,
      gender: student?.gender,
      campus: student?.campus,
      parentName: student?.primaryParentName,
      term: report.term,
      issuedAt: DateTime.now(),
      subjects: approved,
      attendance: attendance.sessions > 0
          ? attendance
          : report.attendanceSnapshot,
      homeroomTeacher:
          SchoolDataService.instance.homeroomTeacherNameForClass(
        report.className,
      ),
      homeroomComment: report.homeroomComment,
      principalComment: report.principalComment,
    );
  }

  Future<Uint8List> buildPdfBytes(StudentGradeReport report) {
    return buildPdfFromSnapshot(buildSnapshot(report));
  }

  Future<Uint8List> buildPdfFromSnapshot(
    GradeReportCertificateSnapshot cert,
  ) async {
    final logo = _logoImage(cert.schoolId);
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xFF312E81), width: 2.2),
            ),
            padding: const pw.EdgeInsets.all(6),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColor.fromInt(0xFFC9A227),
                  width: 1.4,
                ),
              ),
              padding: const pw.EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logo != null)
                        pw.Container(
                          width: 56,
                          height: 56,
                          margin: const pw.EdgeInsets.only(right: 14),
                          child: pw.Image(logo, fit: pw.BoxFit.contain),
                        ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              cert.schoolName,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromInt(0xFF312E81),
                              ),
                            ),
                            if ((cert.schoolCity ?? '').trim().isNotEmpty ||
                                (cert.schoolAddress ?? '').trim().isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 2),
                                child: pw.Text(
                                  [
                                    if ((cert.schoolAddress ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      cert.schoolAddress!.trim(),
                                    if ((cert.schoolCity ?? '').trim().isNotEmpty)
                                      cert.schoolCity!.trim(),
                                  ].join(' | '),
                                  textAlign: pw.TextAlign.center,
                                  style: const pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                              ),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              'GRADE REPORT CERTIFICATE',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1.4,
                                color: PdfColor.fromInt(0xFFC9A227),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(color: PdfColor.fromInt(0xFF312E81), thickness: 0.8),
                  pw.SizedBox(height: 10),
                  _infoGrid(cert),
                  pw.SizedBox(height: 14),
                  pw.Text(
                    'Approved subject results',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF312E81),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  if (cert.subjects.isEmpty)
                    pw.Text(
                      'No approved subjects have been entered for this term.',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    )
                  else
                    pw.TableHelper.fromTextArray(
                      headers: const [
                        'Subject',
                        'Score',
                        'Max',
                        '%',
                        'Grade',
                      ],
                      data: [
                        for (final subject in cert.subjects)
                          [
                            subject.subject,
                            subject.score.toStringAsFixed(1),
                            subject.maxScore.toStringAsFixed(0),
                            subject.percentage.toStringAsFixed(1),
                            subject.letterGrade,
                          ],
                      ],
                      headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: PdfColors.white,
                      ),
                      headerDecoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFF312E81),
                      ),
                      cellStyle: const pw.TextStyle(fontSize: 9),
                      cellAlignment: pw.Alignment.centerLeft,
                      headerAlignment: pw.Alignment.centerLeft,
                      border: pw.TableBorder.all(
                        color: PdfColors.grey400,
                        width: 0.3,
                      ),
                      cellPadding: const pw.EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 4,
                      ),
                    ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    children: [
                      _statBox('Average', '${cert.average.toStringAsFixed(1)}%'),
                      pw.SizedBox(width: 8),
                      _statBox('GPA', cert.gpa.toStringAsFixed(2)),
                      pw.SizedBox(width: 8),
                      _statBox(
                        'Attendance',
                        cert.attendance.sessions == 0
                            ? '-'
                            : '${(cert.attendance.rate * 100).round()}%  '
                                '(${cert.attendance.present}P '
                                '${cert.attendance.late}L '
                                '${cert.attendance.absent}A)',
                      ),
                    ],
                  ),
                  if ((cert.homeroomComment ?? '').trim().isNotEmpty) ...[
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'Homeroom comment',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      cert.homeroomComment!.trim(),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                  if ((cert.principalComment ?? '').trim().isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Principal comment',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      cert.principalComment!.trim(),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                  pw.Spacer(),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _signature('Homeroom teacher', cert.homeroomTeacher),
                      _signature('Principal / Head of school', null),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Issued ${_formatDate(cert.issuedAt)}  |  Official school record',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return doc.save();
  }

  Future<void> downloadPdf(GradeReportCertificateSnapshot cert) async {
    final bytes = await buildPdfFromSnapshot(cert);
    if (kIsWeb) {
      await WebFileUtils.downloadBytes(fileName: cert.fileName, bytes: bytes);
      return;
    }
    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: 'application/pdf',
          name: cert.fileName,
        ),
      ],
      subject: '${cert.schoolName} · Grade report certificate',
      text: '${cert.studentName} · ${cert.className} · ${cert.term}',
    );
  }

  AdminStudentRecord? _studentFor(StudentGradeReport report) {
    final id = report.studentId;
    if (id != null && id.trim().isNotEmpty) {
      final byId = StudentRegistryService.instance.lookupById(id);
      if (byId != null) return byId;
    }
    return StudentRegistryService.instance.lookupByName(report.studentName);
  }

  pw.MemoryImage? _logoImage(String? schoolId) {
    final id = schoolId?.trim();
    if (id == null || id.isEmpty) return null;
    final school = SchoolRegistryService.instance.lookup(id);
    final payload = SchoolSplashBrand.readBytes(
      schoolId: id,
      style: school?.logoStyle,
    );
    if (payload == null || payload.isEmpty) return null;
    try {
      return pw.MemoryImage(payload);
    } catch (_) {
      return null;
    }
  }

  pw.Widget _infoGrid(GradeReportCertificateSnapshot cert) {
    final rows = <List<String>>[
      ['Student name', cert.studentName, 'Student ID', cert.studentId ?? '-'],
      [
        'Class',
        cert.className,
        'Grade',
        (cert.gradeLevel ?? '').trim().isEmpty ? '-' : cert.gradeLevel!,
      ],
      [
        'Term',
        cert.term,
        'Academic year',
        (cert.academicYear ?? '').trim().isEmpty ? '-' : cert.academicYear!,
      ],
      [
        'Gender',
        (cert.gender ?? '').trim().isEmpty ? '-' : cert.gender!,
        'Campus',
        (cert.campus ?? '').trim().isEmpty ? '-' : cert.campus!,
      ],
      [
        'Parent / guardian',
        (cert.parentName ?? '').trim().isEmpty ? '-' : cert.parentName!,
        'Homeroom teacher',
        (cert.homeroomTeacher ?? '').trim().isEmpty
            ? '-'
            : cert.homeroomTeacher!,
      ],
    ];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.15),
        1: pw.FlexColumnWidth(1.55),
        2: pw.FlexColumnWidth(1.15),
        3: pw.FlexColumnWidth(1.55),
      },
      children: [
        for (final row in rows)
          pw.TableRow(
            children: [
              for (var i = 0; i < 4; i++)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: pw.Text(
                    row[i],
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight:
                          i.isEven ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: i.isEven
                          ? PdfColor.fromInt(0xFF312E81)
                          : PdfColors.black,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  pw.Widget _statBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFEEF2FF),
          border: pw.Border.all(color: PdfColor.fromInt(0xFFC7D2FE)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF312E81),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _signature(String title, String? name) {
    return pw.Container(
      width: 200,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 160,
            height: 28,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.6),
              ),
            ),
            alignment: pw.Alignment.bottomCenter,
            child: pw.Text(
              (name ?? '').trim(),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
