import 'package:flutter/material.dart';

import 'package:mayabela/models/discipline_case.dart';
import 'package:mayabela/models/leave_request.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/discipline_service.dart';
import 'package:mayabela/services/leave_request_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

/// Parent side of EDUABA Student Affairs:
/// - View / respond to discipline & behaviour cases for linked children.
/// - Submit leave requests to the homeroom teacher and track decisions.
class ParentStudentAffairsScreen extends StatefulWidget {
  const ParentStudentAffairsScreen({super.key});

  @override
  State<ParentStudentAffairsScreen> createState() =>
      _ParentStudentAffairsScreenState();
}

class _ParentStudentAffairsScreenState
    extends State<ParentStudentAffairsScreen> {
  @override
  void initState() {
    super.initState();
    DisciplineService.instance.ensureLoaded();
    LeaveRequestService.instance.ensureLoaded();
  }

  List<String> get _childIds => AuthService.activeLinkedStudentIds();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Behaviour & Leave'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Behaviour'),
              Tab(text: 'Leave Requests'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showRequestLeaveDialog(context),
          icon: const Icon(Icons.free_cancellation_outlined),
          label: const Text('Request Leave'),
        ),
        body: TabBarView(
          children: [
            _behaviourTab(context),
            _leaveTab(context),
          ],
        ),
      ),
    );
  }

  Widget _behaviourTab(BuildContext context) {
    return ListenableBuilder(
      listenable: DisciplineService.instance,
      builder: (context, _) {
        final cases = DisciplineService.instance.forStudentIds(_childIds);
        if (cases.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No behaviour or discipline updates for your children.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: cases.length,
          itemBuilder: (context, i) {
            final c = cases[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c.studentName} — ${c.title}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(_parentStatusText(c)),
                    if (c.outcomeNotes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Note from school: ${c.outcomeNotes}'),
                    ],
                    if (c.hearingAt != null &&
                        c.parentInvited &&
                        c.status == DisciplineCaseStatus.hearingScheduled) ...[
                      const SizedBox(height: 4),
                      Text(
                        'You are invited to the hearing on '
                        '${_dateLabel(c.hearingAt!)}. You can also contact '
                        'Student Affairs from Messages.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _leaveTab(BuildContext context) {
    return ListenableBuilder(
      listenable: LeaveRequestService.instance,
      builder: (context, _) {
        final username = AuthService.currentUser?.username ?? '';
        final requests = LeaveRequestService.instance.forParent(username);
        if (requests.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No leave requests yet. Use Request Leave to notify the '
                'homeroom teacher about a planned absence.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          itemBuilder: (context, i) {
            final r = requests[i];
            final (color, label) = switch (r.status) {
              LeaveRequestStatus.pending => (
                  Colors.orange.shade800,
                  'Waiting for homeroom teacher'
                ),
              LeaveRequestStatus.approved => (
                  Colors.green.shade700,
                  'Approved by ${r.reviewedByName}'
                ),
              LeaveRequestStatus.rejected => (
                  Colors.red.shade700,
                  'Rejected by ${r.reviewedByName}'
                ),
            };
            return Card(
              child: ListTile(
                leading: const Icon(Icons.free_cancellation_outlined),
                title: Text(
                  '${r.studentName}: ${_dateLabel(r.startDate)} → ${_dateLabel(r.endDate)}',
                ),
                subtitle: Text(
                  '${r.reason}\n$label'
                  '${r.reviewNote.isNotEmpty ? ' — ${r.reviewNote}' : ''}',
                ),
                isThreeLine: true,
                iconColor: color,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showRequestLeaveDialog(BuildContext context) async {
    final children = <({String id, String name, String className})>[];
    for (final id in _childIds) {
      final record = StudentRegistryService.instance.lookupById(id);
      if (record != null) {
        children.add(
          (id: record.studentId, name: record.fullName, className: record.className),
        );
      }
    }
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link a child first (waiting for homeroom approval).'),
        ),
      );
      return;
    }

    String childId = children.first.id;
    DateTime start = DateTime.now().add(const Duration(days: 1));
    DateTime end = DateTime.now().add(const Duration(days: 1));
    final reasonCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Request Leave'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: childId,
                  decoration: const InputDecoration(labelText: 'Child'),
                  items: [
                    for (final c in children)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name} (${c.className})'),
                      ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => childId = v ?? childId),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('From: ${_dateLabel(start)}'),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: start,
                    );
                    if (picked != null) {
                      setDialogState(() {
                        start = picked;
                        if (end.isBefore(start)) end = start;
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('To: ${_dateLabel(end)}'),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      firstDate: start,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: end.isBefore(start) ? start : end,
                    );
                    if (picked != null) setDialogState(() => end = picked);
                  },
                ),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'e.g. Family travel, medical appointment',
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
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || reasonCtrl.text.trim().isEmpty) return;
    final child = children.firstWhere((c) => c.id == childId);
    await LeaveRequestService.instance.submit(
      studentId: child.id,
      studentName: child.name,
      className: child.className,
      startDate: start,
      endDate: end,
      reason: reasonCtrl.text,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request sent to the homeroom teacher.'),
        ),
      );
    }
  }

  static String _parentStatusText(DisciplineCase c) => switch (c.status) {
        DisciplineCaseStatus.submitted ||
        DisciplineCaseStatus.investigating =>
          'The school is reviewing a ${c.kind.name} report.',
        DisciplineCaseStatus.hearingScheduled => 'A hearing has been scheduled.',
        DisciplineCaseStatus.resolved =>
          'Resolved — ${switch (c.outcome) {
            DisciplineOutcome.warning => 'warning issued',
            DisciplineOutcome.suspension => 'suspension',
            DisciplineOutcome.restorative => 'restorative action',
            DisciplineOutcome.none => 'closed',
          }}.',
        DisciplineCaseStatus.dismissed => 'Case dismissed — no action needed.',
        DisciplineCaseStatus.escalated =>
          'Case escalated to school leadership.',
      };

  static String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
