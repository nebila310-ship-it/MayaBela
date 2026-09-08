import 'dart:convert';
import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:mayabela/models/payroll_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/ethiopia_payroll_tax.dart';
import 'package:mayabela/utils/web_file_utils.dart';

/// Excel / PDF / print for the HR payroll register.
class PayrollExportService {
  PayrollExportService._();
  static final instance = PayrollExportService._();

  static const payrollHeaders = [
    'Staff ID',
    'Name',
    'Role',
    'Job',
    'Basic',
    'Taxable allow.',
    'Exempt allow.',
    'Gross',
    'PAYE',
    'Staff pension',
    'School pension',
    'Advance',
    'Other deduction',
    'Other reason',
    'Total deductions',
    'Net pay',
  ];

  static const advanceHeaders = [
    'Staff ID',
    'Name',
    'Job',
    'Advance recovered',
    'Net pay',
  ];

  static const otherHeaders = [
    'Staff ID',
    'Name',
    'Job',
    'Amount',
    'Reason',
    'Net pay',
  ];

  Future<void> exportExcel({
    required List<PayrollRegisterRow> rows,
    required String periodYm,
  }) async {
    final bytes = buildExcelBytes(rows: rows, periodYm: periodYm);
    await _deliver(
      bytes: Uint8List.fromList(bytes),
      fileName: 'payroll_${periodYm}_$schoolToken.xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      subject: 'Payroll $periodYm',
    );
  }

  Future<void> exportPdf({
    required List<PayrollRegisterRow> rows,
    required String periodYm,
  }) async {
    final bytes = await buildPdfBytes(rows: rows, periodYm: periodYm);
    await _deliver(
      bytes: bytes,
      fileName: 'payroll_${periodYm}_$schoolToken.pdf',
      mimeType: 'application/pdf',
      subject: 'Payroll $periodYm',
    );
  }

  Future<void> printRegister({
    required List<PayrollRegisterRow> rows,
    required String periodYm,
  }) =>
      exportPdf(rows: rows, periodYm: periodYm);

  List<int> buildExcelBytes({
    required List<PayrollRegisterRow> rows,
    required String periodYm,
  }) {
    final excel = Excel.createExcel();
    final defaultName = excel.sheets.keys.first;
    excel.rename(defaultName, 'Payroll');
    _writeSheet(excel['Payroll'], payrollSheet(rows));
    _writeSheet(excel['Summary'], summarySheet(rows, periodYm));
    final advances = advanceSheet(rows);
    if (advances.length > 1) {
      _writeSheet(excel['Advances'], advances);
    }
    final others = otherSheet(rows);
    if (others.length > 1) {
      _writeSheet(excel['Other deductions'], others);
    }
    return excel.encode() ?? utf8.encode(buildCsv(rows));
  }

  Future<Uint8List> buildPdfBytes({
    required List<PayrollRegisterRow> rows,
    required String periodYm,
  }) async {
    final schoolId = AuthService.activeSchoolId ?? '-';
    final generated = DateTime.now().toIso8601String().split('T').first;
    final payroll = payrollSheet(rows);
    final advances = advanceSheet(rows);
    final others = otherSheet(rows);
    final summary = summarySheet(rows, periodYm);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Payroll register · $periodYm',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'School: $schoolId  ·  Generated: $generated  ·  '
              '${EthiopianPayrollTax.proclamation}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
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
        build: (context) => [
          _pdfTable(payroll),
          pw.SizedBox(height: 14),
          pw.Text(
            'Totals',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 6),
          _pdfTable(summary),
          if (advances.length > 1) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Salary advances',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
            pw.SizedBox(height: 6),
            _pdfTable(advances),
          ],
          if (others.length > 1) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Other deductions',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
            pw.SizedBox(height: 6),
            _pdfTable(others),
          ],
        ],
      ),
    );
    return doc.save();
  }

  String buildCsv(List<PayrollRegisterRow> rows) {
    return payrollSheet(rows).map(_csvLine).join('\n');
  }

  List<List<String>> payrollSheet(List<PayrollRegisterRow> rows) {
    final paid = rows.where((r) => r.hasSalary).toList();
    return [
      payrollHeaders,
      for (final row in paid) _payrollCells(row),
      if (paid.isNotEmpty) _payrollTotalRow(paid),
    ];
  }

  List<List<String>> advanceSheet(List<PayrollRegisterRow> rows) {
    final items = rows.where((r) => r.hasAdvance).toList();
    if (items.isEmpty) return [advanceHeaders];
    return [
      advanceHeaders,
      for (final row in items)
        [
          row.person.personId,
          row.person.fullName,
          row.person.jobTitle,
          _n(row.calc.salaryAdvance),
          _n(row.calc.net),
        ],
    ];
  }

  List<List<String>> otherSheet(List<PayrollRegisterRow> rows) {
    final items = rows.where((r) => r.hasOtherDeduction).toList();
    if (items.isEmpty) return [otherHeaders];
    return [
      otherHeaders,
      for (final row in items)
        [
          row.person.personId,
          row.person.fullName,
          row.person.jobTitle,
          _n(row.calc.otherDeductions),
          row.otherNote.isEmpty ? 'Other' : row.otherNote,
          _n(row.calc.net),
        ],
    ];
  }

  List<List<String>> summarySheet(
    List<PayrollRegisterRow> rows,
    String periodYm,
  ) {
    final paid = rows.where((r) => r.hasSalary).toList();
    double sum(double Function(PayrollRegisterRow r) pick) =>
        EthiopianPayrollTax.money(
          paid.fold(0.0, (s, r) => s + pick(r)),
        );
    return [
      ['Item', 'Amount (ETB)'],
      ['Period', periodYm],
      ['Staff on payroll', '${paid.length}'],
      ['Gross', _n(sum((r) => r.calc.gross))],
      ['PAYE (MoR)', _n(sum((r) => r.calc.paye))],
      ['Staff pension (POESSA 7%)', _n(sum((r) => r.calc.employeePension))],
      ['School pension (POESSA 11%)', _n(sum((r) => r.calc.employerPension))],
      ['Salary advances', _n(sum((r) => r.calc.salaryAdvance))],
      ['Other deductions', _n(sum((r) => r.calc.otherDeductions))],
      ['Total staff deductions', _n(sum((r) => r.calc.totalStaffDeductions))],
      ['Net pay', _n(sum((r) => r.calc.net))],
    ];
  }

  List<String> _payrollCells(PayrollRegisterRow row) {
    final c = row.calc;
    return [
      row.person.personId,
      row.person.fullName,
      row.person.kind.name,
      row.person.jobTitle,
      _n(c.basicSalary),
      _n(c.taxableAllowances),
      _n(c.exemptAllowances),
      _n(c.gross),
      _n(c.paye),
      _n(c.employeePension),
      _n(c.employerPension),
      _n(c.salaryAdvance),
      _n(c.otherDeductions),
      row.otherNote,
      _n(c.totalStaffDeductions),
      _n(c.net),
    ];
  }

  List<String> _payrollTotalRow(List<PayrollRegisterRow> paid) {
    double sum(double Function(PayrollRegisterRow r) pick) =>
        EthiopianPayrollTax.money(
          paid.fold(0.0, (s, r) => s + pick(r)),
        );
    return [
      '',
      'TOTAL',
      '',
      '${paid.length} staff',
      _n(sum((r) => r.calc.basicSalary)),
      _n(sum((r) => r.calc.taxableAllowances)),
      _n(sum((r) => r.calc.exemptAllowances)),
      _n(sum((r) => r.calc.gross)),
      _n(sum((r) => r.calc.paye)),
      _n(sum((r) => r.calc.employeePension)),
      _n(sum((r) => r.calc.employerPension)),
      _n(sum((r) => r.calc.salaryAdvance)),
      _n(sum((r) => r.calc.otherDeductions)),
      '',
      _n(sum((r) => r.calc.totalStaffDeductions)),
      _n(sum((r) => r.calc.net)),
    ];
  }

  pw.Widget _pdfTable(List<List<String>> rows) {
    if (rows.isEmpty) return pw.Text('No data');
    final headers = rows.first;
    final data = rows.length <= 1 ? <List<String>>[] : rows.sublist(1);
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data
          .map(
            (r) => List<String>.generate(
              headers.length,
              (i) => i < r.length ? r[i] : '',
            ),
          )
          .toList(),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 7,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
    );
  }

  void _writeSheet(Sheet sheet, List<List<String>> rows) {
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .value = TextCellValue(rows[r][c]);
      }
    }
  }

  String _n(num value) => EthiopianPayrollTax.money(value.toDouble()).toStringAsFixed(2);

  String _csvLine(List<String> row) {
    return row.map((cell) {
      if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
        return '"${cell.replaceAll('"', '""')}"';
      }
      return cell;
    }).join(',');
  }

  String get schoolToken =>
      (AuthService.activeSchoolId ?? 'school').replaceAll(
        RegExp(r'[^A-Za-z0-9-]'),
        '_',
      );

  Future<void> _deliver({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String subject,
  }) async {
    if (kIsWeb) {
      await WebFileUtils.downloadBytes(fileName: fileName, bytes: bytes);
      return;
    }
    await Share.shareXFiles(
      [
        XFile.fromData(bytes, mimeType: mimeType, name: fileName),
      ],
      subject: subject,
      text: subject,
    );
  }
}
