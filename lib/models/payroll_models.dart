import 'package:mayabela/services/ethiopia_payroll_tax.dart';

enum PayrollPersonKind { teacher, employee, driver }

class PayrollPerson {
  const PayrollPerson({
    required this.kind,
    required this.personId,
    required this.schoolId,
    required this.fullName,
    required this.jobTitle,
    this.isActive = true,
  });

  final PayrollPersonKind kind;
  final String personId;
  final String schoolId;
  final String fullName;
  final String jobTitle;
  final bool isActive;

  String get profileId => '${kind.name}:$personId';
}

class PayrollProfile {
  const PayrollProfile({
    required this.id,
    required this.schoolId,
    required this.kind,
    required this.personId,
    required this.basicSalary,
    this.taxableAllowances = 0,
    this.exemptAllowances = 0,
    this.pensionEligible = true,
    this.notes = '',
    required this.updatedAt,
  });

  final String id;
  final String schoolId;
  final PayrollPersonKind kind;
  final String personId;
  final double basicSalary;
  final double taxableAllowances;
  final double exemptAllowances;
  final bool pensionEligible;
  final String notes;
  final DateTime updatedAt;

  EthiopianPayslipBreakdown get preview => EthiopianPayrollTax.breakdown(
        basicSalary: basicSalary,
        taxableAllowances: taxableAllowances,
        exemptAllowances: exemptAllowances,
        pensionEligible: pensionEligible,
      );

  PayrollProfile copyWith({
    double? basicSalary,
    double? taxableAllowances,
    double? exemptAllowances,
    bool? pensionEligible,
    String? notes,
    DateTime? updatedAt,
  }) {
    return PayrollProfile(
      id: id,
      schoolId: schoolId,
      kind: kind,
      personId: personId,
      basicSalary: basicSalary ?? this.basicSalary,
      taxableAllowances: taxableAllowances ?? this.taxableAllowances,
      exemptAllowances: exemptAllowances ?? this.exemptAllowances,
      pensionEligible: pensionEligible ?? this.pensionEligible,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'kind': kind.name,
        'personId': personId,
        'basicSalary': basicSalary,
        'taxableAllowances': taxableAllowances,
        'exemptAllowances': exemptAllowances,
        'pensionEligible': pensionEligible,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PayrollProfile.fromMap(Map<String, dynamic> map) {
    return PayrollProfile(
      id: (map['id'] ?? '').toString(),
      schoolId: (map['schoolId'] ?? '').toString().toUpperCase(),
      kind: PayrollPersonKind.values.firstWhere(
        (k) => k.name == map['kind'],
        orElse: () => PayrollPersonKind.employee,
      ),
      personId: (map['personId'] ?? '').toString(),
      basicSalary: (map['basicSalary'] as num?)?.toDouble() ?? 0,
      taxableAllowances: (map['taxableAllowances'] as num?)?.toDouble() ?? 0,
      exemptAllowances: (map['exemptAllowances'] as num?)?.toDouble() ?? 0,
      pensionEligible: map['pensionEligible'] != false,
      notes: (map['notes'] ?? '').toString(),
      updatedAt: DateTime.tryParse('${map['updatedAt']}') ?? DateTime.now(),
    );
  }
}

class PayrollSlip {
  const PayrollSlip({
    required this.personId,
    required this.kind,
    required this.fullName,
    required this.jobTitle,
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
  });

  final String personId;
  final PayrollPersonKind kind;
  final String fullName;
  final String jobTitle;
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

  Map<String, dynamic> toMap() => {
        'personId': personId,
        'kind': kind.name,
        'fullName': fullName,
        'jobTitle': jobTitle,
        'basicSalary': basicSalary,
        'taxableAllowances': taxableAllowances,
        'exemptAllowances': exemptAllowances,
        'taxableIncome': taxableIncome,
        'paye': paye,
        'employeePension': employeePension,
        'employerPension': employerPension,
        'gross': gross,
        'net': net,
        'pensionEligible': pensionEligible,
      };

  factory PayrollSlip.fromMap(Map<String, dynamic> map) {
    return PayrollSlip(
      personId: (map['personId'] ?? '').toString(),
      kind: PayrollPersonKind.values.firstWhere(
        (k) => k.name == map['kind'],
        orElse: () => PayrollPersonKind.employee,
      ),
      fullName: (map['fullName'] ?? '').toString(),
      jobTitle: (map['jobTitle'] ?? '').toString(),
      basicSalary: (map['basicSalary'] as num?)?.toDouble() ?? 0,
      taxableAllowances: (map['taxableAllowances'] as num?)?.toDouble() ?? 0,
      exemptAllowances: (map['exemptAllowances'] as num?)?.toDouble() ?? 0,
      taxableIncome: (map['taxableIncome'] as num?)?.toDouble() ?? 0,
      paye: (map['paye'] as num?)?.toDouble() ?? 0,
      employeePension: (map['employeePension'] as num?)?.toDouble() ?? 0,
      employerPension: (map['employerPension'] as num?)?.toDouble() ?? 0,
      gross: (map['gross'] as num?)?.toDouble() ?? 0,
      net: (map['net'] as num?)?.toDouble() ?? 0,
      pensionEligible: map['pensionEligible'] != false,
    );
  }
}

class PayrollRun {
  const PayrollRun({
    required this.id,
    required this.schoolId,
    required this.periodYm,
    required this.createdAt,
    required this.createdBy,
    required this.slips,
    this.notes = '',
  });

  final String id;
  final String schoolId;
  final String periodYm;
  final DateTime createdAt;
  final String createdBy;
  final List<PayrollSlip> slips;
  final String notes;

  double get totalPaye => slips.fold(0.0, (s, e) => s + e.paye);
  double get totalEmployeePension =>
      slips.fold(0.0, (s, e) => s + e.employeePension);
  double get totalEmployerPension =>
      slips.fold(0.0, (s, e) => s + e.employerPension);
  double get totalNet => slips.fold(0.0, (s, e) => s + e.net);
  double get totalGross => slips.fold(0.0, (s, e) => s + e.gross);

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'periodYm': periodYm,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'notes': notes,
        'slips': slips.map((s) => s.toMap()).toList(),
      };

  factory PayrollRun.fromMap(Map<String, dynamic> map) {
    final raw = map['slips'];
    final slips = <PayrollSlip>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          slips.add(PayrollSlip.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    return PayrollRun(
      id: (map['id'] ?? '').toString(),
      schoolId: (map['schoolId'] ?? '').toString().toUpperCase(),
      periodYm: (map['periodYm'] ?? '').toString(),
      createdAt: DateTime.tryParse('${map['createdAt']}') ?? DateTime.now(),
      createdBy: (map['createdBy'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      slips: slips,
    );
  }
}
