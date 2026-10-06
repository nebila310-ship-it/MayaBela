import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/models/payroll_models.dart';
import 'package:mayabela/services/ethiopia_payroll_tax.dart';
import 'package:mayabela/services/payroll_export_service.dart';
import 'package:mayabela/services/payroll_service.dart';
import 'package:mayabela/theme/classroom_palette.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

enum _PayrollEditField { basic, advance, other }

class _PayrollDraft {
  _PayrollDraft({
    required this.basic,
    required this.advance,
    required this.other,
  });

  double basic;
  double advance;
  double other;
}

class WebPayrollPage extends StatefulWidget {
  const WebPayrollPage({super.key, this.embedded = false});

  final bool embedded;

  /// Employees shown on one register page so the list stays on-screen.
  static const registerPageSize = 10;

  @override
  State<WebPayrollPage> createState() => _WebPayrollPageState();
}

class _WebPayrollPageState extends State<WebPayrollPage> {
  static const _tabular = FontFeature.tabularFigures();

  String _query = '';
  late String _periodYm;
  late final TextEditingController _periodController;
  var _exporting = false;
  var _page = 0;

  String? _editPersonId;
  _PayrollEditField? _editField;
  final Map<String, _PayrollDraft> _drafts = {};
  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocus = FocusNode();
  var _committing = false;
  var _suppressFocusCommit = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodYm = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _periodController = TextEditingController(text: _periodYm);
    _editFocus.addListener(_onEditFocusChange);
    PayrollService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    _editFocus.removeListener(_onEditFocusChange);
    _editFocus.dispose();
    _editController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  void _onEditFocusChange() {
    if (_suppressFocusCommit || _editFocus.hasFocus || _editPersonId == null) {
      return;
    }
    _commitEdit();
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

  double _parseMoney(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '')) ?? 0;

  EthiopianPayslipBreakdown _calcFor(PayrollRegisterRow row) {
    final draft = _drafts[row.person.profileId];
    if (draft == null) return row.calc;
    return EthiopianPayrollTax.breakdown(
      basicSalary: draft.basic,
      taxableAllowances: row.profile?.taxableAllowances ?? 0,
      exemptAllowances: row.profile?.exemptAllowances ?? 0,
      salaryAdvance: draft.advance,
      otherDeductions: draft.other,
      pensionEligible: row.profile?.pensionEligible ?? true,
    );
  }

  _PayrollDraft _draftFor(PayrollRegisterRow row) {
    return _drafts.putIfAbsent(row.person.profileId, () {
      final calc = row.calc;
      return _PayrollDraft(
        basic: calc.basicSalary,
        advance: calc.salaryAdvance,
        other: calc.otherDeductions,
      );
    });
  }

  double _draftValue(_PayrollDraft draft, _PayrollEditField field) {
    return switch (field) {
      _PayrollEditField.basic => draft.basic,
      _PayrollEditField.advance => draft.advance,
      _PayrollEditField.other => draft.other,
    };
  }

  void _writeDraft(_PayrollDraft draft, _PayrollEditField field, double value) {
    switch (field) {
      case _PayrollEditField.basic:
        draft.basic = EthiopianPayrollTax.money(value);
      case _PayrollEditField.advance:
        draft.advance = EthiopianPayrollTax.money(value);
      case _PayrollEditField.other:
        draft.other = EthiopianPayrollTax.money(value);
    }
  }

  Future<void> _beginEdit(
    PayrollRegisterRow row,
    _PayrollEditField field,
  ) async {
    if (!PayrollService.instance.canManage) return;
    final id = row.person.profileId;
    if (_editPersonId == id && _editField == field) return;
    _suppressFocusCommit = true;
    try {
      if (_editPersonId != null && _editPersonId != id) {
        await _commitEdit();
      }
      PayrollRegisterRow latest = row;
      for (final item in PayrollService.instance.registerRows()) {
        if (item.person.profileId == id) {
          latest = item;
          break;
        }
      }
      final draft = _draftFor(latest);
      final value = _draftValue(draft, field);
      _editController.value = TextEditingValue(
        text: value == 0 ? '' : value.toStringAsFixed(2),
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: value == 0 ? 0 : value.toStringAsFixed(2).length,
        ),
      );
      setState(() {
        _editPersonId = id;
        _editField = field;
      });
    } catch (_) {
      _suppressFocusCommit = false;
      rethrow;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editPersonId == id && _editField == field) {
        _editFocus.requestFocus();
      }
      _suppressFocusCommit = false;
    });
  }

  void _onEditChanged(String raw) {
    final id = _editPersonId;
    final field = _editField;
    if (id == null || field == null) return;
    final draft = _drafts[id];
    if (draft == null) return;
    _writeDraft(draft, field, _parseMoney(raw));
    setState(() {});
  }

  Future<void> _commitEdit() async {
    if (_committing) return;
    final id = _editPersonId;
    final field = _editField;
    if (id == null || field == null) return;
    final draft = _drafts[id];
    if (draft == null) {
      setState(() {
        _editPersonId = null;
        _editField = null;
      });
      return;
    }
    _committing = true;
    final svc = PayrollService.instance;
    PayrollRegisterRow? row;
    for (final item in svc.registerRows()) {
      if (item.person.profileId == id) {
        row = item;
        break;
      }
    }
    try {
      if (row != null && svc.canManage) {
        final saved = row.profile;
        final unchanged = saved != null &&
            EthiopianPayrollTax.money(saved.basicSalary) == draft.basic &&
            EthiopianPayrollTax.money(saved.salaryAdvance) == draft.advance &&
            EthiopianPayrollTax.money(saved.otherDeductions) == draft.other;
        final emptyNew = saved == null &&
            draft.basic == 0 &&
            draft.advance == 0 &&
            draft.other == 0;
        if (!unchanged && !emptyNew) {
          await svc.upsertProfile(
            person: row.person,
            basicSalary: draft.basic,
            taxableAllowances: saved?.taxableAllowances ?? 0,
            exemptAllowances: saved?.exemptAllowances ?? 0,
            salaryAdvance: draft.advance,
            otherDeductions: draft.other,
            otherDeductionNote: saved?.otherDeductionNote ?? '',
            pensionEligible: saved?.pensionEligible ?? true,
            notes: saved?.notes ?? '',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _editPersonId = null;
          _editField = null;
        });
      } else {
        _editPersonId = null;
        _editField = null;
      }
      _committing = false;
    }
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
        final live = [
          for (final row in rows) (row: row, calc: _calcFor(row)),
        ];
        final paid = live.where((r) => r.calc.basicSalary > 0).toList();
        final advances = live.where((r) => r.calc.salaryAdvance > 0).toList();
        final others = live.where((r) => r.calc.otherDeductions > 0).toList();
        final latest = svc.latestRun();
        final canManage = svc.canManage;
        double sum(double Function(EthiopianPayslipBreakdown c) pick) =>
            EthiopianPayrollTax.money(
              paid.fold(0.0, (s, r) => s + pick(r.calc)),
            );

        final pageRows = _pageSlice(rows);
        final totalNet = sum((c) => c.net);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.embedded)
                Text('Payroll', style: WebErpTheme.sectionTitle(context)),
              Text(
                'Click Basic, Advance, or Other deduct to type. Income tax and '
                'the 7% staff pension update themselves. The school 11% pension '
                'is not taken from net pay.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                      letterSpacing: -0.1,
                    ),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Ethiopian income tax monthly schedule (1395/2025)',
                ),
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
                  _stat('Gross', _etb(sum((c) => c.gross))),
                  _stat('Income tax', _etb(sum((c) => c.paye))),
                  _stat(
                    'Staff deductions',
                    _etb(sum((c) => c.totalStaffDeductions)),
                  ),
                  _stat('Net pay', _etb(totalNet), highlight: true),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                ),
                Text(
                  'Amounts in ETB. Click a highlighted cell to edit. '
                  'Every column stays on this page.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                _fitCard(
                  child: _fitTable(
                    key: const ValueKey('payroll-register-table'),
                    columnWeights: const [
                      1.15, 1.7, 1.3, 1.05, 1.0, 1.05, 1.15, 1.0, 1.1, 1.1, 1.25,
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
                    ],
                    numeric: const {3, 4, 5, 6, 7, 8, 9, 10},
                    editableHeaders: canManage ? const {3, 7, 8} : const {},
                    headerHints: const {
                      3: 'Click to edit basic salary',
                      6: '7% of basic · school adds 11% (not from net)',
                      7: 'Click to edit salary advance',
                      8: 'Click to edit other deduction',
                      10: 'Gross − tax − 7% pension − advance − other',
                    },
                    rows: [
                      for (final row in pageRows)
                        _registerRow(row, canManage: canManage),
                      if (paid.isNotEmpty)
                        [
                          _cell(''),
                          _cell(
                            'TOTAL',
                            emphasize: true,
                            color: ClassroomPalette.teal,
                            letterSpacing: 0.8,
                          ),
                          _cell(
                            '${paid.length} staff',
                            color: ClassroomPalette.muted,
                          ),
                          _moneyText(sum((c) => c.basicSalary)),
                          _moneyText(sum((c) => c.gross)),
                          _moneyText(sum((c) => c.paye), color: ClassroomPalette.orange),
                          _moneyText(
                            sum((c) => c.employeePension),
                            color: ClassroomPalette.purple,
                          ),
                          _moneyText(sum((c) => c.salaryAdvance)),
                          _moneyText(sum((c) => c.otherDeductions)),
                          _moneyText(sum((c) => c.totalStaffDeductions)),
                          _totalPayableCell(totalNet),
                        ],
                    ],
                    rowDecorations: [
                      for (var i = 0; i < pageRows.length; i++)
                        i.isOdd
                            ? const BoxDecoration(color: Color(0xFFF8FBFA))
                            : null,
                      if (paid.isNotEmpty)
                        const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFE0F2F1),
                              Color(0xFFFFF8E1),
                              Color(0xFFE8F5E9),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                _pager(total: rows.length),
                if (advances.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Salary advances',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
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
                        for (final item in advances)
                          [
                            _cell(item.row.person.personId),
                            _cell(item.row.person.fullName, emphasize: true),
                            _cell(item.row.person.jobTitle),
                            _moneyText(item.calc.salaryAdvance),
                            _moneyText(
                              item.calc.net,
                              emphasize: true,
                              color: ClassroomPalette.green,
                            ),
                          ],
                      ],
                    ),
                  ),
                ],
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Other deductions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
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
                        for (final item in others)
                          [
                            _cell(item.row.person.personId),
                            _cell(item.row.person.fullName, emphasize: true),
                            _cell(item.row.person.jobTitle),
                            _moneyText(item.calc.otherDeductions),
                            _cell(
                              item.row.otherNote.isEmpty
                                  ? 'Other'
                                  : item.row.otherNote,
                            ),
                            _moneyText(
                              item.calc.net,
                              emphasize: true,
                              color: ClassroomPalette.green,
                            ),
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

  List<Widget> _registerRow(
    PayrollRegisterRow row, {
    required bool canManage,
  }) {
    final calc = _calcFor(row);
    return [
      _cell(row.person.personId, color: ClassroomPalette.muted),
      _cell(
        row.person.fullName,
        emphasize: true,
        muted: !row.person.isActive,
        strike: !row.person.isActive,
        letterSpacing: -0.2,
      ),
      _cell(row.person.jobTitle),
      _editableAmount(
        row: row,
        field: _PayrollEditField.basic,
        value: calc.basicSalary,
        canManage: canManage,
      ),
      _moneyText(calc.gross),
      _moneyText(calc.paye, color: ClassroomPalette.orange),
      Tooltip(
        message: calc.pensionEligible
            ? '7% of basic · locked'
            : 'Pension off for this staff member',
        child: KeyedSubtree(
          key: ValueKey('payroll-cell-pension-${row.person.personId}'),
          child: _moneyText(
            calc.employeePension,
            color: ClassroomPalette.purple,
          ),
        ),
      ),
      _editableAmount(
        row: row,
        field: _PayrollEditField.advance,
        value: calc.salaryAdvance,
        canManage: canManage,
      ),
      _editableAmount(
        row: row,
        field: _PayrollEditField.other,
        value: calc.otherDeductions,
        canManage: canManage,
      ),
      _moneyText(calc.totalStaffDeductions),
      KeyedSubtree(
        key: ValueKey('payroll-net-${row.person.personId}'),
        child: _moneyText(
          calc.net,
          emphasize: true,
          color: ClassroomPalette.green,
        ),
      ),
    ];
  }

  Widget _editableAmount({
    required PayrollRegisterRow row,
    required _PayrollEditField field,
    required double value,
    required bool canManage,
  }) {
    final personId = row.person.personId;
    final cellKey = switch (field) {
      _PayrollEditField.basic => 'payroll-cell-basic-$personId',
      _PayrollEditField.advance => 'payroll-cell-advance-$personId',
      _PayrollEditField.other => 'payroll-cell-other-$personId',
    };
    final inputKey = switch (field) {
      _PayrollEditField.basic => 'payroll-input-basic-$personId',
      _PayrollEditField.advance => 'payroll-input-advance-$personId',
      _PayrollEditField.other => 'payroll-input-other-$personId',
    };
    final editing =
        _editPersonId == row.person.profileId && _editField == field;
    if (!canManage) {
      return KeyedSubtree(
        key: ValueKey(cellKey),
        child: _moneyText(value),
      );
    }
    if (editing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: SizedBox(
          height: 34,
          child: TextField(
            key: ValueKey(inputKey),
            controller: _editController,
            focusNode: _editFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.15,
              height: 1.2,
              fontFeatures: [_tabular],
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              filled: true,
              fillColor: const Color(0xFFE0F2F1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ClassroomPalette.teal),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ClassroomPalette.teal),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: ClassroomPalette.teal,
                  width: 1.6,
                ),
              ),
            ),
            onChanged: _onEditChanged,
            onSubmitted: (_) => _commitEdit(),
          ),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey(cellKey),
        onTap: () => _beginEdit(row, field),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFB2DFDB)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                _amount(value),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.15,
                  color: value == 0
                      ? ClassroomPalette.muted
                      : ClassroomPalette.ink,
                  fontFeatures: const [_tabular],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _moneyText(
    num value, {
    bool emphasize = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        _amount(value),
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.2,
          fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
          letterSpacing: -0.15,
          color: color,
          fontFeatures: const [_tabular],
        ),
      ),
    );
  }

  Widget _totalPayableCell(double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: DecoratedBox(
        key: const ValueKey('payroll-total-net'),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00897B), Color(0xFF1E8E3E), Color(0xFFF9AB00)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: ClassroomPalette.teal.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            _amount(value),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              fontFeatures: [_tabular],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, {bool highlight = false}) {
    if (!highlight) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ClassroomPalette.muted,
              fontSize: 11.5,
              letterSpacing: 0.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: -0.3,
              fontFeatures: [_tabular],
            ),
          ),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF1E8E3E)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: ClassroomPalette.green.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 10.5,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.3,
                fontFeatures: [_tabular],
              ),
            ),
          ],
        ),
      ),
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
    Set<int> editableHeaders = const {},
    Map<int, String> headerHints = const {},
    List<BoxDecoration?> rowDecorations = const [],
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
          color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
        ),
      ),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF3F6F5)),
          children: [
            for (var i = 0; i < headers.length; i++)
              _headerCell(
                headers[i],
                numeric: numeric.contains(i),
                editable: editableHeaders.contains(i),
                hint: headerHints[i],
              ),
          ],
        ),
        for (var r = 0; r < rows.length; r++)
          TableRow(
            decoration: r < rowDecorations.length ? rowDecorations[r] : null,
            children: rows[r],
          ),
      ],
    );
  }

  Widget _headerCell(
    String text, {
    bool numeric = false,
    bool editable = false,
    String? hint,
  }) {
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
      child: Text(
        text,
        textAlign: numeric ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 10.5,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.25,
          color: editable ? ClassroomPalette.teal : ClassroomPalette.muted,
        ),
      ),
    );
    if (hint == null) return label;
    return Tooltip(message: hint, child: label);
  }

  Widget _cell(
    String text, {
    bool header = false,
    bool numeric = false,
    bool emphasize = false,
    bool muted = false,
    bool strike = false,
    Color? color,
    double? letterSpacing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        textAlign: numeric ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: header ? 10.5 : 12.5,
          height: 1.25,
          fontWeight: header || emphasize ? FontWeight.w800 : FontWeight.w500,
          letterSpacing: letterSpacing ?? (header ? 0.2 : -0.15),
          color: color ?? (muted ? ClassroomPalette.muted : ClassroomPalette.ink),
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
