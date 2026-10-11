import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/finance_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/finance_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FinanceService.instance.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'accountant.lia',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
      fullName: 'LIA Accountant',
    );
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-FIN-1',
        fullName: 'Sara Regular',
        grade: 'Grade 1',
        className: 'Grade 1A',
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2017, 1, 1),
        fundingType: StudentFundingType.regular,
      ),
      AdminStudentRecord(
        studentId: 'STU-FIN-2',
        fullName: 'Yonas Scholar',
        grade: 'Grade 1',
        className: 'Grade 1A',
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2017, 2, 2),
        fundingType: StudentFundingType.scholarship,
      ),
    ], replace: true);
  });

  tearDown(() => AuthService.currentUser = null);

  test('partial payments keep the student outstanding balance', () {
    FinanceService.instance.addFeeStructure(
      title: 'Annual tuition',
      grade: 'Grade 1',
      academicYear: '2025/2026',
      amount: 60000,
      installmentCount: 1,
    );
    final created = FinanceService.instance.generateInvoices(
      academicYear: '2025/2026',
      grade: 'Grade 1',
    );
    expect(created, 2);

    final regular = FinanceService.instance.invoicesForSchool().firstWhere(
      (i) => i.studentId == 'STU-FIN-1',
    );
    FinanceService.instance.recordPayment(
      invoiceId: regular.id,
      amount: 20000,
      method: FinancePaymentMethod.bankTransfer,
      reference: 'CBE-1001',
    );
    FinanceService.instance.recordPayment(
      invoiceId: regular.id,
      amount: 15000,
      method: FinancePaymentMethod.cash,
    );

    final statement =
        FinanceService.instance.statementForStudent('STU-FIN-1')!;
    expect(statement.billed, 60000);
    expect(statement.paid, 35000);
    expect(statement.outstanding, 25000);
    expect(statement.payments.first.receiptNo, startsWith('REC-'));
  });

  test('scholarship students use the scholarship fee plan', () {
    FinanceService.instance.addFeeStructure(
      title: 'Annual tuition',
      grade: 'Grade 1',
      academicYear: '2025/2026',
      amount: 60000,
      fundingType: 'regular',
    );
    FinanceService.instance.addFeeStructure(
      title: 'Scholarship tuition',
      grade: 'Grade 1',
      academicYear: '2025/2026',
      amount: 0,
      fundingType: 'scholarship',
    );
    FinanceService.instance.generateInvoices(academicYear: '2025/2026');

    expect(
      FinanceService.instance
          .statementForStudent('STU-FIN-2')!
          .billed,
      0,
    );
    expect(
      FinanceService.instance
          .statementForStudent('STU-FIN-1')!
          .billed,
      60000,
    );
  });

  test('cashbox expected close matches receipts minus refunds', () {
    final box = FinanceService.instance.addCashbox(
      name: 'Main office',
      openingBalance: 5000,
    );
    FinanceService.instance.recordCashMovement(
      cashboxId: box.id,
      kind: FinanceCashKind.receipt,
      amount: 25000,
    );
    FinanceService.instance.recordCashMovement(
      cashboxId: box.id,
      kind: FinanceCashKind.refund,
      amount: 2000,
    );
    expect(FinanceService.instance.expectedCash(box.id), 28000);

    final close = FinanceService.instance.closeCashbox(
      cashboxId: box.id,
      counted: 27900,
    );
    expect(close.expected, 28000);
    expect(close.variance, -100);
  });

  test('expense workflow cannot record a payroll salary run', () {
    expect(
      () => FinanceService.instance.requestExpense(
        category: 'Payroll salary run',
        amount: 10000,
      ),
      throwsStateError,
    );

    final expense = FinanceService.instance.requestExpense(
      category: 'Office supplies',
      amount: 800,
      supplier: 'Staples',
    );
    expect(expense.status, FinanceExpenseStatus.requested);
    FinanceService.instance.approveExpense(expense.id);
    FinanceService.instance.payExpense(
      id: expense.id,
      method: FinancePaymentMethod.bankTransfer,
      reference: 'INV-88',
    );
    expect(
      FinanceService.instance.controlTotals().expensesPaid,
      800,
    );
  });

  test('control totals stay consistent across fee and expense desks', () {
    FinanceService.instance.addFeeStructure(
      title: 'Tuition',
      grade: 'Grade 1',
      academicYear: '2025/2026',
      amount: 10000,
    );
    FinanceService.instance.generateInvoices(academicYear: '2025/2026');
    final invoice = FinanceService.instance.invoicesForSchool().first;
    FinanceService.instance.recordPayment(
      invoiceId: invoice.id,
      amount: 4000,
      method: FinancePaymentMethod.cash,
    );
    final expense = FinanceService.instance.requestExpense(
      category: 'Internet & telephone',
      amount: 500,
    );
    FinanceService.instance.approveExpense(expense.id);
    FinanceService.instance.payExpense(
      id: expense.id,
      method: FinancePaymentMethod.cash,
    );

    final totals = FinanceService.instance.controlTotals();
    expect(totals.billed, 20000);
    expect(totals.collected, 4000);
    expect(totals.outstanding, 16000);
    expect(totals.expensesPaid, 500);
    expect(totals.netCashMovement, 3500);
    expect(FinanceService.instance.auditForSchool(), isNotEmpty);
  });
}
