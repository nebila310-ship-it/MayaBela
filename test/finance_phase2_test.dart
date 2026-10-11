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
      ),
      AdminStudentRecord(
        studentId: 'STU-FIN-2',
        fullName: 'Yonas Scholar',
        grade: 'Grade 1',
        className: 'Grade 1A',
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2017, 2, 2),
      ),
    ], replace: true);
  });

  tearDown(() => AuthService.currentUser = null);

  test('department budget remaining uses paid expenses and supplier payments', () {
    FinanceService.instance.addBudget(
      department: 'Academics',
      academicYear: '2025/2026',
      amount: 2000000,
    );
    final expense = FinanceService.instance.requestExpense(
      category: 'Educational materials',
      amount: 1200000,
    );
    FinanceService.instance.approveExpense(expense.id);
    FinanceService.instance.payExpense(
      id: expense.id,
      method: FinancePaymentMethod.bankTransfer,
    );

    final bill = FinanceService.instance.addPayable(
      supplier: 'Book House',
      department: 'Academics',
      amount: 200000,
      dueDate: DateTime.now().add(const Duration(days: 10)),
    );
    FinanceService.instance.payPayable(
      id: bill.id,
      amount: 80000,
      method: FinancePaymentMethod.cheque,
    );

    final usage = FinanceService.instance.budgetUsage().single;
    expect(usage.actual, 1280000);
    expect(usage.remaining, 720000);
    expect(usage.overrun, isFalse);
    expect(usage.consumedPercent, closeTo(64, 0.1));
  });

  test('supplier payable stays a liability until it is paid', () {
    final bill = FinanceService.instance.addPayable(
      supplier: 'Ethio Telecom',
      department: 'Administration',
      amount: 15000,
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      invoiceRef: 'ET-88',
    );
    expect(bill.status, FinanceInvoiceStatus.overdue);
    expect(FinanceService.instance.controlTotals().payablesOutstanding, 15000);

    FinanceService.instance.payPayable(
      id: bill.id,
      amount: 5000,
      method: FinancePaymentMethod.bankTransfer,
      reference: 'CBE-9',
    );
    expect(bill.outstanding, 10000);
    expect(bill.status, FinanceInvoiceStatus.overdue);
    expect(FinanceService.instance.controlTotals().payablesOutstanding, 10000);
  });

  test('parent fee statements only include the requested children', () {
    FinanceService.instance.addFeeStructure(
      title: 'Tuition',
      grade: 'Grade 1',
      academicYear: '2025/2026',
      amount: 60000,
    );
    FinanceService.instance.generateInvoices(academicYear: '2025/2026');
    final invoice = FinanceService.instance.invoicesForSchool().firstWhere(
      (i) => i.studentId == 'STU-FIN-1',
    );
    FinanceService.instance.recordPayment(
      invoiceId: invoice.id,
      amount: 20000,
      method: FinancePaymentMethod.cash,
    );

    final mine = FinanceService.instance.statementsForStudentIds(['STU-FIN-1']);
    expect(mine, hasLength(1));
    expect(mine.single.studentName, 'Sara Regular');
    expect(mine.single.billed, 60000);
    expect(mine.single.paid, 20000);
    expect(mine.single.outstanding, 40000);
    expect(mine.single.payments.single.receiptNo, startsWith('REC-'));

    final other = FinanceService.instance.statementsForStudentIds(['STU-FIN-2']);
    expect(other.single.studentId, 'STU-FIN-2');
    expect(other.single.payments, isEmpty);
  });
}
