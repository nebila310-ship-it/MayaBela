import 'package:flutter/material.dart';

import 'package:mayabela/models/qa_finding.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/qa_findings_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/web_erp/pages/web_curriculum_page.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// EDUABA Quality Assurance desk (§2) — audit findings & improvement plans.
///
/// QA logs findings from audits (teaching quality, assessment integrity,
/// exam/grading process, Student Affairs fairness, policy compliance), issues
/// improvement plans with an owner and due date, and tracks resolution. The
/// metrics header is the quality report the Deputy GM / GM reads.
class WebQaPage extends StatefulWidget {
  const WebQaPage({super.key});

  @override
  State<WebQaPage> createState() => _WebQaPageState();
}

class _WebQaPageState extends State<WebQaPage> {
  String _statusFilter = 'open';
  QaFindingArea? _areaFilter;

  bool get _canManage => ModuleAccess.canManage('quality_assurance');
  String get _schoolId => AuthService.activeSchoolId ?? '';

  static const _ownerRoles = <(String, String)>[
    ('principal', 'Principal'),
    ('vice_president', 'Vice Principal'),
    ('section_director', 'Section Director'),
    ('student_affairs', 'Student Affairs'),
    ('registrar', 'Registrar'),
    ('accountant', 'Finance Manager'),
    ('human_resource', 'Human Resources'),
    ('transport_admin', 'Transport Head'),
    ('procurement', 'Procurement'),
    ('storekeeper', 'Store Keeper'),
  ];

  @override
  void initState() {
    super.initState();
    QaFindingsService.instance.ensureLoaded();
    CurriculumService.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    return ListenableBuilder(
      listenable: QaFindingsService.instance,
      builder: (context, _) {
        var findings = QaFindingsService.instance.forSchool(_schoolId);
        findings = switch (_statusFilter) {
          'open' => findings.where((f) => f.isOpen).toList(),
          'resolved' => findings.where((f) => !f.isOpen).toList(),
          _ => findings,
        };
        if (_areaFilter != null) {
          findings = findings.where((f) => f.area == _areaFilter).toList();
        }
        return SingleChildScrollView(
          padding: EdgeInsets.all(narrow ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quality Assurance', style: WebErpTheme.sectionTitle(context)),
              const SizedBox(height: 4),
              Text(
                'Audit findings & improvement plans — academic standards, '
                'assessment integrity, grading process, Student Affairs '
                'fairness, and policy compliance. Metrics report to the '
                'Deputy GM / General Manager.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              _metricsRow(context, narrow),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_canManage)
                    FilledButton.icon(
                      onPressed: () => _showNewFindingDialog(context),
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('New Finding'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => showCurriculumFeedbackDialog(context),
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Curriculum feedback'),
                  ),
                  for (final (value, label) in const [
                    ('open', 'Open'),
                    ('resolved', 'Resolved'),
                    ('all', 'All'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _statusFilter == value,
                      onSelected: (_) => setState(() => _statusFilter = value),
                    ),
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<QaFindingArea?>(
                      initialValue: _areaFilter,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Audit area',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(child: Text('All areas')),
                        for (final a in QaFindingArea.values)
                          DropdownMenuItem(
                            value: a,
                            child: Text(QaFinding.areaLabel(a)),
                          ),
                      ],
                      onChanged: (v) => setState(() => _areaFilter = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (findings.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: WebErpTheme.cardDecoration(context),
                  child: const Text('No QA findings in this view.'),
                )
              else
                for (final f in findings) _findingCard(context, f),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------- metrics

  Widget _metricsRow(BuildContext context, bool narrow) {
    final m = QaFindingsService.instance.metricsForSchool(_schoolId);
    final scheme = Theme.of(context).colorScheme;
    final cards = <(String, int, Color, Color)>[
      ('Open findings', m.open, scheme.primaryContainer, scheme.onPrimaryContainer),
      ('Critical', m.critical, scheme.errorContainer, scheme.onErrorContainer),
      ('Overdue plans', m.overdue, scheme.tertiaryContainer, scheme.onTertiaryContainer),
      ('Resolved', m.resolved, scheme.secondaryContainer, scheme.onSecondaryContainer),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (label, count, bg, fg) in cards)
          Container(
            width: narrow ? 150 : 180,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    color: fg,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label, style: TextStyle(color: fg, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------- cards

  Widget _findingCard(BuildContext context, QaFinding f) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(f.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              _chip(
                QaFinding.areaLabel(f.area),
                scheme.secondaryContainer,
                scheme.onSecondaryContainer,
              ),
              _severityChip(context, f.severity),
              _statusChip(context, f.status),
              if (f.isOverdue)
                _chip('Overdue', scheme.errorContainer, scheme.onErrorContainer),
            ],
          ),
          if (f.details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(f.details),
          ],
          if (f.improvementPlan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Improvement plan',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(f.improvementPlan),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Raised by ${f.raisedByName.isEmpty ? 'QA' : f.raisedByName}'
            ' • ${_dateLabel(f.createdAt)}'
            '${f.ownerRole.isNotEmpty ? ' • Owner: ${_ownerLabel(f.ownerRole)}' : ''}'
            '${f.dueDate != null ? ' • Due: ${_dateLabel(f.dueDate!)}' : ''}'
            '${f.resolvedAt != null ? ' • Resolved: ${_dateLabel(f.resolvedAt!)}' : ''}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          if (f.resolutionNotes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Resolution: ${f.resolutionNotes}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
          if (_canManage && f.isOpen) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (f.status == QaFindingStatus.open)
                  OutlinedButton.icon(
                    onPressed: () => QaFindingsService.instance.updateFinding(
                      f.id,
                      (cur) => cur.copyWith(status: QaFindingStatus.inReview),
                    ),
                    icon: const Icon(Icons.search),
                    label: const Text('Start Review'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: () => _showPlanDialog(context, f),
                  icon: const Icon(Icons.assignment_outlined),
                  label: Text(
                    f.improvementPlan.isEmpty
                        ? 'Issue Improvement Plan'
                        : 'Edit Improvement Plan',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showResolveDialog(context, f),
                  icon: const Icon(Icons.task_alt),
                  label: const Text('Mark Resolved'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );

  Widget _severityChip(BuildContext context, QaFindingSeverity s) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (s) {
      QaFindingSeverity.low => (scheme.surfaceContainerHighest, scheme.onSurface),
      QaFindingSeverity.medium =>
        (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      QaFindingSeverity.high =>
        (scheme.primaryContainer, scheme.onPrimaryContainer),
      QaFindingSeverity.critical =>
        (scheme.errorContainer, scheme.onErrorContainer),
    };
    return _chip(QaFinding.severityLabel(s), bg, fg);
  }

  Widget _statusChip(BuildContext context, QaFindingStatus s) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (s) {
      QaFindingStatus.open => (scheme.errorContainer, scheme.onErrorContainer),
      QaFindingStatus.inReview =>
        (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      QaFindingStatus.actionPlanned =>
        (scheme.primaryContainer, scheme.onPrimaryContainer),
      QaFindingStatus.resolved =>
        (scheme.secondaryContainer, scheme.onSecondaryContainer),
    };
    return _chip(QaFinding.statusLabel(s), bg, fg);
  }

  // -------------------------------------------------------------- dialogs

  Future<void> _showNewFindingDialog(BuildContext context) async {
    var area = QaFindingArea.academic;
    var severity = QaFindingSeverity.medium;
    String? ownerRole;
    DateTime? dueDate;
    final titleCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();
    final planCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New QA Finding'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<QaFindingArea>(
                    initialValue: area,
                    decoration: const InputDecoration(labelText: 'Audit area'),
                    items: [
                      for (final a in QaFindingArea.values)
                        DropdownMenuItem(
                          value: a,
                          child: Text(QaFinding.areaLabel(a)),
                        ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => area = v ?? QaFindingArea.academic),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<QaFindingSeverity>(
                    initialValue: severity,
                    decoration: const InputDecoration(labelText: 'Severity'),
                    items: [
                      for (final s in QaFindingSeverity.values)
                        DropdownMenuItem(
                          value: s,
                          child: Text(QaFinding.severityLabel(s)),
                        ),
                    ],
                    onChanged: (v) => setDialogState(
                      () => severity = v ?? QaFindingSeverity.medium,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Finding',
                      hintText: 'e.g. Grade 6 exam marking inconsistencies',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: detailsCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Details / evidence',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: planCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Improvement plan (optional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    initialValue: ownerRole,
                    decoration: const InputDecoration(
                      labelText: 'Plan owner (optional)',
                    ),
                    items: [
                      const DropdownMenuItem(child: Text('—')),
                      for (final (key, label) in _ownerRoles)
                        DropdownMenuItem(value: key, child: Text(label)),
                    ],
                    onChanged: (v) => setDialogState(() => ownerRole = v),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                        initialDate:
                            DateTime.now().add(const Duration(days: 14)),
                        helpText: 'Improvement plan due date',
                      );
                      if (picked != null) {
                        setDialogState(() => dueDate = picked);
                      }
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      dueDate == null
                          ? 'Set due date (optional)'
                          : 'Due ${_dateLabel(dueDate!)}',
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
              child: const Text('Log Finding'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || titleCtrl.text.trim().isEmpty) return;
    await QaFindingsService.instance.raiseFinding(
      area: area,
      title: titleCtrl.text,
      details: detailsCtrl.text,
      severity: severity,
      improvementPlan: planCtrl.text,
      ownerRole: ownerRole ?? '',
      dueDate: dueDate,
    );
  }

  Future<void> _showPlanDialog(BuildContext context, QaFinding f) async {
    final planCtrl = TextEditingController(text: f.improvementPlan);
    String? ownerRole = f.ownerRole.isEmpty ? null : f.ownerRole;
    DateTime? dueDate = f.dueDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Improvement Plan — ${f.title}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: planCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Improvement plan',
                    hintText: 'Corrective actions, training, re-checks…',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: ownerRole,
                  decoration: const InputDecoration(labelText: 'Plan owner'),
                  items: [
                    const DropdownMenuItem(child: Text('—')),
                    for (final (key, label) in _ownerRoles)
                      DropdownMenuItem(value: key, child: Text(label)),
                  ],
                  onChanged: (v) => setDialogState(() => ownerRole = v),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: dueDate ??
                          DateTime.now().add(const Duration(days: 14)),
                      helpText: 'Improvement plan due date',
                    );
                    if (picked != null) setDialogState(() => dueDate = picked);
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    dueDate == null
                        ? 'Set due date'
                        : 'Due ${_dateLabel(dueDate!)}',
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
              child: const Text('Save Plan'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || planCtrl.text.trim().isEmpty) return;
    await QaFindingsService.instance.updateFinding(
      f.id,
      (cur) => cur.copyWith(
        improvementPlan: planCtrl.text.trim(),
        ownerRole: ownerRole ?? '',
        dueDate: dueDate,
        status: QaFindingStatus.actionPlanned,
      ),
    );
  }

  Future<void> _showResolveDialog(BuildContext context, QaFinding f) async {
    final notesCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Resolve — ${f.title}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Resolution notes',
              hintText: 'What was verified / improved',
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
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    await QaFindingsService.instance.updateFinding(
      f.id,
      (cur) => cur.copyWith(
        status: QaFindingStatus.resolved,
        resolvedAt: DateTime.now(),
        resolutionNotes: notesCtrl.text.trim(),
      ),
    );
  }

  String _ownerLabel(String key) {
    for (final (k, label) in _ownerRoles) {
      if (k == key) return label;
    }
    return key;
  }

  String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
