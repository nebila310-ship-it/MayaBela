import 'package:flutter/material.dart';

import 'package:mayabela/models/finance_models.dart';
import 'package:mayabela/screens/finance_coming_soon_screen.dart';
import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/services/finance_service.dart';
import 'package:mayabela/services/persistence/finance_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/web_erp/pages/web_finance_statements_panel.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// Fillable, report-oriented Finance desk. Payroll stays in HR.
class WebFinanceHubPage extends StatefulWidget {
  const WebFinanceHubPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebFinanceHubPage> createState() => _WebFinanceHubPageState();
}

class _WebFinanceHubPageState extends State<WebFinanceHubPage> {
  int _section = 0;
  String _year = '2025/2026';

  static const _nav = [
    (0, 'Control', Icons.dashboard_customize_outlined, Color(0xFFEA580C)),
    (1, 'Fee plans', Icons.tune_rounded, Color(0xFF7C3AED)),
    (2, 'Invoices', Icons.receipt_long_outlined, Color(0xFF0F766E)),
    (3, 'Cash', Icons.point_of_sale_rounded, Color(0xFF2563EB)),
    (4, 'Expenses', Icons.payments_outlined, Color(0xFFDB2777)),
    (5, 'Budgets', Icons.pie_chart_outline, Color(0xFF0891B2)),
    (6, 'Payables', Icons.storefront_outlined, Color(0xFFB45309)),
    (7, 'Reports', Icons.insights_outlined, Color(0xFF15803D)),
    (8, 'Statements', Icons.account_balance_outlined, Color(0xFF1D4ED8)),
  ];

  bool get _canManage => ModuleAccess.canManage('finance');

  @override
  void initState() {
    super.initState();
    FinancePersistenceService.instance.loadIntoService().then((_) {
      if (!mounted) return;
      FinanceService.instance.ensureDefaults();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FinanceService.instance,
      builder: (context, _) {
        final narrow = WebViewport.isNarrow(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(narrow),
            _sectionChips(narrow),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: WebViewport.pagePadding(context),
                child: _body(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _hero(bool narrow) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(narrow ? 14 : 20, 16, narrow ? 14 : 20, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: FinancePalette.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finance',
            style: WebErpTheme.sectionTitle(context).copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Record fees, cash, expenses, and supplier bills. The ledger posts '
            'every tile into trial balance, income & expenditure, balance sheet, '
            'and cash flow. Payroll stays in Human Resource.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionChips(bool narrow) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          for (final item in _nav) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: _section == item.$1,
                avatar: Icon(item.$3, size: 16, color: item.$4),
                label: Text(item.$2),
                selectedColor: item.$4.withValues(alpha: 0.16),
                onSelected: (_) => setState(() => _section = item.$1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _body() {
    return switch (_section) {
      1 => _feePlans(),
      2 => _invoices(),
      3 => _cash(),
      4 => _expenses(),
      5 => _budgets(),
      6 => _payables(),
      7 => _reports(),
      8 => const WebFinanceStatementsPanel(),
      _ => _control(),
    };
  }

  Widget _control() {
    final totals = FinanceService.instance.controlTotals();
    final ledger = FinanceService.instance.ledger();
    final asOf = DateTime.now();
    final surplus = ledger.incomeAndExpenditure(to: asOf).surplus;
    final books = ledger.balanceSheet(asOf: asOf);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _stat('Fees billed', totals.billed, const Color(0xFF7C3AED)),
            _stat('Cash collected', totals.collected, const Color(0xFF0F766E)),
            _stat('Outstanding', totals.outstanding, const Color(0xFFEA580C)),
            _stat('Cash on hand', totals.cashOnHand, const Color(0xFF2563EB)),
            _stat('Expenses paid', totals.expensesPaid, const Color(0xFFDB2777)),
            _stat(
              'Net cash movement',
              totals.netCashMovement,
              const Color(0xFF15803D),
            ),
            _stat(
              'Supplier payables',
              totals.payablesOutstanding,
              const Color(0xFFB45309),
            ),
            _stat(
              'Budget used',
              totals.budgetActual,
              const Color(0xFF0891B2),
            ),
            _stat(
              surplus >= 0 ? 'Ledger surplus' : 'Ledger deficit',
              surplus,
              surplus >= 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626),
            ),
            _stat(
              'Balance sheet assets',
              books.totalAssets,
              const Color(0xFF7C3AED),
            ),
            _stat(
              'Budget disbursed',
              totals.budgetDisbursed,
              const Color(0xFF0F766E),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _card(
          color: const Color(0xFF7C3AED),
          icon: Icons.account_balance_outlined,
          title: 'Automatic financial statements',
          body:
              'The same invoices, receipts, expenses, and payables build a '
              'Sage 50-style trial balance, income & expenditure, balance sheet, '
              'and cash flow. No second set of numbers.',
          action: 'Open statements',
          onTap: () => setState(() => _section = 8),
        ),
        const SizedBox(height: 12),
        _card(
          color: const Color(0xFF1D4ED8),
          icon: Icons.groups_outlined,
          title: 'Payroll stays in HR',
          body: FinanceService.payrollStaysInHr,
          action: 'Open HR Payroll',
          onTap: () => widget.onNavigate?.call('payroll'),
        ),
        const SizedBox(height: 12),
        _card(
          color: const Color(0xFF0F766E),
          icon: Icons.inventory_2_outlined,
          title: 'Procurement & store',
          body:
              'Purchase orders and goods received stay in Inventory. Finance records the supplier payment after goods arrive.',
          action: 'Open Inventory',
          onTap: () => widget.onNavigate?.call('inventory'),
        ),
        const SizedBox(height: 16),
        Text('Recent audit', style: WebErpTheme.sectionTitle(context)),
        const SizedBox(height: 8),
        ...FinanceService.instance.auditForSchool().take(8).map(
              (e) => ListTile(
                dense: true,
                leading: const Icon(Icons.history, color: FinancePalette.primary),
                title: Text(e.action.replaceAll('_', ' ')),
                subtitle: Text('${e.detail ?? ''} · ${e.actor}'),
              ),
            ),
      ],
    );
  }

  Widget _feePlans() {
    final rows = FinanceService.instance.structuresForSchool();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Fee plans by grade and student type',
                style: WebErpTheme.sectionTitle(context),
              ),
            ),
            if (_canManage)
              FilledButton.icon(
                onPressed: _addStructure,
                icon: const Icon(Icons.add),
                label: const Text('Add plan'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Regular and scholarship students can have different amounts. '
          'Installments split the annual fee. Late fees, due day, and a '
          'collections cashbox stay on the plan.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Text('No fee plans yet. Add one for each grade you bill.')
        else
          ...rows.map((s) {
            final box = s.collectionCashboxId == null
                ? null
                : FinanceService.instance.cashboxes
                    .cast<FinanceCashbox?>()
                    .firstWhere(
                      (c) => c!.id == s.collectionCashboxId,
                      orElse: () => null,
                    );
            return _tile(
              icon: Icons.tune_rounded,
              color: s.active
                  ? const Color(0xFF7C3AED)
                  : Colors.grey,
              title: '${s.title} · ${s.grade}',
              subtitle:
                  '${s.academicYear} · ${s.fundingType} · ${_etb(s.amount)}'
                  '${s.installmentCount > 1 ? ' · ${s.installmentCount} installments' : ''}'
                  '${s.dueDay == null ? '' : ' · due day ${s.dueDay}'}'
                  '${s.lateFeeAmount > 0 ? ' · late fee ${_etb(s.lateFeeAmount)}' : ''}'
                  '${box == null ? '' : ' · collect to ${box.name}'}'
                  '${s.active ? '' : ' · inactive'}'
                  '${s.notes == null ? '' : ' · ${s.notes}'}',
              trailing: !_canManage
                  ? null
                  : Wrap(
                      children: [
                        TextButton(
                          onPressed: () => _editStructure(s),
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          onPressed: () {
                            final n = FinanceService.instance.generateInvoices(
                              academicYear: s.academicYear,
                              grade: s.grade,
                              structureId: s.id,
                            );
                            _toast(
                              n == 0
                                  ? 'No new invoices for this plan.'
                                  : 'Created $n invoice(s) from ${s.title}.',
                            );
                          },
                          child: const Text('Generate'),
                        ),
                      ],
                    ),
            );
          }),
      ],
    );
  }

  Widget _invoices() {
    final rows = FinanceService.instance.invoicesForSchool();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Student invoices', style: WebErpTheme.sectionTitle(context)),
            SizedBox(
              width: 140,
              child: TextField(
                controller: TextEditingController(text: _year),
                decoration: const InputDecoration(
                  labelText: 'Academic year',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) => setState(() => _year = v.trim()),
              ),
            ),
            if (_canManage)
              FilledButton.icon(
                onPressed: () {
                  final n = FinanceService.instance.generateInvoices(
                    academicYear: _year,
                  );
                  _toast(
                    n == 0
                        ? 'No new invoices. Add a fee plan that matches student grades.'
                        : 'Created $n invoice(s).',
                  );
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate invoices'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Text('Generate invoices from fee plans to start collections.')
        else
          ...rows.map((inv) {
            return _tile(
              icon: Icons.receipt_long_outlined,
              color: _invoiceColor(inv.status),
              title: '${inv.studentName} · ${inv.title}',
              subtitle:
                  '${inv.studentId} · ${_etb(inv.outstanding)} of ${_etb(inv.amount)} due · ${inv.status.label}',
              trailing: inv.isPaid || !_canManage
                  ? null
                  : TextButton(
                      onPressed: () => _recordPayment(inv),
                      child: const Text('Record payment'),
                    ),
              onTap: () => _showStatement(inv.studentId),
            );
          }),
      ],
    );
  }

  Widget _cash() {
    final boxes = FinanceService.instance.cashboxesForSchool();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Cashboxes', style: WebErpTheme.sectionTitle(context)),
            ),
            if (_canManage)
              FilledButton.icon(
                onPressed: _addCashbox,
                icon: const Icon(Icons.add),
                label: const Text('Add cashbox'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Treasury, fee collections, and dedicated budget cashboxes. '
          'Pay expenses and supplier bills from a named box. '
          'Transfer between boxes or close the day by counting cash.',
        ),
        const SizedBox(height: 12),
        if (boxes.isEmpty) const Text('No cashboxes yet.') else
          ...boxes.map((box) {
            final expected = FinanceService.instance.expectedCash(box.id);
            final color = switch (box.purpose) {
              FinanceCashboxPurpose.budget => const Color(0xFF0891B2),
              FinanceCashboxPurpose.collections => const Color(0xFF0F766E),
              FinanceCashboxPurpose.general => const Color(0xFF2563EB),
            };
            return _tile(
              icon: box.purpose == FinanceCashboxPurpose.budget
                  ? Icons.savings_outlined
                  : Icons.point_of_sale_rounded,
              color: color,
              title: '${box.name} · ${_etb(expected)}',
              subtitle:
                  '${box.purpose.label}'
                  '${box.department == null ? '' : ' · ${box.department}'}'
                  '${box.cashierName == null ? '' : ' · ${box.cashierName}'}'
                  '${box.location == null ? '' : ' · ${box.location}'}',
              onTap: () => _showCashboxLedger(box),
              trailing: !_canManage
                  ? null
                  : Wrap(
                      children: [
                        TextButton(
                          onPressed: () => _cashMove(box),
                          child: const Text('Move'),
                        ),
                        TextButton(
                          onPressed: () => _transferCash(box),
                          child: const Text('Transfer'),
                        ),
                        TextButton(
                          onPressed: () => _closeCash(box, expected),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
            );
          }),
      ],
    );
  }

  Widget _expenses() {
    final rows = FinanceService.instance.expensesForSchool();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Operating expenses',
                style: WebErpTheme.sectionTitle(context),
              ),
            ),
            if (_canManage)
              FilledButton.icon(
                onPressed: _addExpense,
                icon: const Icon(Icons.add),
                label: const Text('Request expense'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Request → approve → pay from a cashbox. Charge a department budget '
          'when the money should leave that budget cashbox. Salary stays in HR.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty) const Text('No expense requests yet.') else
          ...rows.map((e) {
            final box = e.cashboxId == null
                ? null
                : FinanceService.instance.cashboxes
                    .cast<FinanceCashbox?>()
                    .firstWhere(
                      (c) => c!.id == e.cashboxId,
                      orElse: () => null,
                    );
            return _tile(
              icon: Icons.payments_outlined,
              color: const Color(0xFFDB2777),
              title: '${e.category} · ${_etb(e.amount)}',
              subtitle:
                  '${e.status.label} · ${e.department ?? FinanceExpenseCategories.departmentFor(e.category)}'
                  '${e.voucherNo == null ? '' : ' · ${e.voucherNo}'}'
                  ' · ${e.supplier ?? e.purpose ?? e.requestedBy}'
                  '${box == null ? '' : ' · paid from ${box.name}'}',
              trailing: !_canManage
                  ? null
                  : Wrap(
                      children: [
                        if (e.status == FinanceExpenseStatus.requested) ...[
                          TextButton(
                            onPressed: () => _run(() {
                              FinanceService.instance.approveExpense(e.id);
                            }),
                            child: const Text('Approve'),
                          ),
                          TextButton(
                            onPressed: () => _run(() {
                              FinanceService.instance.rejectExpense(e.id);
                            }),
                            child: const Text('Reject'),
                          ),
                        ],
                        if (e.status == FinanceExpenseStatus.approved)
                          TextButton(
                            onPressed: () => _payExpense(e),
                            child: const Text('Pay from cashbox'),
                          ),
                      ],
                    ),
            );
          }),
      ],
    );
  }

  Widget _budgets() {
    final rows = FinanceService.instance.budgetUsage();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Department budgets',
                style: WebErpTheme.sectionTitle(context),
              ),
            ),
            if (_canManage)
              FilledButton.icon(
                onPressed: _addBudget,
                icon: const Icon(Icons.add),
                label: const Text('Add budget'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Allocate a ceiling, then disburse cash from treasury into a dedicated '
          'budget cashbox. Spending is paid from that box and cannot exceed the allocation.',
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Text('No budgets yet. Add one per department.')
        else
          ...rows.map((usage) {
            final color = usage.overrun
                ? const Color(0xFFDC2626)
                : const Color(0xFF0891B2);
            final box = usage.budget.cashboxId == null
                ? null
                : FinanceService.instance.cashboxes
                    .cast<FinanceCashbox?>()
                    .firstWhere(
                      (c) => c!.id == usage.budget.cashboxId,
                      orElse: () => null,
                    );
            return _tile(
              icon: Icons.pie_chart_outline,
              color: color,
              title: '${usage.budget.department} · ${usage.budget.period}',
              subtitle:
                  '${usage.budget.academicYear}'
                  ' · allocated ${_etb(usage.budget.amount)}'
                  ' · disbursed ${_etb(usage.disbursed)}'
                  ' · spent ${_etb(usage.actual)}'
                  ' · still to release ${_etb(usage.remainingToDisburse)}'
                  '${box == null ? '' : ' · ${box.name} ${_etb(usage.cashboxBalance)}'}'
                  '${usage.overrun ? ' · over budget' : ''}'
                  '${usage.budget.custodian == null ? '' : ' · ${usage.budget.custodian}'}',
              trailing: !_canManage
                  ? null
                  : TextButton(
                      onPressed: () => _disburseBudget(usage),
                      child: const Text('Disburse'),
                    ),
            );
          }),
      ],
    );
  }

  Widget _payables() {
    final rows = FinanceService.instance.payablesForSchool();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Supplier payables',
                style: WebErpTheme.sectionTitle(context),
              ),
            ),
            if (_canManage)
              FilledButton.icon(
                onPressed: _addPayable,
                icon: const Icon(Icons.add),
                label: const Text('Add supplier bill'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Record the bill, approve it, then pay from a cashbox. '
          'It is a liability until cash leaves. Charge a department budget when needed.',
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Text('No supplier bills yet.')
        else
          ...rows.map((bill) {
            final box = bill.cashboxId == null
                ? null
                : FinanceService.instance.cashboxes
                    .cast<FinanceCashbox?>()
                    .firstWhere(
                      (c) => c!.id == bill.cashboxId,
                      orElse: () => null,
                    );
            return _tile(
              icon: Icons.storefront_outlined,
              color: _invoiceColor(bill.status),
              title: '${bill.supplier} · ${_etb(bill.outstanding)}',
              subtitle:
                  '${bill.department} · ${_etb(bill.amount)} · ${bill.status.label}'
                  '${bill.approved ? ' · approved' : ' · awaiting approval'}'
                  '${bill.invoiceRef == null ? '' : ' · ${bill.invoiceRef}'}'
                  '${bill.voucherNo == null ? '' : ' · ${bill.voucherNo}'}'
                  '${box == null ? '' : ' · paid from ${box.name}'}',
              trailing: bill.isPaid || !_canManage
                  ? null
                  : Wrap(
                      children: [
                        if (!bill.approved)
                          TextButton(
                            onPressed: () => _run(() {
                              FinanceService.instance.approvePayable(bill.id);
                            }),
                            child: const Text('Approve'),
                          ),
                        if (bill.approved)
                          TextButton(
                            onPressed: () => _payPayable(bill),
                            child: const Text('Pay from cashbox'),
                          ),
                      ],
                    ),
            );
          }),
      ],
    );
  }

  Widget _reports() {
    final totals = FinanceService.instance.controlTotals();
    final overdue = FinanceService.instance
        .invoicesForSchool()
        .where((i) => i.status == FinanceInvoiceStatus.overdue)
        .toList();
    final byCategory = <String, double>{};
    for (final e in FinanceService.instance.expensesForSchool().where(
      (x) => x.status == FinanceExpenseStatus.paid,
    )) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Finance reports', style: WebErpTheme.sectionTitle(context)),
        const SizedBox(height: 12),
        _tile(
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFF0F766E),
          title: 'Collections vs billed',
          subtitle:
              'Collected ${_etb(totals.collected)} of ${_etb(totals.billed)} · '
              'outstanding ${_etb(totals.outstanding)}',
        ),
        _tile(
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFEA580C),
          title: '${totals.overdueCount} overdue invoice(s)',
          subtitle: overdue.isEmpty
              ? 'No overdue student balances.'
              : overdue
                  .take(6)
                  .map((i) => '${i.studentName} ${_etb(i.outstanding)}')
                  .join(' · '),
        ),
        _tile(
          icon: Icons.pie_chart_outline,
          color: const Color(0xFFDB2777),
          title: 'Expenses by category',
          subtitle: byCategory.isEmpty
              ? 'No paid expenses yet.'
              : byCategory.entries
                  .map((e) => '${e.key}: ${_etb(e.value)}')
                  .join(' · '),
        ),
        _tile(
          icon: Icons.savings_outlined,
          color: const Color(0xFF2563EB),
          title: 'Cash on hand',
          subtitle: FinanceService.instance
              .cashboxesForSchool()
              .map(
                (b) =>
                    '${b.name} ${_etb(FinanceService.instance.expectedCash(b.id))}',
              )
              .join(' · '),
        ),
        _tile(
          icon: Icons.storefront_outlined,
          color: const Color(0xFFB45309),
          title: 'Supplier payables',
          subtitle: totals.payablesOutstanding <= 0
              ? 'No unpaid supplier bills.'
              : '${_etb(totals.payablesOutstanding)} still owed',
        ),
        _tile(
          icon: Icons.pie_chart_outline,
          color: const Color(0xFF0891B2),
          title: 'Budget utilization',
          subtitle: totals.budgetApproved <= 0
              ? 'No departmental budgets yet.'
              : '${totals.budgetConsumedPercent.toStringAsFixed(0)}% of ${_etb(totals.budgetApproved)} used',
        ),
        _tile(
          icon: Icons.account_balance_outlined,
          color: const Color(0xFF1D4ED8),
          title: 'Formal financial statements',
          subtitle:
              'Trial balance, income & expenditure, balance sheet, and cash flow '
              'are generated from the ledger — not typed in.',
          onTap: () => setState(() => _section = 8),
        ),
      ],
    );
  }

  Widget _stat(String label, double value, Color color) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.9))),
          const SizedBox(height: 6),
          Text(
            _etb(value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required Color color,
    required IconData icon,
    required String title,
    required String body,
    required String action,
    VoidCallback? onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(body, style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 6),
                    Text(
                      action,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Color _invoiceColor(FinanceInvoiceStatus status) => switch (status) {
        FinanceInvoiceStatus.paid => const Color(0xFF15803D),
        FinanceInvoiceStatus.partial => const Color(0xFF0F766E),
        FinanceInvoiceStatus.overdue => const Color(0xFFDC2626),
        FinanceInvoiceStatus.pending => const Color(0xFFEA580C),
      };

  String _etb(double value) => '${value.toStringAsFixed(0)} ETB';

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _run(VoidCallback fn) {
    try {
      fn();
    } catch (e) {
      _toast(e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _addStructure() => _editStructure();

  Future<void> _editStructure([FinanceFeeStructure? existing]) async {
    final title = TextEditingController(text: existing?.title ?? 'Annual tuition');
    final year = TextEditingController(text: existing?.academicYear ?? _year);
    final amount = TextEditingController(
      text: (existing?.amount ?? 60000).toStringAsFixed(0),
    );
    final installments = TextEditingController(
      text: '${existing?.installmentCount ?? 3}',
    );
    final lateFee = TextEditingController(
      text: (existing?.lateFeeAmount ?? 0).toStringAsFixed(0),
    );
    final dueDay = TextEditingController(
      text: existing?.dueDay?.toString() ?? '',
    );
    final notes = TextEditingController(text: existing?.notes ?? '');
    final grades = ClassStructureService.instance.gradesForSchool();
    var grade = existing?.grade ?? (grades.isEmpty ? 'Grade 1' : grades.first);
    var funding = existing?.fundingType ?? 'regular';
    var collectionId = existing?.collectionCashboxId;
    var active = existing?.active ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
        title: Text(existing == null ? 'Fee plan' : 'Edit fee plan'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: year,
                  decoration: const InputDecoration(labelText: 'Academic year'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: grade,
                  decoration: const InputDecoration(labelText: 'Grade'),
                  items: [
                    for (final g in (grades.isEmpty ? ['Grade 1'] : grades))
                      DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (v) => grade = v ?? grade,
                ),
                DropdownButtonFormField<String>(
                  initialValue: funding,
                  decoration: const InputDecoration(labelText: 'Student type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'regular',
                      child: Text('Regular student'),
                    ),
                    DropdownMenuItem(
                      value: 'scholarship',
                      child: Text('Scholarship student'),
                    ),
                  ],
                  onChanged: (v) => funding = v ?? funding,
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (ETB)'),
                ),
                TextField(
                  controller: installments,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Installments'),
                ),
                TextField(
                  controller: dueDay,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Due day of month (optional)',
                  ),
                ),
                TextField(
                  controller: lateFee,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Late fee if overdue (ETB)',
                  ),
                ),
                DropdownButtonFormField<String?>(
                  initialValue: collectionId,
                  decoration: const InputDecoration(
                    labelText: 'Collections cashbox',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Any collections / treasury box'),
                    ),
                    for (final box
                        in FinanceService.instance.cashboxesForSchool())
                      DropdownMenuItem(
                        value: box.id,
                        child: Text(_cashboxLabel(box)),
                      ),
                  ],
                  onChanged: (v) => collectionId = v,
                ),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                if (existing != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Plan is active'),
                    value: active,
                    onChanged: (v) => setDialog(() => active = v),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
        ),
      ),
    );
    if (ok != true) return;
    if (existing == null) {
      FinanceService.instance.addFeeStructure(
        title: title.text,
        grade: grade,
        academicYear: year.text,
        amount: double.tryParse(amount.text) ?? 0,
        fundingType: funding,
        installmentCount: int.tryParse(installments.text) ?? 1,
        collectionCashboxId: collectionId,
        lateFeeAmount: double.tryParse(lateFee.text) ?? 0,
        dueDay: int.tryParse(dueDay.text),
        notes: notes.text,
      );
      return;
    }
    FinanceService.instance.updateFeeStructure(
      id: existing.id,
      title: title.text,
      grade: grade,
      academicYear: year.text,
      amount: double.tryParse(amount.text) ?? 0,
      fundingType: funding,
      installmentCount: int.tryParse(installments.text) ?? 1,
      collectionCashboxId: collectionId,
      lateFeeAmount: double.tryParse(lateFee.text) ?? 0,
      dueDay: int.tryParse(dueDay.text),
      notes: notes.text,
      active: active,
    );
  }

  Future<void> _recordPayment(FinanceInvoice invoice) async {
    final amount = TextEditingController(
      text: invoice.outstanding.toStringAsFixed(0),
    );
    final reference = TextEditingController();
    var method = FinancePaymentMethod.cash;
    String? cashboxId = _defaultCollectionsCashbox(invoice);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record payment · ${invoice.studentName}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Outstanding ${_etb(invoice.outstanding)}'),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount received'),
              ),
              DropdownButtonFormField<FinancePaymentMethod>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Method'),
                items: [
                  for (final m in FinancePaymentMethod.values)
                    DropdownMenuItem(value: m, child: Text(m.label)),
                ],
                onChanged: (v) => method = v ?? method,
              ),
              _cashboxField(
                value: cashboxId,
                label: 'Receive into cashbox',
                onChanged: (v) => cashboxId = v,
              ),
              TextField(
                controller: reference,
                decoration: const InputDecoration(
                  labelText: 'Bank / mobile / cheque reference',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save receipt'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final pay = FinanceService.instance.recordPayment(
        invoiceId: invoice.id,
        amount: double.tryParse(amount.text) ?? 0,
        method: method,
        reference: reference.text,
        cashboxId: cashboxId,
      );
      _toast('Receipt ${pay.receiptNo} recorded.');
    } catch (e) {
      _toast(e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  void _showStatement(String studentId) {
    final statement = FinanceService.instance.statementForStudent(studentId);
    if (statement == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(statement.studentName),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Billed ${_etb(statement.billed)} · Paid ${_etb(statement.paid)} · '
                'Outstanding ${_etb(statement.outstanding)}',
              ),
              const SizedBox(height: 12),
              for (final inv in statement.invoices)
                Text('${inv.title}: ${_etb(inv.outstanding)} open'),
              const SizedBox(height: 8),
              for (final p in statement.payments)
                Text('${p.receiptNo} · ${_etb(p.amount)} · ${p.method.label}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCashbox() async {
    final name = TextEditingController(text: 'Cafeteria');
    final opening = TextEditingController(text: '0');
    final cashier = TextEditingController();
    final location = TextEditingController();
    var purpose = FinanceCashboxPurpose.general;
    String? department;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cashbox'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              DropdownButtonFormField<FinanceCashboxPurpose>(
                initialValue: purpose,
                decoration: const InputDecoration(labelText: 'Purpose'),
                items: [
                  for (final p in FinanceCashboxPurpose.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (v) => purpose = v ?? purpose,
              ),
              DropdownButtonFormField<String?>(
                initialValue: department,
                decoration: const InputDecoration(
                  labelText: 'Department (budget boxes)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Not department-specific'),
                  ),
                  for (final d in FinanceDepartments.values)
                    DropdownMenuItem(value: d, child: Text(d)),
                ],
                onChanged: (v) => department = v,
              ),
              TextField(
                controller: opening,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Opening balance'),
              ),
              TextField(
                controller: cashier,
                decoration: const InputDecoration(labelText: 'Custodian / cashier'),
              ),
              TextField(
                controller: location,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    FinanceService.instance.addCashbox(
      name: name.text,
      openingBalance: double.tryParse(opening.text) ?? 0,
      cashierName: cashier.text,
      purpose: purpose,
      department: department,
      location: location.text,
    );
  }

  Future<void> _cashMove(FinanceCashbox box) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    var kind = FinanceCashKind.receipt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cash movement · ${box.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<FinanceCashKind>(
              initialValue: kind,
              items: [
                for (final k in FinanceCashKind.values)
                  DropdownMenuItem(value: k, child: Text(k.label)),
              ],
              onChanged: (v) => kind = v ?? kind,
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _run(() {
      FinanceService.instance.recordCashMovement(
        cashboxId: box.id,
        kind: kind,
        amount: double.tryParse(amount.text) ?? 0,
        note: note.text,
      );
    });
  }

  Future<void> _transferCash(FinanceCashbox from) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final others = FinanceService.instance
        .cashboxesForSchool()
        .where((b) => b.id != from.id)
        .toList();
    if (others.isEmpty) {
      _toast('Add a second cashbox before transferring.');
      return;
    }
    var toId = others.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Transfer from ${from.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available ${_etb(FinanceService.instance.expectedCash(from.id))}'),
            DropdownButtonFormField<String>(
              initialValue: toId,
              decoration: const InputDecoration(labelText: 'To cashbox'),
              items: [
                for (final box in others)
                  DropdownMenuItem(
                    value: box.id,
                    child: Text(_cashboxLabel(box)),
                  ),
              ],
              onChanged: (v) => toId = v ?? toId,
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _run(() {
      FinanceService.instance.transferBetweenCashboxes(
        fromCashboxId: from.id,
        toCashboxId: toId,
        amount: double.tryParse(amount.text) ?? 0,
        note: note.text,
      );
    });
  }

  void _showCashboxLedger(FinanceCashbox box) {
    final moves = FinanceService.instance
        .cashMovesForSchool()
        .where((m) => m.cashboxId == box.id)
        .toList()
        .reversed
        .take(20);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(box.name),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${box.purpose.label} · on hand '
                '${_etb(FinanceService.instance.expectedCash(box.id))}',
              ),
              const SizedBox(height: 12),
              if (moves.isEmpty) const Text('No movements yet.'),
              for (final move in moves)
                Text(
                  '${move.kind.label} ${_etb(move.amount)} · ${move.note ?? move.reference ?? move.recordedBy}',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _closeCash(FinanceCashbox box, double expected) async {
    final counted = TextEditingController(text: expected.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Close ${box.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Expected ${_etb(expected)}'),
            TextField(
              controller: counted,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Counted cash'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close day'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final close = FinanceService.instance.closeCashbox(
      cashboxId: box.id,
      counted: double.tryParse(counted.text) ?? expected,
    );
    _toast(
      'Variance ${_etb(close.variance)} (counted minus expected).',
    );
  }

  Future<void> _addExpense() async {
    var category = FinanceExpenseCategories.values.first;
    final amount = TextEditingController();
    final supplier = TextEditingController();
    final purpose = TextEditingController();
    final voucher = TextEditingController();
    var department = FinanceExpenseCategories.departmentFor(category);
    String? budgetId;
    String? cashboxId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Expense request'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in FinanceExpenseCategories.values)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) {
                    category = v ?? category;
                    department =
                        FinanceExpenseCategories.departmentFor(category);
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: department,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: [
                    for (final d in FinanceDepartments.values)
                      DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (v) => department = v ?? department,
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (ETB)'),
                ),
                TextField(
                  controller: supplier,
                  decoration: const InputDecoration(labelText: 'Supplier / payee'),
                ),
                TextField(
                  controller: purpose,
                  decoration: const InputDecoration(labelText: 'Purpose'),
                ),
                TextField(
                  controller: voucher,
                  decoration: const InputDecoration(labelText: 'Voucher no.'),
                ),
                _budgetField(
                  value: budgetId,
                  onChanged: (v) => budgetId = v,
                ),
                _cashboxField(
                  value: cashboxId,
                  label: 'Preferred paying cashbox',
                  onChanged: (v) => cashboxId = v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _run(() {
      FinanceService.instance.requestExpense(
        category: category,
        amount: double.tryParse(amount.text) ?? 0,
        supplier: supplier.text,
        purpose: purpose.text,
        department: department,
        voucherNo: voucher.text,
        budgetId: budgetId,
        cashboxId: cashboxId,
      );
    });
  }

  Future<void> _payExpense(FinanceExpense expense) async {
    var method = FinancePaymentMethod.cash;
    final reference = TextEditingController();
    String? cashboxId = expense.cashboxId ??
        _budgetCashboxId(expense.budgetId) ??
        _fallbackPayCashbox();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pay expense from cashbox'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${expense.category} · ${_etb(expense.amount)}'),
            DropdownButtonFormField<FinancePaymentMethod>(
              initialValue: method,
              items: [
                for (final m in FinancePaymentMethod.values)
                  DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: (v) => method = v ?? method,
            ),
            _cashboxField(
              value: cashboxId,
              label: 'Pay from cashbox',
              onChanged: (v) => cashboxId = v,
            ),
            TextField(
              controller: reference,
              decoration: const InputDecoration(labelText: 'Reference / cheque'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Record'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _run(() {
      FinanceService.instance.payExpense(
        id: expense.id,
        method: method,
        reference: reference.text,
        cashboxId: cashboxId,
      );
    });
  }

  Future<void> _addBudget() async {
    var department = FinanceDepartments.values.first;
    final year = TextEditingController(text: _year);
    final amount = TextEditingController();
    var period = 'Annual';
    final custodian = TextEditingController();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Allocate department budget'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: department,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: [
                    for (final d in FinanceDepartments.values)
                      DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (v) => department = v ?? department,
                ),
                DropdownButtonFormField<String>(
                  initialValue: period,
                  decoration: const InputDecoration(labelText: 'Period'),
                  items: const [
                    DropdownMenuItem(value: 'Annual', child: Text('Annual')),
                    DropdownMenuItem(value: 'Term', child: Text('Term')),
                    DropdownMenuItem(value: 'Month', child: Text('Month')),
                  ],
                  onChanged: (v) => period = v ?? period,
                ),
                TextField(
                  controller: year,
                  decoration: const InputDecoration(labelText: 'Academic year'),
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Allocated ceiling (ETB)',
                  ),
                ),
                TextField(
                  controller: custodian,
                  decoration: const InputDecoration(
                    labelText: 'Budget cashbox custodian',
                  ),
                ),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A dedicated budget cashbox is opened with zero cash. '
                  'Use Disburse to move money from treasury into that box.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    FinanceService.instance.addBudget(
      department: department,
      academicYear: year.text,
      amount: double.tryParse(amount.text) ?? 0,
      period: period,
      custodian: custodian.text,
      notes: notes.text,
    );
  }

  Future<void> _disburseBudget(FinanceBudgetUsage usage) async {
    final amount = TextEditingController(
      text: usage.remainingToDisburse.clamp(0, double.infinity).toStringAsFixed(0),
    );
    final voucher = TextEditingController();
    final note = TextEditingController();
    final sources = FinanceService.instance
        .cashboxesForSchool()
        .where((b) => b.id != usage.budget.cashboxId)
        .toList();
    if (sources.isEmpty) {
      _toast('Open a treasury or collections cashbox first.');
      return;
    }
    var fromId = sources.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Disburse ${usage.budget.department}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Allocated ${_etb(usage.budget.amount)} · '
              'already released ${_etb(usage.disbursed)} · '
              'still to release ${_etb(usage.remainingToDisburse)}',
            ),
            DropdownButtonFormField<String>(
              initialValue: fromId,
              decoration: const InputDecoration(labelText: 'From treasury cashbox'),
              items: [
                for (final box in sources)
                  DropdownMenuItem(
                    value: box.id,
                    child: Text(_cashboxLabel(box)),
                  ),
              ],
              onChanged: (v) => fromId = v ?? fromId,
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount to release'),
            ),
            TextField(
              controller: voucher,
              decoration: const InputDecoration(labelText: 'Voucher / warrant no.'),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disburse'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _run(() {
      FinanceService.instance.disburseBudget(
        budgetId: usage.budget.id,
        amount: double.tryParse(amount.text) ?? 0,
        fromCashboxId: fromId,
        voucherNo: voucher.text,
        note: note.text,
      );
    });
  }

  Future<void> _addPayable() async {
    var department = FinanceDepartments.values.first;
    final supplier = TextEditingController();
    final amount = TextEditingController();
    final invoiceRef = TextEditingController();
    final purpose = TextEditingController();
    final voucher = TextEditingController();
    String? budgetId;
    final due = TextEditingController(
      text: DateTime.now().add(const Duration(days: 14)).toIso8601String().split('T').first,
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supplier bill'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: supplier,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: department,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: [
                    for (final d in FinanceDepartments.values)
                      DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (v) => department = v ?? department,
                ),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount owed'),
                ),
                TextField(
                  controller: due,
                  decoration: const InputDecoration(labelText: 'Due date YYYY-MM-DD'),
                ),
                TextField(
                  controller: invoiceRef,
                  decoration: const InputDecoration(labelText: 'Supplier invoice no.'),
                ),
                TextField(
                  controller: voucher,
                  decoration: const InputDecoration(labelText: 'Internal voucher no.'),
                ),
                TextField(
                  controller: purpose,
                  decoration: const InputDecoration(labelText: 'Purpose'),
                ),
                _budgetField(
                  value: budgetId,
                  onChanged: (v) => budgetId = v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    FinanceService.instance.addPayable(
      supplier: supplier.text,
      department: department,
      amount: double.tryParse(amount.text) ?? 0,
      dueDate: DateTime.tryParse(due.text) ?? DateTime.now(),
      invoiceRef: invoiceRef.text,
      purpose: purpose.text,
      voucherNo: voucher.text,
      budgetId: budgetId,
    );
  }

  Future<void> _payPayable(FinancePayable bill) async {
    final amount = TextEditingController(text: bill.outstanding.toStringAsFixed(0));
    final reference = TextEditingController();
    var method = FinancePaymentMethod.cash;
    String? cashboxId =
        bill.cashboxId ?? _budgetCashboxId(bill.budgetId) ?? _fallbackPayCashbox();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pay ${bill.supplier} from cashbox'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Outstanding ${_etb(bill.outstanding)}'),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount paid'),
            ),
            DropdownButtonFormField<FinancePaymentMethod>(
              initialValue: method,
              items: [
                for (final m in FinancePaymentMethod.values)
                  DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: (v) => method = v ?? method,
            ),
            _cashboxField(
              value: cashboxId,
              label: 'Pay from cashbox',
              onChanged: (v) => cashboxId = v,
            ),
            TextField(
              controller: reference,
              decoration: const InputDecoration(labelText: 'Reference'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Record'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _run(() {
      FinanceService.instance.payPayable(
        id: bill.id,
        amount: double.tryParse(amount.text) ?? 0,
        method: method,
        reference: reference.text,
        cashboxId: cashboxId,
      );
    });
  }

  String _cashboxLabel(FinanceCashbox box) {
    return '${box.name} · ${box.purpose.label} · '
        '${_etb(FinanceService.instance.expectedCash(box.id))}';
  }

  String? _defaultCollectionsCashbox(FinanceInvoice invoice) {
    final plan = invoice.structureId == null
        ? null
        : FinanceService.instance.structures
            .cast<FinanceFeeStructure?>()
            .firstWhere(
              (s) => s!.id == invoice.structureId,
              orElse: () => null,
            );
    return plan?.collectionCashboxId ??
        FinanceService.instance
            .cashboxesForSchool()
            .where((b) => b.purpose == FinanceCashboxPurpose.collections)
            .cast<FinanceCashbox?>()
            .firstWhere((_) => true, orElse: () => null)
            ?.id;
  }

  String? _budgetCashboxId(String? budgetId) {
    if (budgetId == null) return null;
    return FinanceService.instance.budgets
        .cast<FinanceBudget?>()
        .firstWhere((b) => b!.id == budgetId, orElse: () => null)
        ?.cashboxId;
  }

  String? _fallbackPayCashbox() {
    final boxes = FinanceService.instance.cashboxesForSchool();
    if (boxes.isEmpty) return null;
    return boxes.first.id;
  }

  Widget _cashboxField({
    required String? value,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    final boxes = FinanceService.instance.cashboxesForSchool();
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Do not move a cashbox'),
        ),
        for (final box in boxes)
          DropdownMenuItem(value: box.id, child: Text(_cashboxLabel(box))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _budgetField({
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final budgets = FinanceService.instance.budgetsForSchool();
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Charge department budget'),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('No specific budget'),
        ),
        for (final budget in budgets)
          DropdownMenuItem(
            value: budget.id,
            child: Text(
              '${budget.department} · ${budget.academicYear} · ${_etb(budget.amount)}',
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
