import 'package:mayabela/models/finance_ledger_models.dart';
import 'package:mayabela/models/finance_models.dart';

/// Rebuilds a balanced general ledger from Finance desk documents.
/// Same pattern as Sage 50 / Peachtree: source tiles post journals; statements
/// are only a view of those journals. Journals are not stored separately so
/// existing fee, cash, expense, and payable rows keep the books in balance.
class FinanceLedger {
  FinanceLedger._({
    required this.schoolId,
    required this.journals,
  });

  final String schoolId;
  final List<FinanceJournalEntry> journals;

  static const _eps = 0.02;

  static String cashAccount(FinancePaymentMethod? method) {
    return method == FinancePaymentMethod.cash ? FinanceCoa.cash : FinanceCoa.bank;
  }

  factory FinanceLedger.build({
    required String schoolId,
    required List<FinanceInvoice> invoices,
    required List<FinancePayment> payments,
    required List<FinanceCashbox> cashboxes,
    required List<FinanceCashMovement> cashMoves,
    required List<FinanceExpense> expenses,
    required List<FinancePayable> payables,
    List<FinanceBudgetDisbursement> disbursements = const [],
  }) {
    final journals = <FinanceJournalEntry>[];

    void post({
      required String id,
      required DateTime date,
      required String sourceType,
      required String sourceId,
      required String narration,
      required String debit,
      required String credit,
      required double amount,
      String? memo,
    }) {
      if (amount.abs() < _eps) return;
      journals.add(
        FinanceJournalEntry(
          id: id,
          date: date,
          sourceType: sourceType,
          sourceId: sourceId,
          narration: narration,
          lines: [
            FinanceJournalLine(
              accountCode: debit,
              debit: amount,
              credit: 0,
              memo: memo,
            ),
            FinanceJournalLine(
              accountCode: credit,
              debit: 0,
              credit: amount,
              memo: memo,
            ),
          ],
        ),
      );
    }

    for (final box in cashboxes) {
      post(
        id: 'J-opening-${box.id}',
        date: DateTime(1970, 1, 1),
        sourceType: 'opening',
        sourceId: box.id,
        narration: 'Opening cash — ${box.name}',
        debit: FinanceCoa.cash,
        credit: FinanceCoa.openingSurplus,
        amount: box.openingBalance,
      );
    }

    for (final invoice in invoices) {
      post(
        id: 'J-invoice-${invoice.id}',
        date: invoice.issuedAt,
        sourceType: 'invoice',
        sourceId: invoice.id,
        narration:
            'Fee invoice ${invoice.id} · ${invoice.studentName} · ${invoice.title}',
        debit: FinanceCoa.feesReceivable,
        credit: FinanceCoa.tuitionIncome,
        amount: invoice.amount,
      );
    }

    for (final payment in payments) {
      post(
        id: 'J-payment-${payment.id}',
        date: payment.paidAt,
        sourceType: 'payment',
        sourceId: payment.id,
        narration:
            'Fee receipt ${payment.receiptNo} · ${payment.studentName}',
        debit: cashAccount(payment.method),
        credit: FinanceCoa.feesReceivable,
        amount: payment.amount,
        memo: payment.reference,
      );
    }

    for (final bill in payables) {
      post(
        id: 'J-payable-${bill.id}',
        date: bill.issuedAt,
        sourceType: 'payable',
        sourceId: bill.id,
        narration: 'Supplier bill ${bill.supplier} · ${bill.department}',
        debit: FinanceCoa.expenseForDepartment(bill.department),
        credit: FinanceCoa.accountsPayable,
        amount: bill.amount,
        memo: bill.invoiceRef,
      );
      post(
        id: 'J-payable-pay-${bill.id}',
        date: bill.lastPaidAt ?? bill.dueDate,
        sourceType: 'payable_pay',
        sourceId: bill.id,
        narration: 'Supplier payment ${bill.supplier}',
        debit: FinanceCoa.accountsPayable,
        credit: cashAccount(bill.paymentMethod),
        amount: bill.paidAmount,
        memo: bill.invoiceRef,
      );
    }

    for (final expense in expenses) {
      if (expense.status == FinanceExpenseStatus.rejected ||
          expense.status == FinanceExpenseStatus.requested) {
        continue;
      }
      final dept = FinanceExpenseCategories.departmentFor(expense.category);
      post(
        id: 'J-expense-${expense.id}',
        date: expense.date,
        sourceType: 'expense_accrue',
        sourceId: expense.id,
        narration: 'Expense accrued · ${expense.category}',
        debit: FinanceCoa.expenseForDepartment(dept),
        credit: FinanceCoa.accruedExpenses,
        amount: expense.amount,
        memo: expense.purpose,
      );
      if (expense.status == FinanceExpenseStatus.paid) {
        post(
          id: 'J-expense-pay-${expense.id}',
          date: expense.paidAt ?? expense.date,
          sourceType: 'expense_pay',
          sourceId: expense.id,
          narration: 'Expense paid · ${expense.category}',
          debit: FinanceCoa.accruedExpenses,
          credit: cashAccount(expense.paymentMethod),
          amount: expense.amount,
          memo: expense.reference,
        );
      }
    }

    final linkedRefs = <String>{
      for (final payment in payments) payment.id,
      for (final expense in expenses) expense.id,
      for (final bill in payables) bill.id,
      for (final row in disbursements) row.id,
    };

    for (final move in cashMoves) {
      final ref = (move.reference ?? '').trim();
      if (ref.isNotEmpty && linkedRefs.contains(ref)) continue;
      switch (move.kind) {
        case FinanceCashKind.receipt:
          post(
            id: 'J-cash-${move.id}',
            date: move.at,
            sourceType: 'cash_receipt',
            sourceId: move.id,
            narration: move.note ?? 'Cash receipt',
            debit: FinanceCoa.cash,
            credit: FinanceCoa.otherIncome,
            amount: move.amount,
          );
        case FinanceCashKind.payment:
          post(
            id: 'J-cash-${move.id}',
            date: move.at,
            sourceType: 'cash_payment',
            sourceId: move.id,
            narration: move.note ?? 'Cash payment',
            debit: FinanceCoa.otherExpense,
            credit: FinanceCoa.cash,
            amount: move.amount,
          );
        case FinanceCashKind.refund:
          post(
            id: 'J-cash-${move.id}',
            date: move.at,
            sourceType: 'cash_refund',
            sourceId: move.id,
            narration: move.note ?? 'Fee refund',
            debit: FinanceCoa.tuitionIncome,
            credit: FinanceCoa.cash,
            amount: move.amount,
          );
        case FinanceCashKind.transferOut:
          post(
            id: 'J-cash-${move.id}',
            date: move.at,
            sourceType: 'cash_transfer',
            sourceId: move.id,
            narration: move.note ?? 'Transfer to bank',
            debit: FinanceCoa.bank,
            credit: FinanceCoa.cash,
            amount: move.amount,
          );
        case FinanceCashKind.transferIn:
          post(
            id: 'J-cash-${move.id}',
            date: move.at,
            sourceType: 'cash_transfer',
            sourceId: move.id,
            narration: move.note ?? 'Transfer from bank',
            debit: FinanceCoa.cash,
            credit: FinanceCoa.bank,
            amount: move.amount,
          );
      }
    }

    journals.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });

    return FinanceLedger._(schoolId: schoolId, journals: journals);
  }

  bool get journalsBalanced => journals.every((j) => j.isBalanced);

  List<FinanceJournalEntry> journalsAsOf(DateTime asOf, {DateTime? from}) {
    return [
      for (final journal in journals)
        if (!journal.date.isAfter(asOf) &&
            (from == null || !journal.date.isBefore(from)))
          journal,
    ];
  }

  List<FinanceAccountBalance> _balances(
    DateTime asOf, {
    DateTime? from,
    bool includeOpening = true,
  }) {
    final debit = <String, double>{};
    final credit = <String, double>{};
    for (final journal in journalsAsOf(asOf, from: from)) {
      if (!includeOpening && journal.sourceType == 'opening') continue;
      for (final line in journal.lines) {
        debit[line.accountCode] = (debit[line.accountCode] ?? 0) + line.debit;
        credit[line.accountCode] =
            (credit[line.accountCode] ?? 0) + line.credit;
      }
    }
    return [
      for (final account in FinanceCoa.chart)
        FinanceAccountBalance(
          account: account,
          debit: debit[account.code] ?? 0,
          credit: credit[account.code] ?? 0,
        ),
    ];
  }

  FinanceAccountBalance balanceFor(String code, DateTime asOf) {
    return _balances(asOf).firstWhere((row) => row.account.code == code);
  }

  FinanceTrialBalance trialBalance({required DateTime asOf}) {
    return FinanceTrialBalance(
      rows: _balances(asOf).where((row) => !row.isZero).toList(),
      asOf: asOf,
    );
  }

  FinanceIncomeStatement incomeAndExpenditure({
    DateTime? from,
    required DateTime to,
  }) {
    final rows = _balances(to, from: from, includeOpening: false);
    return FinanceIncomeStatement(
      income: [
        for (final row in rows)
          if (row.account.type == FinanceAccountType.income && !row.isZero)
            FinanceStatementLine(
              account: row.account,
              amount: row.statementAmount,
            ),
      ],
      expenses: [
        for (final row in rows)
          if (row.account.type == FinanceAccountType.expense && !row.isZero)
            FinanceStatementLine(
              account: row.account,
              amount: row.statementAmount,
            ),
      ],
      from: from,
      to: to,
    );
  }

  FinanceBalanceSheet balanceSheet({required DateTime asOf}) {
    final rows = _balances(asOf);
    final surplus = incomeAndExpenditure(to: asOf).surplus;
    final assets = [
      for (final row in rows)
        if (row.account.type == FinanceAccountType.asset && !row.isZero)
          FinanceStatementLine(
            account: row.account,
            amount: row.statementAmount,
          ),
    ];
    final liabilities = [
      for (final row in rows)
        if (row.account.type == FinanceAccountType.liability && !row.isZero)
          FinanceStatementLine(
            account: row.account,
            amount: row.statementAmount,
          ),
    ];
    final equity = [
      for (final row in rows)
        if (row.account.type == FinanceAccountType.equity && !row.isZero)
          FinanceStatementLine(
            account: row.account,
            amount: row.statementAmount,
          ),
      if (surplus.abs() >= _eps)
        FinanceStatementLine(
          account: const FinanceAccount(
            code: '3100',
            name: 'Surplus / (deficit) for the period',
            type: FinanceAccountType.equity,
          ),
          amount: surplus,
        ),
    ];
    return FinanceBalanceSheet(
      assets: assets,
      liabilities: liabilities,
      equity: equity,
      asOf: asOf,
    );
  }

  FinanceCashFlowStatement cashFlow({
    DateTime? from,
    required DateTime to,
  }) {
    double cashDelta(FinanceJournalEntry journal) {
      var delta = 0.0;
      for (final line in journal.lines) {
        if (line.accountCode != FinanceCoa.cash &&
            line.accountCode != FinanceCoa.bank) {
          continue;
        }
        delta += line.debit - line.credit;
      }
      return delta;
    }

    final opening = from == null
        ? cashboxesOpening(to)
        : cashAndBankAsOf(from.subtract(const Duration(milliseconds: 1)));

    var feeIn = 0.0;
    var otherIn = 0.0;
    var supplierOut = 0.0;
    var expenseOut = 0.0;
    var refundOut = 0.0;
    var otherOut = 0.0;

    for (final journal in journalsAsOf(to, from: from)) {
      if (journal.sourceType == 'opening' ||
          journal.sourceType == 'cash_transfer' ||
          journal.sourceType == 'invoice' ||
          journal.sourceType == 'payable' ||
          journal.sourceType == 'expense_accrue') {
        continue;
      }
      final delta = cashDelta(journal);
      switch (journal.sourceType) {
        case 'payment':
          if (delta > 0) feeIn += delta;
        case 'cash_receipt':
          if (delta > 0) otherIn += delta;
        case 'payable_pay':
          if (delta < 0) supplierOut += -delta;
        case 'expense_pay':
          if (delta < 0) expenseOut += -delta;
        case 'cash_refund':
          if (delta < 0) refundOut += -delta;
        case 'cash_payment':
          if (delta < 0) otherOut += -delta;
        default:
          if (delta > 0) {
            otherIn += delta;
          } else if (delta < 0) {
            otherOut += -delta;
          }
      }
    }

    List<FinanceCashFlowLine> positives(Map<String, double> map) => [
          for (final entry in map.entries)
            if (entry.value >= _eps)
              FinanceCashFlowLine(label: entry.key, amount: entry.value),
        ];

    return FinanceCashFlowStatement(
      operatingIn: positives({
        'Student fee collections': feeIn,
        'Other cash receipts': otherIn,
      }),
      operatingOut: positives({
        'Supplier payments': supplierOut,
        'Operating expenses paid': expenseOut,
        'Fee refunds': refundOut,
        'Other cash payments': otherOut,
      }),
      investing: const [],
      financing: const [],
      openingCash: opening,
      from: from,
      to: to,
    );
  }

  double cashboxesOpening(DateTime asOf) {
    var total = 0.0;
    for (final journal in journalsAsOf(asOf)) {
      if (journal.sourceType != 'opening') continue;
      for (final line in journal.lines) {
        if (line.accountCode == FinanceCoa.cash ||
            line.accountCode == FinanceCoa.bank) {
          total += line.debit - line.credit;
        }
      }
    }
    return total;
  }

  double cashAndBankAsOf(DateTime asOf) {
    final cash = balanceFor(FinanceCoa.cash, asOf).statementAmount;
    final bank = balanceFor(FinanceCoa.bank, asOf).statementAmount;
    return cash + bank;
  }
}
