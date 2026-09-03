import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/content/training_manuals.dart';
import 'package:mayabela/models/golive_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/widgets/mfa_settings_card.dart';

/// Parent / student / settings surface for MFA, consent, rights, and manuals.
class GoliveSelfServiceScreen extends StatefulWidget {
  const GoliveSelfServiceScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<GoliveSelfServiceScreen> createState() => _GoliveSelfServiceScreenState();
}

class _GoliveSelfServiceScreenState extends State<GoliveSelfServiceScreen> {
  @override
  void initState() {
    super.initState();
    GoliveService.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthService.currentUser?.roleKey ?? AuthService.roleParent;
    final audience = role == AuthService.roleTeacher
        ? 'teacher'
        : role == AuthService.roleParent
            ? 'parent'
            : role == AuthService.roleStudent
                ? 'parent'
                : 'admin';
    return DefaultTabController(
      initialIndex: widget.initialTab.clamp(0, 2),
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Privacy & training'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Authenticator'),
              Tab(text: 'Privacy'),
              Tab(text: 'Training'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: GoliveService.instance,
          builder: (context, _) {
            return TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [MfaSettingsCard()],
                ),
                _PrivacyTab(),
                _TrainingTab(audience: audience),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PrivacyTab extends StatelessWidget {
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
              onPressed: () => _fileRequest(context, DataRightsKind.access),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Request a copy'),
            ),
            OutlinedButton.icon(
              onPressed: () => _fileRequest(context, DataRightsKind.erasure),
              icon: const Icon(Icons.hide_source_outlined),
              label: const Text('Request redaction'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Consents', style: Theme.of(context).textTheme.titleMedium),
        if (consents.isEmpty) const Text('No consent records yet.'),
        for (final row in consents)
          ListTile(
            title: Text('${row.purpose.name} · ${row.state.name}'),
            subtitle: Text(
              '${row.subjectName} ${row.studentId} · ${row.updatedAt.toLocal()}',
            ),
          ),
        const SizedBox(height: 12),
        Text('My requests', style: Theme.of(context).textTheme.titleMedium),
        if (rights.isEmpty) const Text('No data-rights requests yet.'),
        for (final row in rights)
          ListTile(
            title: Text('${row.kind.name} · ${row.status.name}'),
            subtitle: Text(
              '${row.studentName} ${row.studentId} · ${row.details}',
            ),
          ),
      ],
    );
  }

  Future<void> _recordConsent(BuildContext context) async {
    var purpose = ConsentPurpose.dataProcessing;
    final studentId = TextEditingController(
      text: AuthService.activeLinkedStudentIds().isEmpty
          ? ''
          : AuthService.activeLinkedStudentIds().first,
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record consent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<ConsentPurpose>(
              key: ValueKey(purpose),
              initialValue: purpose,
              decoration: const InputDecoration(labelText: 'Purpose'),
              items: [
                for (final item in ConsentPurpose.values)
                  DropdownMenuItem(value: item, child: Text(item.name)),
              ],
              onChanged: (value) {
                if (value != null) purpose = value;
              },
            ),
            TextField(
              controller: studentId,
              decoration: const InputDecoration(
                labelText: 'Student id (optional)',
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
            child: const Text('Grant'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await GoliveService.instance.recordConsent(
        purpose: purpose,
        state: ConsentState.granted,
        studentId: studentId.text,
      );
    }
    studentId.dispose();
  }

  Future<void> _fileRequest(BuildContext context, DataRightsKind kind) async {
    final studentId = TextEditingController(
      text: AuthService.activeLinkedStudentIds().isEmpty
          ? ''
          : AuthService.activeLinkedStudentIds().first,
    );
    final details = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(kind == DataRightsKind.access
            ? 'Request a copy'
            : 'Request redaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      final req = await GoliveService.instance.fileDataRightsRequest(
        kind: kind,
        studentId: studentId.text,
        details: details.text,
      );
      if (kind == DataRightsKind.access &&
          req.studentId.isNotEmpty &&
          context.mounted) {
        final json = GoliveService.instance
            .subjectAccessExport(req.studentId)
            .toString();
        await Clipboard.setData(ClipboardData(text: json));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Access export copied (no staff notes).')),
          );
        }
      }
    }
    studentId.dispose();
    details.dispose();
  }
}

class _TrainingTab extends StatelessWidget {
  const _TrainingTab({required this.audience});
  final String audience;

  @override
  Widget build(BuildContext context) {
    final articles = TrainingManuals.forAudience(audience);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final article in articles)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(article.summary),
                  const SizedBox(height: 8),
                  Text(article.body),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
