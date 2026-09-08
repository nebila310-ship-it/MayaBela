import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/models/payroll_models.dart';
import 'package:mayabela/services/ethiopia_payroll_tax.dart';
import 'package:mayabela/services/payroll_export_service.dart';

void main() {
  PayrollRegisterRow _row({
    required String name,
    required double basic,
    double advance = 0,
    double other = 0,
    String otherNote = '',
  }) {
    final person = PayrollPerson(
      kind: PayrollPersonKind.teacher,
      personId: 'TCH-1',
      schoolId: 'FR-001',
      fullName: name,
      jobTitle: 'Math',
    );
    final profile = PayrollProfile(
      id: person.profileId,
      schoolId: person.schoolId,
      kind: person.kind,
      personId: person.personId,
      basicSalary: basic,
      salaryAdvance: advance,
      otherDeductions: other,
      otherDeductionNote: otherNote,
      updatedAt: DateTime.utc(2026, 9, 1),
    );
    return PayrollRegisterRow(
      person: person,
      profile: profile,
      calc: profile.preview,
    );
  }

  test('Excel and PDF payroll files include net pay, advances, and deductions',
      () async {
    final rows = [
      _row(name: 'A Teacher', basic: 12000, advance: 1000),
      _row(
        name: 'B Staff',
        basic: 7000,
        other: 200,
        otherNote: 'Staff loan',
      ),
    ];
    final exporter = PayrollExportService.instance;
    final csv = exporter.buildCsv(rows);
    expect(csv, contains('Net pay'));
    expect(csv, contains('TOTAL'));
    expect(csv, contains('A Teacher'));

    final advances = exporter.advanceSheet(rows);
    expect(advances.length, 2);
    expect(advances[1][1], 'A Teacher');
    expect(advances[1][3], '1000.00');

    final others = exporter.otherSheet(rows);
    expect(others.length, 2);
    expect(others[1][4], 'Staff loan');

    final excel = exporter.buildExcelBytes(rows: rows, periodYm: '2026-09');
    expect(excel.length, greaterThan(100));

    final pdf = await exporter.buildPdfBytes(rows: rows, periodYm: '2026-09');
    expect(pdf.length, greaterThan(100));
    expect(
      EthiopianPayrollTax.breakdown(
        basicSalary: 12000,
        salaryAdvance: 1000,
      ).net,
      7910,
    );
  });
}
