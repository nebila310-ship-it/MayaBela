import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/finance_ledger_models.dart';
import 'package:mayabela/models/finance_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/finance_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/pages/web_finance_statements_panel.dart';

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

  final asOf = DateTime(2099, 12, 31);

  test('every auto-posted journal is balanced and the trial balance ties', () {
    FinanceService.instance.addCashbox(name: 'Main', openingBalance: 5000);
    FinanceService.instance.addFeeStructure(
      title: 'Tuition',
      grade: 'Grade 1',
      academicYear: '2025/2026',
      amount: 60000,
    );
    FinanceService.instance.generateInvoices(academicYear: '2025/2026');
    final invoice = FinanceService.instance.invoicesForSchool().single;
    FinanceService.instance.recordPayment(
      invoiceId: invoice.id,
      amount: 20000,
      method: FinancePaymentMethod.bankTransfer,
    );
    final expense = FinanceService.instance.requestExpense(
      category: 'Office supplies',
      amount: 800,
    );
    FinanceService.instance.approveExpense(expense.id);
    FinanceService.instance.payExpense(
      id: expense.id,
      method: FinancePaymentMethod.bankTransfer,
    );
    FinanceService.instance.addPayable(
      supplier: 'Book House',
      department: 'Academics',
      amount: 15000,
      dueDate: DateTime(2026, 1, 15),
    );

    final ledger = FinanceService.instance.ledger();
    expect(ledger.journals, isNotEmpty);
    expect(ledger.journals.every((j) => j.isBalanced), isTrue);

    final tb = ledger.trialBalance(asOf: asOf);
    expect(tb.isBalanced, isTrue);
    expect(tb.totalDebit, tb.totalCredit);
  });

  test('fee invoice and receipt update receivable, income, and bank', () {
    FinanceService.instance.addFeeStructure(
      title: 'Tuition',
      grade: 'Grade 1',
      academicYear: '2025/2026',
      amount: 60000,
    );
    FinanceService.instance.generateInvoices(academicYear: '2025/2026');
    final invoice = FinanceService.instance.invoicesForSchool().single;
    FinanceService.instance.recordPayment(
      invoiceId: invoice.id,
      amount: 20000,
      method: FinancePaymentMethod.bankTransfer,
    );

    final ledger = FinanceService.instance.ledger();
    expect(ledger.balanceFor(FinanceCoa.feesReceivable, asOf).statementAmount, 40000);
    expect(ledger.balanceFor(FinanceCoa.tuitionIncome, asOf).statementAmount, 60000);
    expect(ledger.balanceFor(FinanceCoa.bank, asOf).statementAmount, 20000);
    expect(ledger.balanceFor(FinanceCoa.cash, asOf).statementAmount, 0);

    final ie = ledger.incomeAndExpenditure(to: asOf);
    expect(ie.totalIncome, 60000);
    expect(ie.surplus, 60000);

    final bs = ledger.balanceSheet(asOf: asOf);
    expect(bs.totalAssets, 60000);
    expect(bs.totalEquity, 60000);
    expect(bs.isBalanced, isTrue);
  });

  test('supplier bill is a liability until paid and hits the department expense', () {
    final bill = FinanceService.instance.addPayable(
      supplier: 'Ethio Telecom',
      department: 'Administration',
      amount: 15000,
      dueDate: DateTime(2026, 2, 1),
    );
    FinanceService.instance.payPayable(
      id: bill.id,
      amount: 5000,
      method: FinancePaymentMethod.cheque,
    );

    final ledger = FinanceService.instance.ledger();
    expect(
      ledger.balanceFor(FinanceCoa.administration, asOf).statementAmount,
      15000,
    );
    expect(
      ledger.balanceFor(FinanceCoa.accountsPayable, asOf).statementAmount,
      10000,
    );
    expect(ledger.balanceFor(FinanceCoa.bank, asOf).statementAmount, -5000);

    final bs = ledger.balanceSheet(asOf: asOf);
    expect(bs.isBalanced, isTrue);
    expect(bs.totalAssets, -5000);
    expect(bs.totalLiabilities, 10000);
    expect(bs.totalEquity, -15000);
  });

  test('approved expense accrues then payment clears the accrual', () {
    final expense = FinanceService.instance.requestExpense(
      category: 'Educational materials',
      amount: 1200,
    );
    FinanceService.instance.approveExpense(expense.id);

    var ledger = FinanceService.instance.ledger();
    expect(ledger.balanceFor(FinanceCoa.academics, asOf).statementAmount, 1200);
    expect(
      ledger.balanceFor(FinanceCoa.accruedExpenses, asOf).statementAmount,
      1200,
    );
    expect(ledger.incomeAndExpenditure(to: asOf).surplus, -1200);

    FinanceService.instance.payExpense(
      id: expense.id,
      method: FinancePaymentMethod.cash,
    );
    ledger = FinanceService.instance.ledger();
    expect(ledger.balanceFor(FinanceCoa.academics, asOf).statementAmount, 1200);
    expect(
      ledger.balanceFor(FinanceCoa.accruedExpenses, asOf).statementAmount,
      0,
    );
    expect(ledger.balanceFor(FinanceCoa.cash, asOf).statementAmount, -1200);
    expect(ledger.balanceSheet(asOf: asOf).isBalanced, isTrue);
  });

  test('cash flow closing cash matches the balance sheet cash and bank', () {
    FinanceService.instance.addCashbox(name: 'Main', openingBalance: 5000);
    FinanceService.instance.addFeeStructure(
      title: 'Tuition',
      grade: 'Grade 1',
      academicYear: '2025/2026',
      amount: 10000,
    );
    FinanceService.instance.generateInvoices(academicYear: '2025/2026');
    final invoice = FinanceService.instance.invoicesForSchool().single;
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

    final ledger = FinanceService.instance.ledger();
    final cf = ledger.cashFlow(to: asOf);
    final bs = ledger.balanceSheet(asOf: asOf);
    expect(cf.openingCash, 5000);
    expect(cf.netOperating, 3500);
    expect(cf.closingCash, 8500);
    expect(ledger.cashAndBankAsOf(asOf), 8500);
    expect(
      bs.assets
          .where(
            (l) =>
                l.account.code == FinanceCoa.cash ||
                l.account.code == FinanceCoa.bank,
          )
          .fold<double>(0, (s, l) => s + l.amount),
      8500,
    );
    expect(bs.isBalanced, isTrue);
    expect(cf.operatingIn.single.label, 'Student fee collections');
    expect(cf.operatingOut.single.label, 'Operating expenses paid');
  });

  test('requested expenses and payroll-like categories stay off the ledger', () {
    expect(
      () => FinanceService.instance.requestExpense(
        category: 'Payroll salary run',
        amount: 10000,
      ),
      throwsStateError,
    );
    FinanceService.instance.requestExpense(
      category: 'Office supplies',
      amount: 800,
    );
    final ledger = FinanceService.instance.ledger();
    expect(ledger.journals, isEmpty);
    expect(ledger.incomeAndExpenditure(to: asOf).surplus, 0);
  });

  testWidgets('statements desk shows the four formal reports', (tester) async {
    FinanceService.instance.addFeeStructure(
      title: 'Tuition',
      grade: 'Grade 1',
      academicYear: '2025/2026',
      amount: 10000,
    );
    FinanceService.instance.generateInvoices(academicYear: '2025/2026');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WebFinanceStatementsPanel(),
          ),
        ),
      ),
    );
    expect(find.text('Ledger & statements'), findsOneWidget);
    expect(find.text('Trial balance'), findsWidgets);
    expect(find.text('Income & expenditure'), findsOneWidget);
    expect(find.text('Balance sheet'), findsOneWidget);
    expect(find.text('Cash flow'), findsOneWidget);
    expect(find.textContaining('1100'), findsWidgets);
    await tester.tap(find.text('Balance sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Statement of financial position'), findsOneWidget);
    expect(find.text('Books balance'), findsOneWidget);
  });
}
