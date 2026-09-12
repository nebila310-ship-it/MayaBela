import 'package:flutter/material.dart';

import 'package:mayabela/models/dosa_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dosa_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// DoSA desk: clubs/Gojo, scholarships, grievances, internships, leadership.
class WebStudentProgramsPage extends StatefulWidget {
  const WebStudentProgramsPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebStudentProgramsPage> createState() => _WebStudentProgramsPageState();
}

class _WebStudentProgramsPageState extends State<WebStudentProgramsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 7, vsync: this);
  final _svc = DosaService.instance;

  bool get _canManage => ModuleAccess.canManage('student_affairs');
  String get _schoolId => AuthService.activeSchoolId ?? '';

  @override
  void initState() {
    super.initState();
    _svc.ensureLoaded();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<AdminStudentRecord> get _students {
    return StudentRegistryService.instance
        .getAllStudents()
        .where(
          (s) =>
              s.isActive &&
              (_schoolId.isEmpty ||
                  s.schoolId.trim().toUpperCase() == _schoolId.toUpperCase()),
        )
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    return ListenableBuilder(
      listenable: _svc,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                narrow ? 12 : 20,
                narrow ? 12 : 20,
                narrow ? 12 : 20,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student programs',
                    style: WebErpTheme.sectionTitle(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Clubs and Gojo, merit scholarships (reads the markbook, '
                    'never writes grades), grievances, internships / career hours, '
                    'attendance and transport oversight (reads only), and '
                    'graduation / event logistics. Minutes stay on the meeting.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _engagementStrip(),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(text: 'Clubs (${_svc.activeClubCount(_schoolId)})'),
                      Tab(
                        text:
                            'Scholarships (${_svc.pendingScholarshipCount(_schoolId)})',
                      ),
                      Tab(
                        text:
                            'Grievances (${_svc.openGrievanceCount(_schoolId)})',
                      ),
                      Tab(
                        text:
                            'Internships (${_svc.internshipsForSchool(_schoolId).length})',
                      ),
                      Tab(
                        text:
                            'Leadership (${_svc.meetingsForSchool(_schoolId).length})',
                      ),
                      Tab(
                        text:
                            'Tasks (${_svc.openLeadershipTaskCount(_schoolId)})',
                      ),
                      Tab(
                        text:
                            'Oversight (${_svc.attendanceOversight(_schoolId).length})',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _clubsTab(),
                  _scholarshipsTab(),
                  _grievancesTab(),
                  _internshipsTab(),
                  _meetingsTab(),
                  _tasksTab(),
                  _oversightTab(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _clubsTab() {
    final clubs = _svc.clubsForSchool(_schoolId);
    return _list(
      action: _canManage
          ? FilledButton.icon(
              onPressed: _addClub,
              icon: const Icon(Icons.add),
              label: const Text('New club / Gojo'),
            )
          : null,
      empty: 'No clubs or Gojo groups yet.',
      children: [
        for (final club in clubs)
          _card(
            title: '${club.name} · ${club.kind.name}',
            subtitle: [
              if (club.advisorName.trim().isNotEmpty) club.advisorName,
              if (club.meetingDay.trim().isNotEmpty) club.meetingDay,
              club.published ? 'Published' : 'Hidden',
            ].join(' · '),
            body: [
              if (club.description.trim().isNotEmpty) Text(club.description),
              for (final m in _svc.membershipsForClub(club.id))
                ListTile(
                  dense: true,
                  title: Text('${m.studentName} · ${m.status.name}'),
                  subtitle: Text(
                    'Gojo hours: ${m.gojoHours}'
                    '${m.engagementRating == null ? '' : ' · ${m.engagementRating}/5'}'
                    '${m.evaluationNotes.isEmpty ? '' : '\n${m.evaluationNotes}'}',
                  ),
                  trailing: _canManage
                      ? Wrap(
                          children: [
                            TextButton(
                              onPressed: () => _svc.setMembershipStatus(
                                m.id,
                                MembershipStatus.active,
                              ),
                              child: const Text('Approve'),
                            ),
                            TextButton(
                              onPressed: () => _svc.addGojoHours(m.id, 1),
                              child: const Text('+1h'),
                            ),
                            TextButton(
                              onPressed: () => _evaluateMember(m),
                              child: const Text('Evaluate'),
                            ),
                            if (m.status != MembershipStatus.withdrawn)
                              TextButton(
                                onPressed: () => _svc.setMembershipStatus(
                                  m.id,
                                  MembershipStatus.withdrawn,
                                ),
                                child: const Text('Withdraw'),
                              ),
                          ],
                        )
                      : null,
                ),
              if (_canManage)
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () => _enrollStudent(club.id),
                      child: const Text('Add member'),
                    ),
                    TextButton(
                      onPressed: () => _openClubDiscussion(club.id),
                      child: const Text('Club discussion'),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  Widget _scholarshipsTab() {
    final items = _svc.scholarshipsForSchool(_schoolId);
    return _list(
      action: _canManage
          ? FilledButton.icon(
              onPressed: _addScholarship,
              icon: const Icon(Icons.add),
              label: const Text('Record application'),
            )
          : null,
      empty: 'No scholarship applications yet.',
      children: [
        for (final row in items)
          _card(
            title: '${row.studentName} · ${row.title}',
            subtitle:
                '${row.status.name} · avg ${row.snapshotAverage?.toStringAsFixed(1) ?? '—'} / ${row.minAverage}'
                '${row.meetsThreshold ? ' · meets threshold' : ''}',
            body: [
              if (row.note.trim().isNotEmpty) Text(row.note),
              if (_canManage)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _svc.refreshScholarshipAverage(row.id),
                      child: const Text('Refresh markbook avg'),
                    ),
                    TextButton(
                      onPressed: () => _svc.reviewScholarship(
                        row.id,
                        ScholarshipStatus.awarded,
                      ),
                      child: const Text('Award'),
                    ),
                    TextButton(
                      onPressed: () => _svc.reviewScholarship(
                        row.id,
                        ScholarshipStatus.declined,
                      ),
                      child: const Text('Decline'),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  Widget _grievancesTab() {
    final items = _svc.grievancesForSchool(_schoolId);
    return _list(
      empty: 'No grievances filed.',
      children: [
        for (final row in items)
          _card(
            title: row.title.isEmpty ? row.studentName : row.title,
            subtitle: [
              row.studentName,
              row.status.name,
              row.category,
              if (row.assignedTo.isNotEmpty) 'assigned ${row.assignedTo}',
              if (row.dueAt != null)
                'due ${row.dueAt!.toIso8601String().split('T').first}',
            ].join(' · '),
            body: [
              if (row.details.trim().isNotEmpty) Text(row.details),
              if (row.resolution.trim().isNotEmpty)
                Text('Resolution: ${row.resolution}'),
              if (_canManage && row.status != GrievanceStatus.resolved)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _assignGrievance(row),
                      child: const Text('Assign'),
                    ),
                    TextButton(
                      onPressed: () => _svc.reviewGrievance(
                        row.id,
                        GrievanceStatus.reviewing,
                      ),
                      child: const Text('Review'),
                    ),
                    FilledButton(
                      onPressed: () => _resolveGrievance(row),
                      child: const Text('Resolve'),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  Widget _internshipsTab() {
    final items = _svc.internshipsForSchool(_schoolId);
    return _list(
      action: _canManage
          ? FilledButton.icon(
              onPressed: _addInternship,
              icon: const Icon(Icons.add),
              label: const Text('New internship'),
            )
          : null,
      empty: 'No internships recorded.',
      children: [
        for (final row in items)
          _card(
            title: '${row.studentName} · ${row.host}',
            subtitle: [
              row.role,
              row.status.name,
              if (row.careerField.isNotEmpty) row.careerField,
              if (row.hoursLogged > 0)
                '${row.hoursLogged.toStringAsFixed(0)}h logged',
            ].join(' · '),
            body: [
              if (row.supervisor.trim().isNotEmpty)
                Text('Supervisor: ${row.supervisor}'),
              if (row.notes.trim().isNotEmpty) Text(row.notes),
              if (_canManage)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final status in InternshipStatus.values)
                      TextButton(
                        onPressed: () =>
                            _svc.updateInternshipStatus(row.id, status),
                        child: Text(status.name),
                      ),
                    TextButton(
                      onPressed: () => _svc.logInternshipHours(row.id, 1),
                      child: const Text('+1 career hour'),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  Widget _engagementStrip() {
    final snap = _svc.engagementForSchool(_schoolId);
    Widget chip(String label, int value) {
      return Chip(
        visualDensity: VisualDensity.compact,
        label: Text('$label · $value'),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Clubs', snap.publishedClubs),
        chip('Active members', snap.activeMembers),
        chip('Gojo hours', snap.gojoHours),
        chip('Scholarships', snap.pendingScholarships),
        chip('Awarded', snap.awardedScholarships),
        chip('Open grievances', snap.openGrievances),
        chip('Internships', snap.internships),
        chip('Upcoming events', snap.upcomingMeetings),
        chip('Evaluated', snap.evaluatedMembers),
        for (final entry in snap.activeByClub.entries)
          chip(entry.key, entry.value),
      ],
    );
  }

  Widget _meetingsTab() {
    final items = _svc.meetingsForSchool(_schoolId);
    return _list(
      action: _canManage
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _addMeeting,
                  icon: const Icon(Icons.add),
                  label: const Text('Leadership / graduation'),
                ),
                OutlinedButton.icon(
                  onPressed: _openLeadershipChat,
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Leadership chat'),
                ),
              ],
            )
          : null,
      empty: 'No leadership meetings or graduation events.',
      children: [
        for (final row in items)
          _card(
            title: '${row.title} · ${row.kind.name}',
            subtitle: [
              row.startsAt.toLocal().toString(),
              if (row.venue.isNotEmpty) row.venue,
              if (row.calendarEventId != null) 'On calendar',
            ].join(' · '),
            body: [
              if (row.agenda.trim().isNotEmpty) Text(row.agenda),
              if (row.notes.trim().isNotEmpty) Text(row.notes),
              if (row.transportRoute.isNotEmpty || row.transportNote.isNotEmpty)
                Text(
                  [
                    if (row.transportRoute.isNotEmpty)
                      'Bus / route ${row.transportRoute}',
                    if (row.transportNote.isNotEmpty) row.transportNote,
                  ].join(' · '),
                ),
              for (final task in row.tasks)
                CheckboxListTile(
                  dense: true,
                  value: task.done,
                  title: Text(task.title),
                  subtitle: task.assignee.isEmpty ? null : Text(task.assignee),
                  onChanged: _canManage
                      ? (_) => _svc.toggleTask(row.id, task.id)
                      : null,
                ),
              if (_canManage)
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () => _addMeetingTask(row),
                      child: const Text('Add task'),
                    ),
                    TextButton(
                      onPressed: () => _updateMeetingNotes(row),
                      child: const Text('Update notes'),
                    ),
                    if (row.kind != DosaMeetingKind.leadership)
                      TextButton(
                        onPressed: () => _editMeetingLogistics(row),
                        child: const Text('Venue / transport'),
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  Widget _oversightTab() {
    final flags = _svc.attendanceOversight(_schoolId);
    final buses = _svc.transportCoordination(_schoolId);
    final trips = _svc.academicTransportEvents(_schoolId);
    return _list(
      empty: 'No attendance flags or academic transport notes.',
      children: [
        const Text(
          'Attendance oversight reads the live register. Transport lists the '
          'existing bus register for graduation / field-trip coordination. '
          'Neither writes attendance or GPS.',
        ),
        const SizedBox(height: 12),
        Text(
          flags.isEmpty
              ? 'No at-risk attendance flags.'
              : 'At-risk attendance: ${flags.length}',
        ),
        for (final row in flags)
          _card(
            title: '${row.studentName} · ${row.className}',
            subtitle:
                '${row.level.name} · present ${row.attendanceRate.toStringAsFixed(0)}% · '
                '${row.consecutiveAbsences} consecutive absences',
            body: [
              if (row.patterns.isNotEmpty)
                Text(row.patterns.map((p) => p.label).join(' · ')),
            ],
          ),
        const SizedBox(height: 8),
        Text(
          buses.isEmpty
              ? 'No published buses on the transport register.'
              : 'Academic transport routes: ${buses.length}',
        ),
        for (final bus in buses)
          _card(
            title: '${bus.busNumber} · ${bus.routeName}',
            subtitle: [
              bus.busId,
              if (bus.plateNumber.isNotEmpty) bus.plateNumber,
              'cap ${bus.capacity}',
            ].join(' · '),
            body: [
              if ((bus.notes ?? '').trim().isNotEmpty) Text(bus.notes!),
            ],
          ),
        if (trips.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Graduation / event transport notes'),
          for (final row in trips)
            _card(
              title: '${row.title} · ${row.kind.name}',
              subtitle: [
                if (row.venue.isNotEmpty) row.venue,
                if (row.transportRoute.isNotEmpty) row.transportRoute,
              ].join(' · '),
              body: [
                if (row.transportNote.isNotEmpty) Text(row.transportNote),
              ],
            ),
        ],
      ],
    );
  }

  Widget _tasksTab() {
    final items = _svc.leadershipTasksForSchool(_schoolId);
    return _list(
      action: _canManage
          ? FilledButton.icon(
              onPressed: _addLeadershipTask,
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('Leadership task'),
            )
          : null,
      empty: 'No open leadership tasks. Meeting checklists stay on the meeting.',
      children: [
        for (final row in items)
          _card(
            title: row.title,
            subtitle: [
              if (row.assignee.trim().isNotEmpty) row.assignee,
              if (row.dueAt != null)
                'Due ${row.dueAt!.toIso8601String().substring(0, 10)}',
              row.done ? 'Done' : 'Open',
            ].join(' · '),
            body: [
              if (row.notes.trim().isNotEmpty) Text(row.notes),
              if (_canManage)
                CheckboxListTile(
                  dense: true,
                  value: row.done,
                  title: const Text('Complete'),
                  onChanged: (_) => _svc.toggleLeadershipTask(row.id),
                ),
            ],
          ),
      ],
    );
  }

  Widget _list({
    Widget? action,
    required String empty,
    required List<Widget> children,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (action != null) ...[
          Align(alignment: Alignment.centerLeft, child: action),
          const SizedBox(height: 12),
        ],
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(empty),
          )
        else
          ...children,
      ],
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required List<Widget> body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: WebErpTheme.cardDecoration(context),
        child: ExpansionTile(
          title: Text(title),
          subtitle: Text(subtitle),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: body,
        ),
      ),
    );
  }

  Future<String?> _pickStudent() async {
    final students = _students;
    if (students.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active students found.')),
        );
      }
      return null;
    }
    var studentId = students.first.studentId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Student'),
          content: DropdownButtonFormField<String>(
            key: ValueKey(studentId),
            initialValue: studentId,
            items: [
              for (final s in students)
                DropdownMenuItem(
                  value: s.studentId,
                  child: Text('${s.fullName} (${s.className})'),
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

  Future<void> _addClub() async {
    var kind = ClubKind.club;
    final name = TextEditingController();
    final advisor = TextEditingController();
    final day = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Club / Gojo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              DropdownButtonFormField<ClubKind>(
                key: ValueKey(kind),
                initialValue: kind,
                items: [
                  for (final value in ClubKind.values)
                    DropdownMenuItem(value: value, child: Text(value.name)),
                ],
                onChanged: (v) => setDialogState(() => kind = v ?? kind),
              ),
              TextField(
                controller: advisor,
                decoration: const InputDecoration(labelText: 'Advisor'),
              ),
              TextField(
                controller: day,
                decoration: const InputDecoration(labelText: 'Meeting day'),
              ),
              TextField(
                controller: desc,
                decoration: const InputDecoration(labelText: 'Description'),
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await _svc.createClub(
      name: name.text,
      kind: kind,
      advisorName: advisor.text,
      meetingDay: day.text,
      description: desc.text,
    );
  }

  Future<void> _enrollStudent(String clubId) async {
    final studentId = await _pickStudent();
    if (studentId == null) return;
    await _svc.joinClub(clubId: clubId, studentId: studentId);
  }

  Future<void> _addScholarship() async {
    final studentId = await _pickStudent();
    if (studentId == null) return;
    final title = TextEditingController(text: 'Merit scholarship');
    await _svc.applyScholarship(studentId: studentId, title: title.text);
  }

  Future<void> _resolveGrievance(Grievance row) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve grievance'),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Resolution'),
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
    if (ok != true) return;
    await _svc.reviewGrievance(
      row.id,
      GrievanceStatus.resolved,
      resolution: note.text,
    );
  }

  Future<void> _addInternship() async {
    final studentId = await _pickStudent();
    if (studentId == null) return;
    final host = TextEditingController();
    final role = TextEditingController();
    final field = TextEditingController();
    final supervisor = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Internship / career placement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: host,
              decoration: const InputDecoration(labelText: 'Host'),
            ),
            TextField(
              controller: role,
              decoration: const InputDecoration(labelText: 'Role'),
            ),
            TextField(
              controller: field,
              decoration: const InputDecoration(labelText: 'Career field'),
            ),
            TextField(
              controller: supervisor,
              decoration: const InputDecoration(labelText: 'Supervisor'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.addInternship(
      studentId: studentId,
      host: host.text,
      role: role.text,
      careerField: field.text,
      supervisor: supervisor.text,
    );
  }

  Future<void> _addLeadershipTask() async {
    final title = TextEditingController();
    final assignee = TextEditingController();
    final notes = TextEditingController();
    DateTime? dueAt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Leadership task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Task'),
            ),
            TextField(
              controller: assignee,
              decoration: const InputDecoration(labelText: 'Assignee'),
            ),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: dueAt ?? DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setDialogState(() => dueAt = picked);
              },
              child: Text(
                dueAt == null
                    ? 'Set due date'
                    : 'Due ${dueAt!.toIso8601String().split('T').first}',
              ),
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
            child: const Text('Save'),
          ),
        ],
      ),
      ),
    );
    if (ok != true) return;
    await _svc.addLeadershipTask(
      title: title.text,
      assignee: assignee.text,
      notes: notes.text,
      dueAt: dueAt,
    );
  }

  Future<void> _addMeeting() async {
    var kind = DosaMeetingKind.leadership;
    final title = TextEditingController();
    final agenda = TextEditingController();
    final venue = TextEditingController();
    final route = TextEditingController();
    final transport = TextEditingController();
    final task = TextEditingController();
    var starts = DateTime.now().add(const Duration(days: 1));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Leadership / event'),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<DosaMeetingKind>(
                key: ValueKey(kind),
                initialValue: kind,
                items: [
                  for (final value in DosaMeetingKind.values)
                    DropdownMenuItem(value: value, child: Text(value.name)),
                ],
                onChanged: (v) => setDialogState(() => kind = v ?? kind),
              ),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: agenda,
                decoration: const InputDecoration(labelText: 'Agenda'),
              ),
              TextButton(
                onPressed: () async {
                  final day = await showDatePicker(
                    context: ctx,
                    initialDate: starts,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2035),
                  );
                  if (day == null) return;
                  setDialogState(() {
                    starts = DateTime(
                      day.year,
                      day.month,
                      day.day,
                      starts.hour,
                      starts.minute,
                    );
                  });
                },
                child: Text(
                  'Starts ${starts.toIso8601String().split('T').first}',
                ),
              ),
              TextField(
                controller: venue,
                decoration: const InputDecoration(labelText: 'Venue'),
              ),
              TextField(
                controller: route,
                decoration: const InputDecoration(
                  labelText: 'Bus / route (academic coordination)',
                ),
              ),
              TextField(
                controller: transport,
                decoration: const InputDecoration(
                  labelText: 'Transport note',
                ),
              ),
              TextField(
                controller: task,
                decoration: const InputDecoration(labelText: 'First task'),
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    await _svc.recordMeeting(
      title: title.text,
      startsAt: starts,
      kind: kind,
      agenda: agenda.text,
      venue: venue.text,
      transportRoute: route.text,
      transportNote: transport.text,
      tasks: task.text.trim().isEmpty
          ? const []
          : [
              DosaTask(id: 'T-0001', title: task.text.trim()),
            ],
    );
  }

  Future<void> _assignGrievance(Grievance row) async {
    final assignee = TextEditingController(text: row.assignedTo);
    var category = row.category;
    DateTime? dueAt = row.dueAt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Assign grievance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'academic', child: Text('Academic')),
                  DropdownMenuItem(
                    value: 'transport',
                    child: Text('Transport'),
                  ),
                  DropdownMenuItem(value: 'welfare', child: Text('Welfare')),
                  DropdownMenuItem(
                    value: 'facilities',
                    child: Text('Facilities'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) =>
                    setDialogState(() => category = v ?? category),
              ),
              TextField(
                controller: assignee,
                decoration: const InputDecoration(labelText: 'Assignee'),
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: dueAt ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setDialogState(() => dueAt = picked);
                  }
                },
                child: Text(
                  dueAt == null
                      ? 'Set due date'
                      : 'Due ${dueAt!.toIso8601String().split('T').first}',
                ),
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _svc.reviewGrievance(
      row.id,
      row.status,
      assignedTo: assignee.text,
      dueAt: dueAt,
      category: category,
    );
  }

  Future<void> _editMeetingLogistics(DosaMeeting row) async {
    final venue = TextEditingController(text: row.venue);
    final route = TextEditingController(text: row.transportRoute);
    final note = TextEditingController(text: row.transportNote);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Venue / academic transport'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: venue,
              decoration: const InputDecoration(labelText: 'Venue'),
            ),
            TextField(
              controller: route,
              decoration: const InputDecoration(labelText: 'Bus / route'),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Transport note'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.updateMeetingLogistics(
      id: row.id,
      venue: venue.text,
      transportRoute: route.text,
      transportNote: note.text,
    );
  }

  Future<void> _evaluateMember(ClubMembership row) async {
    var rating = row.engagementRating ?? 3;
    final notes = TextEditingController(text: row.evaluationNotes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Evaluate ${row.studentName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: rating,
                decoration: const InputDecoration(labelText: 'Engagement (1–5)'),
                items: [
                  for (var i = 1; i <= 5; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: (v) => setDialogState(() => rating = v ?? rating),
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _svc.evaluateMembership(
      id: row.id,
      engagementRating: rating,
      evaluationNotes: notes.text,
    );
  }

  Future<void> _openClubDiscussion(String clubId) async {
    try {
      _svc.ensureClubDiscussion(clubId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Club discussion is ready in Messages.'),
        ),
      );
      widget.onNavigate?.call('support');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _addMeetingTask(DosaMeeting row) async {
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Meeting task'),
        content: TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Task'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    await _svc.addMeetingTask(meetingId: row.id, title: title.text);
  }

  Future<void> _updateMeetingNotes(DosaMeeting row) async {
    final notes = TextEditingController(text: row.notes);
    final agenda = TextEditingController(text: row.agenda);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update meeting'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: agenda,
              decoration: const InputDecoration(labelText: 'Agenda'),
            ),
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.updateMeeting(
      id: row.id,
      agenda: agenda.text,
      notes: notes.text,
    );
  }

  Future<void> _openLeadershipChat() async {
    try {
      _svc.openLeadershipChat();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'DoSA leadership chat is ready. Minutes stay on the meeting record.',
          ),
        ),
      );
      widget.onNavigate?.call('support');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}
