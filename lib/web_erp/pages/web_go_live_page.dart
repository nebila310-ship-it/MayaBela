import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/content/training_manuals.dart';
import 'package:mayabela/models/golive_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/student_excel_import.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/widgets/mfa_settings_card.dart';

/// LIA Phase J go-live desk: MFA, privacy, backups, Excel import, training.
class WebGoLivePage extends StatefulWidget {
  const WebGoLivePage({super.key});

  @override
  State<WebGoLivePage> createState() => _WebGoLivePageState();
}

class _WebGoLivePageState extends State<WebGoLivePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this);

  bool get _canManage => ModuleAccess.canManage('go_live');

  @override
  void initState() {
    super.initState();
    GoliveService.instance.ensureLoaded();
  }

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
                'Go-live & compliance',
                style: WebErpTheme.sectionTitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                'Opt-in authenticator, consent and data-rights tooling, school '
                'snapshots, Excel → student import, and short training. This '
                'does not change markbook or exams, and it does not claim 99.5% '
                'uptime.',
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
                  Tab(text: 'Authenticator'),
                  Tab(text: 'Privacy'),
                  Tab(text: 'Backups'),
                  Tab(text: 'Import'),
                  Tab(text: 'Training'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: GoliveService.instance,
            builder: (context, _) {
              return TabBarView(
                controller: _tabs,
                children: [
                  _OverviewTab(canManage: _canManage),
                  const _MfaTab(),
                  _PrivacyTab(canManage: _canManage),
                  _BackupTab(canManage: _canManage),
                  _ImportTab(canManage: _canManage),
                  const _TrainingDeskTab(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.canManage});
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final svc = GoliveService.instance;
    final cap = svc.capacitySnapshot();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _stat(context, 'MFA enrolled', '${cap.mfaEnrolled}'),
            _stat(context, 'Open data-rights', '${cap.openDataRights}'),
            _stat(
              context,
              'Last backup',
              cap.lastBackupAt == null
                  ? 'None yet'
                  : cap.lastBackupAt!.toLocal().toString().split('.').first,
            ),
            _stat(context, 'Cloud', cap.cloudReady ? 'Ready' : 'Offline'),
            _stat(context, 'Storage', cap.storageReady ? 'Ready' : 'Check health'),
          ],
        ),
        const SizedBox(height: 16),
        Text('Capacity checklist', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Target for a serious LIA go-live: about 1,000 concurrent users and '
          '99.5% availability. MayaBela records health signals here. It does '
          'not claim those targets are already met.',
        ),
        const SizedBox(height: 8),
        _CheckRow(label: 'Supabase cloud reachable', ok: cap.cloudReady),
        _CheckRow(label: 'File storage configured', ok: cap.storageReady),
        _CheckRow(
          label: 'At least one school snapshot',
          ok: cap.lastBackupAt != null,
        ),
        const _CheckRow(label: 'Authenticator available (opt-in)', ok: true),
        const _CheckRow(
          label:
              'Platform-owner restore drill lives in tools/restore_drill_staging.mjs',
          ok: true,
        ),
        if (canManage)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Signed in as ${AuthService.currentUser?.username ?? 'staff'}. '
              'You can process erasure without wiping student ids or grades.',
            ),
          ),
      ],
    );
  }

  Widget _stat(BuildContext context, String title, String value) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        ok ? Icons.check_circle : Icons.radio_button_unchecked,
        color: ok ? Colors.teal : Colors.orange,
      ),
      title: Text(label),
    );
  }
}

class _MfaTab extends StatelessWidget {
  const _MfaTab();

  @override
  Widget build(BuildContext context) {
    final rows = GoliveService.instance.enrollmentsForSchool();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const MfaSettingsCard(),
        const SizedBox(height: 16),
        Text('School enrollments', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Secrets are never listed. Only the enrolled user sees a secret once.'),
        if (rows.isEmpty) const Text('No authenticator enrollments yet.'),
        for (final row in rows)
          ListTile(
            title: Text(row.username),
            subtitle: Text(
              '${row.enabled ? 'Enabled' : 'Pending confirm'} · ${row.enrolledAt.toLocal()}',
            ),
          ),
      ],
    );
  }
}

class _PrivacyTab extends StatelessWidget {
  const _PrivacyTab({required this.canManage});
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final svc = GoliveService.instance;
    final consents = svc.consentsForSchool();
    final rights = svc.rightsForSchool();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _recordConsent(context),
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Record consent'),
            ),
            OutlinedButton.icon(
              onPressed: () => _fileRequest(context),
              icon: const Icon(Icons.assignment_ind_outlined),
              label: const Text('File request'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Consent register', style: Theme.of(context).textTheme.titleMedium),
        if (consents.isEmpty) const Text('No consents yet.'),
        for (final row in consents)
          ListTile(
            title: Text('${row.subjectName} · ${row.purpose.name}'),
            subtitle: Text('${row.state.name} · ${row.studentId} · ${row.authorUsername}'),
          ),
        const SizedBox(height: 16),
        Text('Data-rights queue', style: Theme.of(context).textTheme.titleMedium),
        if (rights.isEmpty) const Text('No access or erasure requests.'),
        for (final row in rights)
          Card(
            child: ListTile(
              title: Text('${row.kind.name} · ${row.studentName} ${row.studentId}'),
              subtitle: Text('${row.status.name} · ${row.details}'),
              trailing: canManage
                  ? PopupMenuButton<DataRightsStatus>(
                      onSelected: (status) async {
                        try {
                          if (status == DataRightsStatus.redacted &&
                              row.kind == DataRightsKind.access) {
                            final json = const JsonEncoder.withIndent('  ')
                                .convert(svc.subjectAccessExport(row.studentId));
                            await Clipboard.setData(ClipboardData(text: json));
                          }
                          await svc.reviewDataRights(row.id, status);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: DataRightsStatus.reviewing,
                          child: Text('Mark reviewing'),
                        ),
                        const PopupMenuItem(
                          value: DataRightsStatus.redacted,
                          child: Text('Complete / redact'),
                        ),
                        const PopupMenuItem(
                          value: DataRightsStatus.denied,
                          child: Text('Deny'),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  Future<void> _recordConsent(BuildContext context) async {
    var purpose = ConsentPurpose.dataProcessing;
    final name = TextEditingController();
    final studentId = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record consent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Subject name'),
            ),
            TextField(
              controller: studentId,
              decoration: const InputDecoration(labelText: 'Student id'),
            ),
            DropdownButtonFormField<ConsentPurpose>(
              key: ValueKey(purpose),
              initialValue: purpose,
              items: [
                for (final item in ConsentPurpose.values)
                  DropdownMenuItem(value: item, child: Text(item.name)),
              ],
              onChanged: (value) {
                if (value != null) purpose = value;
              },
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
    if (ok == true && context.mounted) {
      await GoliveService.instance.recordConsent(
        purpose: purpose,
        state: ConsentState.granted,
        subjectName: name.text,
        studentId: studentId.text,
      );
    }
    name.dispose();
    studentId.dispose();
  }

  Future<void> _fileRequest(BuildContext context) async {
    var kind = DataRightsKind.access;
    final studentId = TextEditingController();
    final details = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File data-rights request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<DataRightsKind>(
              key: ValueKey(kind),
              initialValue: kind,
              items: const [
                DropdownMenuItem(
                  value: DataRightsKind.access,
                  child: Text('Access / copy'),
                ),
                DropdownMenuItem(
                  value: DataRightsKind.erasure,
                  child: Text('Erasure / redact'),
                ),
              ],
              onChanged: (value) {
                if (value != null) kind = value;
              },
            ),
            TextField(
              controller: studentId,
              decoration: const InputDecoration(labelText: 'Student id'),
            ),
            TextField(
              controller: details,
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
    if (ok == true && context.mounted) {
      await GoliveService.instance.fileDataRightsRequest(
        kind: kind,
        studentId: studentId.text,
        details: details.text,
      );
    }
    studentId.dispose();
    details.dispose();
  }
}

class _BackupTab extends StatelessWidget {
  const _BackupTab({required this.canManage});
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final svc = GoliveService.instance;
    final rows = svc.backupsForSchool();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'School snapshots record counts and a student directory without '
          'passwords or authenticator secrets. Platform-owner registry restore '
          'is a separate drill (tools/restore_drill_staging.mjs).',
        ),
        const SizedBox(height: 12),
        if (canManage)
          FilledButton.icon(
            onPressed: () async {
              final record = await svc.recordSchoolBackup(
                notes: 'In-app school snapshot',
              );
              final json = const JsonEncoder.withIndent('  ')
                  .convert(svc.schoolSnapshotExport());
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Snapshot ${record.id} copied. ${record.studentCount} students.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.backup_outlined),
            label: const Text('Write school snapshot'),
          ),
        const SizedBox(height: 16),
        if (rows.isEmpty) const Text('No school snapshots yet.'),
        for (final row in rows)
          ListTile(
            title: Text(row.id),
            subtitle: Text(
              '${row.createdAt.toLocal()} · ${row.studentCount} students · '
              '${row.mfaCount} MFA · ${row.createdBy}',
            ),
          ),
      ],
    );
  }
}

class _ImportTab extends StatefulWidget {
  const _ImportTab({required this.canManage});
  final bool canManage;

  @override
  State<_ImportTab> createState() => _ImportTabState();
}

class _ImportTabState extends State<_ImportTab> {
  List<StudentImportRow> _preview = const [];
  String? _message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'CSV or Excel with Full Name, Grade, Class, and Date of Birth. '
          'Optional: Gender, Father/Mother name and phone, Student id. '
          'Duplicates (same name + class, or an existing id) are skipped. '
          'New rows call addStudent and get a STU-#### id. Grades and exams '
          'are not written.',
        ),
        const SizedBox(height: 12),
        if (widget.canManage)
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Pick CSV / Excel'),
              ),
              if (_preview.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text('Import ${_preview.length} rows'),
                ),
            ],
          ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!),
        ],
        const SizedBox(height: 12),
        for (final row in _preview.take(40))
          ListTile(
            dense: true,
            title: Text(row.fullName),
            subtitle: Text(
              '${row.grade} · ${row.className} · '
              '${row.dateOfBirth.toIso8601String().split('T').first}',
            ),
          ),
        if (_preview.length > 40) Text('+ ${_preview.length - 40} more'),
      ],
    );
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _message = 'Could not read file bytes.');
      return;
    }
    try {
      final rows = StudentExcelImport.parseBytes(
        bytes: bytes,
        filename: file.name,
      );
      setState(() {
        _preview = rows;
        _message = '${rows.length} preview rows.';
      });
    } catch (e) {
      setState(() => _message = e.toString());
    }
  }

  Future<void> _import() async {
    try {
      final result =
          await GoliveService.instance.importStudentRows(_preview);
      setState(() {
        _message =
            'Created ${result.createdIds.length}: ${result.createdIds.join(', ')}. '
            'Skipped ${result.skipped.length}.';
        _preview = const [];
      });
    } catch (e) {
      setState(() => _message = e.toString());
    }
  }
}

class _TrainingDeskTab extends StatelessWidget {
  const _TrainingDeskTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final audience in TrainingManuals.audiences) ...[
          Text(
            audience[0].toUpperCase() + audience.substring(1),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final article in TrainingManuals.forAudience(audience))
            Card(
              child: ExpansionTile(
                title: Text(article.title),
                subtitle: Text(article.summary),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(article.body),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
