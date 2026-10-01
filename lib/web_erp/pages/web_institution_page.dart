import 'package:flutter/material.dart';

import 'package:mayabela/models/institution_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/institution_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/web_erp/widgets/web_erp_related_tools.dart';

/// Phase 1 Institutional Management desk — profile, leadership, structure,
/// policies, licenses, and resolutions. Not School / Campus / QA ops.
class WebInstitutionPage extends StatefulWidget {
  const WebInstitutionPage({super.key});

  @override
  State<WebInstitutionPage> createState() => _WebInstitutionPageState();
}

class _WebInstitutionPageState extends State<WebInstitutionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 7, vsync: this);
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
    _tabs.dispose();
    super.dispose();
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
                'Governance of the institution: identity, leadership, policies, '
                'licenses, and board decisions. Academic year, student campus '
                'assignment, and teaching QA stay on their own desks.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Profile'),
                  Tab(text: 'Leadership'),
                  Tab(text: 'Structure'),
                  Tab(text: 'Policies'),
                  Tab(text: 'Licenses'),
                  Tab(text: 'Resolutions'),
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
                controller: _tabs,
                children: [
                  _overviewTab(rec, narrow),
                  _profileTab(rec),
                  _leadershipTab(rec),
                  _structureTab(rec),
                  _policiesTab(rec),
                  _licensesTab(rec),
                  _resolutionsTab(rec),
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
    final cards = <(String, int, Color, Color)>[
      (
        'Active policies',
        m.activePolicies,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      (
        'Licenses expiring',
        m.expiringLicenses,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      (
        'Licenses expired',
        m.expiredLicenses,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      (
        'Open resolutions',
        m.openResolutions,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      (
        'Overdue resolutions',
        m.overdueResolutions,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (label, count, bg, fg) in cards)
              Container(
                width: narrow ? 150 : 180,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
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
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: WebErpTheme.cardDecoration(context),
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
                  '${rec.orgUnits.length} departments / divisions',
                ].join(' · '),
              ),
            ],
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
              if (row.meetingTitle.isNotEmpty) row.meetingTitle,
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

  Future<void> _editResolution([InstitutionResolution? existing]) async {
    var status = existing?.status ?? ResolutionStatus.open;
    final number = TextEditingController(text: existing?.number ?? '');
    final title = TextEditingController(text: existing?.title ?? '');
    final decision = TextEditingController(text: existing?.decision ?? '');
    final owner = TextEditingController(text: existing?.owner ?? '');
    final due = TextEditingController(text: existing?.dueDate ?? '');
    final meeting = TextEditingController(text: existing?.meetingTitle ?? '');
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
        TextField(
          controller: meeting,
          decoration: const InputDecoration(
            labelText: 'Meeting (optional)',
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
