import 'dart:io';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/grade_analytics_service.dart';
import 'package:mayabela/services/grade_outreach_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

class _GradeSheets {
  static const topScorers = 'Top Scorers';
  static const topScorerSubjects = 'Top Scorer Subjects';
  static const underperforming = 'Underperforming';
  static const underperformingSubjects = 'Underperforming Subjects';
}

class GradeReportExportLabels {
  const GradeReportExportLabels({
    required this.reportTitle,
    required this.generatedReport,
    required this.readOnlyHint,
    required this.topScorersSheet,
    required this.topScorerSubjectsSheet,
    required this.underperformingSheet,
    required this.underperformingSubjectsSheet,
    required this.rankType,
    required this.gradeLevel,
    required this.section,
    required this.className,
    required this.rank,
    required this.studentName,
    required this.studentId,
    required this.term,
    required this.average,
    required this.homeroomTeacher,
    required this.parentName,
    required this.parentPhone,
    required this.subject,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.letterGrade,
    required this.comment,
    required this.rankTypeGradeWide,
    required this.rankTypeSection,
    required this.noData,
  });

  factory GradeReportExportLabels.fromStrings(AppStrings s) {
    return GradeReportExportLabels(
      reportTitle: s.exportGradeReportTitle,
      generatedReport: s.generatedReport,
      readOnlyHint: s.readOnlyReportHint,
      topScorersSheet: s.exportTopScorersSheet,
      topScorerSubjectsSheet: s.exportTopScorerSubjectsSheet,
      underperformingSheet: s.exportUnderperformingSheet,
      underperformingSubjectsSheet: s.exportUnderperformingSubjectsSheet,
      rankType: s.exportRankTypeColumn,
      gradeLevel: s.grade,
      section: s.section,
      className: s.className,
      rank: s.exportRankColumn,
      studentName: s.exportStudentColumn,
      studentId: s.studentId,
      term: s.termLabel,
      average: s.exportAverageColumn,
      homeroomTeacher: s.homeroomTeacher,
      parentName: s.parents,
      parentPhone: s.phone,
      subject: s.subjectNameLabel,
      score: s.exportScoreColumn,
      maxScore: s.exportMaxScoreColumn,
      percentage: s.exportPercentageColumn,
      letterGrade: s.exportLetterGradeColumn,
      comment: s.commentLabel,
      rankTypeGradeWide: s.exportRankTypeGradeWide,
      rankTypeSection: s.exportRankTypeSection,
      noData: s.noGradeReports,
    );
  }

  final String reportTitle;
  final String generatedReport;
  final String readOnlyHint;
  final String topScorersSheet;
  final String topScorerSubjectsSheet;
  final String underperformingSheet;
  final String underperformingSubjectsSheet;
  final String rankType;
  final String gradeLevel;
  final String section;
  final String className;
  final String rank;
  final String studentName;
  final String studentId;
  final String term;
  final String average;
  final String homeroomTeacher;
  final String parentName;
  final String parentPhone;
  final String subject;
  final String score;
  final String maxScore;
  final String percentage;
  final String letterGrade;
  final String comment;
  final String rankTypeGradeWide;
  final String rankTypeSection;
  final String noData;
}

class GradeReportExportResult {
  const GradeReportExportResult({
    required this.file,
    required this.fileName,
    required this.shareMessage,
    required this.emailSubject,
  });

  final File file;
  final String fileName;
  final String shareMessage;
  final String emailSubject;
}

class GradeReportExportService {
  GradeReportExportService._();
  static final instance = GradeReportExportService._();

  static bool get isIOS => !kIsWeb && Platform.isIOS;

  final _analytics = GradeAnalyticsService.instance;
  final _data = SchoolDataService.instance;
  final _outreach = GradeOutreachService.instance;

  String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<GradeReportExportResult> buildExcelExport({
    required GradeReportExportLabels labels,
    Iterable<String>? classNames,
  }) async {
    final snapshot = _analytics.buildSnapshot(classNames: classNames);
    final bytes = _buildWorkbook(snapshot, labels);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Failed to build grade report workbook');
    }

    final stamp = DateTime.now();
    final classSuffix = classNames != null && classNames.length == 1
        ? '_${_safeFileToken(classNames.first)}'
        : classNames != null && classNames.isNotEmpty
            ? '_homeroom'
            : '';
    final fileName =
        'grade_report${classSuffix}_${stamp.year}-${stamp.month.toString().padLeft(2, '0')}-${stamp.day.toString().padLeft(2, '0')}.xlsx';
    final file = await _writeExportFile(fileName, bytes);

    final topCount = _topScorerRows(snapshot).length;
    final underCount = snapshot.underperformers.fold(
      0,
      (sum, grade) => sum + grade.totalCount,
    );

    return GradeReportExportResult(
      file: file,
      fileName: fileName,
      shareMessage: '${labels.reportTitle}\n'
          '${formatDate(stamp)}\n'
          '${labels.topScorersSheet}: $topCount\n'
          '${labels.underperformingSheet}: $underCount\n'
          '${labels.readOnlyHint}',
      emailSubject: '${labels.reportTitle} · ${formatDate(stamp)}',
    );
  }

  Future<void> shareExport(GradeReportExportResult export) async {
    final xFile = XFile(
      export.file.path,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      name: export.fileName,
    );
    if (isIOS) {
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
    GradeAnalyticsSnapshot snapshot,
    GradeReportExportLabels labels,
  ) {
    final excel = Excel.createExcel();
    final defaultName = excel.sheets.keys.first;
    excel.rename(defaultName, _GradeSheets.topScorers);
    excel.copy(_GradeSheets.topScorers, _GradeSheets.topScorerSubjects);
    excel.copy(_GradeSheets.topScorers, _GradeSheets.underperforming);
    excel.copy(_GradeSheets.topScorers, _GradeSheets.underperformingSubjects);
    excel.unLink(_GradeSheets.topScorers);
    excel.unLink(_GradeSheets.topScorerSubjects);
    excel.unLink(_GradeSheets.underperforming);
    excel.unLink(_GradeSheets.underperformingSubjects);

    _fillTopScorersSheet(excel[_GradeSheets.topScorers], snapshot, labels);
    _fillTopScorerSubjectsSheet(
      excel[_GradeSheets.topScorerSubjects],
      snapshot,
      labels,
    );
    _fillUnderperformingSheet(
      excel[_GradeSheets.underperforming],
      snapshot,
      labels,
    );
    _fillUnderperformingSubjectsSheet(
      excel[_GradeSheets.underperformingSubjects],
      snapshot,
      labels,
    );

    excel.setDefaultSheet(_GradeSheets.topScorers);
    return excel.encode();
  }

  List<({RankedStudentReport entry, String rankTypeLabel, String gradeLevel, String section})>
      _topScorerRows(GradeAnalyticsSnapshot snapshot) {
    final rows =
        <({RankedStudentReport entry, String rankTypeLabel, String gradeLevel, String section})>[];

    for (final grade in snapshot.topScorers) {
      for (final entry in grade.gradeTopTen) {
        rows.add((
          entry: entry,
          rankTypeLabel: 'grade_wide',
          gradeLevel: grade.gradeLevel,
          section: _sectionForClass(entry.report.className, grade.gradeLevel),
        ));
      }
      for (final section in grade.sections) {
        for (final entry in section.students) {
          rows.add((
            entry: entry,
            rankTypeLabel: 'section',
            gradeLevel: grade.gradeLevel,
            section: section.section,
          ));
        }
      }
    }
    return rows;
  }

  void _fillTopScorersSheet(
    Sheet sheet,
    GradeAnalyticsSnapshot snapshot,
    GradeReportExportLabels labels,
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
    write(row++, 0, labels.generatedReport);
    write(row++, 0, labels.readOnlyHint);
    row++;

    final headers = [
      labels.rankType,
      labels.gradeLevel,
      labels.section,
      labels.className,
      labels.rank,
      labels.studentName,
      labels.studentId,
      labels.term,
      labels.average,
      labels.homeroomTeacher,
      labels.parentName,
      labels.parentPhone,
    ];
    for (var c = 0; c < headers.length; c++) {
      write(row, c, headers[c], bold: true);
    }
    row++;

    final rows = _topScorerRows(snapshot);
    if (rows.isEmpty) {
      write(row, 0, labels.noData);
      return;
    }

    for (final item in rows) {
      final meta = _studentMeta(item.entry.report.studentName);
      final rankLabel = item.rankTypeLabel == 'grade_wide'
          ? labels.rankTypeGradeWide
          : labels.rankTypeSection;
      write(row, 0, rankLabel);
      write(row, 1, item.gradeLevel);
      write(row, 2, item.section);
      write(row, 3, item.entry.report.className);
      write(row, 4, '${item.entry.rank}');
      write(row, 5, item.entry.report.studentName);
      write(row, 6, meta.studentId);
      write(row, 7, item.entry.report.term);
      write(row, 8, item.entry.average.toStringAsFixed(1));
      write(
        row,
        9,
        _data.homeroomTeacherNameForClass(item.entry.report.className) ?? '',
      );
      write(row, 10, meta.parentName);
      write(row, 11, meta.parentPhone);
      row++;
    }
  }

  void _fillTopScorerSubjectsSheet(
    Sheet sheet,
    GradeAnalyticsSnapshot snapshot,
    GradeReportExportLabels labels,
  ) {
    _fillSubjectDetailSheet(
      sheet,
      labels,
      reports: _topScorerRows(snapshot).map((r) => r.entry.report).toList(),
    );
  }

  void _fillUnderperformingSheet(
    Sheet sheet,
    GradeAnalyticsSnapshot snapshot,
    GradeReportExportLabels labels,
  ) {
    var row = 0;
    void write(int r, int c, String value, {bool bold = false}) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        TextCellValue(value),
        cellStyle: bold ? CellStyle(bold: true) : null,
      );
    }

    write(row++, 0, labels.underperformingSheet, bold: true);
    write(row++, 0, labels.generatedReport);
    write(row++, 0, labels.readOnlyHint);
    row++;

    final headers = [
      labels.gradeLevel,
      labels.section,
      labels.className,
      labels.studentName,
      labels.studentId,
      labels.term,
      labels.average,
      labels.homeroomTeacher,
      labels.parentName,
      labels.parentPhone,
    ];
    for (var c = 0; c < headers.length; c++) {
      write(row, c, headers[c], bold: true);
    }
    row++;

    final reports = <StudentGradeReport>[];
    for (final grade in snapshot.underperformers) {
      for (final section in grade.sections) {
        reports.addAll(section.students);
        for (final report in section.students) {
          final meta = _studentMeta(report.studentName);
          write(row, 0, grade.gradeLevel);
          write(row, 1, section.section);
          write(row, 2, report.className);
          write(row, 3, report.studentName);
          write(row, 4, meta.studentId);
          write(row, 5, report.term);
          write(row, 6, report.average.toStringAsFixed(1));
          write(
            row,
            7,
            _data.homeroomTeacherNameForClass(report.className) ?? '',
          );
          write(row, 8, meta.parentName);
          write(row, 9, meta.parentPhone);
          row++;
        }
      }
    }

    if (reports.isEmpty) {
      write(row, 0, labels.noData);
    }
  }

  void _fillUnderperformingSubjectsSheet(
    Sheet sheet,
    GradeAnalyticsSnapshot snapshot,
    GradeReportExportLabels labels,
  ) {
    final reports = <StudentGradeReport>[];
    for (final grade in snapshot.underperformers) {
      for (final section in grade.sections) {
        reports.addAll(section.students);
      }
    }
    _fillSubjectDetailSheet(sheet, labels, reports: reports);
  }

  void _fillSubjectDetailSheet(
    Sheet sheet,
    GradeReportExportLabels labels, {
    required List<StudentGradeReport> reports,
  }) {
    var row = 0;
    void write(int r, int c, String value, {bool bold = false}) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
        TextCellValue(value),
        cellStyle: bold ? CellStyle(bold: true) : null,
      );
    }

    final headers = [
      labels.studentName,
      labels.className,
      labels.subject,
      labels.score,
      labels.maxScore,
      labels.percentage,
      labels.letterGrade,
      labels.comment,
    ];
    for (var c = 0; c < headers.length; c++) {
      write(row, c, headers[c], bold: true);
    }
    row++;

    if (reports.isEmpty) {
      write(row, 0, labels.noData);
      return;
    }

    for (final report in reports) {
      for (final subject in report.subjects) {
        write(row, 0, report.studentName);
        write(row, 1, report.className);
        write(row, 2, subject.subject);
        write(row, 3, subject.score.toStringAsFixed(0));
        write(row, 4, subject.maxScore.toStringAsFixed(0));
        write(row, 5, subject.percentage.toStringAsFixed(1));
        write(row, 6, subject.letterGrade);
        write(row, 7, subject.comment ?? '');
        row++;
      }
    }
  }

  ({String studentId, String parentName, String parentPhone}) _studentMeta(
    String studentName,
  ) {
    final record = StudentRegistryService.instance.lookupByName(studentName);
    if (record == null) {
      return (studentId: '', parentName: _outreach.parentNameForStudent(studentName) ?? '', parentPhone: '');
    }
    return (
      studentId: record.studentId,
      parentName: record.primaryParentName ?? '',
      parentPhone: record.primaryContactPhone ?? '',
    );
  }

  String _sectionForClass(String className, String gradeLevel) {
    if (className.startsWith(gradeLevel)) {
      return className.substring(gradeLevel.length).trim();
    }
    return className;
  }

  Future<File> _writeExportFile(String fileName, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _safeFileToken(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
