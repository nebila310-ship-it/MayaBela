import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/models/payroll_models.dart';
import 'package:mayabela/services/ethiopia_payroll_tax.dart';
import 'package:mayabela/services/payroll_export_service.dart';
import 'package:mayabela/services/payroll_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/widgets/web_erp_hscroll.dart';

class WebPayrollPage extends StatefulWidget {
  const WebPayrollPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<WebPayrollPage> createState() => _WebPayrollPageState();
}

class _WebPayrollPageState extends State<WebPayrollPage> {
  String _query = '';
  late String _periodYm;
  late final TextEditingController _periodController;
  var _exporting = false;

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

  String _etb(num value) => EthiopianPayrollTax.etb(value);

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
                        helper: 'Overtime, taxable benefits — added to PAYE base',
                        onChanged: () => setLocal(() {}),
                      ),
                      const SizedBox(height: 12),
                      _moneyField(
                        controller: exempt,
                        label: 'Tax-exempt allowances (ETB)',
                        helper: 'Paid to staff but not added to PAYE',
                        onChanged: () => setLocal(() {}),
                      ),
                      const SizedBox(height: 12),
                      _moneyField(
                        controller: advance,
                        label: 'Salary advance recovered this month (ETB)',
                        helper: 'Taken from net after PAYE and pension',
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
                        'PAYE ${_etb(preview.paye)} · Staff pension ${_etb(preview.employeePension)} · '
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
            'PAYE ${_etb(run.totalPaye)} · net ${_etb(run.totalNet)}',
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

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.embedded)
                Text('Payroll', style: WebErpTheme.sectionTitle(context)),
              Text(
                'Automatic PAYE from Proclamation 1395/2025 (first 2,000 ETB exempt, '
                'then 15–35%) and POESSA pension (7% staff / 11% school on basic). '
                'Advances and other deductions come off net after tax. '
                'This is a school register, not a substitute for a licensed accountant.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Ethiopian PAYE monthly schedule (1395/2025)'),
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
                      onChanged: (v) => setState(() => _query = v.trim()),
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
                  _stat('PAYE', _etb(sum((r) => r.calc.paye))),
                  _stat(
                    'Staff deductions',
                    _etb(sum((r) => r.calc.totalStaffDeductions)),
                  ),
                  _stat('Net pay', _etb(sum((r) => r.calc.net))),
                  if (latest != null) _stat('Last run', latest.periodYm),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          'Add teachers, other staff, or drivers in HR first.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView(
                        children: [
                          Text(
                            'Payroll register',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: WebErpTheme.cardDecoration(context),
                            child: WebErpHScroll(
                              child: DataTable(
                                showCheckboxColumn: false,
                                headingRowHeight: 44,
                                dataRowMinHeight: 44,
                                dataRowMaxHeight: 56,
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                                columns: const [
                                  DataColumn(label: Text('Staff ID')),
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Job')),
                                  DataColumn(label: Text('Basic'), numeric: true),
                                  DataColumn(label: Text('Gross'), numeric: true),
                                  DataColumn(label: Text('PAYE'), numeric: true),
                                  DataColumn(
                                    label: Text('Staff pension'),
                                    numeric: true,
                                  ),
                                  DataColumn(label: Text('Advance'), numeric: true),
                                  DataColumn(
                                    label: Text('Other deduct.'),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text('Total deduct.'),
                                    numeric: true,
                                  ),
                                  DataColumn(label: Text('Net pay'), numeric: true),
                                  DataColumn(label: Text('')),
                                ],
                                rows: [
                                  for (final row in rows)
                                    DataRow(
                                      onSelectChanged: canManage
                                          ? (_) => _edit(row.person)
                                          : null,
                                      cells: [
                                        DataCell(Text(row.person.personId)),
                                        DataCell(
                                          Text(
                                            row.person.fullName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: row.person.isActive
                                                  ? null
                                                  : Colors.grey,
                                              decoration: row.person.isActive
                                                  ? null
                                                  : TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(row.person.jobTitle)),
                                        DataCell(Text(_etb(row.calc.basicSalary))),
                                        DataCell(Text(_etb(row.calc.gross))),
                                        DataCell(Text(_etb(row.calc.paye))),
                                        DataCell(
                                          Text(_etb(row.calc.employeePension)),
                                        ),
                                        DataCell(Text(_etb(row.calc.salaryAdvance))),
                                        DataCell(
                                          Text(_etb(row.calc.otherDeductions)),
                                        ),
                                        DataCell(
                                          Text(_etb(row.calc.totalStaffDeductions)),
                                        ),
                                        DataCell(
                                          Text(
                                            _etb(row.calc.net),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          canManage
                                              ? TextButton(
                                                  onPressed: () =>
                                                      _edit(row.person),
                                                  child: Text(
                                                    row.hasSalary
                                                        ? 'Edit'
                                                        : 'Set salary',
                                                  ),
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  if (paid.isNotEmpty)
                                    DataRow(
                                      cells: [
                                        const DataCell(Text('')),
                                        const DataCell(
                                          Text(
                                            'TOTAL',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text('${paid.length} staff')),
                                        DataCell(
                                          Text(_etb(sum((r) => r.calc.basicSalary))),
                                        ),
                                        DataCell(
                                          Text(_etb(sum((r) => r.calc.gross))),
                                        ),
                                        DataCell(
                                          Text(_etb(sum((r) => r.calc.paye))),
                                        ),
                                        DataCell(
                                          Text(
                                            _etb(sum((r) => r.calc.employeePension)),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            _etb(sum((r) => r.calc.salaryAdvance)),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            _etb(sum((r) => r.calc.otherDeductions)),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            _etb(
                                              sum((r) => r.calc.totalStaffDeductions),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            _etb(sum((r) => r.calc.net)),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const DataCell(SizedBox.shrink()),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
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
                              'Recovered from net pay after PAYE and pension.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: WebErpTheme.cardDecoration(context),
                              child: WebErpHScroll(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Staff ID')),
                                    DataColumn(label: Text('Name')),
                                    DataColumn(label: Text('Job')),
                                    DataColumn(
                                      label: Text('Advance recovered'),
                                      numeric: true,
                                    ),
                                    DataColumn(
                                      label: Text('Net pay'),
                                      numeric: true,
                                    ),
                                  ],
                                  rows: [
                                    for (final row in advances)
                                      DataRow(
                                        cells: [
                                          DataCell(Text(row.person.personId)),
                                          DataCell(Text(row.person.fullName)),
                                          DataCell(Text(row.person.jobTitle)),
                                          DataCell(
                                            Text(_etb(row.calc.salaryAdvance)),
                                          ),
                                          DataCell(Text(_etb(row.calc.net))),
                                        ],
                                      ),
                                  ],
                                ),
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
                            Container(
                              decoration: WebErpTheme.cardDecoration(context),
                              child: WebErpHScroll(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Staff ID')),
                                    DataColumn(label: Text('Name')),
                                    DataColumn(label: Text('Job')),
                                    DataColumn(
                                      label: Text('Amount'),
                                      numeric: true,
                                    ),
                                    DataColumn(label: Text('Reason')),
                                    DataColumn(
                                      label: Text('Net pay'),
                                      numeric: true,
                                    ),
                                  ],
                                  rows: [
                                    for (final row in others)
                                      DataRow(
                                        cells: [
                                          DataCell(Text(row.person.personId)),
                                          DataCell(Text(row.person.fullName)),
                                          DataCell(Text(row.person.jobTitle)),
                                          DataCell(
                                            Text(_etb(row.calc.otherDeductions)),
                                          ),
                                          DataCell(
                                            Text(
                                              row.otherNote.isEmpty
                                                  ? 'Other'
                                                  : row.otherNote,
                                            ),
                                          ),
                                          DataCell(Text(_etb(row.calc.net))),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
              ),
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
}
