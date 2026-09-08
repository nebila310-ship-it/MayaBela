/// Ethiopian employment payroll (PAYE + POESSA pension).
///
/// PAYE: Income Tax (Amendment) Proclamation No. 1395/2025, monthly Schedule A
/// (effective 8 July 2025). Quick-calc: tax = (taxable × rate) − deduction.
///
/// Pension: private-org POESSA scheme — 7% employee + 11% employer on **basic
/// salary only**. Mandatory for Ethiopian citizens; default on, can be turned
/// off for ineligible staff.
class EthiopianPayrollTax {
  EthiopianPayrollTax._();

  static const employeePensionRate = 0.07;
  static const employerPensionRate = 0.11;

  static const proclamation = 'Income Tax (Amendment) Proclamation No. 1395/2025';
  static const pensionNote =
      'POESSA: employee 7% + employer 11% of basic salary (citizens).';

  /// Monthly PAYE bands. [maxInclusive] null means no ceiling.
  static const brackets = <EthiopianPayeBracket>[
    EthiopianPayeBracket(maxInclusive: 2000, rate: 0, deduction: 0),
    EthiopianPayeBracket(maxInclusive: 4000, rate: 0.15, deduction: 300),
    EthiopianPayeBracket(maxInclusive: 7000, rate: 0.20, deduction: 500),
    EthiopianPayeBracket(maxInclusive: 10000, rate: 0.25, deduction: 850),
    EthiopianPayeBracket(maxInclusive: 14000, rate: 0.30, deduction: 1350),
    EthiopianPayeBracket(maxInclusive: null, rate: 0.35, deduction: 2050),
  ];

  static EthiopianPayeBracket bracketFor(double taxableMonthly) {
    final income = taxableMonthly < 0 ? 0.0 : taxableMonthly;
    for (final band in brackets) {
      final max = band.maxInclusive;
      if (max == null || income <= max) return band;
    }
    return brackets.last;
  }

  static double paye(double taxableMonthly) {
    final income = _money(taxableMonthly);
    if (income <= 0) return 0;
    final band = bracketFor(income);
    return _money(income * band.rate - band.deduction).clamp(0, double.infinity);
  }

  static EthiopianPayslipBreakdown breakdown({
    required double basicSalary,
    double taxableAllowances = 0,
    double exemptAllowances = 0,
    bool pensionEligible = true,
  }) {
    final basic = _money(basicSalary);
    final taxableAllow = _money(taxableAllowances);
    final exemptAllow = _money(exemptAllowances);
    final payeBase = _money(basic + taxableAllow);
    final incomeTax = paye(payeBase);
    final employeePension =
        pensionEligible ? _money(basic * employeePensionRate) : 0.0;
    final employerPension =
        pensionEligible ? _money(basic * employerPensionRate) : 0.0;
    final gross = _money(basic + taxableAllow + exemptAllow);
    final net = _money(gross - incomeTax - employeePension);
    return EthiopianPayslipBreakdown(
      basicSalary: basic,
      taxableAllowances: taxableAllow,
      exemptAllowances: exemptAllow,
      taxableIncome: payeBase,
      paye: incomeTax,
      employeePension: employeePension,
      employerPension: employerPension,
      gross: gross,
      net: net,
      pensionEligible: pensionEligible,
      band: bracketFor(payeBase),
    );
  }

  static double _money(double value) {
    if (value.isNaN || value.isInfinite) return 0;
    return (value * 100).round() / 100;
  }
}

class EthiopianPayeBracket {
  const EthiopianPayeBracket({
    required this.maxInclusive,
    required this.rate,
    required this.deduction,
  });

  final double? maxInclusive;
  final double rate;
  final double deduction;

  String get label {
    if (maxInclusive == null) {
      return 'Over 14,000 ETB · ${(rate * 100).toStringAsFixed(0)}%';
    }
    if (deduction == 0) {
      return '0 – ${maxInclusive!.toStringAsFixed(0)} ETB · exempt';
    }
    return 'Up to ${maxInclusive!.toStringAsFixed(0)} ETB · ${(rate * 100).toStringAsFixed(0)}%';
  }
}

class EthiopianPayslipBreakdown {
  const EthiopianPayslipBreakdown({
    required this.basicSalary,
    required this.taxableAllowances,
    required this.exemptAllowances,
    required this.taxableIncome,
    required this.paye,
    required this.employeePension,
    required this.employerPension,
    required this.gross,
    required this.net,
    required this.pensionEligible,
    required this.band,
  });

  final double basicSalary;
  final double taxableAllowances;
  final double exemptAllowances;
  final double taxableIncome;
  final double paye;
  final double employeePension;
  final double employerPension;
  final double gross;
  final double net;
  final bool pensionEligible;
  final EthiopianPayeBracket band;

  double get totalPension =>
      EthiopianPayrollTax._money(employeePension + employerPension);

  double get employerCost =>
      EthiopianPayrollTax._money(gross + employerPension);
}
