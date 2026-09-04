import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/content/training_manuals.dart';
import 'package:mayabela/models/digital_ops_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cctv/cctv_catalog_service.dart';
import 'package:mayabela/services/digital_ops_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

/// Five-phase desk for Administration Staff (Staff role). Not a new IT login.
class WebDigitalOpsPage extends StatefulWidget {
  const WebDigitalOpsPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebDigitalOpsPage> createState() => _WebDigitalOpsPageState();
}

class _WebDigitalOpsPageState extends State<WebDigitalOpsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  bool get _canManage => ModuleAccess.canManage('digital_ops');

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
                'Digital operations',
                style: WebErpTheme.sectionTitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                'Administration Staff desk: devices, parent access help, '
                'go-live buttons, campus systems, and the Friday checklist. '
                'This is not Full Access and does not change markbook or fees.',
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
                  Tab(text: '1 · People & devices'),
                  Tab(text: '2 · Access help'),
                  Tab(text: '3 · Go-live ops'),
                  Tab(text: '4 · Campus systems'),
                  Tab(text: '5 · Weekly ritual'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              DigitalOpsService.instance,
              EnrollmentService.instance,
              GoliveService.instance,
              DriverRegistryService.instance,
              CctvCatalogService.instance,
            ]),
            builder: (context, _) {
              return TabBarView(
                controller: _tabs,
                children: [
                  _DevicesTab(canManage: _canManage),
                  _AccessHelpTab(
                    onOpenParents: () => widget.onNavigate?.call('parents'),
                  ),
                  _GoLiveOpsTab(
                    canManage: _canManage,
                    onOpenGoLive: () => widget.onNavigate?.call('go_live'),
                  ),
                  _CampusTab(
                    canManage: _canManage,
                    onOpenCctv: () => widget.onNavigate?.call('cctv'),
                    onOpenGps: () =>
                        widget.onNavigate?.call('transport_live_gps'),
                  ),
                  _WeeklyTab(canManage: _canManage),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DevicesTab extends StatelessWidget {
  const _DevicesTab({required this.canManage});
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final svc = DigitalOpsService.instance;
    final sid = AuthService.activeSchoolId;
    final devices = svc.devicesForSchool(sid);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Issue first passwords from HR / Admin. This register is yours: '
          'whose laptop, whose phone, which driver phone, which lab PC. '
          'Tell staff: web is https://mayabela.pages.dev — hard-refresh '
          'Ctrl+Shift+R. Keep the phone app closed until web is stable.',
        ),
        const SizedBox(height: 12),
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _editDevice(context),
              icon: const Icon(Icons.add),
              label: const Text('Add device'),
            ),
          ),
        const SizedBox(height: 12),
        if (devices.isEmpty)
          const Text('No devices recorded yet.')
        else
          for (final row in devices)
            Card(
              child: ListTile(
                leading: Icon(_iconFor(row.kind)),
                title: Text(row.label),
                subtitle: Text(
                  '${row.kind.label}'
                  '${row.assignedTo.isEmpty ? '' : ' · ${row.assignedTo}'}'
                  '${row.location.isEmpty ? '' : ' · ${row.location}'}'
                  '${row.kind == IctDeviceKind.driverPhone ? (row.gpsEnabled ? ' · GPS on' : ' · GPS off') : ''}',
                ),
                trailing: canManage
                    ? IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editDevice(context, existing: row),
                      )
                    : null,
              ),
            ),
      ],
    );
  }

  static IconData _iconFor(IctDeviceKind kind) => switch (kind) {
        IctDeviceKind.laptop => Icons.laptop_outlined,
        IctDeviceKind.phone => Icons.smartphone_outlined,
        IctDeviceKind.driverPhone => Icons.directions_bus_outlined,
        IctDeviceKind.labPc => Icons.computer_outlined,
        IctDeviceKind.tablet => Icons.tablet_mac_outlined,
        IctDeviceKind.other => Icons.devices_other_outlined,
      };
}

Future<void> _editDevice(
  BuildContext context, {
  IctDeviceRecord? existing,
}) async {
  var kind = existing?.kind ?? IctDeviceKind.laptop;
  final label = TextEditingController(text: existing?.label ?? '');
  final assigned = TextEditingController(text: existing?.assignedTo ?? '');
  final location = TextEditingController(text: existing?.location ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  var gps = existing?.gpsEnabled ?? false;
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(existing == null ? 'Add device' : 'Edit device'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<IctDeviceKind>(
                      key: ValueKey(kind),
                      initialValue: kind,
                      decoration: const InputDecoration(labelText: 'Kind'),
                      items: [
                        for (final k in IctDeviceKind.values)
                          DropdownMenuItem(value: k, child: Text(k.label)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => kind = v);
                      },
                    ),
                    TextField(
                      controller: label,
                      decoration: const InputDecoration(
                        labelText: 'Label (e.g. Lab PC 3)',
                      ),
                    ),
                    TextField(
                      controller: assigned,
                      decoration: const InputDecoration(
                        labelText: 'Assigned to',
                      ),
                    ),
                    TextField(
                      controller: location,
                      decoration: const InputDecoration(labelText: 'Location'),
                    ),
                    TextField(
                      controller: notes,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                    if (kind == IctDeviceKind.driverPhone)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('GPS permission on'),
                        value: gps,
                        onChanged: (v) => setLocal(() => gps = v),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              if (existing != null)
                TextButton(
                  onPressed: () async {
                    await DigitalOpsService.instance.removeDevice(existing.id);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: const Text('Remove'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (label.text.trim().isEmpty) return;
                  await DigitalOpsService.instance.upsertDevice(
                    id: existing?.id,
                    kind: kind,
                    label: label.text,
                    assignedTo: assigned.text,
                    location: location.text,
                    notes: notes.text,
                    gpsEnabled: gps,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  label.dispose();
  assigned.dispose();
  location.dispose();
  notes.dispose();
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device register saved')),
    );
  }
}

class _AccessHelpTab extends StatefulWidget {
  const _AccessHelpTab({
    required this.onOpenParents,
  });
  final VoidCallback onOpenParents;

  @override
  State<_AccessHelpTab> createState() => _AccessHelpTabState();
}

class _AccessHelpTabState extends State<_AccessHelpTab> {
  final _lookup = TextEditingController();
  String? _lookupResult;

  @override
  void dispose() {
    _lookup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = DigitalOpsService.instance;
    final sid = AuthService.activeSchoolId;
    final pending = svc.pendingParentLinkRows(sid);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'You help people get in. Registrar / VP still approve parent links. '
          'Do not enter grades or fees from this desk.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pending.length} parent link(s) waiting',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Help the parent: School ID, student ID (STU-####), date of '
                  'birth. Then tell them to wait. Escalate the row to registrar '
                  '— do not approve it here unless Admin gave you Parents.',
                ),
                if (ModuleAccess.canView('parents')) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.onOpenParents,
                    child: const Text('Open parent-link queue'),
                  ),
                ],
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final row in pending.take(12))
                    ListTile(
                      dense: true,
                      title: Text(row.parentFullName.isEmpty
                          ? row.parentUsername
                          : row.parentFullName),
                      subtitle: Text(
                        '${row.studentId} · ${row.relationship.name}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Copy student id for registrar',
                        icon: const Icon(Icons.copy),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: row.studentId),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Copied ${row.studentId} — send to registrar',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _lookup,
          decoration: const InputDecoration(
            labelText: 'Look up student ID',
            hintText: 'STU-1001',
          ),
          textCapitalization: TextCapitalization.characters,
          onSubmitted: (_) => _runLookup(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: _runLookup,
            child: const Text('Check ID'),
          ),
        ),
        if (_lookupResult != null) ...[
          const SizedBox(height: 8),
          Text(_lookupResult!),
        ],
      ],
    );
  }

  void _runLookup() {
    final student = DigitalOpsService.instance.lookupStudent(_lookup.text);
    setState(() {
      if (student == null) {
        _lookupResult =
            'No student with that id on this device. Ask registrar, or wait for cloud Ready.';
      } else {
        _lookupResult =
            '${student.fullName} · ${student.className} · DOB ${student.dateOfBirth.toLocal().toString().split(' ').first}';
      }
    });
  }
}

class _GoLiveOpsTab extends StatelessWidget {
  const _GoLiveOpsTab({
    required this.canManage,
    required this.onOpenGoLive,
  });
  final bool canManage;
  final VoidCallback onOpenGoLive;

  @override
  Widget build(BuildContext context) {
    final last = DigitalOpsService.instance.lastBackupAt();
    final articles = TrainingManuals.all()
        .where((a) => a.audience == 'admin' || a.audience == 'teacher')
        .take(4);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Admin owns policy. You run the buttons: Friday snapshot, help a '
          'colleague enroll authenticator, Excel import when registry sends a '
          'sheet, train teachers from the manuals.',
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Last school snapshot'),
            subtitle: Text(
              last == null
                  ? 'None yet — open Go-live → Backups'
                  : last.toLocal().toString().split('.').first,
            ),
            trailing: ModuleAccess.canView('go_live')
                ? TextButton(
                    onPressed: onOpenGoLive,
                    child: const Text('Open Go-live'),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Text('Training to give staff', style: Theme.of(context).textTheme.titleMedium),
        for (final article in articles)
          ListTile(
            title: Text(article.title),
            subtitle: Text(article.summary),
          ),
        if (!canManage)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Ask Admin to tick Digital operations manage for backups.'),
          ),
      ],
    );
  }
}

class _CampusTab extends StatelessWidget {
  const _CampusTab({
    required this.canManage,
    required this.onOpenCctv,
    required this.onOpenGps,
  });
  final bool canManage;
  final VoidCallback onOpenCctv;
  final VoidCallback onOpenGps;

  @override
  Widget build(BuildContext context) {
    final sid = AuthService.activeSchoolId;
    final sites = CctvCatalogService.instance.sitesForSchool(sid);
    final wired = sites.where((s) => s.isWired).length;
    final missingGps = DigitalOpsService.instance.driverPhonesWithoutGps(sid);
    final labPcs = DigitalOpsService.instance
        .devicesForSchool(sid)
        .where((d) => d.kind == IctDeviceKind.labPc)
        .length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Hardware and access stay with Administration Staff. Academics stay '
          'with teachers. Tick GPS on the driver phone, keep lab PCs on this '
          'register, open CCTV when the school has cameras.',
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: Text('CCTV sites · $wired wired / ${sites.length} listed'),
            trailing: ModuleAccess.canView('cctv')
                ? TextButton(onPressed: onOpenCctv, child: const Text('Open CCTV'))
                : null,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.gps_fixed),
            title: Text('Driver phones without a fresh GPS fix: $missingGps'),
            subtitle: const Text('Ask the driver to allow location on the MayaBela app.'),
            trailing: ModuleAccess.canView('transport_live_gps')
                ? TextButton(onPressed: onOpenGps, child: const Text('Live map'))
                : null,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.computer_outlined),
            title: Text('Lab PCs on the device register: $labPcs'),
            subtitle: const Text('Add them under People & devices.'),
          ),
        ),
        if (!canManage)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Read-only: ask Administration Staff to update CCTV wiring '
              'or the lab-PC register.',
            ),
          ),
      ],
    );
  }
}

class _WeeklyTab extends StatefulWidget {
  const _WeeklyTab({required this.canManage});
  final bool canManage;

  @override
  State<_WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends State<_WeeklyTab> {
  late bool _logins;
  late bool _parents;
  late bool _backup;
  late bool _refresh;
  late bool _devices;
  final _notes = TextEditingController();
  final _chair = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = DigitalOpsService.instance.reviewThisWeek(
      AuthService.activeSchoolId,
    );
    _logins = existing?.loginIssuesReviewed ?? false;
    _parents = existing?.parentLinkPileReviewed ?? false;
    _backup = existing?.backupChecked ?? false;
    _refresh = existing?.hardRefreshReminded ?? false;
    _devices = existing?.devicesChecked ?? false;
    _notes.text = existing?.notes ?? '';
    _chair.text = existing?.chairName ??
        (AuthService.currentUser?.fullName ??
            AuthService.currentUser?.username ??
            '');
  }

  @override
  void dispose() {
    _notes.dispose();
    _chair.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = DigitalOpsService.instance.reviewsForSchool(
      AuthService.activeSchoolId,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Ten minutes, you chair, Admin in the room. MaJo only joins if the '
          'whole school cannot log in.',
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _logins,
          onChanged: widget.canManage
              ? (v) => setState(() => _logins = v ?? false)
              : null,
          title: const Text('Login issues this week reviewed'),
        ),
        CheckboxListTile(
          value: _parents,
          onChanged: widget.canManage
              ? (v) => setState(() => _parents = v ?? false)
              : null,
          title: const Text('Parent-link pile checked (escalated, not approved)'),
        ),
        CheckboxListTile(
          value: _backup,
          onChanged: widget.canManage
              ? (v) => setState(() => _backup = v ?? false)
              : null,
          title: const Text('Last backup date confirmed'),
        ),
        CheckboxListTile(
          value: _refresh,
          onChanged: widget.canManage
              ? (v) => setState(() => _refresh = v ?? false)
              : null,
          title: const Text('Hard-refresh (Ctrl+Shift+R) reminder given'),
        ),
        CheckboxListTile(
          value: _devices,
          onChanged: widget.canManage
              ? (v) => setState(() => _devices = v ?? false)
              : null,
          title: const Text('Device / driver-phone register checked'),
        ),
        TextField(
          controller: _chair,
          enabled: widget.canManage,
          decoration: const InputDecoration(labelText: 'Chair (your name)'),
        ),
        TextField(
          controller: _notes,
          enabled: widget.canManage,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notes for Admin'),
        ),
        const SizedBox(height: 12),
        if (widget.canManage)
          FilledButton(
            onPressed: () async {
              await DigitalOpsService.instance.saveWeeklyReview(
                loginIssuesReviewed: _logins,
                parentLinkPileReviewed: _parents,
                backupChecked: _backup,
                hardRefreshReminded: _refresh,
                devicesChecked: _devices,
                notes: _notes.text,
                chairName: _chair.text,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Weekly ritual saved')),
                );
              }
            },
            child: const Text('Save this week'),
          ),
        const SizedBox(height: 16),
        Text('Earlier weeks', style: Theme.of(context).textTheme.titleMedium),
        if (history.isEmpty)
          const Text('No rituals saved yet.')
        else
          for (final row in history.take(8))
            ListTile(
              title: Text(
                'Week of ${row.weekStart.toLocal().toString().split(' ').first}'
                '${row.complete ? ' · complete' : ''}',
              ),
              subtitle: Text(
                '${row.chairName}'
                '${row.notes.isEmpty ? '' : ' · ${row.notes}'}',
              ),
            ),
      ],
    );
  }
}
