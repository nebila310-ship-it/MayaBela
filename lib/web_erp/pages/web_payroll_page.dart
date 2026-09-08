import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/models/payroll_models.dart';
import 'package:mayabela/services/ethiopia_payroll_tax.dart';
import 'package:mayabela/services/payroll_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodYm =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _periodController = TextEditingController(text: _periodYm);
    PayrollService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  String _etb(num value) {
    final n = value.toDouble();
    final whole = n.truncate();
    final cents = ((n - whole) * 100).round().abs();
    final digits = whole.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    final sign = n < 0 ? '-' : '';
    return '$sign${buf.toString()}.${cents.toString().padLeft(2, '0')} ETB';
  }

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
              pensionEligible: pension,
            );
            return AlertDialog(
              title: Text(person.fullName),
              content: SizedBox(
                width: 460,
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
                      TextField(
                        controller: basic,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Basic salary (ETB / month)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocal(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: taxable,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Taxable allowances (ETB)',
                          helperText: 'Overtime, taxable benefits — added to PAYE base',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocal(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: exempt,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Tax-exempt allowances (ETB)',
                          helperText: 'Paid to staff but not added to PAYE',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocal(() {}),
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
                        'Net ${_etb(preview.net)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        preview.band.label,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
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
        pensionEligible: pension,
      );
    }
    basic.dispose();
    taxable.dispose();
    exempt.dispose();
  }

  Future<void> _runPayroll() async {
    final svc = PayrollService.instance;
    try {
      final run = await svc.runPayroll(periodYm: _periodYm);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payroll ${_periodYm}: ${run.slips.length} slips · '
            'PAYE ${_etb(run.totalPaye)} to MoR · '
            'pension ${_etb(run.totalEmployeePension + run.totalEmployerPension)} to POESSA',
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PayrollService.instance,
      builder: (context, _) {
        final svc = PayrollService.instance;
        var people = svc.peopleForSchool();
        if (_query.isNotEmpty) {
          final q = _query.toLowerCase();
          people = people
              .where(
                (p) =>
                    p.fullName.toLowerCase().contains(q) ||
                    p.personId.toLowerCase().contains(q) ||
                    p.jobTitle.toLowerCase().contains(q),
              )
              .toList();
        }
        final latest = svc.latestRun();
        final canManage = svc.canManage;

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
                  const ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'POESSA: 7% employee + 11% school on basic only. '
                      'Pension is not deducted before PAYE.',
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
                ],
              ),
              if (latest != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _stat('Last run', latest.periodYm),
                    _stat('PAYE (MoR)', _etb(latest.totalPaye)),
                    _stat(
                      'Pension (POESSA)',
                      _etb(
                        latest.totalEmployeePension + latest.totalEmployerPension,
                      ),
                    ),
                    _stat('Net pay', _etb(latest.totalNet)),
                    _stat('Slips', '${latest.slips.length}'),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: people.isEmpty
                    ? Center(
                        child: Text(
                          'Add teachers, other staff, or drivers in HR first.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        itemCount: people.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final person = people[index];
                          final calc = svc.previewFor(person);
                          final hasSalary = calc.basicSalary > 0;
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                person.fullName.isEmpty
                                    ? '?'
                                    : person.fullName[0].toUpperCase(),
                              ),
                            ),
                            title: Text(
                              person.fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: person.isActive ? null : Colors.grey,
                                decoration: person.isActive
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                            subtitle: Text(
                              hasSalary
                                  ? '${person.personId} · ${person.kind.name} · '
                                      'Basic ${_etb(calc.basicSalary)} · '
                                      'PAYE ${_etb(calc.paye)} · '
                                      'Net ${_etb(calc.net)}'
                                  : '${person.personId} · ${person.kind.name} · '
                                      '${person.jobTitle} · salary not set',
                            ),
                            isThreeLine: true,
                            trailing: canManage
                                ? TextButton(
                                    onPressed: () => _edit(person),
                                    child: Text(hasSalary ? 'Edit' : 'Set salary'),
                                  )
                                : null,
                            onTap: canManage ? () => _edit(person) : null,
                          );
                        },
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
