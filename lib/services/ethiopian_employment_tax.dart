import 'dart:math' as math;

/// Ethiopian private-sector employment income tax and pension.
///
/// Income tax brackets follow Proclamation No. 1395/2025 (monthly PAYE).
/// Pension rates follow the private-sector scheme: employee **7%** and
/// employer **11%** of basic salary. Employee pension is withheld before
/// income tax. Rates can change — HR should confirm against the current law.
class EthiopianEmploymentTax {
  EthiopianEmploymentTax._();

  static const proclamation = 'Proc. No. 1395/2025';
  static const employeePensionRate = 0.07;
  static const employerPensionRate = 0.11;

  static double roundEtb(double value) =>
      (value * 100).roundToDouble() / 100;

  static double parseEtb(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static ({double rate, double deduction}) bracket(double taxableMonthlyEtb) {
    final t = taxableMonthlyEtb;
    if (t <= 2000) return (rate: 0.0, deduction: 0);
    if (t <= 4000) return (rate: 0.15, deduction: 300);
    if (t <= 7000) return (rate: 0.20, deduction: 500);
    if (t <= 10000) return (rate: 0.25, deduction: 850);
    if (t <= 14000) return (rate: 0.30, deduction: 1350);
    return (rate: 0.35, deduction: 2050);
  }

  static EthiopianPayrollBreakdown calculate({
    required double basicSalaryEtb,
    double taxableAllowancesEtb = 0,
  }) {
    final basic = math.max(0.0, roundEtb(basicSalaryEtb));
    final allowances = math.max(0.0, roundEtb(taxableAllowancesEtb));
    final gross = roundEtb(basic + allowances);
    final employeePension = roundEtb(basic * employeePensionRate);
    final employerPension = roundEtb(basic * employerPensionRate);
    final taxable = math.max(0.0, roundEtb(gross - employeePension));
    final b = bracket(taxable);
    final incomeTax = math.max(0.0, roundEtb(taxable * b.rate - b.deduction));
    final netPay = roundEtb(gross - employeePension - incomeTax);
    final employerCost = roundEtb(gross + employerPension);
    return EthiopianPayrollBreakdown(
      basicSalaryEtb: basic,
      taxableAllowancesEtb: allowances,
      grossEtb: gross,
      employeePensionEtb: employeePension,
      employerPensionEtb: employerPension,
      taxableIncomeEtb: taxable,
      incomeTaxRate: b.rate,
      incomeTaxEtb: incomeTax,
      netPayEtb: netPay,
      employerCostEtb: employerCost,
    );
  }
}

class EthiopianPayrollBreakdown {
  const EthiopianPayrollBreakdown({
    required this.basicSalaryEtb,
    required this.taxableAllowancesEtb,
    required this.grossEtb,
    required this.employeePensionEtb,
    required this.employerPensionEtb,
    required this.taxableIncomeEtb,
    required this.incomeTaxRate,
    required this.incomeTaxEtb,
    required this.netPayEtb,
    required this.employerCostEtb,
  });

  final double basicSalaryEtb;
  final double taxableAllowancesEtb;
  final double grossEtb;
  final double employeePensionEtb;
  final double employerPensionEtb;
  final double taxableIncomeEtb;
  final double incomeTaxRate;
  final double incomeTaxEtb;
  final double netPayEtb;
  final double employerCostEtb;

  int get incomeTaxPercent => (incomeTaxRate * 100).round();
}
