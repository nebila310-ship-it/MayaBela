import 'package:flutter/material.dart';

import 'package:mayabela/models/dosa_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dosa_service.dart';

/// Student clubs, scholarship apply, internship journal. No leadership minutes.
class StudentProgramsScreen extends StatefulWidget {
  const StudentProgramsScreen({super.key});

  @override
  State<StudentProgramsScreen> createState() => _StudentProgramsScreenState();
}

class _StudentProgramsScreenState extends State<StudentProgramsScreen> {
  final _svc = DosaService.instance;

  String get _selfId =>
      (AuthService.currentUser?.linkedStudentId ?? '').trim().toUpperCase();

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
          title: const Text('Clubs & programs'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Clubs'),
              Tab(text: 'Scholarship'),
              Tab(text: 'Internship'),
              Tab(text: 'Grievances'),
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
                _scholarshipTab(),
                _internshipTab(),
                _grievancesTab(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _clubsTab() {
    final clubs = _svc.clubsForSchool();
    final events = _svc.meetingsForSchool();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final row in events)
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              leading: const Icon(Icons.school_outlined),
              title: Text(row.title),
              subtitle: Text(row.startsAt.toLocal().toString()),
            ),
          ),
        for (final club in clubs)
          Card(
            child: ListTile(
              title: Text(club.name),
              subtitle: Text(club.kind.name),
              trailing: TextButton(
                onPressed: _selfId.isEmpty
                    ? null
                    : () => _svc.joinClub(clubId: club.id, studentId: _selfId),
                child: const Text('Join'),
              ),
            ),
          ),
        for (final row in _svc.membershipsForSchool())
          ListTile(
            title: Text(row.status.name),
            subtitle: Text('${row.gojoHours} Gojo hours'),
          ),
      ],
    );
  }

  Widget _scholarshipTab() {
    final items = _svc.scholarshipsForSchool();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        FilledButton(
          onPressed: _selfId.isEmpty
              ? null
              : () => _svc.applyScholarship(studentId: _selfId),
          child: const Text('Apply (uses current markbook average)'),
        ),
        const SizedBox(height: 8),
        for (final row in items)
          Card(
            child: ListTile(
              title: Text(row.status.name),
              subtitle: Text(
                'Snapshot ${row.snapshotAverage?.toStringAsFixed(1) ?? '—'}',
              ),
            ),
          ),
      ],
    );
  }

  Widget _internshipTab() {
    final items = _svc.internshipsForSchool();
    if (items.isEmpty) {
      return const Center(child: Text('No internship assigned yet.'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final row in items)
          Card(
            child: ListTile(
              title: Text('${row.host} · ${row.status.name}'),
              subtitle: Text(row.notes),
              trailing: TextButton(
                onPressed: () => _svc.updateInternshipStatus(
                  row.id,
                  InternshipStatus.completed,
                  notes: 'Completed from student portal',
                ),
                child: const Text('Mark done'),
              ),
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

  Future<void> _fileGrievance() async {
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
      studentId: _selfId,
    );
  }
}
