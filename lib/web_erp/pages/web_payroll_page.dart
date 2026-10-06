import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/models/payroll_models.dart';
import 'package:mayabela/services/ethiopia_payroll_tax.dart';
import 'package:mayabela/services/payroll_export_service.dart';
import 'package:mayabela/services/payroll_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

class WebPayrollPage extends StatefulWidget {
  const WebPayrollPage({super.key, this.embedded = false});

  final bool embedded;

  /// Employees shown on one register page so the list stays on-screen.
  static const registerPageSize = 10;

  @override
  State<WebPayrollPage> createState() => _WebPayrollPageState();
}

class _WebPayrollPageState extends State<WebPayrollPage> {
  String _query = '';
  late String _periodYm;
  late final TextEditingController _periodController;
  var _exporting = false;
  var _page = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodYm = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _periodController = TextEditingController(text: _periodYm);
    PayrollService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  int _pageIndex(int length) {
    if (length <= 0) return 0;
    final maxPage = (length - 1) ~/ WebPayrollPage.registerPageSize;
    return _page.clamp(0, maxPage);
  }

  List<T> _pageSlice<T>(List<T> items) {
    if (items.isEmpty) return items;
    final size = WebPayrollPage.registerPageSize;
    final start = _pageIndex(items.length) * size;
    final end = (start + size).clamp(0, items.length);
    return items.sublist(start, end);
  }

  String _etb(num value) => EthiopianPayrollTax.etb(value);

  String _amount(num value) =>
      EthiopianPayrollTax.etb(value).replaceAll(' ETB', '');

  Future<void> _edit(PayrollPerson person) async {
    final svc = PayrollService.instance;
    if (!svc.canManage) return;
    final existing = svc.profileFor(person);
    final basic = TextEditingController(
      text: existing == null || existing.basicSalary == 0
          ? ''
          : existing.basicSalary.toStringAsFixed(2),
    );
    final taxable = TextEditingController(
      text: (existing?.taxableAllowances ?? 0) == 0
          ? ''
          : existing!.taxableAllowances.toStringAsFixed(2),
    );
    final exempt = TextEditingController(
      text: (existing?.exemptAllowances ?? 0) == 0
          ? ''
          : existing!.exemptAllowances.toStringAsFixed(2),
    );
    final advance = TextEditingController(
      text: (existing?.salaryAdvance ?? 0) == 0
          ? ''
          : existing!.salaryAdvance.toStringAsFixed(2),
    );
    final other = TextEditingController(
      text: (existing?.otherDeductions ?? 0) == 0
          ? ''
          : existing!.otherDeductions.toStringAsFixed(2),
    );
    final otherNote = TextEditingController(
      text: existing?.otherDeductionNote ?? '',
    );
    var pension = existing?.pensionEligible ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            double parse(TextEditingController c) =>
                double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;
            final preview = EthiopianPayrollTax.breakdown(
              basicSalary: parse(basic),
              taxableAllowances: parse(taxable),
              exemptAllowances: parse(exempt),
              salaryAdvance: parse(advance),
              otherDeductions: parse(other),
              pensionEligible: pension,
            );
            return AlertDialog(
              title: Text(person.fullName),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${person.personId} · ${person.jobTitle}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      _moneyField(
                        controller: basic,
                        label: 'Basic salary (ETB / month)',
                        onChanged: () => setLocal(() {}),
                      ),
                      const SizedBox(height: 12),
                      _moneyField(
                        controller: taxable,
                        label: 'Taxable allowances (ETB)',
                        helper: 'Overtime, taxable benefits — added to the income tax base',
                        onChanged: () => setLocal(() {}),
                      ),
                      const SizedBox(height: 12),
                      _moneyField(
                        controller: exempt,
                        label: 'Tax-exempt allowances (ETB)',
                        helper: 'Paid to staff but not added to income tax',
                        onChanged: () => setLocal(() {}),
                      ),
                      const SizedBox(height: 12),
                      _moneyField(
                        controller: advance,
                        label: 'Salary advance recovered this month (ETB)',
                        helper: 'Taken from net after income tax and pension',
                        onChanged: () => setLocal(() {}),
                      ),
                      const SizedBox(height: 12),
                      _moneyField(
                        controller: other,
                        label: 'Other deduction (ETB)',
                        helper: 'Loan, absence, cooperative, lost item, etc.',
                        onChanged: () => setLocal(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: otherNote,
                        decoration: const InputDecoration(
                          labelText: 'Other deduction reason',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('POESSA pension (7% staff + 11% school)'),
                        subtitle: const Text(
                          'On for Ethiopian citizens. Turn off for ineligible foreigners.',
                        ),
                        value: pension,
                        onChanged: (v) => setLocal(() => pension = v),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Income tax ${_etb(preview.paye)} · Staff pension ${_etb(preview.employeePension)} · '
                        'Advance ${_etb(preview.salaryAdvance)} · Other ${_etb(preview.otherDeductions)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Net ${_etb(preview.net)} · ${preview.band.label}',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w700,
                        ),
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
            );
          },
        );
      },
    );

    if (saved == true) {
      double parse(TextEditingController c) =>
          double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;
      await svc.upsertProfile(
        person: person,
        basicSalary: parse(basic),
        taxableAllowances: parse(taxable),
        exemptAllowances: parse(exempt),
        salaryAdvance: parse(advance),
        otherDeductions: parse(other),
        otherDeductionNote: otherNote.text,
        pensionEligible: pension,
      );
    }
    basic.dispose();
    taxable.dispose();
    exempt.dispose();
    advance.dispose();
    other.dispose();
    otherNote.dispose();
  }

  Widget _moneyField({
    required TextEditingController controller,
    required String label,
    String? helper,
    required VoidCallback onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => onChanged(),
    );
  }

  Future<void> _runPayroll() async {
    final svc = PayrollService.instance;
    try {
      final run = await svc.runPayroll(periodYm: _periodYm);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payroll $_periodYm: ${run.slips.length} slips · '
            'Income tax ${_etb(run.totalPaye)} · net ${_etb(run.totalNet)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _export(String format) async {
    final rows = PayrollService.instance.registerRows();
    if (rows.where((r) => r.hasSalary).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a basic salary before exporting.')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final exporter = PayrollExportService.instance;
      if (format == 'excel') {
        await exporter.exportExcel(rows: rows, periodYm: _periodYm);
      } else {
        await exporter.printRegister(rows: rows, periodYm: _periodYm);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            format == 'excel'
                ? 'Payroll Excel file ready.'
                : 'Payroll PDF ready to print or save.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export payroll: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PayrollService.instance,
      builder: (context, _) {
        final svc = PayrollService.instance;
        var rows = svc.registerRows();
        if (_query.isNotEmpty) {
          final q = _query.toLowerCase();
          rows = rows
              .where(
                (r) =>
                    r.person.fullName.toLowerCase().contains(q) ||
                    r.person.personId.toLowerCase().contains(q) ||
                    r.person.jobTitle.toLowerCase().contains(q) ||
                    r.otherNote.toLowerCase().contains(q),
              )
              .toList();
        }
        final paid = rows.where((r) => r.hasSalary).toList();
        final advances = rows.where((r) => r.hasAdvance).toList();
        final others = rows.where((r) => r.hasOtherDeduction).toList();
        final latest = svc.latestRun();
        final canManage = svc.canManage;
        double sum(double Function(PayrollRegisterRow r) pick) =>
            EthiopianPayrollTax.money(
              paid.fold(0.0, (s, r) => s + pick(r)),
            );

        final pageRows = _pageSlice(rows);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.embedded)
                Text('Payroll', style: WebErpTheme.sectionTitle(context)),
              Text(
                'Income tax (PAYE) is employment tax. Pension, advances, and other '
                'deductions follow. Net pay is the last money column.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Ethiopian income tax monthly schedule (1395/2025)'),
                children: [
                  for (final band in EthiopianPayrollTax.brackets)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(band.label),
                      trailing: Text(
                        band.deduction == 0
                            ? '0 ETB'
                            : 'minus ${band.deduction.toStringAsFixed(0)} ETB',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search staff…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() {
                        _query = v.trim();
                        _page = 0;
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _periodController,
                      decoration: const InputDecoration(
                        labelText: 'Period (YYYY-MM)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (v) {
                        final t = v.trim();
                        if (RegExp(r'^\d{4}-\d{2}$').hasMatch(t)) {
                          setState(() => _periodYm = t);
                        }
                      },
                    ),
                  ),
                  if (canManage)
                    FilledButton.icon(
                      onPressed: _runPayroll,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Run payroll'),
                    ),
                  OutlinedButton.icon(
                    key: const ValueKey('payroll-export-excel'),
                    onPressed: _exporting ? null : () => _export('excel'),
                    icon: const Icon(Icons.table_view_outlined),
                    label: const Text('Export Excel'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('payroll-print'),
                    onPressed: _exporting ? null : () => _export('print'),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print / PDF'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _stat('Period', _periodYm),
                  _stat('Gross', _etb(sum((r) => r.calc.gross))),
                  _stat('Income tax', _etb(sum((r) => r.calc.paye))),
                  _stat(
                    'Staff deductions',
                    _etb(sum((r) => r.calc.totalStaffDeductions)),
                  ),
                  _stat('Net pay', _etb(sum((r) => r.calc.net))),
                  if (latest != null) _stat('Last run', latest.periodYm),
                ],
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Add teachers, other staff, or drivers in HR first.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else ...[
                Text(
                  'Payroll register',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Amounts in ETB. Every column stays on this page.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                _fitCard(
                  child: _fitTable(
                    key: const ValueKey('payroll-register-table'),
                    columnWeights: const [
                      1.15, 1.6, 1.25, 1.0, 1.0, 1.1, 1.15, 1.0, 1.05, 1.15, 1.1, 0.9,
                    ],
                    headers: const [
                      'Staff ID',
                      'Name',
                      'Job',
                      'Basic',
                      'Gross',
                      'Income tax',
                      'Staff pension',
                      'Advance',
                      'Other deduct.',
                      'Total deduct.',
                      'Net pay',
                      '',
                    ],
                    numeric: const {3, 4, 5, 6, 7, 8, 9, 10},
                    rows: [
                      for (final row in pageRows)
                        [
                          _cell(row.person.personId),
                          _cell(
                            row.person.fullName,
                            emphasize: true,
                            muted: !row.person.isActive,
                            strike: !row.person.isActive,
                          ),
                          _cell(row.person.jobTitle),
                          _cell(_amount(row.calc.basicSalary), numeric: true),
                          _cell(_amount(row.calc.gross), numeric: true),
                          _cell(_amount(row.calc.paye), numeric: true),
                          _cell(_amount(row.calc.employeePension), numeric: true),
                          _cell(_amount(row.calc.salaryAdvance), numeric: true),
                          _cell(_amount(row.calc.otherDeductions), numeric: true),
                          _cell(
                            _amount(row.calc.totalStaffDeductions),
                            numeric: true,
                          ),
                          _cell(
                            _amount(row.calc.net),
                            numeric: true,
                            emphasize: true,
                          ),
                          canManage
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => _edit(row.person),
                                    child: Text(
                                      row.hasSalary ? 'Edit' : 'Set salary',
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ],
                      if (paid.isNotEmpty)
                        [
                          _cell(''),
                          _cell('TOTAL', emphasize: true),
                          _cell('${paid.length} staff'),
                          _cell(_amount(sum((r) => r.calc.basicSalary)), numeric: true),
                          _cell(_amount(sum((r) => r.calc.gross)), numeric: true),
                          _cell(_amount(sum((r) => r.calc.paye)), numeric: true),
                          _cell(
                            _amount(sum((r) => r.calc.employeePension)),
                            numeric: true,
                          ),
                          _cell(
                            _amount(sum((r) => r.calc.salaryAdvance)),
                            numeric: true,
                          ),
                          _cell(
                            _amount(sum((r) => r.calc.otherDeductions)),
                            numeric: true,
                          ),
                          _cell(
                            _amount(sum((r) => r.calc.totalStaffDeductions)),
                            numeric: true,
                          ),
                          _cell(
                            _amount(sum((r) => r.calc.net)),
                            numeric: true,
                            emphasize: true,
                          ),
                          const SizedBox.shrink(),
                        ],
                    ],
                  ),
                ),
                _pager(total: rows.length),
                if (advances.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Salary advances',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recovered from net pay after income tax and pension.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _fitCard(
                    child: _fitTable(
                      columnWeights: const [1.2, 1.8, 1.5, 1.4, 1.2],
                      headers: const [
                        'Staff ID',
                        'Name',
                        'Job',
                        'Advance recovered',
                        'Net pay',
                      ],
                      numeric: const {3, 4},
                      rows: [
                        for (final row in advances)
                          [
                            _cell(row.person.personId),
                            _cell(row.person.fullName, emphasize: true),
                            _cell(row.person.jobTitle),
                            _cell(_etb(row.calc.salaryAdvance), numeric: true),
                            _cell(_etb(row.calc.net), numeric: true, emphasize: true),
                          ],
                      ],
                    ),
                  ),
                ],
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Other deductions',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Loans, absence, cooperative, or other recoveries.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _fitCard(
                    child: _fitTable(
                      columnWeights: const [1.1, 1.6, 1.3, 1.1, 1.6, 1.1],
                      headers: const [
                        'Staff ID',
                        'Name',
                        'Job',
                        'Amount',
                        'Reason',
                        'Net pay',
                      ],
                      numeric: const {3, 5},
                      rows: [
                        for (final row in others)
                          [
                            _cell(row.person.personId),
                            _cell(row.person.fullName, emphasize: true),
                            _cell(row.person.jobTitle),
                            _cell(_etb(row.calc.otherDeductions), numeric: true),
                            _cell(row.otherNote.isEmpty ? 'Other' : row.otherNote),
                            _cell(_etb(row.calc.net), numeric: true, emphasize: true),
                          ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _fitCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: WebErpTheme.cardDecoration(context),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }

  Widget _fitTable({
    Key? key,
    required List<double> columnWeights,
    required List<String> headers,
    required List<List<Widget>> rows,
    Set<int> numeric = const {},
  }) {
    return Table(
      key: key,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        for (var i = 0; i < columnWeights.length; i++)
          i: FlexColumnWidth(columnWeights[i]),
      },
      border: TableBorder(
        horizontalInside: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
        ),
      ),
      children: [
        TableRow(
          children: [
            for (var i = 0; i < headers.length; i++)
              _cell(headers[i], header: true, numeric: numeric.contains(i)),
          ],
        ),
        for (final row in rows) TableRow(children: row),
      ],
    );
  }

  Widget _cell(
    String text, {
    bool header = false,
    bool numeric = false,
    bool emphasize = false,
    bool muted = false,
    bool strike = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        textAlign: numeric ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: header ? 11 : 12,
          height: 1.25,
          fontWeight: header || emphasize ? FontWeight.w800 : FontWeight.w500,
          color: muted ? Colors.grey : null,
          decoration: strike ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }

  Widget _pager({required int total}) {
    if (total <= WebPayrollPage.registerPageSize) {
      return const SizedBox.shrink();
    }
    final size = WebPayrollPage.registerPageSize;
    final page = _pageIndex(total);
    final start = page * size + 1;
    final end = ((page + 1) * size).clamp(0, total);
    final lastPage = (total - 1) ~/ size;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Text(
            '$start–$end of $total staff',
            key: const ValueKey('payroll-page-label'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          TextButton(
            key: const ValueKey('payroll-page-prev'),
            onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
            child: const Text('Previous'),
          ),
          TextButton(
            key: const ValueKey('payroll-page-next'),
            onPressed:
                page < lastPage ? () => setState(() => _page = page + 1) : null,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
