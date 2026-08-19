import 'dart:convert';
import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

enum SchoolReportKind {
  students,
  attendance,
  academic,
  finance,
  transport,
  teachers,
  inventory,
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

  String _title(SchoolReportKind kind) => switch (kind) {
        SchoolReportKind.students => 'Student Reports',
        SchoolReportKind.attendance => 'Attendance Reports',
        SchoolReportKind.academic => 'Academic Reports',
        SchoolReportKind.finance => 'Financial Reports',
        SchoolReportKind.transport => 'Transport Reports',
        SchoolReportKind.teachers => 'Teacher Reports',
        SchoolReportKind.inventory => 'Inventory Reports',
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
        return [
          ['Teacher ID', 'Full Name', 'Subjects', 'Classes', 'Phone', 'Active'],
          for (final t in teachers)
            [
              t.teacherId,
              t.fullName,
              t.subject,
              t.assignedClass,
              t.phone ?? '',
              t.isActive ? 'active' : 'inactive',
            ],
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
        return [
          ['Metric', 'Value'],
          ['From', from.toIso8601String().split('T').first],
          ['To', now.toIso8601String().split('T').first],
          ['Present', '${report.presentCount}'],
          ['Late', '${report.lateCount}'],
          ['Absent', '${report.absentCount}'],
          ['Days with records', '${report.dayCount}'],
        ];
      case SchoolReportKind.academic:
        final students = schoolId == null
            ? StudentRegistryService.instance.getAllStudents()
            : StudentRegistryService.instance.studentsForSchool(schoolId);
        return [
          ['Student ID', 'Name', 'Class', 'Grade level'],
          for (final s in students.where((e) => e.isActive))
            [s.studentId, s.fullName, s.className, s.grade],
        ];
      case SchoolReportKind.inventory:
        return [
          ['Note'],
          [
            'Open Inventory → Reports section for stock detail, '
                'or export Students/Finance for related ledgers.',
          ],
        ];
    }
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
