import 'dart:convert';
import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:mayabela/models/admission_application.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/attendance_intelligence_models.dart';
import 'package:mayabela/services/admission_service.dart';
import 'package:mayabela/services/attendance_intelligence_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/grade_analytics_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/student_support_service.dart';
import 'package:mayabela/services/teacher_performance_insights.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

enum SchoolReportKind {
  students,
  attendance,
  academic,
  finance,
  transport,
  teachers,
  inventory,
  admissions,
  health,
}

/// Web-safe school report exporter (CSV / Excel via in-memory bytes + share).
class SchoolReportExportService {
  SchoolReportExportService._();
  static final instance = SchoolReportExportService._();

  /// True once real exporters are wired (sell-readiness gate).
  static const bool hasRealExporter = true;

  Future<void> export({
    required SchoolReportKind kind,
    required String format, // Excel | CSV | PDF | Print
  }) async {
    final normalized = format.trim().toLowerCase();
    if (normalized == 'print') {
      await export(kind: kind, format: 'PDF');
      return;
    }

    final stamp = DateTime.now();
    final stampToken =
        '${stamp.year}-${stamp.month.toString().padLeft(2, '0')}-${stamp.day.toString().padLeft(2, '0')}';
    final schoolId = AuthService.activeSchoolId ?? 'school';
    final subject = '${_title(kind)} · $schoolId';

    if (normalized == 'pdf') {
      final bytes = await _buildPdf(kind);
      await _shareBytes(
        bytes: bytes,
        fileName: '${kind.name}_report_$stampToken.pdf',
        mimeType: 'application/pdf',
        subject: subject,
      );
      return;
    }

    if (normalized == 'csv') {
      final csv = _buildCsv(kind);
      await _shareBytes(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileName: '${kind.name}_report_$stampToken.csv',
        mimeType: 'text/csv',
        subject: subject,
      );
      return;
    }

    // Excel (default)
    final bytes = _buildExcel(kind);
    await _shareBytes(
      bytes: Uint8List.fromList(bytes),
      fileName: '${kind.name}_report_$stampToken.xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      subject: subject,
    );
  }

  /// Builds PDF bytes for tests and direct callers (same data as share export).
  Future<Uint8List> buildPdfBytes(SchoolReportKind kind) => _buildPdf(kind);

  /// Same rows as CSV / Excel / PDF. Public for tests and in-app previews.
  List<List<String>> rowsFor(SchoolReportKind kind) => _rows(kind);

  String _title(SchoolReportKind kind) => switch (kind) {
        SchoolReportKind.students => 'Student Reports',
        SchoolReportKind.attendance => 'Attendance Reports',
        SchoolReportKind.academic => 'Academic Reports',
        SchoolReportKind.finance => 'Financial Reports',
        SchoolReportKind.transport => 'Transport Reports',
        SchoolReportKind.teachers => 'Teacher Reports',
        SchoolReportKind.inventory => 'Inventory Reports',
        SchoolReportKind.admissions => 'Admissions Reports',
        SchoolReportKind.health => 'Health & Clinic Reports',
      };

  Future<void> _shareBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String subject,
  }) async {
    final xFile = XFile.fromData(
      bytes,
      mimeType: mimeType,
      name: fileName,
    );
    await Share.shareXFiles(
      [xFile],
      subject: subject,
      text: subject,
    );
  }

  String _buildCsv(SchoolReportKind kind) {
    final rows = _rows(kind);
    return rows.map(_csvLine).join('\n');
  }

  List<int> _buildExcel(SchoolReportKind kind) {
    final excel = Excel.createExcel();
    final defaultName = excel.sheets.keys.first;
    final sheetName = _title(kind).replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '');
    excel.rename(defaultName, sheetName);
    final sheet = excel[sheetName];
    final rows = _rows(kind);
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .value = TextCellValue(rows[r][c]);
      }
    }
    return excel.encode() ?? utf8.encode(_buildCsv(kind));
  }

  Future<Uint8List> _buildPdf(SchoolReportKind kind) async {
    final rows = _rows(kind);
    final headers = rows.isEmpty ? <String>[] : rows.first;
    final dataRows = rows.length <= 1 ? <List<String>>[] : rows.sublist(1);
    final schoolId = AuthService.activeSchoolId ?? '-';
    final generated = DateTime.now().toIso8601String().split('T').first;

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              _title(kind),
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'School: $schoolId  ·  Generated: $generated',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) {
          if (headers.isEmpty) {
            return [pw.Text('No data')];
          }
          return [
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: dataRows
                  .map((r) => List<String>.generate(
                        headers.length,
                        (i) => i < r.length ? r[i] : '',
                      ))
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.3,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 3,
              ),
            ),
          ];
        },
      ),
    );
    return doc.save();
  }

  List<List<String>> _rows(SchoolReportKind kind) {
    final schoolId = AuthService.activeSchoolId;
    switch (kind) {
      case SchoolReportKind.students:
        final students = schoolId == null
            ? StudentRegistryService.instance.getAllStudents()
            : StudentRegistryService.instance.studentsForSchool(schoolId);
        return [
          ['Student ID', 'Full Name', 'Grade', 'Class', 'Status', 'School ID'],
          for (final s in students)
            [
              s.studentId,
              s.fullName,
              s.grade,
              s.className,
              s.isActive ? 'active' : 'inactive',
              s.schoolId,
            ],
        ];
      case SchoolReportKind.teachers:
        final teachers = schoolId == null
            ? TeacherRegistryService.instance.getAllTeachers()
            : TeacherRegistryService.instance.teachersForSchool(schoolId);
        final insights = TeacherPerformanceInsights.instance.rows(schoolId);
        final byId = {
          for (final row in insights)
            if ((row.teacherId ?? '').trim().isNotEmpty)
              row.teacherId!.trim().toUpperCase(): row,
        };
        final byName = {
          for (final row in insights) row.teacherName.trim().toLowerCase(): row,
        };
        return [
          [
            'Teacher ID',
            'Full Name',
            'Subjects',
            'Classes',
            'Phone',
            'Active',
            'Eval avg',
            'Evals',
            'Observation avg',
            'Observations',
          ],
          for (final t in teachers)
            _teacherRow(
              t,
              byId[t.teacherId.trim().toUpperCase()] ??
                  byName[t.fullName.trim().toLowerCase()],
            ),
        ];
      case SchoolReportKind.finance:
        final fees = SchoolDataService.instance.getAllFees();
        return [
          ['Student', 'Fee', 'Amount', 'Due', 'Status', 'Paid at'],
          for (final f in fees)
            [
              f.studentName,
              f.title,
              f.amount.toStringAsFixed(2),
              f.dueDate.toIso8601String().split('T').first,
              f.status.name,
              f.paidDate?.toIso8601String().split('T').first ?? '',
            ],
        ];
      case SchoolReportKind.transport:
        final buses = BusRegistryService.instance.busesForSchool(schoolId);
        final drivers = DriverRegistryService.instance.driversForSchool(schoolId);
        return [
          ['Type', 'ID', 'Name / Number', 'Route / Plate', 'Phone'],
          for (final b in buses)
            [
              'Bus',
              b.busId,
              b.busNumber,
              '${b.routeName} / ${b.plateNumber}',
              '',
            ],
          for (final d in drivers)
            [
              'Driver',
              d.driverId,
              d.fullName,
              '${d.routeName} / ${d.plateNumber}',
              d.phone ?? '',
            ],
        ];
      case SchoolReportKind.attendance:
        final now = DateTime.now();
        final from = now.subtract(const Duration(days: 30));
        final report = SchoolDataService.instance.buildAttendanceReportForRange(
          fromDate: from,
          toDate: now,
        );
        final profiles = AttendanceIntelligenceService.instance.profiles();
        return [
          [
            'Student',
            'Class',
            'Present',
            'Late',
            'Absent',
            'Sessions',
            'Attendance %',
            'Risk',
            'Marks %',
          ],
          [
            '30-day summary',
            '${from.toIso8601String().split('T').first} – '
                '${now.toIso8601String().split('T').first}',
            '${report.presentCount}',
            '${report.lateCount}',
            '${report.absentCount}',
            '${report.dayCount}',
            '',
            '',
            '',
          ],
          for (final p in profiles)
            [
              p.studentName,
              p.className,
              '${p.present}',
              '${p.late}',
              '${p.absent}',
              '${p.sessions}',
              (p.attendanceRate * 100).round().toString(),
              p.level.name,
              p.hasGrades && p.gradeAverage != null
                  ? p.gradeAverage!.toStringAsFixed(0)
                  : '',
            ],
        ];
      case SchoolReportKind.academic:
        final students = schoolId == null
            ? StudentRegistryService.instance.getAllStudents()
            : StudentRegistryService.instance.studentsForSchool(schoolId);
        final reports = SchoolDataService.instance.getAllGradeReports();
        final latest = <String, StudentGradeReport>{};
        for (final report in reports) {
          latest[_academicKey(
            studentId: report.studentId,
            className: report.className,
            studentName: report.studentName,
          )] = report;
        }
        final attendance = {
          for (final row
              in GradeAnalyticsService.instance.gradeAttendanceRows())
            '${row.className}\u0000${row.studentName}': row,
        };
        final risk = {
          for (final p in AttendanceIntelligenceService.instance.profiles())
            '${p.className}\u0000${p.studentName}': p,
        };
        final seen = <String>{};
        final rows = <List<String>>[
          [
            'Student ID',
            'Name',
            'Class',
            'Grade level',
            'Term',
            'Mark average %',
            'Subjects',
            'Attendance %',
            'Sessions',
            'At-risk',
          ],
        ];
        for (final s in students.where((e) => e.isActive)) {
          final key = _academicKey(
            studentId: s.studentId,
            className: s.className,
            studentName: s.fullName,
          );
          seen.add(key);
          seen.add(_academicKey(
            className: s.className,
            studentName: s.fullName,
          ));
          final report = latest[key] ??
              latest[_academicKey(
                className: s.className,
                studentName: s.fullName,
              )];
          rows.add(
            _academicRow(
              studentId: s.studentId,
              name: s.fullName,
              className: s.className,
              gradeLevel: s.grade,
              report: report,
              attendance: attendance['${s.className}\u0000${s.fullName}'],
              risk: risk['${s.className}\u0000${s.fullName}'],
            ),
          );
        }
        for (final report in reports) {
          final key = _academicKey(
            studentId: report.studentId,
            className: report.className,
            studentName: report.studentName,
          );
          final nameKey = _academicKey(
            className: report.className,
            studentName: report.studentName,
          );
          if (seen.contains(key) || seen.contains(nameKey)) continue;
          seen.add(key);
          rows.add(
            _academicRow(
              studentId: report.studentId ?? '',
              name: report.studentName,
              className: report.className,
              gradeLevel: '',
              report: report,
              attendance:
                  attendance['${report.className}\u0000${report.studentName}'],
              risk: risk['${report.className}\u0000${report.studentName}'],
            ),
          );
        }
        return rows;
      case SchoolReportKind.inventory:
        return [
          ['Note'],
          [
            'Open Inventory → Reports section for stock detail, '
                'or export Students/Finance for related ledgers.',
          ],
        ];
      case SchoolReportKind.admissions:
        final apps = AdmissionService.instance.forSchool(schoolId);
        return [
          [
            'Application ID',
            'Name',
            'Stage',
            'Source',
            'Grade',
            'Previous school',
            'Last grade',
            'Prior average',
            'Exam score',
            'Waitlist rank',
            'Enrolled student',
          ],
          for (final a in apps)
            [
              a.id,
              a.fullName,
              a.stageLabel,
              a.source.name,
              a.gradeApplying,
              a.previousSchool,
              a.lastGradeCompleted,
              a.previousAverage?.toString() ?? '',
              a.examScore?.toString() ?? '',
              a.waitlistRank?.toString() ?? '',
              a.enrolledStudentId ?? '',
            ],
        ];
      case SchoolReportKind.health:
        return StudentSupportService.instance.healthReportRows(schoolId);
    }
  }

  List<String> _teacherRow(
    AdminTeacherRecord teacher,
    TeacherPerformanceRow? insight,
  ) {
    return [
      teacher.teacherId,
      teacher.fullName,
      teacher.subject,
      teacher.assignedClass,
      teacher.phone ?? '',
      teacher.isActive ? 'active' : 'inactive',
      insight?.evaluationAverage?.toStringAsFixed(2) ?? '',
      '${insight?.evaluationCount ?? 0}',
      insight?.observationAverage?.toStringAsFixed(2) ?? '',
      '${insight?.observationCount ?? 0}',
    ];
  }

  String _academicKey({
    String? studentId,
    required String className,
    required String studentName,
  }) {
    final id = (studentId ?? '').trim();
    if (id.isNotEmpty) return 'id:${id.toUpperCase()}';
    return 'name:${className.trim()}\u0000${studentName.trim()}';
  }

  List<String> _academicRow({
    required String studentId,
    required String name,
    required String className,
    required String gradeLevel,
    StudentGradeReport? report,
    GradeAttendanceRow? attendance,
    StudentRiskProfile? risk,
  }) {
    final sessions = attendance?.sessions ?? 0;
    final attendancePct = attendance == null || sessions == 0
        ? (risk == null || risk.sessions == 0
            ? ''
            : (risk.attendanceRate * 100).round().toString())
        : (attendance.attendanceRate * 100).round().toString();
    return [
      studentId,
      name,
      className,
      gradeLevel,
      report?.term ?? '',
      report == null || report.subjects.isEmpty
          ? ''
          : report.average.toStringAsFixed(0),
      report == null ? '' : '${report.subjects.length}',
      attendancePct,
      sessions > 0
          ? '$sessions'
          : (risk == null || risk.sessions == 0 ? '' : '${risk.sessions}'),
      risk?.isAtRisk == true ? 'yes' : 'no',
    ];
  }

  String _csvLine(List<String> cells) {
    return cells.map((c) {
      final needsQuote =
          c.contains(',') || c.contains('"') || c.contains('\n');
      final escaped = c.replaceAll('"', '""');
      return needsQuote ? '"$escaped"' : escaped;
    }).join(',');
  }
}
