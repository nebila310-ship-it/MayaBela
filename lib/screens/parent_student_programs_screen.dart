import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dosa_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

/// Parent view of clubs, scholarships, and grievances. No leadership minutes.
class ParentStudentProgramsScreen extends StatefulWidget {
  const ParentStudentProgramsScreen({super.key});

  @override
  State<ParentStudentProgramsScreen> createState() =>
      _ParentStudentProgramsScreenState();
}

class _ParentStudentProgramsScreenState
    extends State<ParentStudentProgramsScreen> {
  final _svc = DosaService.instance;

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
          title: const Text('Student programs'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Clubs'),
              Tab(text: 'Scholarships'),
              Tab(text: 'Grievances'),
              Tab(text: 'Events'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _fileGrievance,
          icon: const Icon(Icons.report_gmailerrorred_outlined),
          label: const Text('File grievance'),
        ),
        body: ListenableBuilder(
          listenable: _svc,
          builder: (context, _) {
            return TabBarView(
              children: [
                _clubsTab(),
                _scholarshipsTab(),
                _grievancesTab(),
                _eventsTab(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _clubsTab() {
    final clubs = _svc.clubsForSchool();
    final mine = _svc.membershipsForSchool();
    if (clubs.isEmpty) {
      return const Center(child: Text('No published clubs yet.'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final club in clubs)
          Card(
            child: ListTile(
              title: Text('${club.name} · ${club.kind.name}'),
              subtitle: Text(club.description),
              trailing: TextButton(
                onPressed: () => _join(club.id),
                child: const Text('Join'),
              ),
            ),
          ),
        for (final row in mine)
          ListTile(
            title: Text('Membership · ${row.status.name}'),
            subtitle: Text('${row.studentName} · ${row.gojoHours} Gojo hours'),
          ),
      ],
    );
  }

  Widget _scholarshipsTab() {
    final items = _svc.scholarshipsForSchool();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        FilledButton.tonal(
          onPressed: _applyScholarship,
          child: const Text('Apply for merit scholarship'),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No scholarship applications yet.'),
          ),
        for (final row in items)
          Card(
            child: ListTile(
              title: Text('${row.studentName} · ${row.status.name}'),
              subtitle: Text(
                'Average snapshot ${row.snapshotAverage?.toStringAsFixed(1) ?? '—'} '
                '(need ${row.minAverage})',
              ),
            ),
          ),
      ],
    );
  }

  Widget _eventsTab() {
    final items = _svc.meetingsForSchool();
    if (items.isEmpty) {
      return const Center(child: Text('No published graduation events yet.'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final row in items)
          Card(
            child: ListTile(
              title: Text(row.title),
              subtitle: Text(row.startsAt.toLocal().toString()),
            ),
          ),
      ],
    );
  }

  Widget _grievancesTab() {
    final items = _svc.grievancesForSchool();
    if (items.isEmpty) {
      return const Center(child: Text('No grievances filed.'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final row in items)
          Card(
            child: ListTile(
              title: Text(row.title),
              subtitle: Text('${row.status.name}\n${row.details}'),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }

  Future<String?> _pickChild() async {
    final children = _childIds
        .map(StudentRegistryService.instance.lookupById)
        .whereType<AdminStudentRecord>()
        .toList();
    if (children.isEmpty && _childIds.isEmpty) return null;
    if (children.length <= 1) {
      return children.isNotEmpty ? children.first.studentId : _childIds.first;
    }
    var studentId = children.first.studentId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Child'),
          content: DropdownButtonFormField<String>(
            key: ValueKey(studentId),
            initialValue: studentId,
            items: [
              for (final child in children)
                DropdownMenuItem(
                  value: child.studentId,
                  child: Text(child.fullName),
                ),
            ],
            onChanged: (v) => setDialogState(() => studentId = v ?? studentId),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    return ok == true ? studentId : null;
  }

  Future<void> _join(String clubId) async {
    final studentId = await _pickChild();
    if (studentId == null) return;
    await _svc.joinClub(clubId: clubId, studentId: studentId);
  }

  Future<void> _applyScholarship() async {
    final studentId = await _pickChild();
    if (studentId == null) return;
    await _svc.applyScholarship(studentId: studentId);
  }

  Future<void> _fileGrievance() async {
    final studentId = await _pickChild() ?? '';
    final title = TextEditingController();
    final details = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File grievance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: details,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Details'),
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
    );
    if (ok != true || title.text.trim().isEmpty) return;
    await _svc.fileGrievance(
      title: title.text,
      details: details.text,
      studentId: studentId,
    );
  }
}
