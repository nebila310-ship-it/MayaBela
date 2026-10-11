import 'package:flutter/foundation.dart';

import 'package:mayabela/models/finance_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/finance_persistence_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

/// Phase 1 school finance desk: fees, cashboxes, expenses, reports.
/// Payroll stays in HR — this service only records school money movements.
class FinanceService extends ChangeNotifier {
  FinanceService._();
  static final instance = FinanceService._();

  final List<FinanceFeeStructure> _structures = [];
  final List<FinanceInvoice> _invoices = [];
  final List<FinancePayment> _payments = [];
  final List<FinanceCashbox> _cashboxes = [];
  final List<FinanceCashMovement> _cashMoves = [];
  final List<FinanceCashClose> _cashCloses = [];
  final List<FinanceExpense> _expenses = [];
  final List<FinanceAuditEvent> _audit = [];
  int _seq = 1;
  bool _loaded = false;

  List<FinanceFeeStructure> get structures => List.unmodifiable(_structures);
  List<FinanceInvoice> get invoices => List.unmodifiable(_invoices);
  List<FinancePayment> get payments => List.unmodifiable(_payments);
  List<FinanceCashbox> get cashboxes => List.unmodifiable(_cashboxes);
  List<FinanceCashMovement> get cashMoves => List.unmodifiable(_cashMoves);
  List<FinanceCashClose> get cashCloses => List.unmodifiable(_cashCloses);
  List<FinanceExpense> get expenses => List.unmodifiable(_expenses);
  List<FinanceAuditEvent> get audit => List.unmodifiable(_audit);

  static const payrollStaysInHr =
      'Staff salary runs stay in Human Resource → Payroll. '
      'Finance only records school fees, cash, and operating expenses.';

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await FinancePersistenceService.instance.loadIntoService();
  }

  @visibleForTesting
  void resetForTests() {
    _structures.clear();
    _invoices.clear();
    _payments.clear();
    _cashboxes.clear();
    _cashMoves.clear();
    _cashCloses.clear();
    _expenses.clear();
    _audit.clear();
    _seq = 1;
    _loaded = true;
  }

  void applyPersistedData({
    List<FinanceFeeStructure>? structures,
    List<FinanceInvoice>? invoices,
    List<FinancePayment>? payments,
    List<FinanceCashbox>? cashboxes,
    List<FinanceCashMovement>? cashMoves,
    List<FinanceCashClose>? cashCloses,
    List<FinanceExpense>? expenses,
    List<FinanceAuditEvent>? audit,
  }) {
    if (structures != null) {
      _structures
        ..clear()
        ..addAll(structures);
    }
    if (invoices != null) {
      _invoices
        ..clear()
        ..addAll(invoices);
    }
    if (payments != null) {
      _payments
        ..clear()
        ..addAll(payments);
    }
    if (cashboxes != null) {
      _cashboxes
        ..clear()
        ..addAll(cashboxes);
    }
    if (cashMoves != null) {
      _cashMoves
        ..clear()
        ..addAll(cashMoves);
    }
    if (cashCloses != null) {
      _cashCloses
        ..clear()
        ..addAll(cashCloses);
    }
    if (expenses != null) {
      _expenses
        ..clear()
        ..addAll(expenses);
    }
    if (audit != null) {
      _audit
        ..clear()
        ..addAll(audit);
    }
    notifyListeners();
  }

  String get _schoolId =>
      (AuthService.activeSchoolId ?? '').trim().toUpperCase();

  String get _actor {
    final user = AuthService.currentUser;
    final name = user?.fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return user?.username ?? 'finance';
  }

  String _id(String prefix) {
    _seq += 1;
    return '$prefix-${_seq.toString().padLeft(4, '0')}';
  }

  List<FinanceFeeStructure> structuresForSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).trim().toUpperCase();
    return _structures.where((s) => s.schoolId == sid).toList();
  }

  List<FinanceInvoice> invoicesForSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).trim().toUpperCase();
    return _invoices.where((i) => i.schoolId == sid).toList();
  }

  List<FinancePayment> paymentsForSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).trim().toUpperCase();
    return _payments.where((p) => p.schoolId == sid).toList();
  }

  List<FinanceCashbox> cashboxesForSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).trim().toUpperCase();
    return _cashboxes.where((c) => c.schoolId == sid).toList();
  }

  List<FinanceExpense> expensesForSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).trim().toUpperCase();
    return _expenses.where((e) => e.schoolId == sid).toList();
  }

  List<FinanceAuditEvent> auditForSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).trim().toUpperCase();
    return _audit.where((a) => a.schoolId == sid).toList().reversed.toList();
  }

  FinanceStudentStatement? statementForStudent(String studentId) {
    final id = studentId.trim().toUpperCase();
    final invoices =
        invoicesForSchool().where((i) => i.studentId == id).toList();
    if (invoices.isEmpty) return null;
    return FinanceStudentStatement(
      studentId: id,
      studentName: invoices.first.studentName,
      invoices: invoices,
      payments: paymentsForSchool().where((p) => p.studentId == id).toList(),
    );
  }

  FinanceControlTotals controlTotals([String? schoolId]) {
    final invoices = invoicesForSchool(schoolId);
    final payments = paymentsForSchool(schoolId);
    final expenses = expensesForSchool(schoolId);
    return FinanceControlTotals(
      billed: invoices.fold<double>(0, (s, i) => s + i.amount),
      collected: payments.fold<double>(0, (s, p) => s + p.amount),
      outstanding: invoices.fold<double>(0, (s, i) => s + i.outstanding),
      overdueCount:
          invoices.where((i) => i.status == FinanceInvoiceStatus.overdue).length,
      expensesPaid: expenses
          .where((e) => e.status == FinanceExpenseStatus.paid)
          .fold<double>(0, (s, e) => s + e.amount),
      cashOnHand: cashboxesForSchool(schoolId)
          .fold<double>(0, (s, c) => s + expectedCash(c.id)),
      pendingExpenses: expenses
          .where((e) => e.status != FinanceExpenseStatus.paid)
          .fold<double>(0, (s, e) => s + e.amount),
    );
  }

  FinanceFeeStructure addFeeStructure({
    required String title,
    required String grade,
    required String academicYear,
    required double amount,
    String fundingType = 'regular',
    int installmentCount = 1,
    String term = 'Annual',
    String? schoolId,
  }) {
    final sid = (schoolId ?? _schoolId).trim().toUpperCase();
    final row = FinanceFeeStructure(
      id: _id('STR'),
      schoolId: sid,
      title: title.trim(),
      grade: grade.trim(),
      academicYear: academicYear.trim(),
      amount: amount,
      fundingType: fundingType.trim().isEmpty ? 'regular' : fundingType.trim(),
      installmentCount: installmentCount < 1 ? 1 : installmentCount,
      term: term.trim().isEmpty ? 'Annual' : term.trim(),
    );
    _structures.add(row);
    _auditAdd(sid, 'fee_structure', 'Created ${row.title} for ${row.grade}');
    _persist();
    return row;
  }

  int generateInvoices({
    required String academicYear,
    String? grade,
    String? schoolId,
    DateTime? firstDue,
  }) {
    final sid = (schoolId ?? _schoolId).trim().toUpperCase();
    final students = StudentRegistryService.instance.visibleStudents(
      schoolId: sid,
    );
    final due = firstDue ?? DateTime.now().add(const Duration(days: 14));
    var created = 0;
    for (final student in students) {
      if (grade != null &&
          grade.trim().isNotEmpty &&
          student.grade.trim() != grade.trim()) {
        continue;
      }
      final match = _structureFor(student, academicYear, sid);
      if (match == null) continue;
      final already = _invoices.any(
        (i) =>
            i.schoolId == sid &&
            i.studentId == student.studentId &&
            i.structureId == match.id,
      );
      if (already) continue;
      final parts = match.installmentCount < 1 ? 1 : match.installmentCount;
      for (var n = 0; n < parts; n++) {
        final title = parts == 1
            ? match.title
            : '${match.title} — installment ${n + 1} of $parts';
        _invoices.add(
          FinanceInvoice(
            id: _id('INV'),
            schoolId: sid,
            studentId: student.studentId,
            studentName: student.fullName,
            grade: student.grade,
            className: student.className,
            title: title,
            academicYear: academicYear,
            term: match.term,
            fundingType: student.fundingType.name,
            structureId: match.id,
            amount: match.installmentAmount,
            dueDate: DateTime(due.year, due.month + n, due.day),
          ),
        );
        created += 1;
      }
    }
    if (created > 0) {
      _auditAdd(sid, 'invoices', 'Generated $created invoice(s)');
      _persist();
    }
    return created;
  }

  FinanceFeeStructure? _structureFor(
    AdminStudentRecord student,
    String academicYear,
    String schoolId,
  ) {
    final year = academicYear.trim();
    final type = student.fundingType.name;
    final matches = structuresForSchool(schoolId).where((s) {
      return s.academicYear == year &&
          s.grade == student.grade &&
          s.fundingType == type;
    }).toList();
    if (matches.isEmpty) {
      return structuresForSchool(schoolId).cast<FinanceFeeStructure?>().firstWhere(
            (s) =>
                s!.academicYear == year &&
                s.grade == student.grade &&
                s.fundingType == 'regular',
            orElse: () => null,
          );
    }
    return matches.first;
  }

  FinancePayment recordPayment({
    required String invoiceId,
    required double amount,
    required FinancePaymentMethod method,
    String? reference,
    String? note,
    String? cashboxId,
    DateTime? paidAt,
  }) {
    final invoice = _invoices.firstWhere((i) => i.id == invoiceId);
    if (amount <= 0) {
      throw StateError('Payment must be greater than zero.');
    }
    final take = amount > invoice.outstanding ? invoice.outstanding : amount;
    invoice.paidAmount += take;
    final payment = FinancePayment(
      id: _id('PAY'),
      schoolId: invoice.schoolId,
      invoiceId: invoice.id,
      studentId: invoice.studentId,
      studentName: invoice.studentName,
      amount: take,
      method: method,
      paidAt: paidAt ?? DateTime.now(),
      recordedBy: _actor,
      receiptNo: _receiptNo(invoice.schoolId),
      reference: reference?.trim().isEmpty == true ? null : reference?.trim(),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
    );
    _payments.add(payment);
    if (method == FinancePaymentMethod.cash) {
      final box = cashboxId ??
          (cashboxesForSchool(invoice.schoolId).isEmpty
              ? null
              : cashboxesForSchool(invoice.schoolId).first.id);
      if (box != null) {
        _cashMoves.add(
          FinanceCashMovement(
            id: _id('CSHM'),
            schoolId: invoice.schoolId,
            cashboxId: box,
            kind: FinanceCashKind.receipt,
            amount: take,
            at: payment.paidAt,
            recordedBy: _actor,
            note: 'Fee receipt ${payment.receiptNo}',
            reference: payment.id,
          ),
        );
      }
    }
    _auditAdd(
      invoice.schoolId,
      'payment',
      '${payment.receiptNo}: ${take.toStringAsFixed(0)} ETB for ${invoice.studentName}',
    );
    _persist();
    return payment;
  }

  String _receiptNo(String schoolId) {
    final day = DateTime.now();
    final stamp =
        '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
    final count = _payments.where((p) => p.schoolId == schoolId).length + 1;
    return 'REC-$stamp-${count.toString().padLeft(3, '0')}';
  }

  FinanceCashbox addCashbox({
    required String name,
    double openingBalance = 0,
    String? cashierName,
    String? schoolId,
  }) {
    final sid = (schoolId ?? _schoolId).trim().toUpperCase();
    final box = FinanceCashbox(
      id: _id('BOX'),
      schoolId: sid,
      name: name.trim(),
      openingBalance: openingBalance,
      cashierName: cashierName?.trim().isEmpty == true
          ? null
          : cashierName?.trim(),
    );
    _cashboxes.add(box);
    _auditAdd(sid, 'cashbox', 'Opened ${box.name}');
    _persist();
    return box;
  }

  FinanceCashMovement recordCashMovement({
    required String cashboxId,
    required FinanceCashKind kind,
    required double amount,
    String? note,
    String? reference,
  }) {
    final box = _cashboxes.firstWhere((c) => c.id == cashboxId);
    if (amount <= 0) throw StateError('Amount must be greater than zero.');
    final move = FinanceCashMovement(
      id: _id('CSHM'),
      schoolId: box.schoolId,
      cashboxId: box.id,
      kind: kind,
      amount: amount,
      at: DateTime.now(),
      recordedBy: _actor,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      reference: reference?.trim().isEmpty == true ? null : reference?.trim(),
    );
    _cashMoves.add(move);
    _auditAdd(box.schoolId, 'cash', '${kind.label} ${amount.toStringAsFixed(0)} ETB');
    _persist();
    return move;
  }

  double expectedCash(String cashboxId) {
    final box = _cashboxes.cast<FinanceCashbox?>().firstWhere(
          (c) => c!.id == cashboxId,
          orElse: () => null,
        );
    if (box == null) return 0;
    var total = box.openingBalance;
    for (final move in _cashMoves.where((m) => m.cashboxId == cashboxId)) {
      total += move.kind.increasesBalance ? move.amount : -move.amount;
    }
    return total;
  }

  FinanceCashClose closeCashbox({
    required String cashboxId,
    required double counted,
    DateTime? day,
  }) {
    final box = _cashboxes.firstWhere((c) => c.id == cashboxId);
    final close = FinanceCashClose(
      id: _id('CLS'),
      schoolId: box.schoolId,
      cashboxId: box.id,
      day: day ?? DateTime.now(),
      expected: expectedCash(cashboxId),
      counted: counted,
      closedBy: _actor,
    );
    _cashCloses.add(close);
    _auditAdd(
      box.schoolId,
      'cash_close',
      '${box.name}: counted ${counted.toStringAsFixed(0)}, expected ${close.expected.toStringAsFixed(0)}',
    );
    _persist();
    return close;
  }

  FinanceExpense requestExpense({
    required String category,
    required double amount,
    String? supplier,
    String? purpose,
    DateTime? date,
    String? schoolId,
  }) {
    if (category.toLowerCase().contains('payroll') ||
        category.toLowerCase().contains('salary')) {
      throw StateError(payrollStaysInHr);
    }
    final sid = (schoolId ?? _schoolId).trim().toUpperCase();
    final row = FinanceExpense(
      id: _id('EXP'),
      schoolId: sid,
      category: category.trim(),
      amount: amount,
      date: date ?? DateTime.now(),
      requestedBy: _actor,
      supplier: supplier?.trim().isEmpty == true ? null : supplier?.trim(),
      purpose: purpose?.trim().isEmpty == true ? null : purpose?.trim(),
    );
    _expenses.add(row);
    _auditAdd(sid, 'expense_request', '${row.category} ${amount.toStringAsFixed(0)} ETB');
    _persist();
    return row;
  }

  FinanceExpense approveExpense(String id) {
    final row = _expenses.firstWhere((e) => e.id == id);
    final isOwner = AuthService.currentUser?.roleKey == AuthService.roleAdmin;
    if (!isOwner && row.requestedBy == _actor) {
      throw StateError('You cannot approve your own expense request.');
    }
    row.status = FinanceExpenseStatus.approved;
    row.approvedBy = _actor;
    _auditAdd(row.schoolId, 'expense_approve', row.id);
    _persist();
    return row;
  }

  FinanceExpense payExpense({
    required String id,
    required FinancePaymentMethod method,
    String? reference,
    String? cashboxId,
  }) {
    final row = _expenses.firstWhere((e) => e.id == id);
    if (row.status == FinanceExpenseStatus.requested) {
      throw StateError('Approve the expense before recording payment.');
    }
    if (row.status == FinanceExpenseStatus.rejected) {
      throw StateError('A rejected expense cannot be paid.');
    }
    row.status = FinanceExpenseStatus.paid;
    row.paidBy = _actor;
    row.paymentMethod = method;
    row.reference = reference?.trim().isEmpty == true ? null : reference?.trim();
    if (method == FinancePaymentMethod.cash) {
      final box = cashboxId ??
          (cashboxesForSchool(row.schoolId).isEmpty
              ? null
              : cashboxesForSchool(row.schoolId).first.id);
      if (box != null) {
        _cashMoves.add(
          FinanceCashMovement(
            id: _id('CSHM'),
            schoolId: row.schoolId,
            cashboxId: box,
            kind: FinanceCashKind.payment,
            amount: row.amount,
            at: DateTime.now(),
            recordedBy: _actor,
            note: 'Expense ${row.id}',
            reference: row.id,
          ),
        );
      }
    }
    _auditAdd(row.schoolId, 'expense_pay', row.id);
    _persist();
    return row;
  }

  FinanceExpense rejectExpense(String id) {
    final row = _expenses.firstWhere((e) => e.id == id);
    row.status = FinanceExpenseStatus.rejected;
    row.approvedBy = _actor;
    _auditAdd(row.schoolId, 'expense_reject', row.id);
    _persist();
    return row;
  }

  void ensureDefaults({String? schoolId}) {
    final sid = (schoolId ?? _schoolId).trim().toUpperCase();
    if (sid.isEmpty) return;
    if (cashboxesForSchool(sid).isEmpty) {
      addCashbox(
        name: 'Main office',
        openingBalance: 5000,
        cashierName: 'Cashier',
        schoolId: sid,
      );
    }
  }

  void _auditAdd(String schoolId, String action, String detail) {
    _audit.add(
      FinanceAuditEvent(
        id: _id('AUD'),
        schoolId: schoolId,
        action: action,
        actor: _actor,
        at: DateTime.now(),
        detail: detail,
      ),
    );
  }

  void _persist() {
    notifyListeners();
    unawaitedPersist();
  }

  @visibleForTesting
  void unawaitedPersist() {
    FinancePersistenceService.instance.saveFromService(pushCloud: false);
  }
}
