import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/services/ethiopian_employment_tax.dart';

void main() {
  test('untaxed band is 0–2,000 ETB', () {
    final slip = EthiopianEmploymentTax.calculate(basicSalaryEtb: 2000);
    expect(slip.incomeTaxEtb, 0);
    expect(slip.employeePensionEtb, 140);
    expect(slip.employerPensionEtb, 220);
    expect(slip.netPayEtb, 1860);
  });

  test('15% band uses the 300 quick deduction', () {
    final slip = EthiopianEmploymentTax.calculate(basicSalaryEtb: 4000);
    // Taxable = 4000 - 280 = 3720; 3720 * 0.15 - 300 = 258
    expect(slip.employeePensionEtb, 280);
    expect(slip.taxableIncomeEtb, 3720);
    expect(slip.incomeTaxEtb, 258);
    expect(slip.incomeTaxPercent, 15);
  });

  test('25% band continuity around 8,000 taxable', () {
    final slip = EthiopianEmploymentTax.calculate(
      basicSalaryEtb: 8000,
      taxableAllowancesEtb: 560, // taxable = 8560 - 560 pension = 8000
    );
    expect(slip.employeePensionEtb, 560);
    expect(slip.taxableIncomeEtb, 8000);
    expect(slip.incomeTaxEtb, 1150); // 8000 * 0.25 - 850
    expect(slip.netPayEtb, 6850); // 8560 - 560 - 1150
  });

  test('top band is 35% over 14,000 taxable', () {
    final slip = EthiopianEmploymentTax.calculate(basicSalaryEtb: 20000);
    expect(slip.employeePensionEtb, 1400);
    expect(slip.employerPensionEtb, 2200);
    expect(slip.taxableIncomeEtb, 18600);
    expect(slip.incomeTaxEtb, 4460); // 18600 * 0.35 - 2050
    expect(slip.netPayEtb, 14140);
    expect(slip.employerCostEtb, 22200);
  });

  test('negative pay is treated as zero', () {
    final slip = EthiopianEmploymentTax.calculate(basicSalaryEtb: -500);
    expect(slip.grossEtb, 0);
    expect(slip.netPayEtb, 0);
    expect(slip.incomeTaxEtb, 0);
  });
}
