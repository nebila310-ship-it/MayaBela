import 'package:flutter/material.dart';

import 'package:mayabela/models/finance_ledger_models.dart';
import 'package:mayabela/services/finance_ledger.dart';
import 'package:mayabela/services/finance_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

/// Accountant desk: chart of accounts, journals, and auto-built statements.
class WebFinanceStatementsPanel extends StatefulWidget {
  const WebFinanceStatementsPanel({super.key});

  @override
  State<WebFinanceStatementsPanel> createState() =>
      _WebFinanceStatementsPanelState();
}

class _WebFinanceStatementsPanelState extends State<WebFinanceStatementsPanel> {
  FinanceReportPeriod _period = FinanceReportPeriod.all;
  int _view = 0;

  static const _views = [
    (0, 'Trial balance', Icons.balance_outlined, Color(0xFF1D4ED8)),
    (1, 'Income & expenditure', Icons.trending_up_rounded, Color(0xFF0F766E)),
    (2, 'Balance sheet', Icons.account_balance_outlined, Color(0xFF7C3AED)),
    (3, 'Cash flow', Icons.water_drop_outlined, Color(0xFF2563EB)),
    (4, 'Journals', Icons.menu_book_outlined, Color(0xFFB45309)),
    (5, 'Chart of accounts', Icons.account_tree_outlined, Color(0xFFDB2777)),
  ];

  FinanceLedger get _ledger => FinanceService.instance.ledger();

  DateTime get _asOf => _period.asOf;
  DateTime? get _from => _period.from;

  String _etb(double value) {
    final sign = value < 0 ? '-' : '';
    return '$sign${value.abs().toStringAsFixed(2)} ETB';
  }

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Color _typeColor(FinanceAccountType type) => switch (type) {
        FinanceAccountType.asset => const Color(0xFF2563EB),
        FinanceAccountType.liability => const Color(0xFFB45309),
        FinanceAccountType.equity => const Color(0xFF7C3AED),
        FinanceAccountType.income => const Color(0xFF0F766E),
        FinanceAccountType.expense => const Color(0xFFDB2777),
      };

  @override
  Widget build(BuildContext context) {
    final ledger = _ledger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ledger & statements', style: WebErpTheme.sectionTitle(context)),
        const SizedBox(height: 6),
        Text(
          'Every fee invoice, receipt, expense, supplier bill, and cash movement '
          'posts a balanced journal — the same way Sage 50 / Peachtree builds '
          'the trial balance, income & expenditure, statement of financial '
          'position, and cash flow. Payroll stays in Human Resource.',
          style: TextStyle(color: Colors.grey.shade700, height: 1.4),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final period in FinanceReportPeriod.values)
              ChoiceChip(
                selected: _period == period,
                label: Text(period.label),
                onSelected: (_) => setState(() => _period = period),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in _views)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: _view == item.$1,
                    avatar: Icon(item.$3, size: 16, color: item.$4),
                    label: Text(item.$2),
                    selectedColor: item.$4.withValues(alpha: 0.16),
                    onSelected: (_) => setState(() => _view = item.$1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!ledger.journalsBalanced)
          _banner(
            const Color(0xFFDC2626),
            'Journals are out of balance. Do not issue statements until every '
            'entry has equal debits and credits.',
          ),
        if (ledger.journalsBalanced)
          _banner(
            const Color(0xFF15803D),
            '${ledger.journals.length} balanced journal(s) · '
            'period ${_from == null ? 'from opening' : _date(_from!)} '
            'to ${_date(_asOf)}.',
          ),
        const SizedBox(height: 12),
        switch (_view) {
          1 => _income(ledger),
          2 => _balance(ledger),
          3 => _cashFlow(ledger),
          4 => _journals(ledger),
          5 => _chart(),
          _ => _trial(ledger),
        },
      ],
    );
  }

  Widget _banner(Color color, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(text, style: TextStyle(color: color.withValues(alpha: 0.95))),
    );
  }

  Widget _paper({
    required Color color,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, Color.lerp(color, Colors.black, 0.18)!],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String left, String right, {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(left, style: style)),
          Text(right, style: style),
        ],
      ),
    );
  }

  Widget _trial(FinanceLedger ledger) {
    final tb = ledger.trialBalance(asOf: _asOf);
    return _paper(
      color: const Color(0xFF1D4ED8),
      title: 'Trial balance',
      subtitle:
          'As of ${_date(tb.asOf)} · ${tb.isBalanced ? 'Debits equal credits' : 'OUT OF BALANCE'}',
      children: [
        _row('Account', 'Debit / Credit', bold: true),
        const Divider(),
        for (final row in tb.rows)
          _row(
            '${row.account.code}  ${row.account.name}',
            row.net >= 0 ? _etb(row.net) : '(${_etb(-row.net)}) Cr',
            color: _typeColor(row.account.type),
          ),
        const Divider(),
        _row('Total debit', _etb(tb.totalDebit), bold: true),
        _row('Total credit', _etb(tb.totalCredit), bold: true),
        if (tb.rows.isEmpty)
          Text(
            'No posted activity yet. Generate invoices or record cash to open the books.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
      ],
    );
  }

  Widget _income(FinanceLedger ledger) {
    final ie = ledger.incomeAndExpenditure(from: _from, to: _asOf);
    return _paper(
      color: const Color(0xFF0F766E),
      title: 'Income and expenditure',
      subtitle:
          '${_from == null ? 'From opening' : _date(_from!)} to ${_date(ie.to)} · '
          'school operating statement (not a commercial P&L)',
      children: [
        _row('Income', '', bold: true, color: const Color(0xFF0F766E)),
        if (ie.income.isEmpty) _row('No income in this period', _etb(0)),
        for (final line in ie.income)
          _row('${line.account.code}  ${line.account.name}', _etb(line.amount)),
        _row('Total income', _etb(ie.totalIncome), bold: true),
        const Divider(),
        _row('Expenditure', '', bold: true, color: const Color(0xFFDB2777)),
        if (ie.expenses.isEmpty) _row('No expenditure in this period', _etb(0)),
        for (final line in ie.expenses)
          _row('${line.account.code}  ${line.account.name}', _etb(line.amount)),
        _row('Total expenditure', _etb(ie.totalExpenses), bold: true),
        const Divider(),
        _row(
          ie.surplus >= 0 ? 'Surplus for the period' : 'Deficit for the period',
          _etb(ie.surplus),
          bold: true,
          color: ie.surplus >= 0
              ? const Color(0xFF15803D)
              : const Color(0xFFDC2626),
        ),
      ],
    );
  }

  Widget _balance(FinanceLedger ledger) {
    final bs = ledger.balanceSheet(asOf: _asOf);
    return _paper(
      color: const Color(0xFF7C3AED),
      title: 'Statement of financial position',
      subtitle:
          'As of ${_date(bs.asOf)} · Assets = liabilities + equity'
          '${bs.isBalanced ? '' : ' · OUT OF BALANCE'}',
      children: [
        _row('Assets', '', bold: true, color: const Color(0xFF2563EB)),
        if (bs.assets.isEmpty) _row('No asset balances', _etb(0)),
        for (final line in bs.assets)
          _row('${line.account.code}  ${line.account.name}', _etb(line.amount)),
        _row('Total assets', _etb(bs.totalAssets), bold: true),
        const Divider(),
        _row('Liabilities', '', bold: true, color: const Color(0xFFB45309)),
        if (bs.liabilities.isEmpty) _row('No liabilities', _etb(0)),
        for (final line in bs.liabilities)
          _row('${line.account.code}  ${line.account.name}', _etb(line.amount)),
        _row('Total liabilities', _etb(bs.totalLiabilities), bold: true),
        const Divider(),
        _row('Equity / accumulated surplus', '', bold: true, color: const Color(0xFF7C3AED)),
        if (bs.equity.isEmpty) _row('No equity balances', _etb(0)),
        for (final line in bs.equity)
          _row('${line.account.code}  ${line.account.name}', _etb(line.amount)),
        _row('Total equity', _etb(bs.totalEquity), bold: true),
        const Divider(),
        _row(
          'Liabilities + equity',
          _etb(bs.totalLiabilities + bs.totalEquity),
          bold: true,
        ),
        _row(
          bs.isBalanced ? 'Books balance' : 'Books do not balance',
          bs.isBalanced ? 'Yes' : 'Check journals',
          bold: true,
          color: bs.isBalanced
              ? const Color(0xFF15803D)
              : const Color(0xFFDC2626),
        ),
      ],
    );
  }

  Widget _cashFlow(FinanceLedger ledger) {
    final cf = ledger.cashFlow(from: _from, to: _asOf);
    return _paper(
      color: const Color(0xFF2563EB),
      title: 'Statement of cash flows',
      subtitle:
          'Direct method · cash and bank · ${_from == null ? 'from opening' : _date(_from!)} '
          'to ${_date(cf.to)}',
      children: [
        _row('Opening cash and bank', _etb(cf.openingCash), bold: true),
        const Divider(),
        _row('Operating activities', '', bold: true, color: const Color(0xFF0F766E)),
        if (cf.operatingIn.isEmpty && cf.operatingOut.isEmpty)
          _row('No operating cash movement', _etb(0)),
        for (final line in cf.operatingIn)
          _row(line.label, _etb(line.amount)),
        for (final line in cf.operatingOut)
          _row(line.label, '(${_etb(line.amount)})'),
        _row('Net cash from operations', _etb(cf.netOperating), bold: true),
        const Divider(),
        _row('Investing activities', '', bold: true, color: const Color(0xFF7C3AED)),
        if (cf.investing.isEmpty)
          _row('No investing cash flows this period', _etb(0)),
        for (final line in cf.investing)
          _row(line.label, _etb(line.amount)),
        const Divider(),
        _row('Financing activities', '', bold: true, color: const Color(0xFFB45309)),
        if (cf.financing.isEmpty)
          _row('No financing cash flows this period', _etb(0)),
        for (final line in cf.financing)
          _row(line.label, _etb(line.amount)),
        const Divider(),
        _row('Net change in cash and bank', _etb(cf.netChange), bold: true),
        _row(
          'Closing cash and bank',
          _etb(cf.closingCash),
          bold: true,
          color: const Color(0xFF1D4ED8),
        ),
        const SizedBox(height: 8),
        Text(
          'Closing cash should match Cash on hand + Bank on the balance sheet. '
          'Transfers between cashbox and bank are not cash flows.',
          style: TextStyle(color: Colors.grey.shade600, height: 1.35),
        ),
      ],
    );
  }

  Widget _journals(FinanceLedger ledger) {
    final rows = ledger.journalsAsOf(_asOf, from: _from);
    return _paper(
      color: const Color(0xFFB45309),
      title: 'General journal',
      subtitle: '${rows.length} posting(s) in the selected period',
      children: [
        if (rows.isEmpty)
          Text(
            'No journals in this period.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        for (final journal in rows.take(80)) ...[
          _row(
            '${_date(journal.date)}  ${journal.narration}',
            journal.isBalanced ? 'Balanced' : 'Unbalanced',
            bold: true,
            color: journal.isBalanced
                ? const Color(0xFF9A3412)
                : const Color(0xFFDC2626),
          ),
          for (final line in journal.lines)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.debit > 0 ? 'Dr' : 'Cr'}  '
                      '${line.accountCode}  ${line.account.name}',
                    ),
                  ),
                  Text(
                    _etb(line.debit > 0 ? line.debit : line.credit),
                    style: TextStyle(
                      color: line.debit > 0
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF0F766E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
        ],
        if (rows.length > 80)
          Text(
            'Showing the first 80 journals. Narrow the period to review older books.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
      ],
    );
  }

  Widget _chart() {
    return _paper(
      color: const Color(0xFFDB2777),
      title: 'Chart of accounts',
      subtitle:
          'School nominal codes. Debit-normal: assets and expenses. '
          'Credit-normal: liabilities, equity, and income.',
      children: [
        for (final account in FinanceCoa.chart)
          _row(
            '${account.code}  ${account.name}',
            '${account.type.label} · ${account.debitNormal ? 'Dr' : 'Cr'}',
            color: _typeColor(account.type),
          ),
        const Divider(),
        Text(
          'Invoice → Dr 1100 Cr 4000. Receipt → Dr 1000/1010 Cr 1100. '
          'Supplier bill → Dr department expense Cr 2000. '
          'Approved expense → Dr department expense Cr 2100, then Dr 2100 Cr cash/bank when paid. '
          'Opening cashbox → Dr 1000 Cr 3000.',
          style: TextStyle(color: Colors.grey.shade700, height: 1.4),
        ),
      ],
    );
  }
}
