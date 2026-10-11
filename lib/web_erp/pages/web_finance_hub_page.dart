import 'package:flutter/material.dart';

import 'package:mayabela/models/finance_models.dart';
import 'package:mayabela/screens/finance_coming_soon_screen.dart';
import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/services/finance_service.dart';
import 'package:mayabela/services/persistence/finance_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
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
    (5, 'Reports', Icons.insights_outlined, Color(0xFF15803D)),
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
            'Record fees, cash, and expenses. Reports stay on the same numbers. '
            'Payroll stays in Human Resource.',
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
      5 => _reports(),
      _ => _control(),
    };
  }

  Widget _control() {
    final totals = FinanceService.instance.controlTotals();
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
          ],
        ),
        const SizedBox(height: 16),
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
          'Installments split the annual fee automatically.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Text('No fee plans yet. Add one for each grade you bill.')
        else
          ...rows.map(
            (s) => _tile(
              icon: Icons.tune_rounded,
              color: const Color(0xFF7C3AED),
              title: '${s.title} · ${s.grade}',
              subtitle:
                  '${s.academicYear} · ${s.fundingType} · ${_etb(s.amount)}'
                  '${s.installmentCount > 1 ? ' · ${s.installmentCount} installments' : ''}',
            ),
          ),
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
          'Record cash without a bank connection. Close the day by counting physical cash.',
        ),
        const SizedBox(height: 12),
        if (boxes.isEmpty) const Text('No cashboxes yet.') else
          ...boxes.map((box) {
            final expected = FinanceService.instance.expectedCash(box.id);
            return _tile(
              icon: Icons.point_of_sale_rounded,
              color: const Color(0xFF2563EB),
              title: box.name,
              subtitle:
                  'Expected ${_etb(expected)}'
                  '${box.cashierName == null ? '' : ' · ${box.cashierName}'}',
              trailing: !_canManage
                  ? null
                  : Wrap(
                      children: [
                        TextButton(
                          onPressed: () => _cashMove(box),
                          child: const Text('Move cash'),
                        ),
                        TextButton(
                          onPressed: () => _closeCash(box, expected),
                          child: const Text('Close day'),
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
          'Request → approve → record payment. Salary runs are not entered here.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty) const Text('No expense requests yet.') else
          ...rows.map((e) {
            return _tile(
              icon: Icons.payments_outlined,
              color: const Color(0xFFDB2777),
              title: '${e.category} · ${_etb(e.amount)}',
              subtitle:
                  '${e.status.label} · ${e.supplier ?? e.purpose ?? e.requestedBy}',
              trailing: !_canManage
                  ? null
                  : Wrap(
                      children: [
                        if (e.status == FinanceExpenseStatus.requested)
                          TextButton(
                            onPressed: () => _run(() {
                              FinanceService.instance.approveExpense(e.id);
                            }),
                            child: const Text('Approve'),
                          ),
                        if (e.status == FinanceExpenseStatus.approved)
                          TextButton(
                            onPressed: () => _payExpense(e),
                            child: const Text('Record payment'),
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

  Future<void> _addStructure() async {
    final title = TextEditingController(text: 'Annual tuition');
    final year = TextEditingController(text: _year);
    final amount = TextEditingController(text: '60000');
    final installments = TextEditingController(text: '3');
    final grades = ClassStructureService.instance.gradesForSchool();
    var grade = grades.isEmpty ? 'Grade 1' : grades.first;
    var funding = 'regular';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fee plan'),
        content: SizedBox(
          width: 420,
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
    FinanceService.instance.addFeeStructure(
      title: title.text,
      grade: grade,
      academicYear: year.text,
      amount: double.tryParse(amount.text) ?? 0,
      fundingType: funding,
      installmentCount: int.tryParse(installments.text) ?? 1,
    );
  }

  Future<void> _recordPayment(FinanceInvoice invoice) async {
    final amount = TextEditingController(
      text: invoice.outstanding.toStringAsFixed(0),
    );
    final reference = TextEditingController();
    var method = FinancePaymentMethod.cash;
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cashbox'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: opening,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Opening balance'),
            ),
            TextField(
              controller: cashier,
              decoration: const InputDecoration(labelText: 'Cashier (optional)'),
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
    FinanceService.instance.addCashbox(
      name: name.text,
      openingBalance: double.tryParse(opening.text) ?? 0,
      cashierName: cashier.text,
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Expense request'),
        content: SizedBox(
          width: 420,
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
                onChanged: (v) => category = v ?? category,
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
      );
    });
  }

  Future<void> _payExpense(FinanceExpense expense) async {
    var method = FinancePaymentMethod.bankTransfer;
    final reference = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record expense payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<FinancePaymentMethod>(
              initialValue: method,
              items: [
                for (final m in FinancePaymentMethod.values)
                  DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: (v) => method = v ?? method,
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
      FinanceService.instance.payExpense(
        id: expense.id,
        method: method,
        reference: reference.text,
      );
    });
  }
}
