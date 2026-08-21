import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/employee_registry_service.dart';
import 'package:mayabela/services/ethiopian_employment_tax.dart';
import 'package:mayabela/services/persistence/teacher_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/staff_registry_notifier.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

enum _PayrollKind { teacher, employee, driver }

class _PayrollPerson {
  const _PayrollPerson({
    required this.kind,
    required this.id,
    required this.fullName,
    required this.jobTitle,
    required this.basicSalaryEtb,
    required this.taxableAllowancesEtb,
  });

  final _PayrollKind kind;
  final String id;
  final String fullName;
  final String jobTitle;
  final double basicSalaryEtb;
  final double taxableAllowancesEtb;

  String get kindLabel => switch (kind) {
        _PayrollKind.teacher => 'Teacher / staff',
        _PayrollKind.employee => 'Other staff',
        _PayrollKind.driver => 'Driver',
      };
}

/// HR payroll: Ethiopian PAYE + pension for every school employee.
class WebHrPayrollTab extends StatefulWidget {
  const WebHrPayrollTab({super.key});

  @override
  State<WebHrPayrollTab> createState() => _WebHrPayrollTabState();
}

class _WebHrPayrollTabState extends State<WebHrPayrollTab> {
  String _query = '';
  final _calcBasic = TextEditingController(text: '12000');
  final _calcAllowances = TextEditingController(text: '0');

  @override
  void dispose() {
    _calcBasic.dispose();
    _calcAllowances.dispose();
    super.dispose();
  }

  List<_PayrollPerson> _people(String? schoolId) {
    final teachers = TeacherRegistryService.instance
        .teachersForSchool(schoolId ?? '', includeInactive: false)
        .map(
          (t) => _PayrollPerson(
            kind: _PayrollKind.teacher,
            id: t.teacherId,
            fullName: t.fullName,
            jobTitle: t.subject.isEmpty ? 'Classroom teacher' : t.subject,
            basicSalaryEtb: t.basicSalaryEtb,
            taxableAllowancesEtb: t.taxableAllowancesEtb,
          ),
        );
    final employees = EmployeeRegistryService.instance
        .employeesForSchool(schoolId)
        .map(
          (e) => _PayrollPerson(
            kind: _PayrollKind.employee,
            id: e.employeeId,
            fullName: e.fullName,
            jobTitle: e.jobTitle,
            basicSalaryEtb: e.basicSalaryEtb,
            taxableAllowancesEtb: e.taxableAllowancesEtb,
          ),
        );
    final drivers = DriverRegistryService.instance
        .driversForSchool(schoolId)
        .map(
          (d) => _PayrollPerson(
            kind: _PayrollKind.driver,
            id: d.driverId,
            fullName: d.fullName,
            jobTitle: 'Driver · ${d.busNumber}',
            basicSalaryEtb: d.basicSalaryEtb,
            taxableAllowancesEtb: d.taxableAllowancesEtb,
          ),
        );
    var all = [...teachers, ...employees, ...drivers];
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      all = all
          .where(
            (p) =>
                p.fullName.toLowerCase().contains(q) ||
                p.jobTitle.toLowerCase().contains(q) ||
                p.id.toLowerCase().contains(q) ||
                p.kindLabel.toLowerCase().contains(q),
          )
          .toList();
    }
    all.sort((a, b) => a.fullName.compareTo(b.fullName));
    return all;
  }

  Future<void> _editPay(_PayrollPerson person) async {
    if (!ModuleAccess.canHireStaff) return;
    final basic = TextEditingController(
      text: person.basicSalaryEtb == 0
          ? ''
          : person.basicSalaryEtb.toStringAsFixed(2),
    );
    final allow = TextEditingController(
      text: person.taxableAllowancesEtb == 0
          ? ''
          : person.taxableAllowancesEtb.toStringAsFixed(2),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Set pay · ${person.fullName}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${person.kindLabel} · ${person.id}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: basic,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Basic salary (ETB / month)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: allow,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Taxable allowances (ETB)',
                    border: OutlineInputBorder(),
                    helperText:
                        'Pension is 7% employee + 11% employer of basic salary. '
                        'Income tax uses ${EthiopianEmploymentTax.proclamation}.',
                    helperMaxLines: 3,
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
              child: const Text('Save pay'),
            ),
          ],
        );
      },
    );
    final basicVal = EthiopianEmploymentTax.parseEtb(basic.text);
    final allowVal = EthiopianEmploymentTax.parseEtb(allow.text);
    basic.dispose();
    allow.dispose();
    if (saved != true) return;

    switch (person.kind) {
      case _PayrollKind.teacher:
        final existing =
            TeacherRegistryService.instance.lookupById(person.id);
        if (existing == null) return;
        TeacherRegistryService.instance.updateTeacher(
          existing.copyWith(
            basicSalaryEtb: basicVal,
            taxableAllowancesEtb: allowVal,
          ),
        );
        await TeacherPersistenceService.instance.saveRegistryFromService(
          syncTeacherId: existing.teacherId,
        );
      case _PayrollKind.employee:
        final existing =
            EmployeeRegistryService.instance.lookupById(person.id);
        if (existing == null) return;
        EmployeeRegistryService.instance.updateEmployee(
          existing.copyWith(
            basicSalaryEtb: basicVal,
            taxableAllowancesEtb: allowVal,
          ),
        );
      case _PayrollKind.driver:
        final existing =
            DriverRegistryService.instance.lookupById(person.id);
        if (existing == null) return;
        DriverRegistryService.instance.updateDriver(
          existing.copyWith(
            basicSalaryEtb: basicVal,
            taxableAllowancesEtb: allowVal,
          ),
        );
    }
    if (mounted) setState(() {});
  }

  String _etb(double value) {
    final n = value.round();
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return 'ETB ${n < 0 ? '-' : ''}$buf';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        EmployeeRegistryService.instance,
        StaffRegistryNotifier.instance,
      ]),
      builder: (context, _) {
        final schoolId = AuthService.activeSchoolId;
        final people = _people(schoolId);
        final slips = [
          for (final p in people)
            EthiopianEmploymentTax.calculate(
              basicSalaryEtb: p.basicSalaryEtb,
              taxableAllowancesEtb: p.taxableAllowancesEtb,
            ),
        ];
        var netTotal = 0.0;
        var taxTotal = 0.0;
        var empPension = 0.0;
        var erPension = 0.0;
        for (final s in slips) {
          netTotal += s.netPayEtb;
          taxTotal += s.incomeTaxEtb;
          empPension += s.employeePensionEtb;
          erPension += s.employerPensionEtb;
        }
        final calc = EthiopianEmploymentTax.calculate(
          basicSalaryEtb: EthiopianEmploymentTax.parseEtb(_calcBasic.text),
          taxableAllowancesEtb:
              EthiopianEmploymentTax.parseEtb(_calcAllowances.text),
        );
        final canHire = ModuleAccess.canHireStaff;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search teachers, staff, drivers…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _kpi('Employees', '${people.length}'),
                        _kpi('Net this month', _etb(netTotal)),
                        _kpi('PAYE withheld', _etb(taxTotal)),
                        _kpi('Employee pension 7%', _etb(empPension)),
                        _kpi('Employer pension 11%', _etb(erPension)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Built-in calculator for Ethiopian employment tax '
                      '(${EthiopianEmploymentTax.proclamation}) and private-sector '
                      'pension for every Fenote Raey employee — teachers, other '
                      'staff, and drivers. Rates can change; confirm against current law.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: people.isEmpty
                          ? Center(
                              child: Text(
                                'No employees yet. Add teachers, other staff, '
                                'or drivers first.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStatePropertyAll(
                                  WebErpTheme.primary.withValues(alpha: 0.08),
                                ),
                                columns: const [
                                  DataColumn(label: Text('Name')),
                                  DataColumn(label: Text('Role')),
                                  DataColumn(
                                    label: Text('Basic'),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text('Pension 7%'),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text('PAYE'),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text('Net'),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text('ER 11%'),
                                    numeric: true,
                                  ),
                                ],
                                rows: [
                                  for (var i = 0; i < people.length; i++)
                                    DataRow(
                                      cells: [
                                        DataCell(
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                people[i].fullName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                people[i].id,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          onTap: canHire
                                              ? () => _editPay(people[i])
                                              : null,
                                        ),
                                        DataCell(Text(people[i].kindLabel)),
                                        DataCell(
                                          Text(_etb(people[i].basicSalaryEtb)),
                                        ),
                                        DataCell(
                                          Text(_etb(slips[i].employeePensionEtb)),
                                        ),
                                        DataCell(
                                          Text(
                                            '${_etb(slips[i].incomeTaxEtb)}'
                                            ' (${slips[i].incomeTaxPercent}%)',
                                          ),
                                        ),
                                        DataCell(Text(_etb(slips[i].netPayEtb))),
                                        DataCell(
                                          Text(_etb(slips[i].employerPensionEtb)),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 320,
                child: Container(
                  decoration: WebErpTheme.cardDecoration(context),
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What-if calculator',
                          style: WebErpTheme.sectionTitle(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          EthiopianEmploymentTax.proclamation,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _calcBasic,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Basic salary ETB',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _calcAllowances,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Taxable allowances ETB',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        _calcRow('Employee pension 7%', calc.employeePensionEtb),
                        _calcRow('Taxable income', calc.taxableIncomeEtb),
                        _calcRow(
                          'Income tax (${calc.incomeTaxPercent}%)',
                          calc.incomeTaxEtb,
                        ),
                        _calcRow('Net pay', calc.netPayEtb, emphasize: true),
                        const Divider(height: 24),
                        _calcRow('Employer pension 11%', calc.employerPensionEtb),
                        _calcRow('Employer cost', calc.employerCostEtb),
                        const SizedBox(height: 12),
                        Text(
                          'Monthly bands: 0–2,000 0% · 2,001–4,000 15% · '
                          '4,001–7,000 20% · 7,001–10,000 25% · '
                          '10,001–14,000 30% · over 14,000 35%.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kpi(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: WebErpTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _calcRow(String label, double value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            _etb(value),
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: emphasize ? WebErpTheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
