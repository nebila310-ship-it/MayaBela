import 'package:flutter/material.dart';

import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/student_support_service.dart';

/// Parent care portal: health, counseling summaries, IEP sign, college.
/// Never shows safeguarding / child-protection files.
class ParentStudentSupportScreen extends StatefulWidget {
  const ParentStudentSupportScreen({super.key});

  @override
  State<ParentStudentSupportScreen> createState() =>
      _ParentStudentSupportScreenState();
}

class _ParentStudentSupportScreenState
    extends State<ParentStudentSupportScreen> {
  final _svc = StudentSupportService.instance;

  List<String> get _childIds => AuthService.activeLinkedStudentIds();

  @override
  void initState() {
    super.initState();
    _svc.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Student support'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Health'),
              Tab(text: 'Counseling'),
              Tab(text: 'IEP'),
              Tab(text: 'College'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _requestSupport,
          icon: const Icon(Icons.event_available_outlined),
          label: const Text('Request appointment'),
        ),
        body: ListenableBuilder(
          listenable: _svc,
          builder: (context, _) {
            return TabBarView(
              children: [
                _healthTab(),
                _counselingTab(),
                _iepTab(),
                _collegeTab(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _healthTab() {
    final items = _svc.healthForSchool();
    if (items.isEmpty) {
      return const _Empty('No clinic, vaccine, or medication notes yet.');
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final row in items)
          Card(
            child: ListTile(
              title: Text(row.title.isEmpty ? row.type.name : row.title),
              subtitle: Text(
                '${row.studentName}\n${row.details}'
                '${row.staffNotes.trim().isEmpty ? '' : '\n${row.staffNotes}'}',
              ),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }

  Widget _counselingTab() {
    final items = _svc.counselingForSchool();
    final requests = _svc
        .requestsForSchool()
        .where((row) => row.kind == SupportRequestKind.counselingAppointment)
        .toList();
    if (items.isEmpty && requests.isEmpty) {
      return const _Empty('No counseling appointments or summaries yet.');
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final row in items)
          Card(
            child: ListTile(
              title: Text(row.title.isEmpty ? row.kind.name : row.title),
              subtitle: Text(
                '${row.studentName}\n'
                '${row.parentSummary.trim().isEmpty ? 'Appointment / update' : row.parentSummary}',
              ),
              isThreeLine: true,
            ),
          ),
        for (final row in requests)
          Card(
            child: ListTile(
              title: Text('Request · ${row.status.name}'),
              subtitle: Text('${row.studentName}\n${row.body}'),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }

  Widget _iepTab() {
    final items = _svc.iepForSchool();
    if (items.isEmpty) {
      return const _Empty('No IEP or special-needs plan for your child yet.');
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final row in items)
          Card(
            child: ListTile(
              title: Text('${row.studentName} · ${row.stage.name}'),
              subtitle: Text(
                [
                  if (row.goals.trim().isNotEmpty) 'Goals: ${row.goals}',
                  if (row.accommodations.trim().isNotEmpty)
                    'Accommodations: ${row.accommodations}',
                  if (row.parentAgreementText.trim().isNotEmpty)
                    row.parentAgreementText,
                  if (row.parentAgreed) 'Signed',
                ].join('\n'),
              ),
              isThreeLine: true,
              trailing: row.parentAgreed
                  ? const Icon(Icons.verified_outlined)
                  : TextButton(
                      onPressed: () => _signIep(row),
                      child: const Text('Sign'),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _collegeTab() {
    final items = _svc.collegeForSchool();
    if (items.isEmpty) {
      return const _Empty('No college-guidance plan yet.');
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final row in items)
          Card(
            child: ListTile(
              title: Text('${row.studentName} · ${row.stage.name}'),
              subtitle: Text(
                [
                  if (row.targets.trim().isNotEmpty) row.targets,
                  if (row.portfolio.trim().isNotEmpty)
                    'Portfolio: ${row.portfolio}',
                ].join('\n'),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _signIep(IepPlan plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign IEP agreement'),
        content: Text(
          'Sign the special-needs plan for ${plan.studentName}? '
          'This records your agreement. It does not change grades.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.signIepPlan(plan.id);
  }

  Future<void> _requestSupport() async {
    final children = _childIds
        .map(StudentRegistryService.instance.lookupById)
        .whereType<AdminStudentRecord>()
        .toList();
    if (children.isEmpty && _childIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No linked child found.')),
      );
      return;
    }
    var studentId = children.isNotEmpty ? children.first.studentId : _childIds.first;
    var kind = SupportRequestKind.counselingAppointment;
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Request support'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (children.length > 1)
                DropdownButtonFormField<String>(
                  key: ValueKey(studentId),
                  initialValue: studentId,
                  decoration: const InputDecoration(labelText: 'Child'),
                  items: [
                    for (final child in children)
                      DropdownMenuItem(
                        value: child.studentId,
                        child: Text(child.fullName),
                      ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => studentId = v ?? studentId),
                ),
              DropdownButtonFormField<SupportRequestKind>(
                key: ValueKey(kind),
                initialValue: kind,
                items: const [
                  DropdownMenuItem(
                    value: SupportRequestKind.counselingAppointment,
                    child: Text('Counseling appointment'),
                  ),
                  DropdownMenuItem(
                    value: SupportRequestKind.iepAgreement,
                    child: Text('IEP agreement'),
                  ),
                  DropdownMenuItem(
                    value: SupportRequestKind.collegeAppointment,
                    child: Text('College appointment'),
                  ),
                ],
                onChanged: (v) => setDialogState(() => kind = v ?? kind),
              ),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Note'),
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
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _svc.submitSupportRequest(
      studentId: studentId,
      kind: kind,
      body: note.text,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
