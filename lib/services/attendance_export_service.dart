import 'dart:io';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/school_data_service.dart';

enum AttendanceShareChannel { download, whatsApp, telegram, email, share }

/// ASCII-only Excel tab names — iOS Excel/Numbers reject some localized tab names.
class _ExcelSheets {
  static const summary = 'Summary';
  static const dailyTotals = 'Daily Totals';
  static const studentDetails = 'Student Details';
}

class AttendanceExportLabels {
  const AttendanceExportLabels({
    required this.reportTitle,
    required this.dateLabel,
    required this.fromDateLabel,
    required this.toDateLabel,
    required this.generatedReport,
    required this.readOnlyHint,
    required this.summaryLabel,
    required this.absents,
    required this.late,
    required this.present,
    required this.teachersRecorded,
    required this.className,
    required this.teacherColumn,
    required this.studentName,
    required this.grade,
    required this.status,
    required this.noData,
    required this.daysWithRecords,
    required this.totalLabel,
  });

  factory AttendanceExportLabels.fromStrings(AppStrings s) {
    return AttendanceExportLabels(
      reportTitle: s.attendanceReportsTitle,
      dateLabel: s.selectedDate,
      fromDateLabel: s.exportFromDate,
      toDateLabel: s.exportToDate,
      generatedReport: s.generatedReport,
      readOnlyHint: s.readOnlyReportHint,
      summaryLabel: s.summary,
      absents: s.absents,
      late: s.lateArrivals,
      present: s.presentToday,
      teachersRecorded: s.teachersRecordedAttendance,
      className: s.className,
      teacherColumn: s.exportTeacherColumn,
      studentName: s.exportStudentColumn,
      grade: s.grade,
      status: s.status,
      noData: s.noAttendanceReportForDay,
      daysWithRecords: s.exportDaysWithRecords,
      totalLabel: s.totalLabel,
    );
  }

  final String reportTitle;
  final String dateLabel;
  final String fromDateLabel;
  final String toDateLabel;
  final String generatedReport;
  final String readOnlyHint;
  final String summaryLabel;
  final String absents;
  final String late;
  final String present;
  final String teachersRecorded;
  final String className;
  final String teacherColumn;
  final String studentName;
  final String grade;
  final String status;
  final String noData;
  final String daysWithRecords;
  final String totalLabel;
}

class AttendanceExportResult {
  const AttendanceExportResult({
    required this.file,
    required this.fileName,
    required this.report,
    required this.shareMessage,
    required this.emailSubject,
  });

  final File file;
  final String fileName;
  final AttendanceDateRangeReport report;
  final String shareMessage;
  final String emailSubject;
}

class AttendanceShareOutcome {
  const AttendanceShareOutcome({
    required this.file,
    required this.usedIosSaveSheet,
  });

  final File file;
  final bool usedIosSaveSheet;
}

class AttendanceExportService {
  AttendanceExportService._();
  static final instance = AttendanceExportService._();

  static bool get isIOS => !kIsWeb && Platform.isIOS;

  String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _fileDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _rangeFileName(AttendanceDateRangeReport report) {
    final from = _fileDate(report.fromDate);
    final to = _fileDate(report.toDate);
    if (from == to) return 'attendance_report_$from.xlsx';
    return 'attendance_report_${from}_to_$to.xlsx';
  }

  String _statusLabel(AttendanceStatus status, AttendanceExportLabels labels) {
    switch (status) {
      case AttendanceStatus.present:
        return labels.present;
      case AttendanceStatus.late:
        return labels.late;
      case AttendanceStatus.absent:
        return labels.absents;
    }
  }

  String buildShareMessage(
    AttendanceDateRangeReport report,
    AttendanceExportLabels labels,
  ) {
    final range = report.fromDate == report.toDate
        ? formatDate(report.fromDate)
        : '${formatDate(report.fromDate)} – ${formatDate(report.toDate)}';
    return '${labels.reportTitle}\n'
        '$range\n'
        '${labels.absents}: ${report.absentCount} · '
        '${labels.late}: ${report.lateCount} · '
        '${labels.present}: ${report.presentCount}\n'
        '${labels.readOnlyHint}';
  }

  Future<AttendanceExportResult> buildExcelExport({
    required DateTime fromDate,
    required DateTime toDate,
    required AttendanceExportLabels labels,
  }) async {
    final report = SchoolDataService.instance.buildAttendanceReportForRange(
      fromDate: fromDate,
      toDate: toDate,
    );
    final bytes = _buildWorkbook(report, labels);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Failed to build attendance workbook');
    }

    final fileName = _rangeFileName(report);
    final file = await _writeExportFile(fileName, bytes);
    return AttendanceExportResult(
      file: file,
      fileName: fileName,
      report: report,
      shareMessage: buildShareMessage(report, labels),
      emailSubject:
          '${labels.reportTitle} · ${formatDate(report.fromDate)} – ${formatDate(report.toDate)}',
    );
  }

  Future<File> saveToDevice(File source, {required String fileName}) async {
    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final target = File(p.join(dir.path, fileName));
    if (await target.exists()) {
      await target.delete();
    }
    return source.copy(target.path);
  }

  Future<AttendanceShareOutcome> shareViaChannel({
    required AttendanceExportResult export,
    required AttendanceShareChannel channel,
  }) async {
    if (channel == AttendanceShareChannel.download && isIOS) {
      await _shareFile(
        export,
        includeMessage: false,
      );
      return AttendanceShareOutcome(
        file: export.file,
        usedIosSaveSheet: true,
      );
    }

    if (channel == AttendanceShareChannel.download) {
      final saved = await saveToDevice(
        export.file,
        fileName: export.fileName,
      );
      return AttendanceShareOutcome(file: saved, usedIosSaveSheet: false);
    }

    final includeMessage = channel == AttendanceShareChannel.email && !isIOS;
    await _shareFile(
      export,
      includeMessage: includeMessage,
    );
    return AttendanceShareOutcome(
      file: export.file,
      usedIosSaveSheet: false,
    );
  }

  Future<void> _shareFile(
    AttendanceExportResult export, {
    required bool includeMessage,
  }) async {
    final xFile = XFile(
      export.file.path,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      name: export.fileName,
    );

    // iOS drops the attachment when `text` is set alongside files.
    if (isIOS || !includeMessage) {
      await Share.shareXFiles([xFile]);
      return;
    }

    await Share.shareXFiles(
      [xFile],
      text: export.shareMessage,
      subject: export.emailSubject,
    );
  }

  List<int>? _buildWorkbook(
    AttendanceDateRangeReport report,
    AttendanceExportLabels labels,
  ) {
    final excel = Excel.createExcel();
    final defaultName = excel.sheets.keys.first;
    excel.rename(defaultName, _ExcelSheets.summary);
    excel.copy(_ExcelSheets.summary, _ExcelSheets.dailyTotals);
    excel.copy(_ExcelSheets.summary, _ExcelSheets.studentDetails);
    excel.unLink(_ExcelSheets.summary);
    excel.unLink(_ExcelSheets.dailyTotals);
    excel.unLink(_ExcelSheets.studentDetails);

    _fillSummarySheet(excel[_ExcelSheets.summary], report, labels);
    _fillDailySheet(excel[_ExcelSheets.dailyTotals], report, labels);
    _fillDetailsSheet(excel[_ExcelSheets.studentDetails], report, labels);

    excel.setDefaultSheet(_ExcelSheets.summary);
    return excel.encode();
  }

  void _fillSummarySheet(
    Sheet sheet,
    AttendanceDateRangeReport report,
    AttendanceExportLabels labels,
  ) {
    var row = 0;
    void write(int r, int c, String value, {bool bold = false}) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        TextCellValue(value),
        cellStyle: bold ? CellStyle(bold: true) : null,
      );
    }

    write(row++, 0, labels.reportTitle, bold: true);
    write(
      row++,
      0,
      '${labels.fromDateLabel}: ${formatDate(report.fromDate)}',
    );
    write(row++, 0, '${labels.toDateLabel}: ${formatDate(report.toDate)}');
    write(row++, 0, labels.generatedReport);
    write(row++, 0, labels.readOnlyHint);
    row++;

    write(row++, 0, labels.summaryLabel, bold: true);
    write(row++, 0, '${labels.daysWithRecords}: ${report.dayCount}');
    write(row++, 0, '${labels.absents}: ${report.absentCount}');
    write(row++, 0, '${labels.late}: ${report.lateCount}');
    write(row++, 0, '${labels.present}: ${report.presentCount}');
    row++;

    write(row++, 0, labels.teachersRecorded, bold: true);
    final sessions = report.dailyReports
        .expand((daily) => daily.sessions)
        .toList();
    if (sessions.isEmpty) {
      write(row++, 0, labels.noData);
      return;
    }

    write(row, 0, labels.dateLabel, bold: true);
    write(row, 1, labels.className, bold: true);
    write(row, 2, labels.teacherColumn, bold: true);
    write(row, 3, labels.present, bold: true);
    write(row, 4, labels.late, bold: true);
    write(row, 5, labels.absents, bold: true);
    row++;

    for (final daily in report.dailyReports) {
      for (final session in daily.sessions) {
        write(row, 0, formatDate(daily.date));
        write(row, 1, session.className);
        write(row, 2, session.conductedBy);
        write(row, 3, '${session.presentCount}');
        write(row, 4, '${session.lateCount}');
        write(row, 5, '${session.absentCount}');
        row++;
      }
    }
  }

  void _fillDailySheet(
    Sheet sheet,
    AttendanceDateRangeReport report,
    AttendanceExportLabels labels,
  ) {
    var row = 0;
    void write(int r, int c, String value, {bool bold = false}) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        TextCellValue(value),
        cellStyle: bold ? CellStyle(bold: true) : null,
      );
    }

    write(row, 0, labels.dateLabel, bold: true);
    write(row, 1, labels.present, bold: true);
    write(row, 2, labels.late, bold: true);
    write(row, 3, labels.absents, bold: true);
    write(row, 4, labels.totalLabel, bold: true);
    row++;

    for (final daily in report.dailyReports) {
      if (daily.totalCount == 0) continue;
      write(row, 0, formatDate(daily.date));
      write(row, 1, '${daily.presentCount}');
      write(row, 2, '${daily.lateCount}');
      write(row, 3, '${daily.absentCount}');
      write(row, 4, '${daily.totalCount}');
      row++;
    }

    if (row == 1) {
      write(row, 0, labels.noData);
    }
  }

  void _fillDetailsSheet(
    Sheet sheet,
    AttendanceDateRangeReport report,
    AttendanceExportLabels labels,
  ) {
    var row = 0;
    void write(int r, int c, String value, {bool bold = false}) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        TextCellValue(value),
        cellStyle: bold ? CellStyle(bold: true) : null,
      );
    }

    write(row, 0, labels.dateLabel, bold: true);
    write(row, 1, labels.studentName, bold: true);
    write(row, 2, labels.grade, bold: true);
    write(row, 3, labels.className, bold: true);
    write(row, 4, labels.status, bold: true);
    write(row, 5, labels.teacherColumn, bold: true);
    row++;

    if (report.records.isEmpty) {
      write(row, 0, labels.noData);
      return;
    }

    final sorted = List<StudentAttendanceRecord>.from(report.records)
      ..sort((a, b) {
        final dateA = a.date ?? report.fromDate;
        final dateB = b.date ?? report.fromDate;
        final dateCompare = dateA.compareTo(dateB);
        if (dateCompare != 0) return dateCompare;
        final grade = a.grade.compareTo(b.grade);
        if (grade != 0) return grade;
        return a.studentName.compareTo(b.studentName);
      });

    for (final record in sorted) {
      write(row, 0, formatDate(record.date ?? report.fromDate));
      write(row, 1, record.studentName);
      write(row, 2, record.grade);
      write(row, 3, record.className);
      write(row, 4, _statusLabel(record.status, labels));
      write(row, 5, record.conductedBy);
      row++;
    }
  }

  Future<File> _writeExportFile(String fileName, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final file = File(p.join(dir.path, safeName));
    if (await file.exists()) {
      await file.delete();
    }
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
