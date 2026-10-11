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
    ], replace: true);
  });

  tearDown(() => AuthService.currentUser = null);

  test('budget allocation opens a dedicated cashbox and disbursement moves cash', () {
    final treasury = FinanceService.instance.addCashbox(
      name: 'Main treasury',
      openingBalance: 500000,
      purpose: FinanceCashboxPurpose.general,
    );
    final budget = FinanceService.instance.addBudget(
      department: 'Academics',
      academicYear: '2025/2026',
      amount: 200000,
      custodian: 'DoSA',
    );
    expect(budget.cashboxId, isNotNull);
    expect(FinanceService.instance.expectedCash(budget.cashboxId!), 0);

    FinanceService.instance.disburseBudget(
      budgetId: budget.id,
      amount: 80000,
      fromCashboxId: treasury.id,
      voucherNo: 'W-01',
    );

    final usage = FinanceService.instance.usageForBudget(budget);
    expect(usage.disbursed, 80000);
    expect(usage.remainingToDisburse, 120000);
    expect(usage.cashboxBalance, 80000);
    expect(FinanceService.instance.expectedCash(treasury.id), 420000);
    expect(
      FinanceService.instance
          .cashboxesForSchool()
          .where((b) => b.purpose == FinanceCashboxPurpose.budget),
      isNotEmpty,
    );
  });

  test('disbursement cannot exceed allocation or source cash', () {
    final treasury = FinanceService.instance.addCashbox(
      name: 'Main treasury',
      openingBalance: 10000,
    );
    final budget = FinanceService.instance.addBudget(
      department: 'Transport',
      academicYear: '2025/2026',
      amount: 50000,
    );
    expect(
      () => FinanceService.instance.disburseBudget(
        budgetId: budget.id,
        amount: 20000,
        fromCashboxId: treasury.id,
      ),
      throwsStateError,
    );
    expect(
      () => FinanceService.instance.disburseBudget(
        budgetId: budget.id,
        amount: 80000,
        fromCashboxId: treasury.id,
      ),
      throwsStateError,
    );
  });

  test('expense paid from the budget cashbox spends the released cash', () {
    final treasury = FinanceService.instance.addCashbox(
      name: 'Main treasury',
      openingBalance: 100000,
    );
    final budget = FinanceService.instance.addBudget(
      department: 'Academics',
      academicYear: '2025/2026',
      amount: 100000,
    );
    FinanceService.instance.disburseBudget(
      budgetId: budget.id,
      amount: 40000,
      fromCashboxId: treasury.id,
    );
    final expense = FinanceService.instance.requestExpense(
      category: 'Educational materials',
      amount: 15000,
      budgetId: budget.id,
      cashboxId: budget.cashboxId,
      voucherNo: 'V-22',
    );
    FinanceService.instance.approveExpense(expense.id);
    FinanceService.instance.payExpense(
      id: expense.id,
      method: FinancePaymentMethod.cash,
      cashboxId: budget.cashboxId,
    );

    final usage = FinanceService.instance.usageForBudget(budget);
    expect(usage.actual, 15000);
    expect(usage.disbursed, 40000);
    expect(usage.cashboxBalance, 25000);
    expect(expense.cashboxId, budget.cashboxId);
  });

  test('supplier bill needs approval and pays from a named cashbox', () {
    final box = FinanceService.instance.addCashbox(
      name: 'Bank float',
      openingBalance: 20000,
      purpose: FinanceCashboxPurpose.general,
    );
    final bill = FinanceService.instance.addPayable(
      supplier: 'Book House',
      department: 'Academics',
      amount: 9000,
      dueDate: DateTime.now().add(const Duration(days: 7)),
      voucherNo: 'APB-1',
    );
    expect(
      () => FinanceService.instance.payPayable(
        id: bill.id,
        amount: 9000,
        method: FinancePaymentMethod.cash,
        cashboxId: box.id,
      ),
      throwsStateError,
    );
    FinanceService.instance.approvePayable(bill.id);
    FinanceService.instance.payPayable(
      id: bill.id,
      amount: 9000,
      method: FinancePaymentMethod.cash,
      cashboxId: box.id,
    );
    expect(bill.isPaid, isTrue);
    expect(FinanceService.instance.expectedCash(box.id), 11000);
    expect(bill.cashboxId, box.id);
  });

  test('fee plan can name a collections cashbox and generate only that plan', () {
    final collections = FinanceService.instance.addCashbox(
      name: 'Fee window',
      openingBalance: 0,
      purpose: FinanceCashboxPurpose.collections,
    );
    final plan = FinanceService.instance.addFeeStructure(
      title: 'Tuition',
      grade: 'Grade 1',
      academicYear: '2025/2026',
      amount: 10000,
      collectionCashboxId: collections.id,
      dueDay: 15,
      lateFeeAmount: 200,
    );
    final created = FinanceService.instance.generateInvoices(
      academicYear: '2025/2026',
      structureId: plan.id,
    );
    expect(created, 1);
    final invoice = FinanceService.instance.invoicesForSchool().single;
    expect(invoice.dueDate.day, 15);
    FinanceService.instance.recordPayment(
      invoiceId: invoice.id,
      amount: 4000,
      method: FinancePaymentMethod.cash,
      cashboxId: collections.id,
    );
    expect(FinanceService.instance.expectedCash(collections.id), 4000);
  });

  test('transfer moves cash between boxes without changing the school total', () {
    final a = FinanceService.instance.addCashbox(
      name: 'Front office',
      openingBalance: 8000,
    );
    final b = FinanceService.instance.addCashbox(
      name: 'Cafeteria',
      openingBalance: 2000,
    );
    FinanceService.instance.transferBetweenCashboxes(
      fromCashboxId: a.id,
      toCashboxId: b.id,
      amount: 3000,
    );
    expect(FinanceService.instance.expectedCash(a.id), 5000);
    expect(FinanceService.instance.expectedCash(b.id), 5000);
    expect(FinanceService.instance.controlTotals().cashOnHand, 10000);
  });
}
