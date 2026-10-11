import 'package:flutter/material.dart';

import 'package:mayabela/models/hr_workforce_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/hr_workforce_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/theme/classroom_palette.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

/// HR leave register and contract watchlist. Does not touch payroll.
class WebHrWorkforcePage extends StatefulWidget {
  const WebHrWorkforcePage({super.key});

  @override
  State<WebHrWorkforcePage> createState() => _WebHrWorkforcePageState();
}

class _WebHrWorkforcePageState extends State<WebHrWorkforcePage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    HrWorkforceService.instance.ensureLoaded().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  bool get _canManage => ModuleAccess.canHireStaff;

  String get _schoolId => AuthService.activeSchoolId ?? '';

  String _date(DateTime? d) {
    if (d == null) return '—';
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String _leaveType(StaffLeaveType type) => switch (type) {
        StaffLeaveType.annual => 'Annual',
        StaffLeaveType.sick => 'Sick',
        StaffLeaveType.unpaid => 'Unpaid',
        StaffLeaveType.maternity => 'Maternity',
        StaffLeaveType.compassionate => 'Compassionate',
      };

  String _stage(StaffEmploymentStage stage) => switch (stage) {
        StaffEmploymentStage.probation => 'Probation',
        StaffEmploymentStage.confirmed => 'Confirmed',
        StaffEmploymentStage.endingSoon => 'Ending soon',
        StaffEmploymentStage.expired => 'Expired',
      };

  Color _stageColor(StaffEmploymentStage stage) => switch (stage) {
        StaffEmploymentStage.probation => ClassroomPalette.amber,
        StaffEmploymentStage.confirmed => ClassroomPalette.green,
        StaffEmploymentStage.endingSoon => ClassroomPalette.orange,
        StaffEmploymentStage.expired => ClassroomPalette.red,
      };

  Future<void> _recordLeave() async {
    if (!_canManage) return;
    final people = HrWorkforceService.instance.peopleForSchool(_schoolId);
    if (people.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add staff or teachers first.')),
      );
      return;
    }
    HrPersonRef person = people.first;
    var type = StaffLeaveType.annual;
    var start = DateTime.now();
    var end = DateTime.now();
    final reason = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Record staff leave'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<HrPersonRef>(
                    key: ValueKey('leave-${person.personId}'),
                    initialValue: person,
                    decoration: const InputDecoration(
                      labelText: 'Staff member',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final p in people)
                        DropdownMenuItem(
                          value: p,
                          child: Text('${p.name} · ${p.personId}'),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => person = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<StaffLeaveType>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Leave type',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final t in StaffLeaveType.values)
                        DropdownMenuItem(value: t, child: Text(_leaveType(t))),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => type = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('From ${_date(start)}'),
                    trailing: const Icon(Icons.event),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040),
                        initialDate: start,
                      );
                      if (picked != null) setLocal(() => start = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('To ${_date(end)}'),
                    trailing: const Icon(Icons.event),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        firstDate: start,
                        lastDate: DateTime(2040),
                        initialDate: end.isBefore(start) ? start : end,
                      );
                      if (picked != null) setLocal(() => end = picked);
                    },
                  ),
                  TextField(
                    controller: reason,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
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
              child: const Text('Save leave'),
            ),
          ],
        ),
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (ok != true) return;
    await HrWorkforceService.instance.requestLeave(
      person: person,
      type: type,
      startDate: start,
      endDate: end,
      reason: text,
    );
    if (mounted) setState(() {});
  }

  Future<void> _editContract() async {
    if (!_canManage) return;
    final people = HrWorkforceService.instance.peopleForSchool(_schoolId);
    if (people.isEmpty) return;
    HrPersonRef person = people.first;
    var existing = HrWorkforceService.instance.fileFor(person.personId);
    DateTime? hired = existing?.hiredOn;
    DateTime? end = existing?.contractEnd;
    DateTime? probation = existing?.probationEnds;
    final notes = TextEditingController(text: existing?.notes ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Employment file'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<HrPersonRef>(
                    key: ValueKey('file-${person.personId}'),
                    initialValue: person,
                    decoration: const InputDecoration(
                      labelText: 'Staff member',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final p in people)
                        DropdownMenuItem(
                          value: p,
                          child: Text('${p.name} · ${p.personId}'),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() {
                        person = v;
                        existing = HrWorkforceService.instance.fileFor(v.personId);
                        hired = existing?.hiredOn;
                        end = existing?.contractEnd;
                        probation = existing?.probationEnds;
                        notes.text = existing?.notes ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  _dateTile(ctx, 'Hired on', hired, (d) => setLocal(() => hired = d)),
                  _dateTile(
                    ctx,
                    'Probation ends',
                    probation,
                    (d) => setLocal(() => probation = d),
                  ),
                  _dateTile(
                    ctx,
                    'Contract ends',
                    end,
                    (d) => setLocal(() => end = d),
                  ),
                  TextField(
                    controller: notes,
                    decoration: const InputDecoration(
                      labelText: 'HR notes',
                      hintText: 'Passport, work permit, file number…',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
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
              child: const Text('Save file'),
            ),
          ],
        ),
      ),
    );
    final noteText = notes.text;
    notes.dispose();
    if (ok != true) return;
    await HrWorkforceService.instance.upsertEmployment(
      StaffEmploymentFile(
        personId: person.personId,
        schoolId: person.schoolId,
        personName: person.name,
        kind: person.kind,
        hiredOn: hired,
        contractEnd: end,
        probationEnds: probation,
        notes: noteText.trim(),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _dateTile(
    BuildContext ctx,
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onPick,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('$label · ${_date(value)}'),
      trailing: const Icon(Icons.event_outlined),
      onTap: () async {
        final picked = await showDatePicker(
          context: ctx,
          firstDate: DateTime(2015),
          lastDate: DateTime(2040),
          initialDate: value ?? DateTime.now(),
        );
        if (picked != null) onPick(picked);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: HrWorkforceService.instance,
      builder: (context, _) {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }
        final snap = HrWorkforceService.instance.snapshot(_schoolId);
        final leaves = HrWorkforceService.instance.leavesForSchool(_schoolId);
        final files = HrWorkforceService.instance.filesForSchool(_schoolId)
          ..sort((a, b) {
            final as = a.stageOn(DateTime.now());
            final bs = b.stageOn(DateTime.now());
            return as.index.compareTo(bs.index);
          });
        return SingleChildScrollView(
          key: const ValueKey('hr-workforce-page-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Leave & contracts', style: WebErpTheme.sectionTitle(context)),
              const SizedBox(height: 4),
              Text(
                'Workforce desk for leave approvals and employment files. '
                'Salaries stay in Payroll.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _stat('Headcount', '${snap.headcount}', ClassroomPalette.teal, Icons.groups),
                  _stat('Admin staff', '${snap.adminStaff}', ClassroomPalette.purple, Icons.badge),
                  _stat('Teachers', '${snap.teachers}', ClassroomPalette.blue, Icons.school),
                  _stat('Other staff', '${snap.otherStaff}', ClassroomPalette.cyan, Icons.engineering),
                  _stat('On leave today', '${snap.onLeaveToday}', ClassroomPalette.orange, Icons.beach_access),
                  _stat('Pending leave', '${snap.pendingLeave}', ClassroomPalette.amber, Icons.hourglass_top),
                  _stat('Contracts to watch', '${snap.contractsWatch}', ClassroomPalette.red, Icons.warning_amber),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_canManage)
                    FilledButton.icon(
                      onPressed: _recordLeave,
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Record leave'),
                    ),
                  if (_canManage)
                    FilledButton.tonalIcon(
                      onPressed: _editContract,
                      icon: const Icon(Icons.folder_shared_outlined),
                      label: const Text('Employment file'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Leave register', style: WebErpTheme.sectionTitle(context)),
              const SizedBox(height: 8),
              _card(
                child: leaves.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No staff leave recorded yet.'),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < leaves.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            _leaveTile(leaves[i]),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              Text('Employment files', style: WebErpTheme.sectionTitle(context)),
              const SizedBox(height: 8),
              _card(
                child: files.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No contract dates yet. Open Employment file to set hire, probation, and end dates.',
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < files.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            _fileTile(files[i]),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value, Color color, IconData icon) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.white, 0.18)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: WebErpTheme.cardDecoration(context),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }

  Widget _leaveTile(StaffLeaveRecord leave) {
    final pending = leave.status == StaffLeaveStatus.pending;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: pending
            ? ClassroomPalette.amber.withValues(alpha: 0.2)
            : ClassroomPalette.teal.withValues(alpha: 0.15),
        child: Icon(
          Icons.event_available_outlined,
          color: pending ? ClassroomPalette.orange : ClassroomPalette.teal,
        ),
      ),
      title: Text(
        '${leave.personName} · ${_leaveType(leave.type)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${_date(leave.startDate)} → ${_date(leave.endDate)} · ${leave.days} day(s) · '
        '${leave.status.name}${leave.reason.isEmpty ? '' : ' · ${leave.reason}'}',
      ),
      isThreeLine: true,
      trailing: pending && _canManage
          ? Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'Approve',
                  icon: const Icon(Icons.check_circle, color: Color(0xFF1E8E3E)),
                  onPressed: () async {
                    await HrWorkforceService.instance.reviewLeave(
                      leaveId: leave.id,
                      status: StaffLeaveStatus.approved,
                    );
                    if (mounted) setState(() {});
                  },
                ),
                IconButton(
                  tooltip: 'Reject',
                  icon: const Icon(Icons.cancel, color: Color(0xFFD93025)),
                  onPressed: () async {
                    await HrWorkforceService.instance.reviewLeave(
                      leaveId: leave.id,
                      status: StaffLeaveStatus.rejected,
                    );
                    if (mounted) setState(() {});
                  },
                ),
              ],
            )
          : Text(
              leave.status.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
    );
  }

  Widget _fileTile(StaffEmploymentFile file) {
    final stage = file.stageOn(DateTime.now());
    final color = _stageColor(stage);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        child: Icon(Icons.folder_shared_outlined, color: color),
      ),
      title: Text(
        file.personName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${_stage(stage)} · Hired ${_date(file.hiredOn)} · Ends ${_date(file.contractEnd)}'
        '${file.notes.isEmpty ? '' : ' · ${file.notes}'}',
      ),
      isThreeLine: true,
      trailing: Chip(
        label: Text(_stage(stage)),
        backgroundColor: color.withValues(alpha: 0.14),
        labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
        side: BorderSide.none,
      ),
    );
  }
}
