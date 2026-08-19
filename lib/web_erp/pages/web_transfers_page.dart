import 'package:flutter/material.dart';

import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/services/persistence/transfer_persistence_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/transfer_workflow_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// Transfer requests queue + class promotion for the web ERP.
class WebTransfersPage extends StatefulWidget {
  const WebTransfersPage({super.key});

  @override
  State<WebTransfersPage> createState() => _WebTransfersPageState();
}

class _WebTransfersPageState extends State<WebTransfersPage> {
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    TransferPersistenceService.instance.loadIntoService();
  }

  String get _schoolId => AuthService.activeSchoolId ?? 'TB-001';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TransferWorkflowService.instance,
      builder: (context, _) {
        var requests = TransferWorkflowService.instance.requestsForSchool();
        if (_filter != 'all') {
          requests =
              requests.where((r) => r.status.name == _filter).toList();
        }
        final narrow = WebViewport.isNarrow(context);

        return SingleChildScrollView(
          padding: EdgeInsets.all(narrow ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transfers', style: WebErpTheme.sectionTitle(context)),
              const SizedBox(height: 4),
              Text(
                'Internal moves need academic approval. External '
                'leave/transfer-out needs the school owner. '
                'Promotion rolls a whole class forward.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (TransferPermissions.canCreateTransfers ||
                  TransferPermissions.canPromoteStudents) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (TransferPermissions.canCreateTransfers) ...[
                      OutlinedButton.icon(
                        onPressed: () => _showCreateInternal(context),
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Internal Transfer'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _showCreateExternal(context),
                        icon: const Icon(Icons.logout),
                        label: const Text('External / Leave'),
                      ),
                    ],
                    if (TransferPermissions.canPromoteStudents)
                      FilledButton.icon(
                        onPressed: () => _showPromote(context),
                        icon: const Icon(Icons.stairs_outlined),
                        label: const Text('Promote Class'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
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
                      selected: _filter == value,
                      onSelected: (_) => setState(() => _filter = value),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (requests.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: WebErpTheme.cardDecoration(context),
                  child: Center(
                    child: Text(
                      'No transfer requests yet.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  decoration: WebErpTheme.cardDecoration(context),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Student')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Change')),
                        DataColumn(label: Text('Requested By')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [for (final r in requests) _row(context, r)],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  DataRow _row(BuildContext context, TransferRequest r) {
    final canApprove = r.kind == TransferRequestKind.external
        ? TransferPermissions.canApproveExternalTransfers
        : TransferPermissions.canApproveInternalTransfers;
    return DataRow(
      cells: [
        DataCell(Text(_fmt(r.createdAt))),
        DataCell(Text('${r.studentName}\n${r.studentId}',
            style: const TextStyle(height: 1.3))),
        DataCell(Text(r.kind == TransferRequestKind.external
            ? 'External'
            : 'Internal')),
        DataCell(Text(_changeLabel(r))),
        DataCell(Text(r.requestedByName.isNotEmpty
            ? r.requestedByName
            : r.requestedBy)),
        DataCell(_statusChip(r)),
        DataCell(
          r.status == TransferRequestStatus.pending && canApprove
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Approve',
                      icon: Icon(Icons.check_circle_outline,
                          color: Colors.green.shade700),
                      onPressed: () async {
                        final error = await TransferWorkflowService.instance
                            .approveTransfer(r.id);
                        if (context.mounted) {
                          _toast(context, error,
                              'Transfer approved and applied.');
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Reject',
                      icon: Icon(Icons.cancel_outlined,
                          color: Colors.red.shade700),
                      onPressed: () async {
                        final reason = await _askReason(context);
                        if (reason == null) return;
                        final error = await TransferWorkflowService.instance
                            .rejectTransfer(r.id, reason);
                        if (context.mounted) {
                          _toast(context, error, 'Transfer rejected.');
                        }
                      },
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  String _changeLabel(TransferRequest r) {
    if (r.kind == TransferRequestKind.external) {
      return r.externalOutcome == ExternalTransferOutcome.left
          ? 'Leave school'
          : 'Transferred out';
    }
    if (r.internalTarget == InternalTransferTarget.campus) {
      return '${r.fromCampus} → ${r.toCampus}';
    }
    return '${r.fromClassName} → ${r.toClassName}';
  }

  Widget _statusChip(TransferRequest r) {
    final color = switch (r.status) {
      TransferRequestStatus.pending => Colors.orange.shade800,
      TransferRequestStatus.approved => Colors.green.shade700,
      TransferRequestStatus.rejected => Colors.red.shade700,
    };
    final chip = Chip(
      label: Text(r.status.name, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
    if (r.status == TransferRequestStatus.rejected &&
        (r.rejectionReason ?? '').isNotEmpty) {
      return Tooltip(message: r.rejectionReason!, child: chip);
    }
    return chip;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _toast(BuildContext context, String? error, String ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error == null ? ok : _err(error)),
        backgroundColor:
            error == null ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  String _err(String code) => switch (code) {
        'self_approval_blocked' =>
          'You cannot approve your own request. Ask another approver, or have '
              'the owner enable self-approval.',
        'not_allowed' => 'Your roles do not allow this action.',
        'not_pending' => 'This request has already been decided.',
        'reason_required' => 'A reason is required.',
        'student_not_found' => 'Student not found (or already inactive).',
        'no_change' => 'Destination is the same as the current placement.',
        'no_students' => 'No active students in that class.',
        'apply_failed' => 'Could not apply the transfer.',
        _ => 'Action failed ($code).',
      };

  Future<String?> _askReason(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject transfer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    return (reason == null || reason.isEmpty) ? null : reason;
  }

  Future<void> _showCreateInternal(BuildContext context) async {
    final students =
        StudentRegistryService.instance.studentsForSchool(_schoolId);
    if (students.isEmpty) {
      _toast(context, 'no_students', '');
      return;
    }
    AdminStudentRecord? student = students.first;
    var toGrade = student.grade;
    var toSection = '';
    final reasonController = TextEditingController();
    final grades = ClassStructureService.instance.gradesForSchool();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final sections =
              ClassStructureService.instance.sectionsForGrade(toGrade);
          toSection = sections.contains(toSection)
              ? toSection
              : (sections.isNotEmpty ? sections.first : '');
          return AlertDialog(
            title: const Text('Internal Transfer Request'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<AdminStudentRecord>(
                    initialValue: student,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Student',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final s in students)
                        DropdownMenuItem(
                          value: s,
                          child: Text('${s.fullName} · ${s.className}',
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setDialogState(() {
                      student = v;
                      toGrade = v?.grade ?? toGrade;
                    }),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: grades.contains(toGrade) ? toGrade : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'To grade',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final g in grades)
                        DropdownMenuItem(value: g, child: Text(g)),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => toGrade = v ?? toGrade),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue:
                        sections.contains(toSection) ? toSection : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'To section',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final s in sections)
                        DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => toSection = v ?? toSection),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
    if (submitted != true || student == null || !context.mounted) return;

    final target = toGrade == student!.grade
        ? InternalTransferTarget.section
        : InternalTransferTarget.grade;
    var error = await TransferWorkflowService.instance.createInternalTransfer(
      studentId: student!.studentId,
      toGrade: toGrade,
      toSection: toSection,
      target: target,
      reason: reasonController.text,
    );
    if (error != null) {
      if (context.mounted) _toast(context, error, '');
      return;
    }

    // Auto-approve when the creator is also allowed (owner, or
    // self-approval enabled for multi-role staff).
    final created =
        TransferWorkflowService.instance.requestsForSchool().first;
    if (TransferPermissions.canApproveInternalTransfers) {
      error = await TransferWorkflowService.instance.approveTransfer(created.id);
      if (error == 'self_approval_blocked') {
        if (context.mounted) {
          _toast(context, null, 'Request submitted — awaiting approval.');
        }
        return;
      }
      if (context.mounted) {
        _toast(context, error, 'Transfer approved and applied.');
      }
      return;
    }
    if (context.mounted) {
      _toast(context, null, 'Request submitted — awaiting approval.');
    }
  }

  Future<void> _showCreateExternal(BuildContext context) async {
    final students =
        StudentRegistryService.instance.studentsForSchool(_schoolId);
    if (students.isEmpty) {
      _toast(context, 'no_students', '');
      return;
    }
    AdminStudentRecord? student = students.first;
    var outcome = ExternalTransferOutcome.transferred;
    final reasonController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('External Transfer / Leave'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AdminStudentRecord>(
                  initialValue: student,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Student',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final s in students)
                      DropdownMenuItem(
                        value: s,
                        child: Text('${s.fullName} · ${s.className}',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => student = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ExternalTransferOutcome>(
                  initialValue: outcome,
                  decoration: const InputDecoration(
                    labelText: 'Outcome',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ExternalTransferOutcome.transferred,
                      child: Text('Transferred to another school'),
                    ),
                    DropdownMenuItem(
                      value: ExternalTransferOutcome.left,
                      child: Text('Left the school'),
                    ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => outcome = v ?? outcome),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason (required)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Requires school-owner approval. The student becomes inactive '
                  'once approved.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true || student == null || !context.mounted) return;

    var error = await TransferWorkflowService.instance.createExternalTransfer(
      studentId: student!.studentId,
      outcome: outcome,
      reason: reasonController.text,
    );
    if (error != null) {
      if (context.mounted) _toast(context, error, '');
      return;
    }
    final created =
        TransferWorkflowService.instance.requestsForSchool().first;
    if (TransferPermissions.canApproveExternalTransfers) {
      error =
          await TransferWorkflowService.instance.approveTransfer(created.id);
      if (context.mounted) {
        _toast(context, error, 'External transfer applied.');
      }
      return;
    }
    if (context.mounted) {
      _toast(context, null, 'Request submitted — awaiting owner approval.');
    }
  }

  Future<void> _showPromote(BuildContext context) async {
    final grades = ClassStructureService.instance.gradesForSchool();
    if (grades.isEmpty) return;
    var fromGrade = grades.first;
    var fromSection = ClassStructureService.instance
            .sectionsForGrade(fromGrade)
            .firstOrNull ??
        'A';
    var graduate = false;
    String? toGrade;
    var toSection = fromSection;
    final yearController = TextEditingController(
      text: SchoolRegistryService.instance.lookup(_schoolId)?.academicYear ??
          '',
    );

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final fromSections =
              ClassStructureService.instance.sectionsForGrade(fromGrade);
          if (!fromSections.contains(fromSection) && fromSections.isNotEmpty) {
            fromSection = fromSections.first;
          }
          final next = TransferWorkflowService.nextGradeLabel(fromGrade, grades);
          toGrade ??= next;
          final toSections = toGrade == null
              ? <String>[]
              : ClassStructureService.instance.sectionsForGrade(toGrade!);
          if (toSections.isNotEmpty && !toSections.contains(toSection)) {
            toSection = toSections.first;
          }
          final fromClass =
              StudentRegistryService.buildClassName(fromGrade, fromSection);
          final count = StudentRegistryService.instance
              .studentsForClass(fromClass, schoolId: _schoolId)
              .length;

          return AlertDialog(
            title: const Text('Promote Class'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: fromGrade,
                          decoration: const InputDecoration(
                            labelText: 'From grade',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final g in grades)
                              DropdownMenuItem(value: g, child: Text(g)),
                          ],
                          onChanged: (v) => setDialogState(() {
                            fromGrade = v ?? fromGrade;
                            toGrade = TransferWorkflowService.nextGradeLabel(
                                fromGrade, grades);
                            graduate = toGrade == null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: fromSections.contains(fromSection)
                              ? fromSection
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Section',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final s in fromSections)
                              DropdownMenuItem(value: s, child: Text(s)),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => fromSection = v ?? fromSection),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('$count active student(s) in $fromClass'),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mark as graduated (final year)'),
                    value: graduate || next == null,
                    onChanged: next == null
                        ? null
                        : (v) => setDialogState(() {
                              graduate = v;
                              if (!v) toGrade = next;
                            }),
                  ),
                  if (!graduate && next != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: toGrade,
                            decoration: const InputDecoration(
                              labelText: 'To grade',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              for (final g in grades)
                                DropdownMenuItem(value: g, child: Text(g)),
                            ],
                            onChanged: (v) =>
                                setDialogState(() => toGrade = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: toSections.contains(toSection)
                                ? toSection
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'To section',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              for (final s in toSections)
                                DropdownMenuItem(value: s, child: Text(s)),
                            ],
                            onChanged: (v) => setDialogState(
                                () => toSection = v ?? toSection),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: yearController,
                    decoration: const InputDecoration(
                      labelText: 'New academic year (optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: count == 0
                    ? null
                    : () => Navigator.pop(context, true),
                child: Text(graduate || next == null
                    ? 'Graduate $count'
                    : 'Promote $count'),
              ),
            ],
          );
        },
      ),
    );
    if (submitted != true || !context.mounted) return;

    final fromClass =
        StudentRegistryService.buildClassName(fromGrade, fromSection);
    final result = await TransferWorkflowService.instance.promoteClass(
      fromClassName: fromClass,
      toGrade: graduate ? null : toGrade,
      toSection: graduate ? null : toSection,
      graduate: graduate ||
          TransferWorkflowService.nextGradeLabel(fromGrade, grades) == null,
      newAcademicYear: yearController.text,
    );
    if (context.mounted) {
      _toast(
        context,
        result.error,
        graduate || result.error == null && toGrade == null
            ? 'Graduated ${result.count} student(s).'
            : 'Promoted ${result.count} student(s).',
      );
      setState(() {});
    }
  }
}
