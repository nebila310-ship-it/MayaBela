/// Peachtree / Sage 50-style school chart of accounts and statement rows.
/// Assets and expenses are debit-normal; liabilities, equity, and income
/// are credit-normal.
enum FinanceAccountType { asset, liability, equity, income, expense }

extension FinanceAccountTypeX on FinanceAccountType {
  String get label => switch (this) {
        FinanceAccountType.asset => 'Asset',
        FinanceAccountType.liability => 'Liability',
        FinanceAccountType.equity => 'Equity',
        FinanceAccountType.income => 'Income',
        FinanceAccountType.expense => 'Expense',
      };

  bool get debitNormal =>
      this == FinanceAccountType.asset || this == FinanceAccountType.expense;
}

class FinanceAccount {
  const FinanceAccount({
    required this.code,
    required this.name,
    required this.type,
  });

  final String code;
  final String name;
  final FinanceAccountType type;

  bool get debitNormal => type.debitNormal;
}

/// Standard school nominal codes. Payroll stays in HR, so there is no
/// salary / PAYE control account here.
class FinanceCoa {
  FinanceCoa._();

  static const cash = '1000';
  static const bank = '1010';
  static const feesReceivable = '1100';
  static const accountsPayable = '2000';
  static const accruedExpenses = '2100';
  static const openingSurplus = '3000';
  static const tuitionIncome = '4000';
  static const otherIncome = '4100';
  static const academics = '5100';
  static const transport = '5200';
  static const administration = '5300';
  static const marketing = '5400';
  static const facilities = '5500';
  static const otherExpense = '5900';

  static const chart = <FinanceAccount>[
    FinanceAccount(
      code: cash,
      name: 'Cash on hand',
      type: FinanceAccountType.asset,
    ),
    FinanceAccount(
      code: bank,
      name: 'Bank and transfers',
      type: FinanceAccountType.asset,
    ),
    FinanceAccount(
      code: feesReceivable,
      name: 'Fees receivable',
      type: FinanceAccountType.asset,
    ),
    FinanceAccount(
      code: accountsPayable,
      name: 'Accounts payable — suppliers',
      type: FinanceAccountType.liability,
    ),
    FinanceAccount(
      code: accruedExpenses,
      name: 'Accrued operating expenses',
      type: FinanceAccountType.liability,
    ),
    FinanceAccount(
      code: openingSurplus,
      name: 'Opening / retained surplus',
      type: FinanceAccountType.equity,
    ),
    FinanceAccount(
      code: tuitionIncome,
      name: 'Tuition and fee income',
      type: FinanceAccountType.income,
    ),
    FinanceAccount(
      code: otherIncome,
      name: 'Other income',
      type: FinanceAccountType.income,
    ),
    FinanceAccount(
      code: academics,
      name: 'Academic expenses',
      type: FinanceAccountType.expense,
    ),
    FinanceAccount(
      code: transport,
      name: 'Transport expenses',
      type: FinanceAccountType.expense,
    ),
    FinanceAccount(
      code: administration,
      name: 'Administration expenses',
      type: FinanceAccountType.expense,
    ),
    FinanceAccount(
      code: marketing,
      name: 'Marketing expenses',
      type: FinanceAccountType.expense,
    ),
    FinanceAccount(
      code: facilities,
      name: 'Facilities expenses',
      type: FinanceAccountType.expense,
    ),
    FinanceAccount(
      code: otherExpense,
      name: 'Other operating expenses',
      type: FinanceAccountType.expense,
    ),
  ];

  static FinanceAccount byCode(String code) {
    return chart.firstWhere(
      (a) => a.code == code,
      orElse: () => FinanceAccount(
        code: code,
        name: 'Unmapped $code',
        type: FinanceAccountType.expense,
      ),
    );
  }

  static String expenseForDepartment(String department) {
    return switch (department.trim()) {
      'Academics' => academics,
      'Transport' => transport,
      'Administration' => administration,
      'Marketing' => marketing,
      'Facilities' => facilities,
      _ => otherExpense,
    };
  }
}

class FinanceJournalLine {
  const FinanceJournalLine({
    required this.accountCode,
    required this.debit,
    required this.credit,
    this.memo,
  });

  final String accountCode;
  final double debit;
  final double credit;
  final String? memo;

  FinanceAccount get account => FinanceCoa.byCode(accountCode);
}

class FinanceJournalEntry {
  const FinanceJournalEntry({
    required this.id,
    required this.date,
    required this.sourceType,
    required this.sourceId,
    required this.narration,
    required this.lines,
  });

  final String id;
  final DateTime date;
  final String sourceType;
  final String sourceId;
  final String narration;
  final List<FinanceJournalLine> lines;

  double get debitTotal =>
      lines.fold<double>(0, (sum, line) => sum + line.debit);
  double get creditTotal =>
      lines.fold<double>(0, (sum, line) => sum + line.credit);
  bool get isBalanced => (debitTotal - creditTotal).abs() < 0.02;
}

class FinanceAccountBalance {
  const FinanceAccountBalance({
    required this.account,
    required this.debit,
    required this.credit,
  });

  final FinanceAccount account;
  final double debit;
  final double credit;

  double get net => debit - credit;
  double get statementAmount =>
      account.debitNormal ? net : -net;
  bool get isZero => debit.abs() < 0.02 && credit.abs() < 0.02;
}

class FinanceTrialBalance {
  const FinanceTrialBalance({
    required this.rows,
    required this.asOf,
  });

  final List<FinanceAccountBalance> rows;
  final DateTime asOf;

  double get totalDebit =>
      rows.fold<double>(0, (sum, row) => sum + (row.net > 0 ? row.net : 0));
  double get totalCredit =>
      rows.fold<double>(0, (sum, row) => sum + (row.net < 0 ? -row.net : 0));
  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.02;
}

class FinanceStatementLine {
  const FinanceStatementLine({
    required this.account,
    required this.amount,
  });

  final FinanceAccount account;
  final double amount;
}

class FinanceIncomeStatement {
  const FinanceIncomeStatement({
    required this.income,
    required this.expenses,
    required this.from,
    required this.to,
  });

  final List<FinanceStatementLine> income;
  final List<FinanceStatementLine> expenses;
  final DateTime? from;
  final DateTime to;

  double get totalIncome =>
      income.fold<double>(0, (sum, line) => sum + line.amount);
  double get totalExpenses =>
      expenses.fold<double>(0, (sum, line) => sum + line.amount);
  double get surplus => totalIncome - totalExpenses;
}

class FinanceBalanceSheet {
  const FinanceBalanceSheet({
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.asOf,
  });

  final List<FinanceStatementLine> assets;
  final List<FinanceStatementLine> liabilities;
  final List<FinanceStatementLine> equity;
  final DateTime asOf;

  double get totalAssets =>
      assets.fold<double>(0, (sum, line) => sum + line.amount);
  double get totalLiabilities =>
      liabilities.fold<double>(0, (sum, line) => sum + line.amount);
  double get totalEquity =>
      equity.fold<double>(0, (sum, line) => sum + line.amount);
  bool get isBalanced =>
      (totalAssets - (totalLiabilities + totalEquity)).abs() < 0.02;
}

class FinanceCashFlowLine {
  const FinanceCashFlowLine({
    required this.label,
    required this.amount,
  });

  final String label;
  final double amount;
}

class FinanceCashFlowStatement {
  const FinanceCashFlowStatement({
    required this.operatingIn,
    required this.operatingOut,
    required this.investing,
    required this.financing,
    required this.openingCash,
    required this.from,
    required this.to,
  });

  final List<FinanceCashFlowLine> operatingIn;
  final List<FinanceCashFlowLine> operatingOut;
  final List<FinanceCashFlowLine> investing;
  final List<FinanceCashFlowLine> financing;
  final double openingCash;
  final DateTime? from;
  final DateTime to;

  double get netOperating =>
      _sum(operatingIn) - _sum(operatingOut);
  double get netInvesting => _sum(investing);
  double get netFinancing => _sum(financing);
  double get netChange => netOperating + netInvesting + netFinancing;
  double get closingCash => openingCash + netChange;

  static double _sum(List<FinanceCashFlowLine> rows) =>
      rows.fold<double>(0, (sum, line) => sum + line.amount);
}

enum FinanceReportPeriod { all, month, year }

extension FinanceReportPeriodX on FinanceReportPeriod {
  String get label => switch (this) {
        FinanceReportPeriod.all => 'All activity',
        FinanceReportPeriod.month => 'This month',
        FinanceReportPeriod.year => 'This calendar year',
      };

  DateTime get asOf {
    final now = DateTime.now();
    return switch (this) {
      FinanceReportPeriod.all => DateTime(9999, 12, 31, 23, 59, 59),
      FinanceReportPeriod.month => DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      FinanceReportPeriod.year => DateTime(now.year, 12, 31, 23, 59, 59),
    };
  }

  DateTime? get from {
    final now = DateTime.now();
    return switch (this) {
      FinanceReportPeriod.all => null,
      FinanceReportPeriod.month => DateTime(now.year, now.month, 1),
      FinanceReportPeriod.year => DateTime(now.year, 1, 1),
    };
  }
}
