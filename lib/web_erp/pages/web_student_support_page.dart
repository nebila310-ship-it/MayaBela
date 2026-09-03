import 'package:flutter/material.dart';

import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/student_support_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// Care desk: health, counseling, IEP, college, requests, and (when allowed)
/// child-protection files. Safeguarding stays off parent and student tiles.
class WebStudentSupportPage extends StatefulWidget {
  const WebStudentSupportPage({
    super.key,
    this.safeguardingOnly = false,
    this.onNavigate,
  });

  final bool safeguardingOnly;
  final ValueChanged<String>? onNavigate;

  @override
  State<WebStudentSupportPage> createState() => _WebStudentSupportPageState();
}

class _WebStudentSupportPageState extends State<WebStudentSupportPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _svc = StudentSupportService.instance;

  bool get _canManage => ModuleAccess.canManage('student_affairs');
  bool get _canViewCp => ModuleAccess.canView('safeguarding');
  bool get _canManageCp => ModuleAccess.canManage('safeguarding');
  String get _schoolId => AuthService.activeSchoolId ?? '';

  List<String> get _tabIds {
    if (widget.safeguardingOnly) return const ['safeguarding'];
    return [
      'health',
      'counseling',
      'iep',
      'college',
      'requests',
      if (_canViewCp) 'safeguarding',
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabIds.length, vsync: this);
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
                    widget.safeguardingOnly
                        ? 'Safeguarding'
                        : 'Student support',
                    style: WebErpTheme.sectionTitle(context),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.safeguardingOnly
                        ? 'Child-protection case files stay on this desk. '
                            'Do not put case narrative in parent chat.'
                        : 'Clinic, counseling, IEP, and college guidance. '
                            'Child-protection files use the Safeguarding tab. '
                            'This does not enter grades.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      for (final id in _tabIds) Tab(text: _tabLabel(id)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  for (final id in _tabIds) _tabBody(id),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _tabLabel(String id) => switch (id) {
        'health' => 'Health (${_svc.healthForSchool(_schoolId).length})',
        'counseling' =>
          'Counseling (${_svc.counselingForSchool(_schoolId).length})',
        'iep' => 'IEP (${_svc.iepForSchool(_schoolId).length})',
        'college' => 'College (${_svc.collegeForSchool(_schoolId).length})',
        'requests' => 'Requests (${_svc.pendingRequestCount(_schoolId)})',
        'safeguarding' =>
          'Safeguarding (${_svc.openSafeguardingCount(_schoolId)})',
        _ => id,
      };

  Widget _tabBody(String id) => switch (id) {
        'health' => _healthTab(),
        'counseling' => _counselingTab(),
        'iep' => _iepTab(),
        'college' => _collegeTab(),
        'requests' => _requestsTab(),
        'safeguarding' => _safeguardingTab(),
        _ => const SizedBox.shrink(),
      };

  Widget _healthTab() {
    final items = _svc.healthForSchool(_schoolId);
    return _listTab(
      action: _canManage
          ? FilledButton.icon(
              onPressed: _addHealth,
              icon: const Icon(Icons.add),
              label: const Text('Clinic / vaccine / medication'),
            )
          : null,
      empty: 'No clinic, vaccination, or medication notes yet.',
      children: [
        for (final row in items)
          _card(
            title: row.title.isEmpty ? row.type.name : row.title,
            subtitle:
                '${row.studentName} · ${row.type.name}'
                '${row.className == null || row.className!.isEmpty ? '' : ' · ${row.className}'}',
            body: [
              if (row.details.trim().isNotEmpty) Text(row.details),
              if (row.staffNotes.trim().isNotEmpty)
                Text('Staff notes: ${row.staffNotes}'),
              _parentBtn(row.studentId),
            ],
          ),
      ],
    );
  }

  Widget _counselingTab() {
    final items = _svc.counselingForSchool(_schoolId);
    return _listTab(
      action: _canManage
          ? FilledButton.icon(
              onPressed: _addCounseling,
              icon: const Icon(Icons.add),
              label: const Text('Session / appointment / referral'),
            )
          : null,
      empty: 'No counseling sessions or appointments yet.',
      children: [
        for (final row in items)
          _card(
            title: row.title.isEmpty ? row.kind.name : row.title,
            subtitle: '${row.studentName} · ${row.kind.name}',
            body: [
              if (row.parentSummary.trim().isNotEmpty)
                Text('Parent summary: ${row.parentSummary}'),
              if (row.staffNotes.trim().isNotEmpty)
                Text('Staff notes: ${row.staffNotes}'),
              if (row.referralTo != null && row.referralTo!.trim().isNotEmpty)
                Text('Referral: ${row.referralTo}'),
              _parentBtn(row.studentId),
            ],
          ),
      ],
    );
  }

  Widget _iepTab() {
    final items = _svc.iepForSchool(_schoolId);
    return _listTab(
      action: _canManage
          ? FilledButton.icon(
              onPressed: _addIep,
              icon: const Icon(Icons.add),
              label: const Text('New IEP'),
            )
          : null,
      empty: 'No special-needs plans yet.',
      children: [
        for (final row in items)
          _card(
            title: '${row.studentName} · ${row.stage.name}',
            subtitle: row.parentAgreed
                ? 'Parent signed ${row.parentSignedAt}'
                : 'Awaiting parent agreement',
            body: [
              if (row.goals.trim().isNotEmpty) Text('Goals: ${row.goals}'),
              if (row.accommodations.trim().isNotEmpty)
                Text('Accommodations: ${row.accommodations}'),
              if (row.staffNotes.trim().isNotEmpty)
                Text('Staff notes: ${row.staffNotes}'),
              if (_canManage)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final stage in IepStage.values)
                      TextButton(
                        onPressed: () => _svc.updateIepStage(row.id, stage),
                        child: Text(stage.name),
                      ),
                  ],
                ),
              _parentBtn(row.studentId),
            ],
          ),
      ],
    );
  }

  Widget _collegeTab() {
    final items = _svc.collegeForSchool(_schoolId);
    return _listTab(
      action: _canManage
          ? FilledButton.icon(
              onPressed: _addCollege,
              icon: const Icon(Icons.add),
              label: const Text('College plan'),
            )
          : null,
      empty: 'No college-guidance plans yet.',
      children: [
        for (final row in items)
          _card(
            title: '${row.studentName} · ${row.stage.name}',
            subtitle: row.targets.trim().isEmpty ? 'No targets yet' : row.targets,
            body: [
              if (row.portfolio.trim().isNotEmpty)
                Text('Portfolio: ${row.portfolio}'),
              if (row.notes.trim().isNotEmpty) Text('Notes: ${row.notes}'),
              _parentBtn(row.studentId),
            ],
          ),
      ],
    );
  }

  Widget _requestsTab() {
    final items = _svc.requestsForSchool(_schoolId);
    return _listTab(
      empty: 'No parent or student support requests.',
      children: [
        for (final row in items)
          _card(
            title: '${row.studentName} · ${row.kind.name}',
            subtitle: '${row.status.name} · ${row.authorUsername}',
            body: [
              if (row.body.trim().isNotEmpty) Text(row.body),
              if (_canManage && row.status != SupportRequestStatus.completed)
                Wrap(
                  spacing: 8,
                  children: [
                    if (row.status == SupportRequestStatus.open)
                      TextButton(
                        onPressed: () => _svc.acknowledgeSupportRequest(row.id),
                        child: const Text('Acknowledge'),
                      ),
                    FilledButton(
                      onPressed: () => _svc.completeSupportRequest(row.id),
                      child: const Text('Complete'),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  Widget _safeguardingTab() {
    if (!_canViewCp) {
      return const Center(child: Text('Safeguarding files are restricted.'));
    }
    final items = _svc.safeguardingForSchool(_schoolId);
    return _listTab(
      action: _canManageCp
          ? FilledButton.icon(
              onPressed: _addSafeguarding,
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Open case file'),
            )
          : null,
      empty: 'No safeguarding case files.',
      children: [
        for (final row in items)
          _card(
            title: row.title.isEmpty ? row.studentName : row.title,
            subtitle:
                '${row.studentName} · ${row.status.name} · ${row.severity}',
            body: [
              if (row.details.trim().isNotEmpty) Text(row.details),
              if (_canManageCp)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final status in SafeguardingStatus.values)
                      TextButton(
                        onPressed: () =>
                            _svc.updateSafeguardingStatus(row.id, status),
                        child: Text(status.name),
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  Widget _listTab({
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
        if (children.isEmpty) _empty(empty) else ...children,
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
          children: [
            for (final child in body) ...[
              child,
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(text),
      );

  Widget _parentBtn(String studentId) {
    if (!_canManage) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _messageParent(studentId),
        icon: const Icon(Icons.chat_outlined),
        label: const Text('Parent channel'),
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
            decoration: const InputDecoration(labelText: 'Student'),
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

  Future<void> _addHealth() async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    var type = HealthRecordType.clinicVisit;
    final title = TextEditingController();
    final details = TextEditingController();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Health record'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<HealthRecordType>(
                    key: ValueKey(type),
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      for (final value in HealthRecordType.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => type = v ?? type),
                  ),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  TextField(
                    controller: details,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Details'),
                  ),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Staff notes (not shown to parents)',
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _svc.addHealthRecord(
      studentId: studentId,
      type: type,
      title: title.text,
      details: details.text,
      staffNotes: notes.text,
    );
  }

  Future<void> _addCounseling() async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    var kind = CounselingKind.appointment;
    final title = TextEditingController();
    final summary = TextEditingController();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Counseling record'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<CounselingKind>(
                    key: ValueKey(kind),
                    initialValue: kind,
                    items: [
                      for (final value in CounselingKind.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => kind = v ?? kind),
                  ),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  TextField(
                    controller: summary,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Parent summary',
                    ),
                  ),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Staff notes (not shown to parents)',
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _svc.addCounselingRecord(
      studentId: studentId,
      kind: kind,
      title: title.text,
      parentSummary: summary.text,
      staffNotes: notes.text,
    );
  }

  Future<void> _addIep() async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    final goals = TextEditingController();
    final accommodations = TextEditingController();
    final notes = TextEditingController();
    final agreement = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('IEP / special needs'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: goals,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Goals'),
                ),
                TextField(
                  controller: accommodations,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Accommodations'),
                ),
                TextField(
                  controller: agreement,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Parent agreement text'),
                ),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Staff notes (not shown to parents)',
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.addIepPlan(
      studentId: studentId,
      goals: goals.text,
      accommodations: accommodations.text,
      parentAgreementText: agreement.text,
      staffNotes: notes.text,
      stage: IepStage.draftPlan,
    );
  }

  Future<void> _addCollege() async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    var stage = CollegeStage.exploring;
    final targets = TextEditingController();
    final portfolio = TextEditingController();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('College guidance'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<CollegeStage>(
                    key: ValueKey(stage),
                    initialValue: stage,
                    items: [
                      for (final value in CollegeStage.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => stage = v ?? stage),
                  ),
                  TextField(
                    controller: targets,
                    decoration: const InputDecoration(labelText: 'Targets'),
                  ),
                  TextField(
                    controller: portfolio,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Portfolio'),
                  ),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes'),
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _svc.upsertCollegePlan(
      studentId: studentId,
      stage: stage,
      targets: targets.text,
      portfolio: portfolio.text,
      notes: notes.text,
    );
  }

  Future<void> _addSafeguarding() async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    final title = TextEditingController();
    final details = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Safeguarding case file'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: details,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Case details (never send in parent chat)',
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
            child: const Text('Open file'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.openSafeguardingCase(
      studentId: studentId,
      title: title.text,
      details: details.text,
    );
  }

  Future<void> _messageParent(String studentId) async {
    final body = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Parent channel'),
        content: TextField(
          controller: body,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Message',
            hintText: 'Do not include safeguarding case narrative.',
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
    );
    if (ok != true) return;
    try {
      await _svc.openParentChannel(studentId: studentId, body: body.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parent message sent.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }
}
