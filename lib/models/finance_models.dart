enum FinancePaymentMethod {
  cash,
  bankTransfer,
  cheque,
  mobileMoney,
  other,
}

extension FinancePaymentMethodX on FinancePaymentMethod {
  String get label => switch (this) {
        FinancePaymentMethod.cash => 'Cash',
        FinancePaymentMethod.bankTransfer => 'Bank transfer',
        FinancePaymentMethod.cheque => 'Cheque',
        FinancePaymentMethod.mobileMoney => 'Mobile money',
        FinancePaymentMethod.other => 'Other',
      };

  static FinancePaymentMethod parse(Object? raw) {
    final key = (raw?.toString() ?? '').trim();
    for (final value in FinancePaymentMethod.values) {
      if (value.name == key) return value;
    }
    return FinancePaymentMethod.other;
  }
}

enum FinanceInvoiceStatus { pending, partial, paid, overdue }

extension FinanceInvoiceStatusX on FinanceInvoiceStatus {
  String get label => switch (this) {
        FinanceInvoiceStatus.pending => 'Outstanding',
        FinanceInvoiceStatus.partial => 'Part paid',
        FinanceInvoiceStatus.paid => 'Paid',
        FinanceInvoiceStatus.overdue => 'Overdue',
      };

  static FinanceInvoiceStatus parse(Object? raw) {
    final key = (raw?.toString() ?? '').trim();
    for (final value in FinanceInvoiceStatus.values) {
      if (value.name == key) return value;
    }
    return FinanceInvoiceStatus.pending;
  }
}

enum FinanceExpenseStatus { requested, approved, paid, rejected }

extension FinanceExpenseStatusX on FinanceExpenseStatus {
  String get label => switch (this) {
        FinanceExpenseStatus.requested => 'Requested',
        FinanceExpenseStatus.approved => 'Approved',
        FinanceExpenseStatus.paid => 'Paid',
        FinanceExpenseStatus.rejected => 'Rejected',
      };

  static FinanceExpenseStatus parse(Object? raw) {
    final key = (raw?.toString() ?? '').trim();
    for (final value in FinanceExpenseStatus.values) {
      if (value.name == key) return value;
    }
    return FinanceExpenseStatus.requested;
  }
}

enum FinanceCashboxPurpose { general, collections, budget }

extension FinanceCashboxPurposeX on FinanceCashboxPurpose {
  String get label => switch (this) {
        FinanceCashboxPurpose.general => 'General / treasury',
        FinanceCashboxPurpose.collections => 'Fee collections',
        FinanceCashboxPurpose.budget => 'Budget cashbox',
      };

  static FinanceCashboxPurpose parse(Object? raw) {
    final key = (raw?.toString() ?? '').trim();
    for (final value in FinanceCashboxPurpose.values) {
      if (value.name == key) return value;
    }
    return FinanceCashboxPurpose.general;
  }
}

enum FinanceCashKind { receipt, payment, transferIn, transferOut, refund }

extension FinanceCashKindX on FinanceCashKind {
  String get label => switch (this) {
        FinanceCashKind.receipt => 'Cash in',
        FinanceCashKind.payment => 'Cash out',
        FinanceCashKind.transferIn => 'Transfer in',
        FinanceCashKind.transferOut => 'Transfer out',
        FinanceCashKind.refund => 'Refund',
      };

  bool get increasesBalance =>
      this == FinanceCashKind.receipt || this == FinanceCashKind.transferIn;

  static FinanceCashKind parse(Object? raw) {
    final key = (raw?.toString() ?? '').trim();
    for (final value in FinanceCashKind.values) {
      if (value.name == key) return value;
    }
    return FinanceCashKind.receipt;
  }
}

/// Tuition / other charge template by grade and student type.
class FinanceFeeStructure {
  const FinanceFeeStructure({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.grade,
    required this.academicYear,
    required this.amount,
    this.fundingType = 'regular',
    this.installmentCount = 1,
    this.term = 'Annual',
    this.collectionCashboxId,
    this.lateFeeAmount = 0,
    this.dueDay,
    this.notes,
    this.active = true,
  });

  final String id;
  final String schoolId;
  final String title;
  final String grade;
  final String academicYear;
  final String term;
  final String fundingType;
  final double amount;
  final int installmentCount;
  final String? collectionCashboxId;
  final double lateFeeAmount;
  final int? dueDay;
  final String? notes;
  final bool active;

  double get installmentAmount =>
      installmentCount <= 1 ? amount : amount / installmentCount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'title': title,
        'grade': grade,
        'academicYear': academicYear,
        'term': term,
        'fundingType': fundingType,
        'amount': amount,
        'installmentCount': installmentCount,
        if (collectionCashboxId != null)
          'collectionCashboxId': collectionCashboxId,
        'lateFeeAmount': lateFeeAmount,
        if (dueDay != null) 'dueDay': dueDay,
        if (notes != null) 'notes': notes,
        'active': active,
      };

  factory FinanceFeeStructure.fromMap(Map<String, dynamic> map) {
    return FinanceFeeStructure(
      id: (map['id'] as String? ?? '').trim(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      title: map['title'] as String? ?? 'Tuition',
      grade: map['grade'] as String? ?? '',
      academicYear: map['academicYear'] as String? ?? '',
      term: map['term'] as String? ?? 'Annual',
      fundingType: (map['fundingType'] as String? ?? 'regular').trim(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      installmentCount: (map['installmentCount'] as num?)?.toInt() ?? 1,
      collectionCashboxId: map['collectionCashboxId'] as String?,
      lateFeeAmount: (map['lateFeeAmount'] as num?)?.toDouble() ?? 0,
      dueDay: (map['dueDay'] as num?)?.toInt(),
      notes: map['notes'] as String?,
      active: map['active'] as bool? ?? true,
    );
  }
}

class FinanceInvoice {
  FinanceInvoice({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.grade,
    required this.className,
    required this.title,
    required this.academicYear,
    required this.amount,
    required this.dueDate,
    this.term = 'Annual',
    this.fundingType = 'regular',
    this.structureId,
    this.paidAmount = 0,
    DateTime? issuedAt,
  }) : issuedAt = issuedAt ?? dueDate;

  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final String grade;
  final String className;
  final String title;
  final String academicYear;
  final String term;
  final String fundingType;
  final String? structureId;
  final double amount;
  final DateTime dueDate;
  final DateTime issuedAt;
  double paidAmount;

  double get outstanding =>
      (amount - paidAmount).clamp(0, double.infinity).toDouble();

  bool get isPaid => outstanding <= 0.004;

  FinanceInvoiceStatus get status {
    if (isPaid) return FinanceInvoiceStatus.paid;
    final today = DateTime.now();
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final now = DateTime(today.year, today.month, today.day);
    if (now.isAfter(due)) return FinanceInvoiceStatus.overdue;
    if (paidAmount > 0) return FinanceInvoiceStatus.partial;
    return FinanceInvoiceStatus.pending;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        'grade': grade,
        'className': className,
        'title': title,
        'academicYear': academicYear,
        'term': term,
        'fundingType': fundingType,
        if (structureId != null) 'structureId': structureId,
        'amount': amount,
        'dueDate': dueDate.toIso8601String(),
        'issuedAt': issuedAt.toIso8601String(),
        'paidAmount': paidAmount,
      };

  factory FinanceInvoice.fromMap(Map<String, dynamic> map) {
    return FinanceInvoice(
      id: (map['id'] as String? ?? '').trim(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      grade: map['grade'] as String? ?? '',
      className: map['className'] as String? ?? '',
      title: map['title'] as String? ?? '',
      academicYear: map['academicYear'] as String? ?? '',
      term: map['term'] as String? ?? 'Annual',
      fundingType: (map['fundingType'] as String? ?? 'regular').trim(),
      structureId: map['structureId'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      dueDate: DateTime.tryParse(map['dueDate'] as String? ?? '') ??
          DateTime.now(),
      issuedAt: DateTime.tryParse(map['issuedAt'] as String? ?? ''),
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FinancePayment {
  const FinancePayment({
    required this.id,
    required this.schoolId,
    required this.invoiceId,
    required this.studentId,
    required this.studentName,
    required this.amount,
    required this.method,
    required this.paidAt,
    required this.recordedBy,
    required this.receiptNo,
    this.reference,
    this.note,
  });

  final String id;
  final String schoolId;
  final String invoiceId;
  final String studentId;
  final String studentName;
  final double amount;
  final FinancePaymentMethod method;
  final DateTime paidAt;
  final String recordedBy;
  final String receiptNo;
  final String? reference;
  final String? note;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'invoiceId': invoiceId,
        'studentId': studentId,
        'studentName': studentName,
        'amount': amount,
        'method': method.name,
        'paidAt': paidAt.toIso8601String(),
        'recordedBy': recordedBy,
        'receiptNo': receiptNo,
        if (reference != null) 'reference': reference,
        if (note != null) 'note': note,
      };

  factory FinancePayment.fromMap(Map<String, dynamic> map) {
    return FinancePayment(
      id: (map['id'] as String? ?? '').trim(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      invoiceId: map['invoiceId'] as String? ?? '',
      studentId: (map['studentId'] as String? ?? '').trim().toUpperCase(),
      studentName: map['studentName'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      method: FinancePaymentMethodX.parse(map['method']),
      paidAt: DateTime.tryParse(map['paidAt'] as String? ?? '') ??
          DateTime.now(),
      recordedBy: map['recordedBy'] as String? ?? '',
      receiptNo: map['receiptNo'] as String? ?? '',
      reference: map['reference'] as String?,
      note: map['note'] as String?,
    );
  }
}

class FinanceCashbox {
  FinanceCashbox({
    required this.id,
    required this.schoolId,
    required this.name,
    this.openingBalance = 0,
    this.cashierName,
    this.purpose = FinanceCashboxPurpose.general,
    this.department,
    this.budgetId,
    this.location,
  });

  final String id;
  final String schoolId;
  final String name;
  final double openingBalance;
  final String? cashierName;
  final FinanceCashboxPurpose purpose;
  final String? department;
  String? budgetId;
  final String? location;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'name': name,
        'openingBalance': openingBalance,
        if (cashierName != null) 'cashierName': cashierName,
        'purpose': purpose.name,
        if (department != null) 'department': department,
        if (budgetId != null) 'budgetId': budgetId,
        if (location != null) 'location': location,
      };

  factory FinanceCashbox.fromMap(Map<String, dynamic> map) {
    return FinanceCashbox(
      id: (map['id'] as String? ?? '').trim(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      name: map['name'] as String? ?? 'Cashbox',
      openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0,
      cashierName: map['cashierName'] as String?,
      purpose: FinanceCashboxPurposeX.parse(map['purpose']),
      department: map['department'] as String?,
      budgetId: map['budgetId'] as String?,
      location: map['location'] as String?,
    );
  }
}

class FinanceCashMovement {
  const FinanceCashMovement({
    required this.id,
    required this.schoolId,
    required this.cashboxId,
    required this.kind,
    required this.amount,
    required this.at,
    required this.recordedBy,
    this.note,
    this.reference,
  });

  final String id;
  final String schoolId;
  final String cashboxId;
  final FinanceCashKind kind;
  final double amount;
  final DateTime at;
  final String recordedBy;
  final String? note;
  final String? reference;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'cashboxId': cashboxId,
        'kind': kind.name,
        'amount': amount,
        'at': at.toIso8601String(),
        'recordedBy': recordedBy,
        if (note != null) 'note': note,
        if (reference != null) 'reference': reference,
      };

  factory FinanceCashMovement.fromMap(Map<String, dynamic> map) {
    return FinanceCashMovement(
      id: (map['id'] as String? ?? '').trim(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      cashboxId: map['cashboxId'] as String? ?? '',
      kind: FinanceCashKindX.parse(map['kind']),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      at: DateTime.tryParse(map['at'] as String? ?? '') ?? DateTime.now(),
      recordedBy: map['recordedBy'] as String? ?? '',
      note: map['note'] as String?,
      reference: map['reference'] as String?,
    );
  }
}

class FinanceCashClose {
  const FinanceCashClose({
    required this.id,
    required this.schoolId,
    required this.cashboxId,
    required this.day,
    required this.expected,
    required this.counted,
    required this.closedBy,
  });

  final String id;
  final String schoolId;
  final String cashboxId;
  final DateTime day;
  final double expected;
  final double counted;
  final String closedBy;

  double get variance => counted - expected;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'cashboxId': cashboxId,
        'day': day.toIso8601String(),
        'expected': expected,
        'counted': counted,
        'closedBy': closedBy,
      };

  factory FinanceCashClose.fromMap(Map<String, dynamic> map) {
    return FinanceCashClose(
      id: (map['id'] as String? ?? '').trim(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      cashboxId: map['cashboxId'] as String? ?? '',
      day: DateTime.tryParse(map['day'] as String? ?? '') ?? DateTime.now(),
      expected: (map['expected'] as num?)?.toDouble() ?? 0,
      counted: (map['counted'] as num?)?.toDouble() ?? 0,
      closedBy: map['closedBy'] as String? ?? '',
    );
  }
}

class FinanceExpense {
  FinanceExpense({
    required this.id,
    required this.schoolId,
    required this.category,
    required this.amount,
    required this.date,
    required this.requestedBy,
    this.supplier,
    this.purpose,
    this.paymentMethod,
    this.reference,
    this.status = FinanceExpenseStatus.requested,
    this.approvedBy,
    this.paidBy,
    this.paidAt,
    this.budgetId,
    this.cashboxId,
    this.voucherNo,
    this.department,
    this.approvalNote,
  });

  final String id;
  final String schoolId;
  final String category;
  final double amount;
  final DateTime date;
  final String requestedBy;
  final String? supplier;
  final String? purpose;
  FinancePaymentMethod? paymentMethod;
  String? reference;
  FinanceExpenseStatus status;
  String? approvedBy;
  String? paidBy;
  DateTime? paidAt;
  String? budgetId;
  String? cashboxId;
  String? voucherNo;
  String? department;
  String? approvalNote;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'requestedBy': requestedBy,
        if (supplier != null) 'supplier': supplier,
        if (purpose != null) 'purpose': purpose,
        if (paymentMethod != null) 'paymentMethod': paymentMethod!.name,
        if (reference != null) 'reference': reference,
        'status': status.name,
        if (approvedBy != null) 'approvedBy': approvedBy,
        if (paidBy != null) 'paidBy': paidBy,
        if (paidAt != null) 'paidAt': paidAt!.toIso8601String(),
        if (budgetId != null) 'budgetId': budgetId,
        if (cashboxId != null) 'cashboxId': cashboxId,
        if (voucherNo != null) 'voucherNo': voucherNo,
        if (department != null) 'department': department,
        if (approvalNote != null) 'approvalNote': approvalNote,
      };

  factory FinanceExpense.fromMap(Map<String, dynamic> map) {
    return FinanceExpense(
      id: (map['id'] as String? ?? '').trim(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      category: map['category'] as String? ?? 'Other',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      requestedBy: map['requestedBy'] as String? ?? '',
      supplier: map['supplier'] as String?,
      purpose: map['purpose'] as String?,
      paymentMethod: map['paymentMethod'] == null
          ? null
          : FinancePaymentMethodX.parse(map['paymentMethod']),
      reference: map['reference'] as String?,
      status: FinanceExpenseStatusX.parse(map['status']),
      approvedBy: map['approvedBy'] as String?,
      paidBy: map['paidBy'] as String?,
      paidAt: DateTime.tryParse(map['paidAt'] as String? ?? ''),
      budgetId: map['budgetId'] as String?,
      cashboxId: map['cashboxId'] as String?,
      voucherNo: map['voucherNo'] as String?,
      department: map['department'] as String?,
      approvalNote: map['approvalNote'] as String?,
    );
  }
}

class FinanceAuditEvent {
  const FinanceAuditEvent({
    required this.id,
    required this.schoolId,
    required this.action,
    required this.actor,
    required this.at,
    this.detail,
  });

  final String id;
  final String schoolId;
  final String action;
  final String actor;
  final DateTime at;
  final String? detail;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'action': action,
        'actor': actor,
        'at': at.toIso8601String(),
        if (detail != null) 'detail': detail,
      };

  factory FinanceAuditEvent.fromMap(Map<String, dynamic> map) {
    return FinanceAuditEvent(
      id: (map['id'] as String? ?? '').trim(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      action: map['action'] as String? ?? '',
      actor: map['actor'] as String? ?? '',
      at: DateTime.tryParse(map['at'] as String? ?? '') ?? DateTime.now(),
      detail: map['detail'] as String?,
    );
  }
}

class FinanceStudentStatement {
  const FinanceStudentStatement({
    required this.studentId,
    required this.studentName,
    required this.invoices,
    required this.payments,
  });

  final String studentId;
  final String studentName;
  final List<FinanceInvoice> invoices;
  final List<FinancePayment> payments;

  double get billed => invoices.fold<double>(0, (sum, i) => sum + i.amount);
  double get paid => payments.fold<double>(0, (sum, p) => p.amount + sum);
  double get outstanding =>
      invoices.fold<double>(0, (sum, i) => sum + i.outstanding);
}

class FinanceControlTotals {
  const FinanceControlTotals({
    required this.billed,
    required this.collected,
    required this.outstanding,
    required this.overdueCount,
    required this.expensesPaid,
    required this.cashOnHand,
    required this.pendingExpenses,
    this.payablesOutstanding = 0,
    this.budgetApproved = 0,
    this.budgetActual = 0,
    this.budgetDisbursed = 0,
  });

  final double billed;
  final double collected;
  final double outstanding;
  final int overdueCount;
  final double expensesPaid;
  final double cashOnHand;
  final double pendingExpenses;
  final double payablesOutstanding;
  final double budgetApproved;
  final double budgetActual;
  final double budgetDisbursed;

  double get netCashMovement => collected - expensesPaid;
  double get budgetConsumedPercent =>
      budgetApproved <= 0 ? 0 : (budgetActual / budgetApproved) * 100;
}

class FinanceExpenseCategories {
  static const values = [
    'Utilities — electricity & water',
    'Internet & telephone',
    'Educational materials',
    'Maintenance & repairs',
    'Transport & fuel',
    'Food & cafeteria',
    'Cleaning materials',
    'Office supplies',
    'School events',
    'Marketing & advertising',
    'Staff-related (not payroll run)',
    'Other',
  ];

  static String departmentFor(String category) {
    final key = category.toLowerCase();
    if (key.contains('education') || key.contains('event')) return 'Academics';
    if (key.contains('transport') || key.contains('fuel')) return 'Transport';
    if (key.contains('market')) return 'Marketing';
    if (key.contains('office') ||
        key.contains('internet') ||
        key.contains('staff')) {
      return 'Administration';
    }
    if (key.contains('maintenance') ||
        key.contains('clean') ||
        key.contains('utilit')) {
      return 'Facilities';
    }
    return 'Other';
  }
}

class FinanceDepartments {
  static const values = [
    'Academics',
    'Transport',
    'Administration',
    'Marketing',
    'Facilities',
    'Other',
  ];
}

class FinanceBudget {
  FinanceBudget({
    required this.id,
    required this.schoolId,
    required this.department,
    required this.academicYear,
    required this.amount,
    this.period = 'Annual',
    this.cashboxId,
    this.custodian,
    this.notes,
  });

  final String id;
  final String schoolId;
  final String department;
  final String academicYear;
  final String period;
  final double amount;
  String? cashboxId;
  final String? custodian;
  final String? notes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'department': department,
        'academicYear': academicYear,
        'period': period,
        'amount': amount,
        if (cashboxId != null) 'cashboxId': cashboxId,
        if (custodian != null) 'custodian': custodian,
        if (notes != null) 'notes': notes,
      };

  factory FinanceBudget.fromMap(Map<String, dynamic> map) {
    return FinanceBudget(
      id: (map['id'] as String? ?? '').trim(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      department: map['department'] as String? ?? 'Other',
      academicYear: map['academicYear'] as String? ?? '',
      period: map['period'] as String? ?? 'Annual',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      cashboxId: map['cashboxId'] as String?,
      custodian: map['custodian'] as String?,
      notes: map['notes'] as String?,
    );
  }
}

class FinanceBudgetDisbursement {
  const FinanceBudgetDisbursement({
    required this.id,
    required this.schoolId,
    required this.budgetId,
    required this.fromCashboxId,
    required this.toCashboxId,
    required this.amount,
    required this.at,
    required this.recordedBy,
    this.voucherNo,
    this.note,
  });

  final String id;
  final String schoolId;
  final String budgetId;
  final String fromCashboxId;
  final String toCashboxId;
  final double amount;
  final DateTime at;
  final String recordedBy;
  final String? voucherNo;
  final String? note;

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'budgetId': budgetId,
        'fromCashboxId': fromCashboxId,
        'toCashboxId': toCashboxId,
        'amount': amount,
        'at': at.toIso8601String(),
        'recordedBy': recordedBy,
        if (voucherNo != null) 'voucherNo': voucherNo,
        if (note != null) 'note': note,
      };

  factory FinanceBudgetDisbursement.fromMap(Map<String, dynamic> map) {
    return FinanceBudgetDisbursement(
      id: (map['id'] as String? ?? '').trim(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      budgetId: map['budgetId'] as String? ?? '',
      fromCashboxId: map['fromCashboxId'] as String? ?? '',
      toCashboxId: map['toCashboxId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      at: DateTime.tryParse(map['at'] as String? ?? '') ?? DateTime.now(),
      recordedBy: map['recordedBy'] as String? ?? '',
      voucherNo: map['voucherNo'] as String?,
      note: map['note'] as String?,
    );
  }
}

class FinanceBudgetUsage {
  const FinanceBudgetUsage({
    required this.budget,
    required this.actual,
    this.disbursed = 0,
    this.cashboxBalance = 0,
  });

  final FinanceBudget budget;
  final double actual;
  final double disbursed;
  final double cashboxBalance;

  double get remaining => budget.amount - actual;
  double get remainingToDisburse => budget.amount - disbursed;
  double get consumedPercent =>
      budget.amount <= 0 ? 0 : (actual / budget.amount) * 100;
  double get disbursedPercent =>
      budget.amount <= 0 ? 0 : (disbursed / budget.amount) * 100;
  bool get overrun => actual > budget.amount + 0.004;
}

class FinancePayable {
  FinancePayable({
    required this.id,
    required this.schoolId,
    required this.supplier,
    required this.department,
    required this.amount,
    required this.dueDate,
    this.invoiceRef,
    this.purpose,
    this.paidAmount = 0,
    this.paymentMethod,
    this.lastPaidAt,
    DateTime? issuedAt,
    this.approved = false,
    this.approvedBy,
    this.cashboxId,
    this.voucherNo,
    this.budgetId,
  }) : issuedAt = issuedAt ?? dueDate;

  final String id;
  final String schoolId;
  final String supplier;
  final String department;
  final double amount;
  final DateTime dueDate;
  final DateTime issuedAt;
  final String? invoiceRef;
  final String? purpose;
  double paidAmount;
  FinancePaymentMethod? paymentMethod;
  DateTime? lastPaidAt;
  bool approved;
  String? approvedBy;
  String? cashboxId;
  String? voucherNo;
  String? budgetId;

  double get outstanding =>
      (amount - paidAmount).clamp(0, double.infinity).toDouble();

  bool get isPaid => outstanding <= 0.004;

  FinanceInvoiceStatus get status {
    if (isPaid) return FinanceInvoiceStatus.paid;
    final today = DateTime.now();
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final now = DateTime(today.year, today.month, today.day);
    if (now.isAfter(due)) return FinanceInvoiceStatus.overdue;
    if (paidAmount > 0) return FinanceInvoiceStatus.partial;
    return FinanceInvoiceStatus.pending;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'supplier': supplier,
        'department': department,
        'amount': amount,
        'dueDate': dueDate.toIso8601String(),
        'issuedAt': issuedAt.toIso8601String(),
        if (invoiceRef != null) 'invoiceRef': invoiceRef,
        if (purpose != null) 'purpose': purpose,
        'paidAmount': paidAmount,
        if (paymentMethod != null) 'paymentMethod': paymentMethod!.name,
        if (lastPaidAt != null) 'lastPaidAt': lastPaidAt!.toIso8601String(),
        'approved': approved,
        if (approvedBy != null) 'approvedBy': approvedBy,
        if (cashboxId != null) 'cashboxId': cashboxId,
        if (voucherNo != null) 'voucherNo': voucherNo,
        if (budgetId != null) 'budgetId': budgetId,
      };

  factory FinancePayable.fromMap(Map<String, dynamic> map) {
    return FinancePayable(
      id: (map['id'] as String? ?? '').trim(),
      schoolId: (map['schoolId'] as String? ?? '').trim().toUpperCase(),
      supplier: map['supplier'] as String? ?? '',
      department: map['department'] as String? ?? 'Other',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      dueDate: DateTime.tryParse(map['dueDate'] as String? ?? '') ??
          DateTime.now(),
      issuedAt: DateTime.tryParse(map['issuedAt'] as String? ?? ''),
      invoiceRef: map['invoiceRef'] as String?,
      purpose: map['purpose'] as String?,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0,
      paymentMethod: map['paymentMethod'] == null
          ? null
          : FinancePaymentMethodX.parse(map['paymentMethod']),
      lastPaidAt: DateTime.tryParse(map['lastPaidAt'] as String? ?? ''),
      approved: map.containsKey('approved')
          ? map['approved'] == true
          : true,
      approvedBy: map['approvedBy'] as String?,
      cashboxId: map['cashboxId'] as String?,
      voucherNo: map['voucherNo'] as String?,
      budgetId: map['budgetId'] as String?,
    );
  }
}
