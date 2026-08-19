import 'package:flutter/material.dart';

import 'package:mayabela/models/discipline_case.dart';
import 'package:mayabela/models/leave_request.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/discipline_service.dart';
import 'package:mayabela/services/leave_request_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// EDUABA Student Affairs desk — discipline / behaviour cases and
/// parent leave requests, per the Student Affairs branch spec.
class WebStudentAffairsPage extends StatefulWidget {
  const WebStudentAffairsPage({super.key});

  @override
  State<WebStudentAffairsPage> createState() => _WebStudentAffairsPageState();
}

class _WebStudentAffairsPageState extends State<WebStudentAffairsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  String _caseFilter = 'open';
  String _leaveFilter = 'pending';

  bool get _canManage => ModuleAccess.canManage('student_affairs');
  String get _schoolId => AuthService.activeSchoolId ?? '';

  @override
  void initState() {
    super.initState();
    DisciplineService.instance.ensureLoaded();
    LeaveRequestService.instance.ensureLoaded();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(narrow ? 12 : 20, narrow ? 12 : 20, narrow ? 12 : 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student Affairs', style: WebErpTheme.sectionTitle(context)),
              const SizedBox(height: 4),
              Text(
                'Behaviour & incident cases (investigation → hearing → outcome) '
                'and parent leave requests.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Discipline Cases'),
                  Tab(text: 'Leave Requests'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildCasesTab(context, narrow),
              _buildLeaveTab(context, narrow),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- cases

  Widget _buildCasesTab(BuildContext context, bool narrow) {
    return ListenableBuilder(
      listenable: DisciplineService.instance,
      builder: (context, _) {
        final all = DisciplineService.instance.forSchool(_schoolId);
        var cases = all;
        cases = switch (_caseFilter) {
          'open' => cases.where((c) => c.isOpen).toList(),
          'resolved' => cases.where((c) => !c.isOpen).toList(),
          _ => cases,
        };
        return SingleChildScrollView(
          padding: EdgeInsets.all(narrow ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _casesSummaryRow(context, all, narrow),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_canManage)
                    FilledButton.icon(
                      onPressed: () => _showFileReportDialog(context),
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('File Report'),
                    ),
                  for (final (value, label) in const [
                    ('open', 'Open'),
                    ('resolved', 'Closed'),
                    ('all', 'All'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _caseFilter == value,
                      onSelected: (_) => setState(() => _caseFilter = value),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (cases.isEmpty)
                _emptyCard(context, 'No discipline cases in this view.')
              else
                for (final c in cases) _caseCard(context, c),
            ],
          ),
        );
      },
    );
  }

  /// EDUABA §1A "Generates Discipline & Student Affairs Reports" — the
  /// at-a-glance numbers leadership reads from this desk.
  Widget _casesSummaryRow(
    BuildContext context,
    List<DisciplineCase> all,
    bool narrow,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final open = all.where((c) => c.isOpen).length;
    final hearings = all
        .where((c) => c.status == DisciplineCaseStatus.hearingScheduled)
        .length;
    final escalated =
        all.where((c) => c.status == DisciplineCaseStatus.escalated).length;
    final resolved = all.where((c) => !c.isOpen).length;
    final cards = <(String, int, Color, Color)>[
      ('Open cases', open, scheme.primaryContainer, scheme.onPrimaryContainer),
      ('Hearings', hearings, scheme.tertiaryContainer, scheme.onTertiaryContainer),
      ('Escalated', escalated, scheme.errorContainer, scheme.onErrorContainer),
      ('Closed', resolved, scheme.secondaryContainer, scheme.onSecondaryContainer),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (label, count, bg, fg) in cards)
          Container(
            width: narrow ? 140 : 170,
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
                    fontSize: 22,
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

  Widget _caseCard(BuildContext context, DisciplineCase c) {
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
              Text(
                '${c.studentName} — ${c.className}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              _chip(
                c.kind == DisciplineCaseKind.behaviour
                    ? 'Behaviour report'
                    : 'Incident report',
                scheme.secondaryContainer,
                scheme.onSecondaryContainer,
              ),
              _statusChip(context, c.status),
              if (c.outcome != DisciplineOutcome.none)
                _chip(
                  'Outcome: ${c.outcome.name}',
                  scheme.tertiaryContainer,
                  scheme.onTertiaryContainer,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (c.description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(c.description),
          ],
          const SizedBox(height: 6),
          Text(
            'Reported by ${c.reporterName}'
            '${c.hearingAt != null ? ' • Hearing: ${_dateLabel(c.hearingAt!)}${c.parentInvited ? ' (parent invited)' : ''}' : ''}'
            '${c.escalatedTo.isNotEmpty ? ' • Escalated to ${c.escalatedTo == 'principal' ? 'Principal' : 'Vice Principal'}' : ''}'
            '${c.handledByName.isNotEmpty ? ' • Handled by ${c.handledByName}' : ''}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          if (c.outcomeNotes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Notes: ${c.outcomeNotes}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ],
          if (_canManage && c.isOpen) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (c.status == DisciplineCaseStatus.submitted)
                  OutlinedButton.icon(
                    onPressed: () => _updateStatus(
                      c,
                      DisciplineCaseStatus.investigating,
                    ),
                    icon: const Icon(Icons.search),
                    label: const Text('Start Investigation'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _showScheduleHearingDialog(context, c),
                  icon: const Icon(Icons.gavel_outlined),
                  label: const Text('Schedule Hearing'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _showOutcomeDialog(context, c),
                  icon: const Icon(Icons.rule_outlined),
                  label: const Text('Record Outcome'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showEscalateDialog(context, c),
                  icon: const Icon(Icons.trending_up),
                  label: const Text('Escalate'),
                ),
                TextButton.icon(
                  onPressed: () => _dismissCase(c),
                  icon: const Icon(Icons.close),
                  label: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateStatus(
    DisciplineCase c,
    DisciplineCaseStatus status,
  ) async {
    await DisciplineService.instance.updateCase(
      c.id,
      (cur) => cur.copyWith(status: status),
    );
  }

  Future<void> _dismissCase(DisciplineCase c) async {
    await DisciplineService.instance.updateCase(
      c.id,
      (cur) => cur.copyWith(status: DisciplineCaseStatus.dismissed),
      notifyParent: true,
    );
  }

  Future<void> _showFileReportDialog(BuildContext context) async {
    final students = StudentRegistryService.instance
        .getAllStudents()
        .where((s) =>
            s.isActive &&
            (_schoolId.isEmpty ||
                s.schoolId.trim().toUpperCase() == _schoolId.toUpperCase()))
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active students found.')),
      );
      return;
    }

    String? studentId = students.first.studentId;
    var kind = DisciplineCaseKind.behaviour;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('File Student Affairs Report'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: studentId,
                    decoration: const InputDecoration(labelText: 'Student'),
                    items: [
                      for (final s in students)
                        DropdownMenuItem(
                          value: s.studentId,
                          child: Text('${s.fullName} (${s.className})'),
                        ),
                    ],
                    onChanged: (v) => setDialogState(() => studentId = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<DisciplineCaseKind>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Report type'),
                    items: const [
                      DropdownMenuItem(
                        value: DisciplineCaseKind.behaviour,
                        child: Text('Behaviour report (homeroom)'),
                      ),
                      DropdownMenuItem(
                        value: DisciplineCaseKind.incident,
                        child: Text('Incident report (subject/classroom)'),
                      ),
                    ],
                    onChanged: (v) => setDialogState(
                      () => kind = v ?? DisciplineCaseKind.behaviour,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Summary',
                      hintText: 'e.g. Repeated class disruption',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Details',
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
              child: const Text('File Report'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || studentId == null) return;
    final student = students.firstWhere((s) => s.studentId == studentId);
    if (titleCtrl.text.trim().isEmpty) return;
    await DisciplineService.instance.fileReport(
      studentId: student.studentId,
      studentName: student.fullName,
      className: student.className,
      kind: kind,
      title: titleCtrl.text,
      description: descCtrl.text,
    );
  }

  Future<void> _showScheduleHearingDialog(
    BuildContext context,
    DisciplineCase c,
  ) async {
    var inviteParent = true;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: DateTime.now().add(const Duration(days: 3)),
      helpText: 'Hearing date for ${c.studentName}',
    );
    if (date == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Schedule Hearing'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${c.studentName} — ${_dateLabel(date)}'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Invite / notify parent'),
                value: inviteParent,
                onChanged: (v) =>
                    setDialogState(() => inviteParent = v ?? true),
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
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await DisciplineService.instance.updateCase(
      c.id,
      (cur) => cur.copyWith(
        status: DisciplineCaseStatus.hearingScheduled,
        hearingAt: date,
        parentInvited: inviteParent,
        parentNotified: inviteParent,
      ),
      notifyParent: inviteParent,
    );
  }

  Future<void> _showOutcomeDialog(BuildContext context, DisciplineCase c) async {
    var outcome = DisciplineOutcome.warning;
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Outcome — ${c.studentName}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<DisciplineOutcome>(
                  initialValue: outcome,
                  decoration: const InputDecoration(labelText: 'Decision'),
                  items: const [
                    DropdownMenuItem(
                      value: DisciplineOutcome.warning,
                      child: Text('Warning'),
                    ),
                    DropdownMenuItem(
                      value: DisciplineOutcome.suspension,
                      child: Text('Suspension'),
                    ),
                    DropdownMenuItem(
                      value: DisciplineOutcome.restorative,
                      child: Text('Restorative action'),
                    ),
                  ],
                  onChanged: (v) => setDialogState(
                    () => outcome = v ?? DisciplineOutcome.warning,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes shared with teacher & parent',
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
              child: const Text('Resolve Case'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await DisciplineService.instance.updateCase(
      c.id,
      (cur) => cur.copyWith(
        status: DisciplineCaseStatus.resolved,
        outcome: outcome,
        outcomeNotes: notesCtrl.text.trim(),
        parentNotified: true,
      ),
      notifyParent: true,
    );
  }

  Future<void> _showEscalateDialog(BuildContext context, DisciplineCase c) async {
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Escalate critical case to'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'vice_president'),
            child: const Text('Vice Principal'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'principal'),
            child: const Text('Principal'),
          ),
        ],
      ),
    );
    if (target == null) return;
    await DisciplineService.instance.updateCase(
      c.id,
      (cur) => cur.copyWith(
        status: DisciplineCaseStatus.escalated,
        escalatedTo: target,
      ),
    );
  }

  // ---------------------------------------------------------------- leave

  Widget _buildLeaveTab(BuildContext context, bool narrow) {
    return ListenableBuilder(
      listenable: LeaveRequestService.instance,
      builder: (context, _) {
        var requests = LeaveRequestService.instance.forSchool(_schoolId);
        if (_leaveFilter != 'all') {
          requests =
              requests.where((r) => r.status.name == _leaveFilter).toList();
        }
        return SingleChildScrollView(
          padding: EdgeInsets.all(narrow ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label) in const [
                    ('pending', 'Pending'),
                    ('approved', 'Approved'),
                    ('rejected', 'Rejected'),
                    ('all', 'All'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _leaveFilter == value,
                      onSelected: (_) => setState(() => _leaveFilter = value),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (requests.isEmpty)
                _emptyCard(context, 'No leave requests in this view.')
              else
                for (final r in requests) _leaveCard(context, r),
            ],
          ),
        );
      },
    );
  }

  Widget _leaveCard(BuildContext context, LeaveRequest r) {
    final scheme = Theme.of(context).colorScheme;
    final (statusBg, statusFg) = switch (r.status) {
      LeaveRequestStatus.pending => (
          Colors.orange.withValues(alpha: 0.15),
          Colors.orange.shade800
        ),
      LeaveRequestStatus.approved => (
          Colors.green.withValues(alpha: 0.15),
          Colors.green.shade800
        ),
      LeaveRequestStatus.rejected => (
          Colors.red.withValues(alpha: 0.12),
          Colors.red.shade700
        ),
    };
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
              Text(
                '${r.studentName} — ${r.className}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              _chip(r.status.name.toUpperCase(), statusBg, statusFg),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_dateLabel(r.startDate)} → ${_dateLabel(r.endDate)} • ${r.reason}',
          ),
          const SizedBox(height: 4),
          Text(
            'Requested by ${r.parentName}'
            '${r.reviewedByName.isNotEmpty ? ' • Reviewed by ${r.reviewedByName}' : ''}'
            '${r.reviewNote.isNotEmpty ? ' • ${r.reviewNote}' : ''}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          if (_canManage && r.status == LeaveRequestStatus.pending) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _reviewLeave(context, r, approve: true),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _reviewLeave(context, r, approve: false),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reviewLeave(
    BuildContext context,
    LeaveRequest r, {
    required bool approve,
  }) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${approve ? 'Approve' : 'Reject'} leave — ${r.studentName}'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            labelText: 'Note to parent (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LeaveRequestService.instance.review(
      r.id,
      approve: approve,
      note: noteCtrl.text,
    );
  }

  // ---------------------------------------------------------------- shared

  Widget _emptyCard(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: WebErpTheme.cardDecoration(context),
      child: Center(
        child: Text(message, style: TextStyle(color: Colors.grey.shade600)),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _statusChip(BuildContext context, DisciplineCaseStatus status) {
    final (bg, fg, label) = switch (status) {
      DisciplineCaseStatus.submitted => (
          Colors.blue.withValues(alpha: 0.12),
          Colors.blue.shade800,
          'Submitted'
        ),
      DisciplineCaseStatus.investigating => (
          Colors.orange.withValues(alpha: 0.15),
          Colors.orange.shade800,
          'Investigating'
        ),
      DisciplineCaseStatus.hearingScheduled => (
          Colors.purple.withValues(alpha: 0.12),
          Colors.purple.shade700,
          'Hearing scheduled'
        ),
      DisciplineCaseStatus.resolved => (
          Colors.green.withValues(alpha: 0.15),
          Colors.green.shade800,
          'Resolved'
        ),
      DisciplineCaseStatus.dismissed => (
          Colors.grey.withValues(alpha: 0.2),
          Colors.grey.shade700,
          'Dismissed'
        ),
      DisciplineCaseStatus.escalated => (
          Colors.red.withValues(alpha: 0.12),
          Colors.red.shade700,
          'Escalated'
        ),
    };
    return _chip(label, bg, fg);
  }

  static String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
