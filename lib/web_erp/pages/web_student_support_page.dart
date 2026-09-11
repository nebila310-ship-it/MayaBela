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
  String _vaultFilter = 'all';
  String _counselFilter = 'all';
  String _iepFilter = 'all';
  String _requestFilter = 'all';
  String _sgFilter = 'all';
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
                        : 'International-school care desk: clinic disposition, '
                            'MAR medication, confidential vault, counseling, '
                            'MTSS/IEP, college applications, and a tracked '
                            'request queue. Child-protection files stay on '
                            'Safeguarding. This does not enter grades.',
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
    final followUps = _svc.healthFollowUpsDue(schoolId: _schoolId);
    final items = switch (_healthFilter) {
      'today' => _svc.clinicLogForDate(_clinicDay, _schoolId),
      'clinic' => all.where((r) => r.type == HealthRecordType.clinicVisit).toList(),
      'vaccine' => all.where((r) => r.type == HealthRecordType.vaccination).toList(),
      'meds' => all.where((r) => r.type == HealthRecordType.medication).toList(),
      'alert' =>
        all.where((r) => r.type == HealthRecordType.emergencyAlert).toList(),
      'due' => due,
      'followup' => followUps,
      _ => all,
    };
    return _listTab(
      action: null,
      banner: StudentSupportPlaybook.banners['health'],
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
          '${due.isEmpty ? '' : ' · ${due.length} vaccine(s) due'}'
          '${followUps.isEmpty ? '' : ' · ${followUps.length} follow-up(s)'}',
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
              ('followup', 'Follow-up'),
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
                if (row.disposition.isNotEmpty)
                  StudentSupportPlaybook.label(
                    StudentSupportPlaybook.dispositions,
                    row.disposition,
                  ),
                row.recordedAt.toIso8601String().split('T').first,
              ].join(' · '),
              body: [
                if (row.details.trim().isNotEmpty) Text(row.details),
                if (row.vitalNotes.trim().isNotEmpty)
                  Text('Vitals: ${row.vitalNotes}'),
                if (row.vaccineName.isNotEmpty)
                  Text(
                    'Vaccine ${row.vaccineName}'
                    '${row.doseNumber == null ? '' : ' · dose ${row.doseNumber}'}'
                    '${row.nextDueAt == null ? '' : ' · next ${row.nextDueAt!.toIso8601String().split('T').first}'}',
                  ),
                if (row.quantity != null)
                  Text('Given ${row.quantity} ${row.unit}'),
                if (row.followUpAt != null)
                  Text(
                    'Clinic follow-up ${_dateLabel(row.followUpAt!)}',
                  ),
                if (row.parentContactMethod.isNotEmpty)
                  Text(
                    'Parent reached via ${StudentSupportPlaybook.label(StudentSupportPlaybook.parentContactMethods, row.parentContactMethod)}',
                  ),
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
      banner: StudentSupportPlaybook.banners['meds'],
      empty: 'No clinic medication stock yet. This is not the school store.',
      children: [
        for (final row in items)
          _card(
            title:
                '${row.name} · ${row.quantityOnHand.toStringAsFixed(0)} ${row.unit}',
            subtitle: [
              if (row.controlledDrug) 'CONTROLLED',
              StudentSupportPlaybook.label(
                StudentSupportPlaybook.medRoutes,
                row.route,
              ),
              if (row.parentConsentOnFile) 'parent consent on file',
              if (row.needsReorder)
                'Reorder at ${row.reorderLevel.toStringAsFixed(0)}'
              else
                'On hand',
              if (row.batchNumber.isNotEmpty) 'batch ${row.batchNumber}',
              if (row.expiresAt != null)
                'exp ${row.expiresAt!.toIso8601String().split('T').first}',
            ].join(' · '),
            body: [
              if (row.prescriber.trim().isNotEmpty)
                Text('Prescriber: ${row.prescriber}'),
              if (row.notes.trim().isNotEmpty) Text(row.notes),
              if (row.movements.isNotEmpty)
                Text(
                  'MAR ledger: ${row.movements.reversed.take(4).map((m) {
                    final who = m.studentName == null || m.studentName!.isEmpty
                        ? m.reason
                        : '${m.reason} ${m.studentName}';
                    final witness = m.witnessedBy.isEmpty
                        ? ''
                        : ' (witness ${m.witnessedBy})';
                    return '${m.delta > 0 ? '+' : ''}${m.delta} $who$witness';
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
    final all = _svc.documentsForSchool(_schoolId);
    final reviews = _svc.vaultReviewsDue(schoolId: _schoolId);
    final items = _vaultFilter == 'review' ? reviews : all;
    return _listTab(
      action: _canManage
          ? FilledButton.icon(
              onPressed: _addVaultDoc,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Add student file'),
            )
          : null,
      banner: StudentSupportPlaybook.banners['vault'],
      empty: 'No per-student files yet. Admission checklists stay on Admissions.',
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text('All files (${all.length})'),
              selected: _vaultFilter == 'all',
              onSelected: (_) => setState(() => _vaultFilter = 'all'),
            ),
            ChoiceChip(
              label: Text('Review / expiry (${reviews.length})'),
              selected: _vaultFilter == 'review',
              onSelected: (_) => setState(() => _vaultFilter = 'review'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final row in items)
          _card(
            title: row.title.isEmpty
                ? StudentSupportPlaybook.label(
                    StudentSupportPlaybook.vaultCategories,
                    row.category,
                  )
                : row.title,
            subtitle: [
              row.studentName,
              StudentSupportPlaybook.label(
                StudentSupportPlaybook.vaultCategories,
                row.category,
              ),
              StudentSupportPlaybook.label(
                StudentSupportPlaybook.confidentiality,
                row.confidentiality,
              ),
              if (row.filePath != null) 'attached',
            ].join(' · '),
            body: [
              if (row.source.trim().isNotEmpty) Text('Source: ${row.source}'),
              if (row.reviewAt != null)
                Text('Review ${_dateLabel(row.reviewAt!)}'),
              if (row.expiresAt != null)
                Text('Expires ${_dateLabel(row.expiresAt!)}'),
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
    final all = _svc.counselingForSchool(_schoolId);
    final followUps = _svc.counselingFollowUpsDue(schoolId: _schoolId);
    final items = switch (_counselFilter) {
      'followup' => followUps,
      'crisis' => all.where((row) => row.format == 'crisis').toList(),
      'monitor' => all.where((row) => row.riskWatch == 'monitor').toList(),
      _ => all,
    };
    return _listTab(
      action: _canManage
          ? FilledButton.icon(
              onPressed: _addCounseling,
              icon: const Icon(Icons.add),
              label: const Text('Session / appointment / referral'),
            )
          : null,
      banner: StudentSupportPlaybook.banners['counseling'],
      empty: 'No counseling sessions or appointments yet.',
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final (value, label) in [
              ('all', 'All (${all.length})'),
              ('followup', 'Follow-up (${followUps.length})'),
              ('crisis', 'Crisis'),
              ('monitor', 'Risk watch'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _counselFilter == value,
                onSelected: (_) => setState(() => _counselFilter = value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final row in items)
          _card(
            title: row.title.isEmpty ? row.kind.name : row.title,
            subtitle: [
              row.studentName,
              row.kind.name,
              StudentSupportPlaybook.label(
                StudentSupportPlaybook.counselingFormats,
                row.format,
              ),
              if (row.durationMinutes != null) '${row.durationMinutes} min',
              if (row.riskWatch == 'monitor') 'MONITOR',
            ].join(' · '),
            body: [
              if (row.parentSummary.trim().isNotEmpty)
                Text('Parent summary: ${row.parentSummary}'),
              if (row.staffNotes.trim().isNotEmpty)
                Text('Staff notes: ${row.staffNotes}'),
              if (row.referralTo != null && row.referralTo!.trim().isNotEmpty)
                Text('External referral: ${row.referralTo}'),
              if (row.followUpAt != null)
                Text('Follow-up ${_dateLabel(row.followUpAt!)}'),
              Text(
                'Confidential unless DSL override. Risk-watch does not open a '
                'safeguarding case.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              _parentBtn(row.studentId),
            ],
          ),
      ],
    );
  }

  Widget _iepTab() {
    final all = _svc.iepForSchool(_schoolId);
    final items = switch (_iepFilter) {
      'tier3' => all.where((row) => row.mtssTier >= 3).toList(),
      'unsigned' => all.where((row) => !row.parentAgreed).toList(),
      _ => all,
    };
    return _listTab(
      action: _canManage
          ? FilledButton.icon(
              onPressed: _addIep,
              icon: const Icon(Icons.add),
              label: const Text('New IEP / MTSS plan'),
            )
          : null,
      banner: StudentSupportPlaybook.banners['iep'],
      empty: 'No special-needs plans yet.',
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final (value, label) in [
              ('all', 'All (${all.length})'),
              ('tier3', 'Tier 3'),
              ('unsigned', 'Awaiting parent'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _iepFilter == value,
                onSelected: (_) => setState(() => _iepFilter = value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final row in items)
          _card(
            title: '${row.studentName} · Tier ${row.mtssTier} · ${row.stage.name}',
            subtitle: [
              StudentSupportPlaybook.label(
                StudentSupportPlaybook.reviewCycles,
                row.reviewCycle,
              ),
              if (row.nextReviewAt != null)
                'review ${_dateLabel(row.nextReviewAt!)}',
              row.parentAgreed
                  ? 'Parent signed ${row.parentSignedAt}'
                  : 'Awaiting parent agreement',
            ].join(' · '),
            body: [
              if (row.goals.trim().isNotEmpty) Text('SMART goals: ${row.goals}'),
              if (row.accommodations.trim().isNotEmpty)
                Text('Classroom accommodations: ${row.accommodations}'),
              if (row.accessArrangements.isNotEmpty)
                Text(
                  'Exam access: ${row.accessArrangements.map((code) => StudentSupportPlaybook.label(StudentSupportPlaybook.accessArrangements, code)).join(', ')}',
                ),
              if (row.externalReportRef.trim().isNotEmpty)
                Text('External report: ${row.externalReportRef}'),
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
                    for (final tier in const [1, 2, 3])
                      TextButton(
                        onPressed: () => _svc.updateIepAccess(
                          id: row.id,
                          mtssTier: tier,
                        ),
                        child: Text('Tier $tier'),
                      ),
                    TextButton(
                      onPressed: () => _editIepAccess(row),
                      child: const Text('Access arrangements'),
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
      banner: StudentSupportPlaybook.banners['college'],
      empty: 'No college-guidance plans yet.',
      children: [
        for (final row in items)
          _card(
            title: '${row.studentName} · ${row.stage.name}',
            subtitle: [
              if (row.applicationSystem.isNotEmpty)
                StudentSupportPlaybook.label(
                  StudentSupportPlaybook.applicationSystems,
                  row.applicationSystem,
                ),
              if (row.destinationCountry.isNotEmpty) row.destinationCountry,
              if (row.counselorName.isNotEmpty) row.counselorName,
              row.targets.trim().isEmpty ? 'No targets yet' : row.targets,
            ].join(' · '),
            body: [
              if (row.testingPlan.trim().isNotEmpty)
                Text('Testing plan: ${row.testingPlan}'),
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
    final all = _svc.requestsForSchool(_schoolId);
    final overdue = _svc.overdueSupportRequests(schoolId: _schoolId);
    final items = switch (_requestFilter) {
      'urgent' => all
          .where((row) => row.priority == 'urgent' || row.priority == 'high')
          .toList(),
      'overdue' => overdue,
      'open' => all
          .where((row) => row.status != SupportRequestStatus.completed)
          .toList(),
      _ => all,
    };
    return _listTab(
      banner: StudentSupportPlaybook.banners['requests'],
      empty: 'No parent or student support requests.',
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final (value, label) in [
              ('all', 'All (${all.length})'),
              ('open', 'Open'),
              ('urgent', 'Urgent / high'),
              ('overdue', 'Overdue (${overdue.length})'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _requestFilter == value,
                onSelected: (_) => setState(() => _requestFilter = value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final row in items)
          _card(
            title: '${row.studentName} · ${row.kind.name}',
            subtitle: [
              row.status.name,
              StudentSupportPlaybook.label(
                StudentSupportPlaybook.requestPriorities,
                row.priority,
              ),
              row.authorUsername,
              if (row.assignedTo.isNotEmpty) 'assigned ${row.assignedTo}',
              if (row.dueAt != null) 'due ${_dateLabel(row.dueAt!)}',
            ].join(' · '),
            body: [
              if (row.body.trim().isNotEmpty) Text(row.body),
              if (row.lastActionNote.trim().isNotEmpty)
                Text('Last action: ${row.lastActionNote}'),
              if (_canManage && row.status != SupportRequestStatus.completed)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _assignRequest(row),
                      child: const Text('Assign / note'),
                    ),
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
    final all = _svc.safeguardingForSchool(_schoolId);
    final reviews = _svc.safeguardingReviewsDue(schoolId: _schoolId);
    final items = _sgFilter == 'review' ? reviews : all;
    return _listTab(
      action: _canManageCp
          ? FilledButton.icon(
              onPressed: _addSafeguarding,
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Open case file'),
            )
          : null,
      banner: StudentSupportPlaybook.banners['safeguarding'],
      empty: 'No safeguarding case files.',
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text('All cases (${all.length})'),
              selected: _sgFilter == 'all',
              onSelected: (_) => setState(() => _sgFilter = 'all'),
            ),
            ChoiceChip(
              label: Text('Review due (${reviews.length})'),
              selected: _sgFilter == 'review',
              onSelected: (_) => setState(() => _sgFilter = 'review'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final row in items)
          _card(
            title: row.title.isEmpty ? row.studentName : row.title,
            subtitle: [
              row.studentName,
              row.status.name,
              row.severity,
              StudentSupportPlaybook.label(
                StudentSupportPlaybook.safeguardingCategories,
                row.category,
              ),
              if (row.dslName.isNotEmpty) 'DSL ${row.dslName}',
            ].join(' · '),
            body: [
              if (row.details.trim().isNotEmpty) Text(row.details),
              if (row.agencyReferred.isNotEmpty)
                Text('Agency referred: ${row.agencyReferred}'),
              if (row.nextReviewAt != null)
                Text('Next DSL review ${_dateLabel(row.nextReviewAt!)}'),
              if (row.chronology.isNotEmpty)
                Text(
                  'Chronology: ${row.chronology.reversed.take(5).map((entry) => '${_dateLabel(entry.createdAt)} ${entry.author}: ${entry.note}').join(' · ')}',
                ),
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
                    TextButton(
                      onPressed: () => _addSafeguardingNote(row.id),
                      child: const Text('Log chronology'),
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
    String? banner,
    required String empty,
    required List<Widget> children,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (banner != null && banner.isNotEmpty) ...[
          _playbookBanner(banner),
          const SizedBox(height: 12),
        ],
        if (action != null) ...[
          Align(alignment: Alignment.centerLeft, child: action),
          const SizedBox(height: 12),
        ],
        if (children.isEmpty) _empty(empty) else ...children,
      ],
    );
  }

  Widget _playbookBanner(String text) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text),
      ),
    );
  }

  String _dateLabel(DateTime value) =>
      value.toIso8601String().split('T').first;

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
    var disposition = 'returnToClass';
    var contactMethod = 'phone';
    var occurredAt = DateTime.now();
    DateTime? nextDue;
    DateTime? followUp;
    final title = TextEditingController();
    final details = TextEditingController();
    final notes = TextEditingController();
    final dose = TextEditingController();
    final vitals = TextEditingController();
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
                  DropdownButtonFormField<String>(
                    initialValue: disposition,
                    decoration: const InputDecoration(
                      labelText: 'Disposition',
                    ),
                    items: [
                      for (final pair in StudentSupportPlaybook.dispositions)
                        DropdownMenuItem(
                          value: pair.$1,
                          child: Text(pair.$2),
                        ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => disposition = v ?? disposition),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: contactMethod,
                    decoration: const InputDecoration(
                      labelText: 'Parent contact method',
                    ),
                    items: [
                      for (final pair
                          in StudentSupportPlaybook.parentContactMethods)
                        DropdownMenuItem(
                          value: pair.$1,
                          child: Text(pair.$2),
                        ),
                    ],
                    onChanged: (v) => setDialogState(
                      () => contactMethod = v ?? contactMethod,
                    ),
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
                  TextField(
                    controller: vitals,
                    decoration: const InputDecoration(
                      labelText: 'Vitals / observations',
                      hintText: 'Temp, pulse, notes for the infirmary log',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: followUp ??
                            DateTime.now().add(const Duration(days: 2)),
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() => followUp = picked);
                      }
                    },
                    child: Text(
                      followUp == null
                          ? 'Set clinic follow-up'
                          : 'Follow-up ${_dateLabel(followUp!)}',
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
      disposition: disposition,
      followUpAt: followUp,
      vitalNotes: vitals.text,
      parentContactMethod: contactMethod,
    );
  }

  Future<void> _addCounseling() async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    var kind = CounselingKind.appointment;
    var format = 'individual';
    var riskWatch = 'none';
    DateTime? followUp;
    final title = TextEditingController();
    final summary = TextEditingController();
    final notes = TextEditingController();
    final referral = TextEditingController();
    final duration = TextEditingController(text: '30');
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
                  DropdownButtonFormField<String>(
                    initialValue: format,
                    decoration: const InputDecoration(labelText: 'Format'),
                    items: [
                      for (final pair
                          in StudentSupportPlaybook.counselingFormats)
                        DropdownMenuItem(
                          value: pair.$1,
                          child: Text(pair.$2),
                        ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => format = v ?? format),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: riskWatch,
                    decoration: const InputDecoration(
                      labelText: 'Risk watch (does not open a CP case)',
                    ),
                    items: [
                      for (final pair in StudentSupportPlaybook.riskWatch)
                        DropdownMenuItem(
                          value: pair.$1,
                          child: Text(pair.$2),
                        ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => riskWatch = v ?? riskWatch),
                  ),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  TextField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes)',
                    ),
                  ),
                  TextField(
                    controller: summary,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Parent summary',
                    ),
                  ),
                  TextField(
                    controller: referral,
                    decoration: const InputDecoration(
                      labelText: 'External referral (if needed)',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: followUp ??
                            DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() => followUp = picked);
                      }
                    },
                    child: Text(
                      followUp == null
                          ? 'Set counselor follow-up'
                          : 'Follow-up ${_dateLabel(followUp!)}',
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
      referralTo: referral.text,
      format: format,
      durationMinutes: int.tryParse(duration.text),
      followUpAt: followUp,
      riskWatch: riskWatch,
    );
  }

  Future<void> _addIep() async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    var tier = 2;
    var reviewCycle = 'termly';
    var arrangements = <String>{};
    DateTime? nextReview;
    final goals = TextEditingController();
    final accommodations = TextEditingController();
    final notes = TextEditingController();
    final agreement = TextEditingController();
    final reportRef = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('IEP / MTSS learning-support plan'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: tier,
                  decoration: const InputDecoration(
                    labelText: 'MTSS tier',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 1,
                      child: Text('Tier 1 — classroom'),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text('Tier 2 — documented intervention'),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text('Tier 3 — IEP'),
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => tier = v ?? tier),
                ),
                DropdownButtonFormField<String>(
                  initialValue: reviewCycle,
                  decoration: const InputDecoration(labelText: 'Review cycle'),
                  items: [
                    for (final pair in StudentSupportPlaybook.reviewCycles)
                      DropdownMenuItem(
                        value: pair.$1,
                        child: Text(pair.$2),
                      ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => reviewCycle = v ?? reviewCycle),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final pair
                        in StudentSupportPlaybook.accessArrangements)
                      FilterChip(
                        label: Text(pair.$2),
                        selected: arrangements.contains(pair.$1),
                        onSelected: (on) => setDialogState(() {
                          if (on) {
                            arrangements.add(pair.$1);
                          } else {
                            arrangements.remove(pair.$1);
                          }
                        }),
                      ),
                  ],
                ),
                TextField(
                  controller: goals,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'SMART goals',
                  ),
                ),
                TextField(
                  controller: accommodations,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Classroom accommodations'),
                ),
                TextField(
                  controller: reportRef,
                  decoration: const InputDecoration(
                    labelText: 'External EP / psycho-ed report ref',
                  ),
                ),
                TextField(
                  controller: agreement,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Parent agreement text'),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: nextReview ??
                          DateTime.now().add(const Duration(days: 90)),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDialogState(() => nextReview = picked);
                    }
                  },
                  child: Text(
                    nextReview == null
                        ? 'Set next review'
                        : 'Review ${_dateLabel(nextReview!)}',
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
    await _svc.addIepPlan(
      studentId: studentId,
      goals: goals.text,
      accommodations: accommodations.text,
      parentAgreementText: agreement.text,
      staffNotes: notes.text,
      stage: IepStage.draftPlan,
      mtssTier: tier,
      accessArrangements: arrangements.toList(),
      reviewCycle: reviewCycle,
      externalReportRef: reportRef.text,
      nextReviewAt: nextReview,
    );
  }

  Future<void> _addCollege() async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    var stage = CollegeStage.exploring;
    var applicationSystem = 'ucas';
    final targets = TextEditingController();
    final portfolio = TextEditingController();
    final notes = TextEditingController();
    final testing = TextEditingController();
    final counselor = TextEditingController();
    final country = TextEditingController();
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
                  DropdownButtonFormField<String>(
                    initialValue: applicationSystem,
                    decoration: const InputDecoration(
                      labelText: 'Application system',
                    ),
                    items: [
                      for (final pair
                          in StudentSupportPlaybook.applicationSystems)
                        DropdownMenuItem(
                          value: pair.$1,
                          child: Text(pair.$2),
                        ),
                    ],
                    onChanged: (v) => setDialogState(
                      () => applicationSystem = v ?? applicationSystem,
                    ),
                  ),
                  TextField(
                    controller: targets,
                    decoration: const InputDecoration(
                      labelText: 'Target universities',
                    ),
                  ),
                  TextField(
                    controller: testing,
                    decoration: const InputDecoration(
                      labelText: 'Testing plan (SAT / IELTS / …)',
                    ),
                  ),
                  TextField(
                    controller: counselor,
                    decoration: const InputDecoration(
                      labelText: 'College counselor',
                    ),
                  ),
                  TextField(
                    controller: country,
                    decoration: const InputDecoration(
                      labelText: 'Destination country',
                    ),
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
      applicationSystem: applicationSystem,
      testingPlan: testing.text,
      counselorName: counselor.text,
      destinationCountry: country.text,
    );
  }

  Future<void> _addSafeguarding() async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    var category = 'other';
    DateTime? nextReview;
    final title = TextEditingController();
    final details = TextEditingController();
    final dsl = TextEditingController();
    final agency = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Safeguarding case file'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final pair
                      in StudentSupportPlaybook.safeguardingCategories)
                    DropdownMenuItem(
                      value: pair.$1,
                      child: Text(pair.$2),
                    ),
                ],
                onChanged: (v) =>
                    setDialogState(() => category = v ?? category),
              ),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: dsl,
                decoration: const InputDecoration(
                  labelText: 'DSL / DDSL name',
                ),
              ),
              TextField(
                controller: agency,
                decoration: const InputDecoration(
                  labelText: 'Agency referred (if any)',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: nextReview ??
                        DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setDialogState(() => nextReview = picked);
                  }
                },
                child: Text(
                  nextReview == null
                      ? 'Set next DSL review'
                      : 'Review ${_dateLabel(nextReview!)}',
                ),
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
        ),
    );
    if (ok != true) return;
    await _svc.openSafeguardingCase(
      studentId: studentId,
      title: title.text,
      details: details.text,
      category: category,
      dslName: dsl.text,
      nextReviewAt: nextReview,
      agencyReferred: agency.text,
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
    var route = 'oral';
    var controlled = false;
    var consent = false;
    DateTime? expires;
    final name = TextEditingController();
    final qty = TextEditingController(text: '0');
    final reorder = TextEditingController(text: '5');
    final unit = TextEditingController(text: 'unit');
    final batch = TextEditingController();
    final prescriber = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Clinic medication stock'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
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
              DropdownButtonFormField<String>(
                initialValue: route,
                decoration: const InputDecoration(labelText: 'Route'),
                items: [
                  for (final pair in StudentSupportPlaybook.medRoutes)
                    DropdownMenuItem(
                      value: pair.$1,
                      child: Text(pair.$2),
                    ),
                ],
                onChanged: (v) => setDialogState(() => route = v ?? route),
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
              TextField(
                controller: prescriber,
                decoration: const InputDecoration(labelText: 'Prescriber'),
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: expires ?? DateTime.now().add(
                      const Duration(days: 365),
                    ),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2038),
                  );
                  if (picked != null) {
                    setDialogState(() => expires = picked);
                  }
                },
                child: Text(
                  expires == null
                      ? 'Set expiry'
                      : 'Expires ${_dateLabel(expires!)}',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: controlled,
                onChanged: (v) =>
                    setDialogState(() => controlled = v ?? false),
                title: const Text('Controlled drug (witness on dispense)'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: consent,
                onChanged: (v) => setDialogState(() => consent = v ?? false),
                title: const Text('Parent consent on file'),
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
    await _svc.upsertMedicationStock(
      name: name.text,
      unit: unit.text,
      quantityOnHand: double.tryParse(qty.text) ?? 0,
      reorderLevel: double.tryParse(reorder.text) ?? 0,
      batchNumber: batch.text,
      expiresAt: expires,
      controlledDrug: controlled,
      route: route,
      parentConsentOnFile: consent,
      prescriber: prescriber.text,
    );
  }

  Future<void> _dispenseMed(MedicationStockItem row) async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    final qty = TextEditingController(text: '1');
    final note = TextEditingController();
    final witness = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Dispense ${row.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (row.controlledDrug)
              const Text(
                'Controlled drug — record a second-staff witness.',
              ),
            TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Quantity (${row.unit})'),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Dose / note'),
            ),
            TextField(
              controller: witness,
              decoration: InputDecoration(
                labelText: row.controlledDrug
                    ? 'Witness (required)'
                    : 'Witness (optional)',
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
      witnessedBy: witness.text,
    );
  }

  Future<void> _addVaultDoc() async {
    final studentId = await _pickStudent();
    if (studentId == null || !mounted) return;
    var category = 'psychoEd';
    var confidentiality = 'restricted';
    DateTime? reviewAt;
    DateTime? expiresAt;
    final title = TextEditingController();
    final source = TextEditingController();
    var paths = <String>[];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Student document vault'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final pair in StudentSupportPlaybook.vaultCategories)
                      DropdownMenuItem(
                        value: pair.$1,
                        child: Text(pair.$2),
                      ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => category = v ?? category),
                ),
                DropdownButtonFormField<String>(
                  initialValue: confidentiality,
                  decoration:
                      const InputDecoration(labelText: 'Confidentiality'),
                  items: [
                    for (final pair in StudentSupportPlaybook.confidentiality)
                      DropdownMenuItem(
                        value: pair.$1,
                        child: Text(pair.$2),
                      ),
                  ],
                  onChanged: (v) => setDialogState(
                    () => confidentiality = v ?? confidentiality,
                  ),
                ),
                TextField(
                  controller: source,
                  decoration: const InputDecoration(
                    labelText: 'Source (EP / clinic / exam board)',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: reviewAt ??
                          DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2038),
                    );
                    if (picked != null) {
                      setDialogState(() => reviewAt = picked);
                    }
                  },
                  child: Text(
                    reviewAt == null
                        ? 'Set review date'
                        : 'Review ${_dateLabel(reviewAt!)}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: expiresAt ??
                          DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2038),
                    );
                    if (picked != null) {
                      setDialogState(() => expiresAt = picked);
                    }
                  },
                  child: Text(
                    expiresAt == null
                        ? 'Set expiry'
                        : 'Expires ${_dateLabel(expiresAt!)}',
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
      category: category,
      filePath: paths.isEmpty ? null : paths.first,
      confidentiality: confidentiality,
      expiresAt: expiresAt,
      reviewAt: reviewAt,
      source: source.text,
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

  Future<void> _editIepAccess(IepPlan plan) async {
    var selected = {...plan.accessArrangements};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('IB / Cambridge access arrangements'),
          content: Wrap(
            spacing: 6,
            children: [
              for (final pair in StudentSupportPlaybook.accessArrangements)
                FilterChip(
                  label: Text(pair.$2),
                  selected: selected.contains(pair.$1),
                  onSelected: (on) => setDialogState(() {
                    if (on) {
                      selected.add(pair.$1);
                    } else {
                      selected.remove(pair.$1);
                    }
                  }),
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
    await _svc.updateIepAccess(
      id: plan.id,
      accessArrangements: selected.toList(),
    );
  }

  Future<void> _assignRequest(SupportRequest row) async {
    var priority = row.priority;
    DateTime? dueAt = row.dueAt;
    final assignee = TextEditingController(text: row.assignedTo);
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Assign support request'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: [
                    for (final pair in StudentSupportPlaybook.requestPriorities)
                      DropdownMenuItem(
                        value: pair.$1,
                        child: Text(pair.$2),
                      ),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => priority = v ?? priority),
                ),
                TextField(
                  controller: assignee,
                  decoration: const InputDecoration(
                    labelText: 'Assigned counselor / LST',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dueAt ??
                          DateTime.now().add(const Duration(days: 3)),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDialogState(() => dueAt = picked);
                    }
                  },
                  child: Text(
                    dueAt == null ? 'Set due date' : 'Due ${_dateLabel(dueAt!)}',
                  ),
                ),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Last action note',
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _svc.assignSupportRequest(
      id: row.id,
      assignedTo: assignee.text,
      priority: priority,
      dueAt: dueAt,
      lastActionNote: note.text,
    );
  }

  Future<void> _addSafeguardingNote(String id) async {
    DateTime? nextReview;
    final note = TextEditingController();
    final agency = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Safeguarding chronology'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: note,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Chronology note (DSL desk only)',
                  ),
                ),
                TextField(
                  controller: agency,
                  decoration: const InputDecoration(
                    labelText: 'Agency referred (optional)',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: nextReview ??
                          DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDialogState(() => nextReview = picked);
                    }
                  },
                  child: Text(
                    nextReview == null
                        ? 'Set next review'
                        : 'Review ${_dateLabel(nextReview!)}',
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
              child: const Text('Log'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _svc.addSafeguardingChronology(
      id: id,
      note: note.text,
      agencyReferred: agency.text,
      nextReviewAt: nextReview,
    );
  }
}
