import 'package:flutter/material.dart';

import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/school_report_export_service.dart';
import 'package:mayabela/services/student_support_service.dart';
import 'package:mayabela/widgets/course_attachment_picker.dart';
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
  String _healthFilter = 'today';
  DateTime _clinicDay = DateTime.now();
  String? _exporting;

  bool get _canManage => ModuleAccess.canManage('student_affairs');
  bool get _canViewCp => ModuleAccess.canView('safeguarding');
  bool get _canManageCp => ModuleAccess.canManage('safeguarding');
  String get _schoolId => AuthService.activeSchoolId ?? '';

  List<String> get _tabIds {
    if (widget.safeguardingOnly) return const ['safeguarding'];
    return [
      'health',
      'meds',
      'vault',
      'counseling',
      'iep',
      'sel',
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
                        : 'Clinic log, vaccinations, emergency alerts, and '
                            'clinic medication stock on the existing care '
                            'register. Child-protection files stay on Safeguarding. '
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
        'meds' => 'Meds (${_svc.medicationStockForSchool(_schoolId).length})',
        'vault' => 'Vault (${_svc.documentsForSchool(_schoolId).length})',
        'counseling' =>
          'Counseling (${_svc.counselingForSchool(_schoolId).length})',
        'iep' => 'IEP (${_svc.iepForSchool(_schoolId).length})',
        'sel' => 'SEL (${_svc.selForSchool(_schoolId).length})',
        'college' => 'College (${_svc.collegeForSchool(_schoolId).length})',
        'requests' => 'Requests (${_svc.pendingRequestCount(_schoolId)})',
        'safeguarding' =>
          'Safeguarding (${_svc.openSafeguardingCount(_schoolId)})',
        _ => id,
      };

  Widget _tabBody(String id) => switch (id) {
        'health' => _healthTab(),
        'meds' => _medsTab(),
        'vault' => _vaultTab(),
        'counseling' => _counselingTab(),
        'iep' => _iepTab(),
        'sel' => _selTab(),
        'college' => _collegeTab(),
        'requests' => _requestsTab(),
        'safeguarding' => _safeguardingTab(),
        _ => const SizedBox.shrink(),
      };

  Widget _healthTab() {
    final all = _svc.healthForSchool(_schoolId);
    final summary = _svc.clinicSummaryForDate(_clinicDay, _schoolId);
    final due = _svc.vaccinesDueSoon(schoolId: _schoolId);
    final items = switch (_healthFilter) {
      'today' => _svc.clinicLogForDate(_clinicDay, _schoolId),
      'clinic' => all.where((r) => r.type == HealthRecordType.clinicVisit).toList(),
      'vaccine' => all.where((r) => r.type == HealthRecordType.vaccination).toList(),
      'meds' => all.where((r) => r.type == HealthRecordType.medication).toList(),
      'alert' =>
        all.where((r) => r.type == HealthRecordType.emergencyAlert).toList(),
      'due' => due,
      _ => all,
    };
    return _listTab(
      action: null,
      empty: 'No clinic notes in this view.',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_canManage)
              FilledButton.icon(
                onPressed: _addHealth,
                icon: const Icon(Icons.add),
                label: const Text('Log clinic / vaccine / alert'),
              ),
            TextButton.icon(
              onPressed: _pickClinicDay,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                'Clinic day ${_clinicDay.year}-'
                '${_clinicDay.month.toString().padLeft(2, '0')}-'
                '${_clinicDay.day.toString().padLeft(2, '0')}',
              ),
            ),
            if (_canManage)
              FilledButton.tonalIcon(
                onPressed: _exporting != null ? null : _exportHealth,
                icon: const Icon(Icons.download_outlined),
                label: Text(_exporting == null ? 'Export clinic CSV' : 'Exporting…'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Today’s log: ${summary.visits} visits · '
          '${summary.vaccinations} vaccines · '
          '${summary.medications} meds · '
          '${summary.alerts} alerts'
          '${due.isEmpty ? '' : ' · ${due.length} vaccine(s) due'}',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final (value, label) in const [
              ('today', 'Daily log'),
              ('all', 'All records'),
              ('clinic', 'Clinic'),
              ('vaccine', 'Vaccines'),
              ('due', 'Due soon'),
              ('meds', 'Medication'),
              ('alert', 'Emergencies'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _healthFilter == value,
                onSelected: (_) => setState(() => _healthFilter = value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Text('No clinic notes in this view.')
        else
          for (final row in items)
            _card(
              title: row.title.isEmpty ? row.type.name : row.title,
              subtitle: [
                row.studentName,
                row.type.name,
                if (row.className != null && row.className!.isNotEmpty)
                  row.className!,
                if (row.isUrgent) 'URGENT',
                row.recordedAt.toIso8601String().split('T').first,
              ].join(' · '),
              body: [
                if (row.details.trim().isNotEmpty) Text(row.details),
                if (row.vaccineName.isNotEmpty)
                  Text(
                    'Vaccine ${row.vaccineName}'
                    '${row.doseNumber == null ? '' : ' · dose ${row.doseNumber}'}'
                    '${row.nextDueAt == null ? '' : ' · next ${row.nextDueAt!.toIso8601String().split('T').first}'}',
                  ),
                if (row.quantity != null)
                  Text('Given ${row.quantity} ${row.unit}'),
                if (row.createdBy != null && row.createdBy!.isNotEmpty)
                  Text('Recorded by ${row.createdBy}'),
                if (row.parentNotifiedAt != null)
                  Text('Parent notified ${row.parentNotifiedAt}'),
                if (row.staffNotes.trim().isNotEmpty)
                  Text('Staff notes: ${row.staffNotes}'),
                _parentBtn(row.studentId),
              ],
            ),
      ],
    );
  }

  Widget _medsTab() {
    final items = _svc.medicationStockForSchool(_schoolId);
    return _listTab(
      action: _canManage
          ? FilledButton.icon(
              onPressed: _addMedStock,
              icon: const Icon(Icons.add),
              label: const Text('Add medication'),
            )
          : null,
      empty: 'No clinic medication stock yet. This is not the school store.',
      children: [
        for (final row in items)
          _card(
            title:
                '${row.name} · ${row.quantityOnHand.toStringAsFixed(0)} ${row.unit}',
            subtitle: [
              if (row.needsReorder)
                'Reorder at ${row.reorderLevel.toStringAsFixed(0)}'
              else
                'On hand',
              if (row.batchNumber.isNotEmpty) 'batch ${row.batchNumber}',
              if (row.expiresAt != null)
                'exp ${row.expiresAt!.toIso8601String().split('T').first}',
            ].join(' · '),
            body: [
              if (row.notes.trim().isNotEmpty) Text(row.notes),
              if (row.movements.isNotEmpty)
                Text(
                  'Ledger: ${row.movements.reversed.take(4).map((m) {
                    final who = m.studentName == null || m.studentName!.isEmpty
                        ? m.reason
                        : '${m.reason} ${m.studentName}';
                    return '${m.delta > 0 ? '+' : ''}${m.delta} $who';
                  }).join(' · ')}',
                ),
              if (_canManage)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _svc.adjustMedicationStock(
                        id: row.id,
                        delta: 1,
                        reason: 'receive',
                        note: 'Restock +1',
                      ),
                      child: const Text('+1 restock'),
                    ),
                    TextButton(
                      onPressed: () => _dispenseMed(row),
                      child: const Text('Dispense'),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  Widget _vaultTab() {
    final items = _svc.documentsForSchool(_schoolId);
    return _listTab(
      action: _canManage
          ? FilledButton.icon(
              onPressed: _addVaultDoc,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Add student file'),
            )
          : null,
      empty: 'No per-student files yet. Admission checklists stay on Admissions.',
      children: [
        for (final row in items)
          _card(
            title: row.title.isEmpty ? row.category : row.title,
            subtitle:
                '${row.studentName} · ${row.category}'
                '${row.filePath == null ? '' : ' · attached'}',
            body: [
              if (row.notes.trim().isNotEmpty) Text(row.notes),
              _parentBtn(row.studentId),
            ],
          ),
      ],
    );
  }

  Widget _selTab() {
    final items = _svc.selForSchool(_schoolId);
    return _listTab(
      action: _canManage
          ? FilledButton.icon(
              onPressed: _addSel,
              icon: const Icon(Icons.add),
              label: const Text('SEL observation (1–5)'),
            )
          : null,
      empty: 'No SEL scores yet. These are staff ratings, not predictive ML.',
      children: [
        for (final row in items)
          _card(
            title: '${row.studentName} · ${row.domain.name} · ${row.rating}/5',
            subtitle: row.className ?? '',
            body: [
              if (row.notes.trim().isNotEmpty) Text(row.notes),
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
              if (row.trainingSessions.isNotEmpty)
                Text(
                  'Teacher training: ${row.trainingSessions.map((t) => t.topic).join(', ')}',
                ),
              if (_canManage)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final stage in IepStage.values)
                      TextButton(
                        onPressed: () => _svc.updateIepStage(row.id, stage),
                        child: Text(stage.name),
                      ),
                    TextButton(
                      onPressed: () => _addIepTraining(row.id),
                      child: const Text('Log teacher training'),
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
              for (final art in row.artifacts)
                CheckboxListTile(
                  dense: true,
                  value: art.done,
                  title: Text('${art.kind.name} · ${art.title}'),
                  subtitle: Text(
                    [
                      if (art.dueAt != null)
                        'Due ${art.dueAt!.toIso8601String().substring(0, 10)}',
                      if (art.filePath != null) 'File attached',
                    ].join(' · '),
                  ),
                  onChanged: _canManage
                      ? (_) => _svc.toggleCollegeArtifact(row.studentId, art.id)
                      : null,
                ),
              if (_canManage)
                TextButton(
                  onPressed: () => _addCollegeArtifact(row.studentId),
                  child: const Text('Add essay / rec / deadline'),
                ),
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

  Future<void> _pickClinicDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _clinicDay,
      firstDate: DateTime(2024),
      lastDate: DateTime(2032),
    );
    if (picked == null) return;
    setState(() {
      _clinicDay = picked;
      _healthFilter = 'today';
    });
  }

  Future<void> _exportHealth() async {
    setState(() => _exporting = 'health');
    try {
      await SchoolReportExportService.instance.export(
        kind: SchoolReportKind.health,
        format: 'csv',
      );
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  Future<void> _addHealth() async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    var type = HealthRecordType.clinicVisit;
    var severity = 'routine';
    var vaccineName = '';
    var occurredAt = DateTime.now();
    DateTime? nextDue;
    final title = TextEditingController();
    final details = TextEditingController();
    final notes = TextEditingController();
    final dose = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Clinic record'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<HealthRecordType>(
                    key: ValueKey(type),
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(
                        value: HealthRecordType.clinicVisit,
                        child: Text('Clinic visit'),
                      ),
                      DropdownMenuItem(
                        value: HealthRecordType.vaccination,
                        child: Text('Vaccination'),
                      ),
                      DropdownMenuItem(
                        value: HealthRecordType.medication,
                        child: Text('Medication given'),
                      ),
                      DropdownMenuItem(
                        value: HealthRecordType.emergencyAlert,
                        child: Text('Emergency alert'),
                      ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => type = v ?? type),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: severity,
                    decoration: const InputDecoration(labelText: 'Severity'),
                    items: const [
                      DropdownMenuItem(value: 'routine', child: Text('Routine')),
                      DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => severity = v ?? severity),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: occurredAt,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2032),
                      );
                      if (picked != null) {
                        setDialogState(() => occurredAt = picked);
                      }
                    },
                    child: Text(
                      'Recorded ${occurredAt.year}-'
                      '${occurredAt.month.toString().padLeft(2, '0')}-'
                      '${occurredAt.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Complaint / title',
                    ),
                  ),
                  TextField(
                    controller: details,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Treatment / details',
                    ),
                  ),
                  if (type == HealthRecordType.vaccination) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final name in HealthVaccineHints.names)
                          FilterChip(
                            label: Text(name),
                            selected: vaccineName == name,
                            onSelected: (on) => setDialogState(
                              () => vaccineName = on ? name : '',
                            ),
                          ),
                      ],
                    ),
                    TextField(
                      controller: dose,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Dose number'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: nextDue ?? DateTime.now().add(
                            const Duration(days: 30),
                          ),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setDialogState(() => nextDue = picked);
                        }
                      },
                      child: Text(
                        nextDue == null
                            ? 'Set next due date'
                            : 'Next due ${nextDue!.toIso8601String().split('T').first}',
                      ),
                    ),
                  ],
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
      title: title.text.isEmpty && vaccineName.isNotEmpty
          ? vaccineName
          : title.text,
      details: details.text,
      staffNotes: notes.text,
      occurredAt: occurredAt,
      severity: severity,
      vaccineName: vaccineName,
      doseNumber: int.tryParse(dose.text),
      nextDueAt: nextDue,
      notifyParent: type == HealthRecordType.emergencyAlert ||
          severity == 'urgent',
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

  Future<void> _addMedStock() async {
    final name = TextEditingController();
    final qty = TextEditingController(text: '0');
    final reorder = TextEditingController(text: '5');
    final unit = TextEditingController(text: 'unit');
    final batch = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clinic medication stock'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: unit,
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
              TextField(
                controller: qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'On hand'),
              ),
              TextField(
                controller: reorder,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Reorder level'),
              ),
              TextField(
                controller: batch,
                decoration: const InputDecoration(labelText: 'Batch number'),
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
    );
    if (ok != true) return;
    await _svc.upsertMedicationStock(
      name: name.text,
      unit: unit.text,
      quantityOnHand: double.tryParse(qty.text) ?? 0,
      reorderLevel: double.tryParse(reorder.text) ?? 0,
      batchNumber: batch.text,
    );
  }

  Future<void> _dispenseMed(MedicationStockItem row) async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    final qty = TextEditingController(text: '1');
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Dispense ${row.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Quantity (${row.unit})'),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Dose / note'),
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
            child: const Text('Record'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final amount = double.tryParse(qty.text) ?? 1;
    await _svc.adjustMedicationStock(
      id: row.id,
      delta: -amount.abs(),
      studentId: studentId,
      note: note.text,
      reason: 'dispense',
    );
  }

  Future<void> _addVaultDoc() async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    final title = TextEditingController();
    final category = TextEditingController(text: 'identity');
    var paths = <String>[];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Student document vault'),
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
                  controller: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'identity, medical, transcript…',
                  ),
                ),
                const SizedBox(height: 8),
                CourseAttachmentPicker(
                  paths: paths,
                  subdir: 'student_documents',
                  sectionTitle: 'File',
                  onChanged: (next) => setDialogState(() => paths = next),
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
    if (ok != true) return;
    await _svc.addStudentDocument(
      studentId: studentId,
      title: title.text,
      category: category.text,
      filePath: paths.isEmpty ? null : paths.first,
    );
  }

  Future<void> _addSel() async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    var domain = SelDomain.selfAwareness;
    var rating = 3;
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('SEL observation'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<SelDomain>(
                  initialValue: domain,
                  items: [
                    for (final value in SelDomain.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.name),
                      ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => domain = v ?? domain),
                ),
                DropdownButtonFormField<int>(
                  initialValue: rating,
                  decoration: const InputDecoration(labelText: 'Rating 1–5'),
                  items: [
                    for (var i = 1; i <= 5; i++)
                      DropdownMenuItem(value: i, child: Text('$i')),
                  ],
                  onChanged: (v) => setDialogState(() => rating = v ?? rating),
                ),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes'),
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
    if (ok != true) return;
    await _svc.addSelObservation(
      studentId: studentId,
      domain: domain,
      rating: rating,
      notes: notes.text,
    );
  }

  Future<void> _addIepTraining(String planId) async {
    final topic = TextEditingController();
    final trainer = TextEditingController();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('IEP teacher training'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: topic,
                decoration: const InputDecoration(labelText: 'Topic'),
              ),
              TextField(
                controller: trainer,
                decoration: const InputDecoration(labelText: 'Trainer'),
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
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
            child: const Text('Log'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.addIepTraining(
      planId: planId,
      topic: topic.text,
      trainer: trainer.text,
      notes: notes.text,
      trainedAt: DateTime.now(),
    );
  }

  Future<void> _addCollegeArtifact(String studentId) async {
    var kind = CollegeArtifactKind.essay;
    final title = TextEditingController();
    var paths = <String>[];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('College artifact'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<CollegeArtifactKind>(
                  initialValue: kind,
                  items: [
                    for (final value in CollegeArtifactKind.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.name),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => kind = v ?? kind),
                ),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                CourseAttachmentPicker(
                  paths: paths,
                  subdir: 'college_artifacts',
                  sectionTitle: 'File',
                  onChanged: (next) => setDialogState(() => paths = next),
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
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _svc.addCollegeArtifact(
      studentId: studentId,
      title: title.text,
      kind: kind,
      filePath: paths.isEmpty ? null : paths.first,
    );
  }
}
