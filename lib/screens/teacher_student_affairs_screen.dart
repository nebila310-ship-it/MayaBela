import 'package:flutter/material.dart';

import 'package:mayabela/models/discipline_case.dart';
import 'package:mayabela/models/leave_request.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/discipline_service.dart';
import 'package:mayabela/services/leave_request_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';

/// Teacher side of EDUABA Student Affairs:
/// - Subject / homeroom teachers file behaviour & incident reports.
/// - Homeroom teachers receive and decide parent leave requests.
class TeacherStudentAffairsScreen extends StatefulWidget {
  const TeacherStudentAffairsScreen({super.key});

  @override
  State<TeacherStudentAffairsScreen> createState() =>
      _TeacherStudentAffairsScreenState();
}

class _TeacherStudentAffairsScreenState
    extends State<TeacherStudentAffairsScreen> {
  @override
  void initState() {
    super.initState();
    DisciplineService.instance.ensureLoaded();
    LeaveRequestService.instance.ensureLoaded();
  }

  Set<String> get _myClassNames => TeacherAccessService.instance.myClasses
      .map((a) => a.className)
      .toSet();

  bool get _isHomeroom => TeacherAccessService.instance.hasAnyHomeroomClass;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Student Affairs'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Reports'),
              Tab(text: 'Leave Requests'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showFileReportSheet(context),
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Report'),
        ),
        body: TabBarView(
          children: [
            _reportsTab(context),
            _leaveTab(context),
          ],
        ),
      ),
    );
  }

  Widget _reportsTab(BuildContext context) {
    return ListenableBuilder(
      listenable: DisciplineService.instance,
      builder: (context, _) {
        final username = AuthService.currentUser?.username ?? '';
        final mine = DisciplineService.instance.reportedBy(username);
        if (mine.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No reports yet. Use the Report button to send a behaviour '
                'or incident report to Student Affairs.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: mine.length,
          itemBuilder: (context, i) {
            final c = mine[i];
            return Card(
              child: ListTile(
                leading: Icon(
                  c.kind == DisciplineCaseKind.behaviour
                      ? Icons.psychology_alt_outlined
                      : Icons.report_outlined,
                ),
                title: Text('${c.studentName} — ${c.title}'),
                subtitle: Text(
                  '${c.className} • ${_statusLabel(c.status)}'
                  '${c.outcome != DisciplineOutcome.none ? ' • ${c.outcome.name}' : ''}',
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
        final classes = _myClassNames;
        final requests = LeaveRequestService.instance.forClasses(classes);
        if (requests.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No leave requests for your classes yet. Parents submit them '
                'from the family app.',
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
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.studentName} (${r.className})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_dateLabel(r.startDate)} → ${_dateLabel(r.endDate)}\n'
                      '${r.reason}\nRequested by ${r.parentName}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.status == LeaveRequestStatus.pending
                          ? 'Pending decision'
                          : '${r.status.name.toUpperCase()} by ${r.reviewedByName}',
                      style: TextStyle(
                        color: switch (r.status) {
                          LeaveRequestStatus.pending => Colors.orange.shade800,
                          LeaveRequestStatus.approved => Colors.green.shade700,
                          LeaveRequestStatus.rejected => Colors.red.shade700,
                        },
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_isHomeroom &&
                        r.status == LeaveRequestStatus.pending) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                LeaveRequestService.instance.review(
                              r.id,
                              approve: true,
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                LeaveRequestService.instance.review(
                              r.id,
                              approve: false,
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                          ),
                        ],
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

  Future<void> _showFileReportSheet(BuildContext context) async {
    final classes = _myClassNames;
    final students = StudentRegistryService.instance
        .getAllStudents()
        .where((s) => s.isActive && classes.contains(s.className))
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students found for your classes.')),
      );
      return;
    }

    String? studentId = students.first.studentId;
    var kind = _isHomeroom
        ? DisciplineCaseKind.behaviour
        : DisciplineCaseKind.incident;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Report to Student Affairs'),
          content: SingleChildScrollView(
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
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: DisciplineCaseKind.behaviour,
                      child: Text('Behaviour report'),
                    ),
                    DropdownMenuItem(
                      value: DisciplineCaseKind.incident,
                      child: Text('Incident report'),
                    ),
                  ],
                  onChanged: (v) => setDialogState(
                    () => kind = v ?? DisciplineCaseKind.incident,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Summary'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Details'),
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
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || studentId == null || titleCtrl.text.trim().isEmpty) {
      return;
    }
    final student = students.firstWhere((s) => s.studentId == studentId);
    await DisciplineService.instance.fileReport(
      studentId: student.studentId,
      studentName: student.fullName,
      className: student.className,
      kind: kind,
      title: titleCtrl.text,
      description: descCtrl.text,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report sent to Student Affairs.')),
      );
    }
  }

  static String _statusLabel(DisciplineCaseStatus status) => switch (status) {
        DisciplineCaseStatus.submitted => 'Submitted',
        DisciplineCaseStatus.investigating => 'Under investigation',
        DisciplineCaseStatus.hearingScheduled => 'Hearing scheduled',
        DisciplineCaseStatus.resolved => 'Resolved',
        DisciplineCaseStatus.dismissed => 'Dismissed',
        DisciplineCaseStatus.escalated => 'Escalated',
      };

  static String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
