import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/services/ethiopia_payroll_tax.dart';

void main() {
  test('PAYE 1395/2025 and POESSA pension on common monthly salaries', () {
    final twelveK = EthiopianPayrollTax.breakdown(basicSalary: 12000);
    expect(twelveK.paye, 2250);
    expect(twelveK.employeePension, 840);
    expect(twelveK.employerPension, 1320);
    expect(twelveK.net, 8910);

    final exempt = EthiopianPayrollTax.breakdown(basicSalary: 2000);
    expect(exempt.paye, 0);
    expect(exempt.employeePension, 140);
    expect(exempt.net, 1860);

    final sevenK = EthiopianPayrollTax.breakdown(basicSalary: 7000);
    expect(sevenK.paye, 900);
    expect(sevenK.employeePension, 490);
    expect(sevenK.net, 5610);

    final thirtyK = EthiopianPayrollTax.breakdown(basicSalary: 30000);
    expect(thirtyK.paye, 8450);
    expect(thirtyK.employeePension, 2100);
    expect(thirtyK.net, 19450);

    final fourK = EthiopianPayrollTax.breakdown(basicSalary: 4000);
    expect(fourK.paye, 300);
    expect(fourK.employeePension, 280);
    expect(fourK.net, 3420);
  });

  test('pension can be turned off; exempt allowances skip PAYE', () {
    final noPension = EthiopianPayrollTax.breakdown(
      basicSalary: 12000,
      pensionEligible: false,
    );
    expect(noPension.paye, 2250);
    expect(noPension.employeePension, 0);
    expect(noPension.employerPension, 0);
    expect(noPension.net, 9750);

    final withExempt = EthiopianPayrollTax.breakdown(
      basicSalary: 4000,
      taxableAllowances: 1000,
      exemptAllowances: 500,
    );
    // PAYE on 5,000: 20% − 500 = 500
    expect(withExempt.taxableIncome, 5000);
    expect(withExempt.paye, 500);
    expect(withExempt.gross, 5500);
    expect(withExempt.employeePension, 280);
    expect(withExempt.net, 4720);
  });
}
