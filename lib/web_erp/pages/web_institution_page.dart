import 'package:flutter/material.dart';

import 'package:mayabela/models/institution_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/institution_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/web_erp/widgets/web_erp_related_tools.dart';

/// Institutional Management desk — grouped Identity, Governance, Improvement,
/// and Estate. Not School / Campus / QA ops.
class WebInstitutionPage extends StatefulWidget {
  const WebInstitutionPage({super.key});

  @override
  State<WebInstitutionPage> createState() => _WebInstitutionPageState();
}

class _WebInstitutionPageState extends State<WebInstitutionPage>
    with TickerProviderStateMixin {
  late final TabController _groups = TabController(length: 5, vsync: this);
  late final TabController _identity = TabController(length: 2, vsync: this);
  late final TabController _governance = TabController(length: 8, vsync: this);
  late final TabController _improvement = TabController(length: 3, vsync: this);
  late final TabController _estate = TabController(length: 2, vsync: this);
  final _svc = InstitutionService.instance;

  bool get _canManage => ModuleAccess.canManage('institution');
  String get _schoolId => AuthService.activeSchoolId ?? '';

  @override
  void initState() {
    super.initState();
    _svc.ensureLoaded();
  }

  @override
  void dispose() {
    _groups.dispose();
    _identity.dispose();
    _governance.dispose();
    _improvement.dispose();
    _estate.dispose();
    super.dispose();
  }

  void _open(int group, int sub) {
    _groups.animateTo(group);
    switch (group) {
      case 1:
        _identity.animateTo(sub);
      case 2:
        _governance.animateTo(sub);
      case 3:
        _improvement.animateTo(sub);
      case 4:
        _estate.animateTo(sub);
      default:
        break;
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : Colors.green,
      ),
    );
  }

  Future<void> _guarded(Future<void> Function() action) async {
    if (!_canManage) {
      _snack('You can view this desk but cannot change records.', error: true);
      return;
    }
    try {
      await action();
    } catch (e) {
      _snack('$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
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
                'Institutional Management',
                style: WebErpTheme.sectionTitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                'Identity, governance, improvement, and estate of the institution. '
                'Academic year, campus assignment, teaching QA, finance, and '
                'inventory stay on their own desks.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _groups,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Identity'),
                  Tab(text: 'Governance'),
                  Tab(text: 'Improvement'),
                  Tab(text: 'Estate'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _svc,
            builder: (context, _) {
              final rec = _svc.recordFor(_schoolId);
              return TabBarView(
                controller: _groups,
                children: [
                  _overviewTab(rec, narrow),
                  _nested(
                    controller: _identity,
                    labels: const ['Profile', 'Structure'],
                    children: [_profileTab(rec), _structureTab(rec)],
                  ),
                  _nested(
                    controller: _governance,
                    labels: const [
                      'Leadership',
                      'Committees',
                      'Policies',
                      'Licenses',
                      'Meetings',
                      'Resolutions',
                      'Risks',
                      'Partners',
                    ],
                    children: [
                      _leadershipTab(rec),
                      _committeesTab(rec),
                      _policiesTab(rec),
                      _licensesTab(rec),
                      _meetingsTab(rec),
                      _resolutionsTab(rec),
                      _risksTab(rec),
                      _partnersTab(rec),
                    ],
                  ),
                  _nested(
                    controller: _improvement,
                    labels: const ['SEF', 'CAPA', 'Scorecard'],
                    children: [_sefTab(rec), _capaTab(rec), _scorecardTab(rec)],
                  ),
                  _nested(
                    controller: _estate,
                    labels: const ['Property', 'Archive'],
                    children: [_propertyTab(rec), _archiveTab(rec)],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _overviewTab(InstitutionRecord rec, bool narrow) {
    final m = _svc.metricsFor(_schoolId);
    final scheme = Theme.of(context).colorScheme;
    final cards = <(String, int, Color, Color, VoidCallback)>[
      (
        'Active policies',
        m.activePolicies,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        () => _open(2, 2),
      ),
      (
        'Licenses expiring',
        m.expiringLicenses,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        () => _open(2, 3),
      ),
      (
        'Licenses expired',
        m.expiredLicenses,
        scheme.errorContainer,
        scheme.onErrorContainer,
        () => _open(2, 3),
      ),
      (
        'Open resolutions',
        m.openResolutions,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        () => _open(2, 5),
      ),
      (
        'Overdue resolutions',
        m.overdueResolutions,
        scheme.errorContainer,
        scheme.onErrorContainer,
        () => _open(2, 5),
      ),
      (
        'Open risks',
        m.openRisks,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        () => _open(2, 6),
      ),
      (
        'Risks due for review',
        m.risksDueSoon,
        scheme.errorContainer,
        scheme.onErrorContainer,
        () => _open(2, 6),
      ),
      (
        'Open CAPA',
        m.openCapas,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        () => _open(3, 1),
      ),
      (
        'Overdue CAPA',
        m.overdueCapas,
        scheme.errorContainer,
        scheme.onErrorContainer,
        () => _open(3, 1),
      ),
      (
        'KPIs off track',
        m.kpisOffTrack,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        () => _open(3, 2),
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (label, count, bg, fg, onTap) in cards)
              Material(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: narrow ? 150 : 180,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$count',
                          style: TextStyle(
                            color: fg,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(label, style: TextStyle(color: fg, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: WebErpTheme.cardDecoration(context),
          child: InkWell(
            onTap: () => _open(1, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.profile.legalName.isEmpty
                      ? 'Legal identity not set yet'
                      : rec.profile.legalName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    InstitutionProfile.legalFormLabel(rec.profile.legalForm),
                    if (rec.profile.registrationNumber.isNotEmpty)
                      'Reg. ${rec.profile.registrationNumber}',
                    '${rec.leadership.length} leadership seats',
                    '${m.activeCommittees} active committees',
                    '${rec.orgUnits.length} departments / divisions',
                    '${m.activePartners} partners',
                    '${rec.properties.length} property assets',
                    '${m.retentionLapsed} archive items past retention',
                  ].join(' · '),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const WebErpRelatedToolsCard(
          title: 'Operational school desks (not this module)',
          tools: [
            WebErpRelatedTool(
              routeId: 'school',
              label: 'School Management',
              icon: Icons.school_outlined,
              subtitle: 'Academic year, grade levels, office contact',
            ),
            WebErpRelatedTool(
              routeId: 'campus',
              label: 'Campus Management',
              icon: Icons.location_city_outlined,
              subtitle: 'Campus names and student / teacher assignment',
            ),
            WebErpRelatedTool(
              routeId: 'quality_assurance',
              label: 'QA Findings & Plans',
              icon: Icons.verified_outlined,
              subtitle: 'Teaching observations and academic improvement plans',
            ),
          ],
        ),
      ],
    );
  }

  Widget _profileTab(InstitutionRecord rec) {
    return _ProfileForm(
      key: ValueKey('profile-${rec.updatedAt.toIso8601String()}'),
      profile: rec.profile,
      canManage: _canManage,
      onSave: (profile) => _guarded(() async {
        await _svc.saveProfile(profile, schoolId: _schoolId);
        _snack('Institution profile saved');
      }),
    );
  }

  Widget _leadershipTab(InstitutionRecord rec) {
    return _listTab(
      empty: 'No leadership or board seats yet.',
      onAdd: () => _editLeadership(),
      children: [
        for (final seat in rec.leadership)
          _tile(
            title: seat.personName,
            subtitle: [
              LeadershipSeat.seatLabel(seat.seatType),
              if (seat.title.isNotEmpty) seat.title,
              if (seat.isActing) 'Acting',
              if (seat.termEnd.isNotEmpty) 'until ${seat.termEnd}',
            ].join(' · '),
            onEdit: () => _editLeadership(seat),
            onDelete: () => _guarded(() async {
              await _svc.deleteLeadership(seat.id, schoolId: _schoolId);
            }),
          ),
      ],
    );
  }

  Widget _committeesTab(InstitutionRecord rec) {
    return _listTab(
      empty: 'No standing committees yet.',
      onAdd: () => _editCommittee(),
      children: [
        Text(
          'Terms of reference and membership. Teaching QA panels stay on the QA desk.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final committee in rec.committees)
          _tile(
            title: committee.name,
            subtitle: [
              InstitutionCommittee.statusLabel(committee.status),
              if (committee.chairName.isNotEmpty)
                'Chair: ${committee.chairName}',
              if (committee.members.isNotEmpty) committee.members,
            ].join(' · '),
            onEdit: () => _editCommittee(committee),
            onDelete: () => _guarded(() async {
              await _svc.deleteCommittee(committee.id, schoolId: _schoolId);
            }),
          ),
      ],
    );
  }

  Widget _structureTab(InstitutionRecord rec) {
    final campuses = SchoolRegistryService.instance.campusesForSchool(
      _schoolId,
    );
    return _listTab(
      empty: 'No departments or campus framework yet.',
      onAdd: () => _editOrgUnit(),
      extraAction: _Action(
        label: 'Add campus site',
        onTap: () => _editSite(campuses: campuses),
      ),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Departments & divisions',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (rec.orgUnits.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('No organizational units yet.'),
          ),
        for (final unit in rec.orgUnits)
          _tile(
            title: unit.name,
            subtitle: [
              OrgUnit.kindLabel(unit.kind),
              if (unit.headName.isNotEmpty) 'Head: ${unit.headName}',
            ].join(' · '),
            onEdit: () => _editOrgUnit(unit),
            onDelete: () => _guarded(() async {
              await _svc.deleteOrgUnit(unit.id, schoolId: _schoolId);
            }),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Text(
            'Campus framework',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          campuses.isEmpty
              ? 'Create campus names in Campus Management first, then mark HQ here.'
              : 'Uses the same campus names as Campus Management. Student assignment stays there.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (rec.sites.isEmpty)
          const Text('No institutional campus sites recorded.'),
        for (final site in rec.sites)
          _tile(
            title: site.campusName,
            subtitle: [
              if (site.isHeadquarters) 'Headquarters',
              site.status.name,
              if (site.notes.isNotEmpty) site.notes,
            ].join(' · '),
            onEdit: () => _editSite(existing: site, campuses: campuses),
            onDelete: () => _guarded(() async {
              await _svc.deleteSite(site.id, schoolId: _schoolId);
            }),
          ),
      ],
    );
  }

  Widget _policiesTab(InstitutionRecord rec) {
    return _listTab(
      empty: 'No policies or circulars yet.',
      onAdd: () => _editPolicy(),
      extraAction: _Action(label: 'Add circular', onTap: () => _editCircular()),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Policy library',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        for (final policy in rec.policies)
          _tile(
            title: '${policy.number}  ${policy.title}',
            subtitle: [
              InstitutionPolicy.statusLabel(policy.status),
              if (policy.owner.isNotEmpty) policy.owner,
              if (policy.reviewDate.isNotEmpty) 'Review ${policy.reviewDate}',
              if (policy.reviewDueSoon) 'Review due soon',
            ].join(' · '),
            onEdit: () => _editPolicy(policy),
            onDelete: () => _guarded(() async {
              await _svc.deletePolicy(policy.id, schoolId: _schoolId);
            }),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Text(
            'Official circulars',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          'Numbered institutional instruments. Parent newsletters stay in Announcements.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (rec.circulars.isEmpty) const Text('No circulars yet.'),
        for (final circular in rec.circulars)
          _tile(
            title: '${circular.number}  ${circular.title}',
            subtitle: circular.issuedOn,
            onEdit: () => _editCircular(circular),
            onDelete: () => _guarded(() async {
              await _svc.deleteCircular(circular.id, schoolId: _schoolId);
            }),
          ),
      ],
    );
  }

  Widget _licensesTab(InstitutionRecord rec) {
    return _listTab(
      empty: 'No licenses or accreditations yet.',
      onAdd: () => _editLicense(),
      children: [
        for (final license in rec.licenses)
          _tile(
            title: license.title,
            subtitle: [
              InstitutionLicense.healthLabel(license.health),
              if (license.issuer.isNotEmpty) license.issuer,
              if (license.number.isNotEmpty) license.number,
              if (license.expiresOn.isNotEmpty) 'Expires ${license.expiresOn}',
              license.campusScope,
            ].join(' · '),
            tone: switch (license.health) {
              LicenseHealth.expired => Colors.red.shade700,
              LicenseHealth.expiring => Colors.orange.shade800,
              _ => null,
            },
            onEdit: () => _editLicense(license),
            onDelete: () => _guarded(() async {
              await _svc.deleteLicense(license.id, schoolId: _schoolId);
            }),
          ),
      ],
    );
  }

  Widget _resolutionsTab(InstitutionRecord rec) {
    return _listTab(
      empty: 'No board / SLT resolutions yet.',
      onAdd: () => _editResolution(),
      children: [
        for (final row in rec.resolutions)
          _tile(
            title: '${row.number}  ${row.title}',
            subtitle: [
              InstitutionResolution.statusLabel(row.status),
              if (row.isOverdue) 'Overdue',
              if (row.owner.isNotEmpty) row.owner,
              if (row.dueDate.isNotEmpty) 'Due ${row.dueDate}',
              if (rec.meetingTitleFor(row.meetingId).isNotEmpty)
                rec.meetingTitleFor(row.meetingId)
              else if (row.meetingTitle.isNotEmpty)
                row.meetingTitle,
            ].join(' · '),
            tone: row.isOverdue ? Colors.red.shade700 : null,
            onEdit: () => _editResolution(row),
            onDelete: () => _guarded(() async {
              await _svc.deleteResolution(row.id, schoolId: _schoolId);
            }),
          ),
      ],
    );
  }

  Widget _meetingsTab(InstitutionRecord rec) {
    return _listTab(
      empty: 'No board / SLT / committee meetings yet.',
      onAdd: () => _editMeeting(),
      extraAction: _Action(
        label: 'Add resolution',
        onTap: () => _editResolution(),
      ),
      children: [
        Text(
          'Attendance and body of the meeting. Decisions still live as resolutions.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final meeting in rec.meetings)
          _tile(
            title: meeting.title,
            subtitle: [
              InstitutionMeeting.bodyLabel(meeting.bodyKind),
              if (meeting.bodyKind == MeetingBodyKind.committee &&
                  rec.committeeNameFor(meeting.committeeId).isNotEmpty)
                rec.committeeNameFor(meeting.committeeId),
              if (meeting.heldOn.isNotEmpty) meeting.heldOn,
              if (meeting.attendance.isNotEmpty) meeting.attendance,
              '${rec.resolutions.where((r) => r.meetingId == meeting.id).length} resolutions',
            ].join(' · '),
            onEdit: () => _editMeeting(meeting),
            onDelete: () => _guarded(() async {
              await _svc.deleteMeeting(meeting.id, schoolId: _schoolId);
            }),
          ),
      ],
    );
  }

  Widget _risksTab(InstitutionRecord rec) {
    return _listTab(
      empty: 'No institutional risks recorded.',
      onAdd: () => _editRisk(),
      children: [
        Text(
          'Governance, licence, and reputation risks. Student discipline, health, '
          'and store inventory stay on their own desks.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final risk in rec.risks)
          _tile(
            title: risk.title,
            subtitle: [
              InstitutionRisk.statusLabel(risk.status),
              if (risk.isOverdue) 'Review overdue',
              if (risk.reviewDueSoon && !risk.isOverdue) 'Review due soon',
              'Likelihood ${InstitutionRisk.likelihoodLabel(risk.likelihood)}',
              'Impact ${InstitutionRisk.impactLabel(risk.impact)}',
              if (risk.owner.isNotEmpty) risk.owner,
              if (risk.reviewDate.isNotEmpty) 'Review ${risk.reviewDate}',
            ].join(' · '),
            tone: risk.isOverdue
                ? Colors.red.shade700
                : (risk.reviewDueSoon ? Colors.orange.shade800 : null),
            onEdit: () => _editRisk(risk),
            onDelete: () => _guarded(() async {
              await _svc.deleteRisk(risk.id, schoolId: _schoolId);
            }),
          ),
      ],
    );
  }

  Widget _partnersTab(InstitutionRecord rec) {
    return _listTab(
      empty: 'No partners or affiliations yet.',
      onAdd: () => _editPartner(),
      children: [
        Text(
          'Ministries, accreditors, sister schools, and MOUs. Vendors and payroll '
          'suppliers stay in Finance / Inventory.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final partner in rec.partners)
          _tile(
            title: partner.name,
            subtitle: [
              InstitutionPartner.kindLabel(partner.kind),
              InstitutionPartner.statusLabel(partner.status),
              if (partner.contact.isNotEmpty) partner.contact,
              if (partner.agreementRef.isNotEmpty) partner.agreementRef,
            ].join(' · '),
            onEdit: () => _editPartner(partner),
            onDelete: () => _guarded(() async {
              await _svc.deletePartner(partner.id, schoolId: _schoolId);
            }),
          ),
      ],
    );
  }

  Widget _sefTab(InstitutionRecord rec) {
    return _listTab(
      empty: 'No institutional self-evaluation entries yet.',
      onAdd: () => _editSef(),
      extraAction: _Action(label: 'Add CAPA', onTap: () => _editCapa()),
      children: [
        Text(
          'Institutional SEF judgments. Teaching observations stay on QA Findings.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final row in rec.sefEntries)
          _tile(
            title: '${row.cycle}  ${row.area}',
            subtitle: [
              InstitutionSefEntry.statusLabel(row.status),
              InstitutionSefEntry.judgmentLabel(row.judgment),
              if (row.owner.isNotEmpty) row.owner,
            ].join(' · '),
            onEdit: () => _editSef(row),
            onDelete: () => _guarded(() async {
              await _svc.deleteSef(row.id, schoolId: _schoolId);
            }),
          ),
      ],
    );
  }

  Widget _capaTab(InstitutionRecord rec) {
    return _listTab(
      empty: 'No corrective / preventive actions yet.',
      onAdd: () => _editCapa(),
      children: [
        Text(
          'Institutional improvement actions from SEF, risks, or licences. '
          'Teaching QA action plans stay on the QA desk.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final row in rec.capas)
          _tile(
            title: '${row.number}  ${row.title}',
            subtitle: [
              InstitutionCapa.statusLabel(row.status),
              if (row.isOverdue) 'Overdue',
              InstitutionCapa.sourceLabel(row.source),
              if (rec.sefTitleFor(row.sefId).isNotEmpty)
                rec.sefTitleFor(row.sefId),
              if (rec.riskTitleFor(row.riskId).isNotEmpty)
                rec.riskTitleFor(row.riskId),
              if (row.owner.isNotEmpty) row.owner,
              if (row.dueDate.isNotEmpty) 'Due ${row.dueDate}',
            ].join(' · '),
            tone: row.isOverdue ? Colors.red.shade700 : null,
            onEdit: () => _editCapa(row),
            onDelete: () => _guarded(() async {
              await _svc.deleteCapa(row.id, schoolId: _schoolId);
            }),
          ),
      ],
    );
  }

  Widget _scorecardTab(InstitutionRecord rec) {
    return _listTab(
      empty: 'No institutional KPIs yet.',
      onAdd: () => _editKpi(),
      children: [
        Text(
          'Strategy scorecard for the institution. Markbook and exam results stay '
          'on academic desks.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final row in rec.kpis)
          _tile(
            title: row.name,
            subtitle: [
              InstitutionKpi.statusLabel(row.status),
              InstitutionKpi.themeLabel(row.theme),
              if (row.period.isNotEmpty) row.period,
              if (row.target.isNotEmpty) 'Target ${row.target}',
              if (row.actual.isNotEmpty) 'Actual ${row.actual}',
            ].join(' · '),
            tone: switch (row.status) {
              KpiStatus.offTrack => Colors.red.shade700,
              KpiStatus.atRisk => Colors.orange.shade800,
              KpiStatus.onTrack => null,
            },
            onEdit: () => _editKpi(row),
            onDelete: () => _guarded(() async {
              await _svc.deleteKpi(row.id, schoolId: _schoolId);
            }),
          ),
      ],
    );
  }

  Widget _propertyTab(InstitutionRecord rec) {
    return _listTab(
      empty: 'No capital assets or property recorded.',
      onAdd: () => _editProperty(),
      children: [
        Text(
          'Land, buildings, and facilities. Furniture and store stock stay in Inventory.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final row in rec.properties)
          _tile(
            title: row.name,
            subtitle: [
              InstitutionProperty.kindLabel(row.kind),
              InstitutionProperty.statusLabel(row.status),
              row.campusScope,
              if (row.acquiredOn.isNotEmpty) 'Acquired ${row.acquiredOn}',
            ].join(' · '),
            onEdit: () => _editProperty(row),
            onDelete: () => _guarded(() async {
              await _svc.deleteProperty(row.id, schoolId: _schoolId);
            }),
          ),
      ],
    );
  }

  Widget _archiveTab(InstitutionRecord rec) {
    return _listTab(
      empty: 'No archive or retention records yet.',
      onAdd: () => _editArchive(),
      children: [
        Text(
          'Retention for institutional records. Student files stay in SIS.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final row in rec.archive)
          _tile(
            title: row.title,
            subtitle: [
              InstitutionArchiveItem.statusLabel(row.status),
              InstitutionArchiveItem.seriesLabel(row.series),
              if (row.retentionLapsed) 'Retention lapsed',
              if (row.retentionUntil.isNotEmpty) 'Until ${row.retentionUntil}',
              if (row.location.isNotEmpty) row.location,
            ].join(' · '),
            tone: row.retentionLapsed ? Colors.orange.shade800 : null,
            onEdit: () => _editArchive(row),
            onDelete: () => _guarded(() async {
              await _svc.deleteArchive(row.id, schoolId: _schoolId);
            }),
          ),
      ],
    );
  }

  Widget _nested({
    required TabController controller,
    required List<String> labels,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final label in labels) Tab(text: label)],
        ),
        Expanded(
          child: TabBarView(controller: controller, children: children),
        ),
      ],
    );
  }

  Widget _listTab({
    required String empty,
    required VoidCallback onAdd,
    _Action? extraAction,
    required List<Widget> children,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_canManage)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              if (extraAction != null)
                OutlinedButton(
                  onPressed: extraAction.onTap,
                  child: Text(extraAction.label),
                ),
            ],
          ),
        const SizedBox(height: 12),
        if (children.isEmpty) Text(empty) else ...children,
      ],
    );
  }

  Widget _tile({
    required String title,
    required String subtitle,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    Color? tone,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: WebErpTheme.cardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w700, color: tone),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ],
            ),
          ),
          if (_canManage) ...[
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editLeadership([LeadershipSeat? existing]) async {
    var type = existing?.seatType ?? LeadershipSeatType.principal;
    var acting = existing?.isActing ?? false;
    final name = TextEditingController(text: existing?.personName ?? '');
    final title = TextEditingController(text: existing?.title ?? '');
    final start = TextEditingController(text: existing?.termStart ?? '');
    final end = TextEditingController(text: existing?.termEnd ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    final saved = await _formDialog(
      title: existing == null ? 'Add leadership seat' : 'Edit leadership seat',
      builder: (setDialogState) => [
        DropdownButtonFormField<LeadershipSeatType>(
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Seat'),
          items: [
            for (final v in LeadershipSeatType.values)
              DropdownMenuItem(
                value: v,
                child: Text(LeadershipSeat.seatLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => type = v ?? LeadershipSeatType.other),
        ),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Person name'),
        ),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title (optional)'),
        ),
        TextField(
          controller: start,
          decoration: const InputDecoration(
            labelText: 'Term start (YYYY-MM-DD)',
          ),
        ),
        TextField(
          controller: end,
          decoration: const InputDecoration(labelText: 'Term end (YYYY-MM-DD)'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Acting / cover'),
          value: acting,
          onChanged: (v) => setDialogState(() => acting = v),
        ),
        TextField(
          controller: notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertLeadership(
        LeadershipSeat(
          id: existing?.id ?? InstitutionService.newId('lead'),
          seatType: type,
          personName: name.text.trim(),
          title: title.text.trim(),
          termStart: start.text.trim(),
          termEnd: end.text.trim(),
          isActing: acting,
          notes: notes.text.trim(),
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editOrgUnit([OrgUnit? existing]) async {
    var kind = existing?.kind ?? OrgUnitKind.academicDepartment;
    final name = TextEditingController(text: existing?.name ?? '');
    final head = TextEditingController(text: existing?.headName ?? '');
    final mandate = TextEditingController(text: existing?.mandate ?? '');
    final saved = await _formDialog(
      title: existing == null ? 'Add department / division' : 'Edit unit',
      builder: (setDialogState) => [
        DropdownButtonFormField<OrgUnitKind>(
          initialValue: kind,
          decoration: const InputDecoration(labelText: 'Kind'),
          items: [
            for (final v in OrgUnitKind.values)
              DropdownMenuItem(value: v, child: Text(OrgUnit.kindLabel(v))),
          ],
          onChanged: (v) =>
              setDialogState(() => kind = v ?? OrgUnitKind.academicDepartment),
        ),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        TextField(
          controller: head,
          decoration: const InputDecoration(labelText: 'Head of unit'),
        ),
        TextField(
          controller: mandate,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Mandate'),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertOrgUnit(
        OrgUnit(
          id: existing?.id ?? InstitutionService.newId('unit'),
          name: name.text.trim(),
          kind: kind,
          headName: head.text.trim(),
          mandate: mandate.text.trim(),
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editSite({
    InstitutionSite? existing,
    required List<String> campuses,
  }) async {
    if (campuses.isEmpty && (existing?.campusName.isEmpty ?? true)) {
      _snack('Add a campus name in Campus Management first.', error: true);
      return;
    }
    var campus = existing?.campusName ?? campuses.first;
    var hq = existing?.isHeadquarters ?? false;
    var status = existing?.status ?? InstitutionSiteStatus.active;
    final notes = TextEditingController(text: existing?.notes ?? '');
    final saved = await _formDialog(
      title: existing == null ? 'Add campus site' : 'Edit campus site',
      builder: (setDialogState) => [
        DropdownButtonFormField<String>(
          initialValue: campuses.contains(campus) ? campus : campuses.first,
          decoration: const InputDecoration(labelText: 'Campus'),
          items: [
            for (final name in campuses)
              DropdownMenuItem(value: name, child: Text(name)),
          ],
          onChanged: (v) => setDialogState(() => campus = v ?? campus),
        ),
        DropdownButtonFormField<InstitutionSiteStatus>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            for (final v in InstitutionSiteStatus.values)
              DropdownMenuItem(value: v, child: Text(v.name)),
          ],
          onChanged: (v) =>
              setDialogState(() => status = v ?? InstitutionSiteStatus.active),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Headquarters'),
          value: hq,
          onChanged: (v) => setDialogState(() => hq = v),
        ),
        TextField(
          controller: notes,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertSite(
        InstitutionSite(
          id: existing?.id ?? InstitutionService.newId('site'),
          campusName: campus,
          isHeadquarters: hq,
          status: status,
          notes: notes.text.trim(),
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editPolicy([InstitutionPolicy? existing]) async {
    var status = existing?.status ?? PolicyStatus.draft;
    final number = TextEditingController(text: existing?.number ?? '');
    final title = TextEditingController(text: existing?.title ?? '');
    final owner = TextEditingController(text: existing?.owner ?? '');
    final review = TextEditingController(text: existing?.reviewDate ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    final saved = await _formDialog(
      title: existing == null ? 'Add policy' : 'Edit policy',
      builder: (setDialogState) => [
        TextField(
          controller: number,
          decoration: const InputDecoration(
            labelText: 'Policy number',
            hintText: 'POL-2026-001',
          ),
        ),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        TextField(
          controller: owner,
          decoration: const InputDecoration(labelText: 'Owner'),
        ),
        DropdownButtonFormField<PolicyStatus>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            for (final v in PolicyStatus.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionPolicy.statusLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => status = v ?? PolicyStatus.draft),
        ),
        TextField(
          controller: review,
          decoration: const InputDecoration(
            labelText: 'Review date (YYYY-MM-DD)',
          ),
        ),
        TextField(
          controller: notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertPolicy(
        InstitutionPolicy(
          id: existing?.id ?? InstitutionService.newId('pol'),
          number: number.text.trim(),
          title: title.text.trim(),
          owner: owner.text.trim(),
          status: status,
          reviewDate: review.text.trim(),
          notes: notes.text.trim(),
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editCircular([OfficialCircular? existing]) async {
    final number = TextEditingController(text: existing?.number ?? '');
    final title = TextEditingController(text: existing?.title ?? '');
    final issued = TextEditingController(text: existing?.issuedOn ?? '');
    final body = TextEditingController(text: existing?.body ?? '');
    final saved = await _formDialog(
      title: existing == null ? 'Add official circular' : 'Edit circular',
      builder: (_) => [
        TextField(
          controller: number,
          decoration: const InputDecoration(
            labelText: 'Circular number',
            hintText: 'CIR-2026-014',
          ),
        ),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        TextField(
          controller: issued,
          decoration: const InputDecoration(
            labelText: 'Issued on (YYYY-MM-DD)',
          ),
        ),
        TextField(
          controller: body,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Body'),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertCircular(
        OfficialCircular(
          id: existing?.id ?? InstitutionService.newId('cir'),
          number: number.text.trim(),
          title: title.text.trim(),
          issuedOn: issued.text.trim(),
          body: body.text.trim(),
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editLicense([InstitutionLicense? existing]) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final issuer = TextEditingController(text: existing?.issuer ?? '');
    final number = TextEditingController(text: existing?.number ?? '');
    final issued = TextEditingController(text: existing?.issuedOn ?? '');
    final expires = TextEditingController(text: existing?.expiresOn ?? '');
    final scope = TextEditingController(
      text: existing?.campusScope ?? 'Institution-wide',
    );
    final notes = TextEditingController(text: existing?.notes ?? '');
    final saved = await _formDialog(
      title: existing == null ? 'Add license / accreditation' : 'Edit license',
      builder: (_) => [
        TextField(
          controller: title,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'Education operating license',
          ),
        ),
        TextField(
          controller: issuer,
          decoration: const InputDecoration(labelText: 'Issuer'),
        ),
        TextField(
          controller: number,
          decoration: const InputDecoration(labelText: 'Number'),
        ),
        TextField(
          controller: issued,
          decoration: const InputDecoration(
            labelText: 'Issued on (YYYY-MM-DD)',
          ),
        ),
        TextField(
          controller: expires,
          decoration: const InputDecoration(
            labelText: 'Expires on (YYYY-MM-DD)',
          ),
        ),
        TextField(
          controller: scope,
          decoration: const InputDecoration(
            labelText: 'Campus scope',
            hintText: 'Institution-wide or a campus name',
          ),
        ),
        TextField(
          controller: notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes / conditions'),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertLicense(
        InstitutionLicense(
          id: existing?.id ?? InstitutionService.newId('lic'),
          title: title.text.trim(),
          issuer: issuer.text.trim(),
          number: number.text.trim(),
          issuedOn: issued.text.trim(),
          expiresOn: expires.text.trim(),
          campusScope: scope.text.trim(),
          notes: notes.text.trim(),
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editResolution([
    InstitutionResolution? existing,
    InstitutionMeeting? fromMeeting,
  ]) async {
    final rec = _svc.recordFor(_schoolId);
    var status = existing?.status ?? ResolutionStatus.open;
    var meetingId = existing?.meetingId ?? fromMeeting?.id ?? '';
    if (meetingId.isNotEmpty && rec.meetings.every((m) => m.id != meetingId)) {
      meetingId = '';
    }
    final number = TextEditingController(text: existing?.number ?? '');
    final title = TextEditingController(text: existing?.title ?? '');
    final decision = TextEditingController(text: existing?.decision ?? '');
    final owner = TextEditingController(text: existing?.owner ?? '');
    final due = TextEditingController(text: existing?.dueDate ?? '');
    final meeting = TextEditingController(
      text: existing?.meetingTitle.isNotEmpty == true
          ? existing!.meetingTitle
          : (fromMeeting?.title ?? rec.meetingTitleFor(meetingId)),
    );
    final saved = await _formDialog(
      title: existing == null ? 'Add resolution' : 'Edit resolution',
      builder: (setDialogState) => [
        TextField(
          controller: number,
          decoration: const InputDecoration(
            labelText: 'Resolution number',
            hintText: 'RES-2026-08',
          ),
        ),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        TextField(
          controller: decision,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Decision'),
        ),
        TextField(
          controller: owner,
          decoration: const InputDecoration(labelText: 'Implementation owner'),
        ),
        TextField(
          controller: due,
          decoration: const InputDecoration(labelText: 'Due date (YYYY-MM-DD)'),
        ),
        if (rec.meetings.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: meetingId,
            decoration: const InputDecoration(labelText: 'Meeting register'),
            items: [
              const DropdownMenuItem(value: '', child: Text('None / other')),
              for (final row in rec.meetings)
                DropdownMenuItem(value: row.id, child: Text(row.title)),
            ],
            onChanged: (v) => setDialogState(() {
              meetingId = v ?? '';
              final selected = rec.meetings
                  .where((m) => m.id == meetingId)
                  .firstOrNull;
              if (selected != null) meeting.text = selected.title;
            }),
          ),
        TextField(
          controller: meeting,
          decoration: const InputDecoration(
            labelText: 'Meeting title (optional)',
            hintText: 'Board 12 Sep 2026',
          ),
        ),
        DropdownButtonFormField<ResolutionStatus>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            for (final v in ResolutionStatus.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionResolution.statusLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => status = v ?? ResolutionStatus.open),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertResolution(
        InstitutionResolution(
          id: existing?.id ?? InstitutionService.newId('res'),
          number: number.text.trim(),
          title: title.text.trim(),
          decision: decision.text.trim(),
          owner: owner.text.trim(),
          dueDate: due.text.trim(),
          status: status,
          meetingTitle: meeting.text.trim(),
          meetingId: meetingId,
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editCommittee([InstitutionCommittee? existing]) async {
    final rec = _svc.recordFor(_schoolId);
    var status = existing?.status ?? CommitteeStatus.active;
    var chairSeatId = existing?.chairSeatId ?? '';
    if (chairSeatId.isNotEmpty &&
        rec.leadership.every((s) => s.id != chairSeatId)) {
      chairSeatId = '';
    }
    final name = TextEditingController(text: existing?.name ?? '');
    final chair = TextEditingController(text: existing?.chairName ?? '');
    final members = TextEditingController(text: existing?.members ?? '');
    final tor = TextEditingController(text: existing?.termsOfReference ?? '');
    final saved = await _formDialog(
      title: existing == null ? 'Add committee' : 'Edit committee',
      builder: (setDialogState) => [
        TextField(
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Committee name',
            hintText: 'Safeguarding committee',
          ),
        ),
        if (rec.leadership.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: chairSeatId,
            decoration: const InputDecoration(
              labelText: 'Chair (from leadership)',
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('None / type name'),
              ),
              for (final seat in rec.leadership)
                DropdownMenuItem(
                  value: seat.id,
                  child: Text(
                    '${seat.personName} · ${LeadershipSeat.seatLabel(seat.seatType)}',
                  ),
                ),
            ],
            onChanged: (v) => setDialogState(() {
              chairSeatId = v ?? '';
              final seat = rec.leadership
                  .where((s) => s.id == chairSeatId)
                  .firstOrNull;
              if (seat != null) chair.text = seat.personName;
            }),
          ),
        TextField(
          controller: chair,
          decoration: const InputDecoration(labelText: 'Chair name'),
        ),
        TextField(
          controller: members,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Members',
            hintText: 'Names, comma separated',
          ),
        ),
        TextField(
          controller: tor,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Terms of reference'),
        ),
        DropdownButtonFormField<CommitteeStatus>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            for (final v in CommitteeStatus.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionCommittee.statusLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => status = v ?? CommitteeStatus.active),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertCommittee(
        InstitutionCommittee(
          id: existing?.id ?? InstitutionService.newId('com'),
          name: name.text.trim(),
          chairName: chair.text.trim(),
          chairSeatId: chairSeatId,
          members: members.text.trim(),
          termsOfReference: tor.text.trim(),
          status: status,
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editMeeting([InstitutionMeeting? existing]) async {
    final rec = _svc.recordFor(_schoolId);
    var bodyKind = existing?.bodyKind ?? MeetingBodyKind.board;
    var committeeId = existing?.committeeId ?? '';
    if (committeeId.isNotEmpty &&
        rec.committees.every((c) => c.id != committeeId)) {
      committeeId = '';
    }
    final title = TextEditingController(text: existing?.title ?? '');
    final heldOn = TextEditingController(text: existing?.heldOn ?? '');
    final attendance = TextEditingController(text: existing?.attendance ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    final saved = await _formDialog(
      title: existing == null ? 'Add meeting' : 'Edit meeting',
      builder: (setDialogState) => [
        TextField(
          controller: title,
          decoration: const InputDecoration(
            labelText: 'Meeting title',
            hintText: 'Board 12 Sep 2026',
          ),
        ),
        TextField(
          controller: heldOn,
          decoration: const InputDecoration(labelText: 'Held on (YYYY-MM-DD)'),
        ),
        DropdownButtonFormField<MeetingBodyKind>(
          initialValue: bodyKind,
          decoration: const InputDecoration(labelText: 'Body'),
          items: [
            for (final v in MeetingBodyKind.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionMeeting.bodyLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => bodyKind = v ?? MeetingBodyKind.board),
        ),
        if (rec.committees.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: committeeId,
            decoration: const InputDecoration(
              labelText: 'Committee (if a committee meeting)',
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('None')),
              for (final committee in rec.committees)
                DropdownMenuItem(
                  value: committee.id,
                  child: Text(committee.name),
                ),
            ],
            onChanged: (v) => setDialogState(() {
              committeeId = v ?? '';
              if (committeeId.isNotEmpty) {
                bodyKind = MeetingBodyKind.committee;
              }
            }),
          ),
        TextField(
          controller: attendance,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Attendance'),
        ),
        TextField(
          controller: notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes / minutes summary',
          ),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertMeeting(
        InstitutionMeeting(
          id: existing?.id ?? InstitutionService.newId('mtg'),
          title: title.text.trim(),
          heldOn: heldOn.text.trim(),
          bodyKind: bodyKind,
          committeeId: committeeId,
          attendance: attendance.text.trim(),
          notes: notes.text.trim(),
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editRisk([InstitutionRisk? existing]) async {
    var likelihood = existing?.likelihood ?? RiskLikelihood.medium;
    var impact = existing?.impact ?? RiskImpact.medium;
    var status = existing?.status ?? RiskStatus.open;
    final title = TextEditingController(text: existing?.title ?? '');
    final owner = TextEditingController(text: existing?.owner ?? '');
    final review = TextEditingController(text: existing?.reviewDate ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    final saved = await _formDialog(
      title: existing == null ? 'Add institutional risk' : 'Edit risk',
      builder: (setDialogState) => [
        TextField(
          controller: title,
          decoration: const InputDecoration(
            labelText: 'Risk',
            hintText: 'Operating licence lapses',
          ),
        ),
        TextField(
          controller: owner,
          decoration: const InputDecoration(labelText: 'Owner'),
        ),
        DropdownButtonFormField<RiskLikelihood>(
          initialValue: likelihood,
          decoration: const InputDecoration(labelText: 'Likelihood'),
          items: [
            for (final v in RiskLikelihood.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionRisk.likelihoodLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => likelihood = v ?? RiskLikelihood.medium),
        ),
        DropdownButtonFormField<RiskImpact>(
          initialValue: impact,
          decoration: const InputDecoration(labelText: 'Impact'),
          items: [
            for (final v in RiskImpact.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionRisk.impactLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => impact = v ?? RiskImpact.medium),
        ),
        TextField(
          controller: review,
          decoration: const InputDecoration(
            labelText: 'Review date (YYYY-MM-DD)',
          ),
        ),
        DropdownButtonFormField<RiskStatus>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            for (final v in RiskStatus.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionRisk.statusLabel(v)),
              ),
          ],
          onChanged: (v) => setDialogState(() => status = v ?? RiskStatus.open),
        ),
        TextField(
          controller: notes,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notes / controls'),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertRisk(
        InstitutionRisk(
          id: existing?.id ?? InstitutionService.newId('rsk'),
          title: title.text.trim(),
          owner: owner.text.trim(),
          likelihood: likelihood,
          impact: impact,
          reviewDate: review.text.trim(),
          status: status,
          notes: notes.text.trim(),
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editPartner([InstitutionPartner? existing]) async {
    var kind = existing?.kind ?? PartnerKind.mou;
    var status = existing?.status ?? PartnerStatus.active;
    final name = TextEditingController(text: existing?.name ?? '');
    final contact = TextEditingController(text: existing?.contact ?? '');
    final agreement = TextEditingController(text: existing?.agreementRef ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    final saved = await _formDialog(
      title: existing == null ? 'Add partner / affiliation' : 'Edit partner',
      builder: (setDialogState) => [
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        DropdownButtonFormField<PartnerKind>(
          initialValue: kind,
          decoration: const InputDecoration(labelText: 'Kind'),
          items: [
            for (final v in PartnerKind.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionPartner.kindLabel(v)),
              ),
          ],
          onChanged: (v) => setDialogState(() => kind = v ?? PartnerKind.mou),
        ),
        TextField(
          controller: contact,
          decoration: const InputDecoration(labelText: 'Contact'),
        ),
        TextField(
          controller: agreement,
          decoration: const InputDecoration(
            labelText: 'Agreement / MOU reference',
          ),
        ),
        DropdownButtonFormField<PartnerStatus>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            for (final v in PartnerStatus.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionPartner.statusLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => status = v ?? PartnerStatus.active),
        ),
        TextField(
          controller: notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertPartner(
        InstitutionPartner(
          id: existing?.id ?? InstitutionService.newId('ptr'),
          name: name.text.trim(),
          kind: kind,
          contact: contact.text.trim(),
          agreementRef: agreement.text.trim(),
          status: status,
          notes: notes.text.trim(),
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editSef([InstitutionSefEntry? existing]) async {
    var judgment = existing?.judgment ?? SefJudgment.developing;
    var status = existing?.status ?? SefStatus.draft;
    final cycle = TextEditingController(text: existing?.cycle ?? '');
    final area = TextEditingController(text: existing?.area ?? '');
    final evidence = TextEditingController(text: existing?.evidence ?? '');
    final owner = TextEditingController(text: existing?.owner ?? '');
    final saved = await _formDialog(
      title: existing == null ? 'Add SEF judgment' : 'Edit SEF judgment',
      builder: (setDialogState) => [
        TextField(
          controller: cycle,
          decoration: const InputDecoration(
            labelText: 'Cycle',
            hintText: '2025/26',
          ),
        ),
        TextField(
          controller: area,
          decoration: const InputDecoration(
            labelText: 'Area / standard',
            hintText: 'Leadership and management',
          ),
        ),
        DropdownButtonFormField<SefJudgment>(
          initialValue: judgment,
          decoration: const InputDecoration(labelText: 'Judgment'),
          items: [
            for (final v in SefJudgment.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionSefEntry.judgmentLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => judgment = v ?? SefJudgment.developing),
        ),
        TextField(
          controller: owner,
          decoration: const InputDecoration(labelText: 'Owner'),
        ),
        DropdownButtonFormField<SefStatus>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            for (final v in SefStatus.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionSefEntry.statusLabel(v)),
              ),
          ],
          onChanged: (v) => setDialogState(() => status = v ?? SefStatus.draft),
        ),
        TextField(
          controller: evidence,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Evidence summary'),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertSef(
        InstitutionSefEntry(
          id: existing?.id ?? InstitutionService.newId('sef'),
          cycle: cycle.text.trim(),
          area: area.text.trim(),
          judgment: judgment,
          evidence: evidence.text.trim(),
          owner: owner.text.trim(),
          status: status,
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editCapa([InstitutionCapa? existing]) async {
    final rec = _svc.recordFor(_schoolId);
    var source = existing?.source ?? CapaSource.other;
    var status = existing?.status ?? CapaStatus.open;
    var sefId = existing?.sefId ?? '';
    var riskId = existing?.riskId ?? '';
    if (sefId.isNotEmpty && rec.sefEntries.every((e) => e.id != sefId)) {
      sefId = '';
    }
    if (riskId.isNotEmpty && rec.risks.every((e) => e.id != riskId)) {
      riskId = '';
    }
    final number = TextEditingController(text: existing?.number ?? '');
    final title = TextEditingController(text: existing?.title ?? '');
    final owner = TextEditingController(text: existing?.owner ?? '');
    final due = TextEditingController(text: existing?.dueDate ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    final saved = await _formDialog(
      title: existing == null ? 'Add CAPA' : 'Edit CAPA',
      builder: (setDialogState) => [
        TextField(
          controller: number,
          decoration: const InputDecoration(
            labelText: 'Action number',
            hintText: 'CAPA-2026-03',
          ),
        ),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        DropdownButtonFormField<CapaSource>(
          initialValue: source,
          decoration: const InputDecoration(labelText: 'Source'),
          items: [
            for (final v in CapaSource.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionCapa.sourceLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => source = v ?? CapaSource.other),
        ),
        if (rec.sefEntries.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: sefId,
            decoration: const InputDecoration(labelText: 'Linked SEF'),
            items: [
              const DropdownMenuItem(value: '', child: Text('None')),
              for (final row in rec.sefEntries)
                DropdownMenuItem(
                  value: row.id,
                  child: Text('${row.cycle} · ${row.area}'),
                ),
            ],
            onChanged: (v) => setDialogState(() {
              sefId = v ?? '';
              if (sefId.isNotEmpty) source = CapaSource.sef;
            }),
          ),
        if (rec.risks.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: riskId,
            decoration: const InputDecoration(labelText: 'Linked risk'),
            items: [
              const DropdownMenuItem(value: '', child: Text('None')),
              for (final row in rec.risks)
                DropdownMenuItem(value: row.id, child: Text(row.title)),
            ],
            onChanged: (v) => setDialogState(() {
              riskId = v ?? '';
              if (riskId.isNotEmpty) source = CapaSource.risk;
            }),
          ),
        TextField(
          controller: owner,
          decoration: const InputDecoration(labelText: 'Owner'),
        ),
        TextField(
          controller: due,
          decoration: const InputDecoration(labelText: 'Due date (YYYY-MM-DD)'),
        ),
        DropdownButtonFormField<CapaStatus>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            for (final v in CapaStatus.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionCapa.statusLabel(v)),
              ),
          ],
          onChanged: (v) => setDialogState(() => status = v ?? CapaStatus.open),
        ),
        TextField(
          controller: notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertCapa(
        InstitutionCapa(
          id: existing?.id ?? InstitutionService.newId('capa'),
          number: number.text.trim(),
          title: title.text.trim(),
          source: source,
          sefId: sefId,
          riskId: riskId,
          owner: owner.text.trim(),
          dueDate: due.text.trim(),
          status: status,
          notes: notes.text.trim(),
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editKpi([InstitutionKpi? existing]) async {
    var theme = existing?.theme ?? KpiTheme.governance;
    var status = existing?.status ?? KpiStatus.onTrack;
    final name = TextEditingController(text: existing?.name ?? '');
    final target = TextEditingController(text: existing?.target ?? '');
    final actual = TextEditingController(text: existing?.actual ?? '');
    final period = TextEditingController(text: existing?.period ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    final saved = await _formDialog(
      title: existing == null ? 'Add institutional KPI' : 'Edit KPI',
      builder: (setDialogState) => [
        TextField(
          controller: name,
          decoration: const InputDecoration(
            labelText: 'KPI',
            hintText: 'Board meetings held on schedule',
          ),
        ),
        DropdownButtonFormField<KpiTheme>(
          initialValue: theme,
          decoration: const InputDecoration(labelText: 'Theme'),
          items: [
            for (final v in KpiTheme.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionKpi.themeLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => theme = v ?? KpiTheme.governance),
        ),
        TextField(
          controller: period,
          decoration: const InputDecoration(
            labelText: 'Period',
            hintText: '2025/26 T1',
          ),
        ),
        TextField(
          controller: target,
          decoration: const InputDecoration(labelText: 'Target'),
        ),
        TextField(
          controller: actual,
          decoration: const InputDecoration(labelText: 'Actual'),
        ),
        DropdownButtonFormField<KpiStatus>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            for (final v in KpiStatus.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionKpi.statusLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => status = v ?? KpiStatus.onTrack),
        ),
        TextField(
          controller: notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertKpi(
        InstitutionKpi(
          id: existing?.id ?? InstitutionService.newId('kpi'),
          name: name.text.trim(),
          theme: theme,
          target: target.text.trim(),
          actual: actual.text.trim(),
          period: period.text.trim(),
          status: status,
          notes: notes.text.trim(),
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editProperty([InstitutionProperty? existing]) async {
    var kind = existing?.kind ?? PropertyKind.building;
    var status = existing?.status ?? PropertyStatus.inUse;
    final name = TextEditingController(text: existing?.name ?? '');
    final campus = TextEditingController(
      text: existing?.campusScope ?? 'Institution-wide',
    );
    final acquired = TextEditingController(text: existing?.acquiredOn ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    final saved = await _formDialog(
      title: existing == null
          ? 'Add property / capital asset'
          : 'Edit property',
      builder: (setDialogState) => [
        TextField(
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Main campus block A',
          ),
        ),
        DropdownButtonFormField<PropertyKind>(
          initialValue: kind,
          decoration: const InputDecoration(labelText: 'Kind'),
          items: [
            for (final v in PropertyKind.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionProperty.kindLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => kind = v ?? PropertyKind.building),
        ),
        TextField(
          controller: campus,
          decoration: const InputDecoration(
            labelText: 'Campus scope',
            hintText: 'Institution-wide or a campus name',
          ),
        ),
        TextField(
          controller: acquired,
          decoration: const InputDecoration(
            labelText: 'Acquired on (YYYY-MM-DD)',
          ),
        ),
        DropdownButtonFormField<PropertyStatus>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            for (final v in PropertyStatus.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionProperty.statusLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => status = v ?? PropertyStatus.inUse),
        ),
        TextField(
          controller: notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes / title details'),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertProperty(
        InstitutionProperty(
          id: existing?.id ?? InstitutionService.newId('prop'),
          name: name.text.trim(),
          kind: kind,
          campusScope: campus.text.trim(),
          status: status,
          acquiredOn: acquired.text.trim(),
          notes: notes.text.trim(),
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<void> _editArchive([InstitutionArchiveItem? existing]) async {
    var series = existing?.series ?? ArchiveSeries.other;
    var status = existing?.status ?? ArchiveStatus.current;
    final title = TextEditingController(text: existing?.title ?? '');
    final until = TextEditingController(text: existing?.retentionUntil ?? '');
    final location = TextEditingController(text: existing?.location ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    final saved = await _formDialog(
      title: existing == null
          ? 'Add archive / retention record'
          : 'Edit archive',
      builder: (setDialogState) => [
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        DropdownButtonFormField<ArchiveSeries>(
          initialValue: series,
          decoration: const InputDecoration(labelText: 'Series'),
          items: [
            for (final v in ArchiveSeries.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionArchiveItem.seriesLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => series = v ?? ArchiveSeries.other),
        ),
        TextField(
          controller: until,
          decoration: const InputDecoration(
            labelText: 'Retain until (YYYY-MM-DD)',
          ),
        ),
        TextField(
          controller: location,
          decoration: const InputDecoration(
            labelText: 'Location / box / system',
          ),
        ),
        DropdownButtonFormField<ArchiveStatus>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            for (final v in ArchiveStatus.values)
              DropdownMenuItem(
                value: v,
                child: Text(InstitutionArchiveItem.statusLabel(v)),
              ),
          ],
          onChanged: (v) =>
              setDialogState(() => status = v ?? ArchiveStatus.current),
        ),
        TextField(
          controller: notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ],
    );
    if (saved != true) return;
    await _guarded(() async {
      await _svc.upsertArchive(
        InstitutionArchiveItem(
          id: existing?.id ?? InstitutionService.newId('arc'),
          title: title.text.trim(),
          series: series,
          retentionUntil: until.text.trim(),
          location: location.text.trim(),
          status: status,
          notes: notes.text.trim(),
        ),
        schoolId: _schoolId,
      );
    });
  }

  Future<bool?> _formDialog({
    required String title,
    required List<Widget> Function(void Function(VoidCallback)) builder,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final child in builder(setDialogState)) ...[
                    child,
                    const SizedBox(height: 10),
                  ],
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
  }
}

class _Action {
  const _Action({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({
    super.key,
    required this.profile,
    required this.canManage,
    required this.onSave,
  });

  final InstitutionProfile profile;
  final bool canManage;
  final ValueChanged<InstitutionProfile> onSave;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final _legal = TextEditingController(text: widget.profile.legalName);
  late final _trading = TextEditingController(text: widget.profile.tradingName);
  late var _form = widget.profile.legalForm;
  late final _reg = TextEditingController(
    text: widget.profile.registrationNumber,
  );
  late final _founded = TextEditingController(
    text: widget.profile.foundingDate,
  );
  late final _registered = TextEditingController(
    text: widget.profile.registeredAddress,
  );
  late final _operating = TextEditingController(
    text: widget.profile.operatingAddress,
  );
  late final _motto = TextEditingController(text: widget.profile.motto);
  late final _vision = TextEditingController(text: widget.profile.vision);
  late final _mission = TextEditingController(text: widget.profile.mission);
  late final _langs = TextEditingController(
    text: widget.profile.officialLanguages,
  );

  @override
  void dispose() {
    _legal.dispose();
    _trading.dispose();
    _reg.dispose();
    _founded.dispose();
    _registered.dispose();
    _operating.dispose();
    _motto.dispose();
    _vision.dispose();
    _mission.dispose();
    _langs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: WebErpTheme.cardDecoration(context),
          child: Column(
            children: [
              TextField(
                controller: _legal,
                enabled: widget.canManage,
                decoration: const InputDecoration(
                  labelText: 'Legal name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _trading,
                enabled: widget.canManage,
                decoration: const InputDecoration(
                  labelText: 'Trading / display name',
                  helperText:
                      'Operational school name and academic year stay in School Management.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<InstitutionLegalForm>(
                initialValue: _form,
                decoration: const InputDecoration(
                  labelText: 'Legal form',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final v in InstitutionLegalForm.values)
                    DropdownMenuItem(
                      value: v,
                      child: Text(InstitutionProfile.legalFormLabel(v)),
                    ),
                ],
                onChanged: widget.canManage
                    ? (v) => setState(
                        () => _form = v ?? InstitutionLegalForm.privateSchool,
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reg,
                enabled: widget.canManage,
                decoration: const InputDecoration(
                  labelText: 'Registration number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _founded,
                enabled: widget.canManage,
                decoration: const InputDecoration(
                  labelText: 'Founding date',
                  hintText: 'YYYY-MM-DD',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _registered,
                enabled: widget.canManage,
                decoration: const InputDecoration(
                  labelText: 'Registered address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _operating,
                enabled: widget.canManage,
                decoration: const InputDecoration(
                  labelText: 'Operating address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _motto,
                enabled: widget.canManage,
                decoration: const InputDecoration(
                  labelText: 'Motto',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _vision,
                enabled: widget.canManage,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Vision',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mission,
                enabled: widget.canManage,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mission',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _langs,
                enabled: widget.canManage,
                decoration: const InputDecoration(
                  labelText: 'Official languages of record',
                  hintText: 'English, Amharic',
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.canManage) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => widget.onSave(
                      InstitutionProfile(
                        legalName: _legal.text.trim(),
                        tradingName: _trading.text.trim(),
                        legalForm: _form,
                        registrationNumber: _reg.text.trim(),
                        foundingDate: _founded.text.trim(),
                        registeredAddress: _registered.text.trim(),
                        operatingAddress: _operating.text.trim(),
                        motto: _motto.text.trim(),
                        vision: _vision.text.trim(),
                        mission: _mission.text.trim(),
                        officialLanguages: _langs.text.trim(),
                      ),
                    ),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save legal identity'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
