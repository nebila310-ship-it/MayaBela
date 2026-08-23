import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/school_lifecycle.dart';
import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/screens/maya_assistant_screen.dart';
import 'package:mayabela/screens/platform_audit_log_screen.dart';
import 'package:mayabela/screens/platform_bulk_sms_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/maya_assistant_service.dart';
import 'package:mayabela/services/platform_audit_log_service.dart';
import 'package:mayabela/services/platform_backup_service.dart';
import 'package:mayabela/services/platform_expiry_alert_service.dart';
import 'package:mayabela/services/platform_owner_service.dart';
import 'package:mayabela/services/platform_schools_cloud_service.dart';
import 'package:mayabela/services/school_admin_credentials_service.dart';
import 'package:mayabela/services/school_enrollment_metrics_service.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/services/school_platform_insight.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/phone_utils.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/platform_pin_flows.dart';
import 'package:mayabela/widgets/school_grade_level_picker.dart';
import 'package:mayabela/widgets/school_logo_display.dart';
import 'package:mayabela/widgets/school_onboarding_checklist_card.dart';
import 'package:mayabela/widgets/send_school_admin_credentials.dart';
import 'package:url_launcher/url_launcher.dart';

enum _SchoolListFilter { all, active, expiring, blocked, attention }

Future<void> _saveSchoolLogoFromPicker({
  required BuildContext context,
  required String schoolId,
  required SchoolLogoStyle style,
  required VoidCallback onSaved,
  void Function(Uint8List bytes)? onPreviewBytes,
  void Function(String message)? onError,
}) async {
  final logos = SchoolLogoService.instance;
  final picked = await logos.pickLogoXFile();
  if (picked == null) {
    onError?.call(logos.lastError ?? 'Logo selection cancelled.');
    return;
  }
  final raw = await picked.readAsBytes();
  final normalized = await logos.normalizeToBytes(raw, style);
  if (normalized == null) {
    onError?.call(logos.lastError ?? 'Could not process that image.');
    return;
  }
  onPreviewBytes?.call(normalized);
  final saved = await logos.saveLogoBytes(
    schoolId,
    normalized,
    style: style,
  );
  if (saved == null) {
    onError?.call(logos.lastError ?? 'Could not save logo.');
    return;
  }
  final remoteUrl = await logos.uploadToServer(
    schoolId: schoolId,
    localPath: saved,
    bytes: normalized,
  );
  await SchoolRegistryService.instance.setSchoolLogo(
    schoolId,
    localPath: saved,
    remoteUrl: remoteUrl,
    style: style,
  );
  if (context.mounted) onSaved();
}

/// Hidden owner console — only reachable via secret gesture on login. Not a user role.
class PlatformConsoleScreen extends StatefulWidget {
  const PlatformConsoleScreen({super.key});

  @override
  State<PlatformConsoleScreen> createState() => _PlatformConsoleScreenState();
}

class _PlatformConsoleScreenState extends State<PlatformConsoleScreen> {
  final _registry = SchoolRegistryService.instance;
  List<SchoolRecord> _schools = [];
  String _filter = '';
  _SchoolListFilter _listFilter = _SchoolListFilter.all;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _registry.load();
    // Cloud is source of truth for the owner console on every device/browser.
    await PlatformSchoolsCloudService.instance.syncAllSchoolsFromCloud();
    await PlatformAuditLogService.instance.load();
    await SchoolAdminCredentialsService.instance.backfillMissingCredentials();
    await PlatformExpiryAlertService.instance.checkAndNotifyOwner();
    _refresh();
  }

  Future<void> _reloadFromCloud() async {
    final n = await PlatformSchoolsCloudService.instance.syncAllSchoolsFromCloud();
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n > 0
              ? 'Loaded $n school(s) from cloud.'
              : 'No schools found in cloud yet. Create one, or check your connection.',
        ),
      ),
    );
  }

  void _refresh() {
    setState(() {
      _schools = _registry.getAllSchools();
    });
  }

  List<SchoolRecord> get _visible {
    final q = _filter.trim().toLowerCase();
    Iterable<SchoolRecord> list = _schools;
    if (q.isNotEmpty) {
      list = list.where(
        (s) =>
            s.id.toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q) ||
            (s.city ?? '').toLowerCase().contains(q) ||
            (s.address ?? '').toLowerCase().contains(q) ||
            (s.adminContactPhone ?? '').contains(q),
      );
    }
    return list.where((s) {
      final insight = SchoolPlatformInsight.forSchool(s);
      return switch (_listFilter) {
        _SchoolListFilter.all => true,
        _SchoolListFilter.active => s.isAccessible,
        _SchoolListFilter.expiring => insight.expiryWarning || insight.isExpired,
        _SchoolListFilter.blocked => !s.isAccessible,
        _SchoolListFilter.attention => insight.health == SchoolHealthStatus.needsAttention,
      };
    }).toList();
  }

  Future<void> _openCreateSchool() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _PlatformCreateSchoolPage()),
    );
    if (created == true) _refresh();
  }

  Future<void> _changePin() => showPlatformChangePinFlow(context);

  Future<void> _exportJson() async {
    try {
      await PlatformBackupService.instance.shareJsonBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Backup ready to share'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Export failed'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    try {
      await PlatformBackupService.instance.shareCsvBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('CSV export ready to share'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Export failed'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _openAuditLog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlatformAuditLogScreen()),
    );
  }

  void _openBulkSms() {
    final List<SchoolRecord> schools;
    if (_listFilter == _SchoolListFilter.expiring && _visible.isNotEmpty) {
      schools = _visible;
    } else {
      schools = PlatformExpiryAlertService.instance
          .expiringSchools()
          .map((a) => SchoolRegistryService.instance.lookup(a.schoolId))
          .whereType<SchoolRecord>()
          .toList();
    }
    if (schools.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expiring schools found')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlatformBulkSmsScreen(initialSchools: schools),
      ),
    );
  }

  Widget _expiryAlertBanner() {
    final alerts = PlatformExpiryAlertService.instance.urgentAlerts;
    if (alerts.isEmpty) return const SizedBox.shrink();

    final expired = alerts.where((a) => a.isExpired).length;
    final soon = alerts.where((a) => !a.isExpired).length;
    final summary = [
      if (expired > 0) '$expired expired',
      if (soon > 0) '$soon expiring within 7 days',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.deepOrange.shade900.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _listFilter = _SchoolListFilter.expiring),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subscription alert',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        summary,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Bulk SMS',
                  onPressed: _openBulkSms,
                  icon: const Icon(Icons.sms_outlined, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _schools.where((s) => s.isAccessible).length;
    final blocked = _schools.length - active;
    final metrics = SchoolEnrollmentMetricsService.instance;
    final totalStudents = metrics.platformBillableStudentTotal();
    final estRevenue = metrics.estimatedPlatformMonthlyRevenueEtb();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Maya Platform'),
        actions: [
          IconButton(
            tooltip: 'Refresh schools from cloud',
            onPressed: _reloadFromCloud,
            icon: const Icon(Icons.cloud_download_outlined),
          ),
          IconButton(
            tooltip: MayaAssistantService.titleForRole(
              MayaAssistantService.rolePlatformOwner,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MayaAssistantScreen(
                    roleKey: MayaAssistantService.rolePlatformOwner,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'export_json':
                  await _exportJson();
                case 'export_csv':
                  await _exportCsv();
                case 'audit':
                  _openAuditLog();
                case 'bulk_sms':
                  _openBulkSms();
                case 'reload_cloud':
                  await _reloadFromCloud();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'reload_cloud', child: Text('Reload schools from cloud')),
              PopupMenuItem(value: 'export_json', child: Text('Export backup (JSON)')),
              PopupMenuItem(value: 'export_csv', child: Text('Export schools (CSV)')),
              PopupMenuItem(value: 'audit', child: Text('Audit log')),
              PopupMenuItem(value: 'bulk_sms', child: Text('Bulk SMS · expiring')),
            ],
          ),
          IconButton(
            tooltip: 'Change PIN',
            onPressed: _changePin,
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSchool,
        icon: const Icon(Icons.add_business),
        label: const Text('New school'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statChip('$active active', Colors.green),
                _statChip('$blocked blocked', Colors.orange),
                _statChip('${_schools.length} schools', Colors.blueGrey),
                _statChip(
                  '${SchoolEnrollmentMetricsService.formatCount(totalStudents)} students',
                  Colors.lightBlueAccent,
                ),
                _statChip('~$estRevenue ETB/mo', Colors.tealAccent),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _filter = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name, city, or School ID',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          _schoolErpBusBanner(),
          _expiryAlertBanner(),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('All', _SchoolListFilter.all),
                _filterChip('Active', _SchoolListFilter.active),
                _filterChip('Expiring', _SchoolListFilter.expiring),
                _filterChip('Blocked', _SchoolListFilter.blocked),
                _filterChip('Needs attention', _SchoolListFilter.attention),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _visible.isEmpty
                ? const Center(
                    child: Text(
                      'No schools yet.\nTap "New school" to onboard a customer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: listPagePadding(context, bottom: 88),
                    itemCount: _visible.length,
                    itemBuilder: (context, index) {
                      final school = _visible[index];
                      return _SchoolTile(
                        school: school,
                        onChanged: _refresh,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _schoolErpBusBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14532D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.lightGreenAccent.withValues(alpha: 0.45)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.directions_bus, color: Colors.lightGreenAccent),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Register Driver and Live GPS are not in this Owner console.\n'
              'Sign out, choose Admin, then enter School ID + admin phone + password. '
              'SCHOOL BUS is at the top of the left menu.',
              style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _filterChip(String label, _SchoolListFilter value) {
    final selected = _listFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _listFilter = value),
        selectedColor: Colors.lightBlueAccent.withValues(alpha: 0.25),
        checkmarkColor: Colors.lightBlueAccent,
        labelStyle: TextStyle(
          color: selected ? Colors.lightBlueAccent : Colors.white70,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        backgroundColor: const Color(0xFF1E293B),
        side: BorderSide(
          color: selected ? Colors.lightBlueAccent.withValues(alpha: 0.5) : Colors.white24,
        ),
      ),
    );
  }
}

class _SchoolTile extends StatefulWidget {
  const _SchoolTile({required this.school, required this.onChanged});

  final SchoolRecord school;
  final VoidCallback onChanged;

  @override
  State<_SchoolTile> createState() => _SchoolTileState();
}

class _SchoolTileState extends State<_SchoolTile> {
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  @override
  void didUpdateWidget(_SchoolTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.school.id != widget.school.id ||
        oldWidget.school.logoPath != widget.school.logoPath) {
      _loadLogo();
    }
  }

  Future<void> _loadLogo() async {
    final path = await SchoolLogoService.instance.resolvedLogoPath(
      widget.school.id,
      storedPath: widget.school.logoPath,
    );
    if (mounted) setState(() => _logoPath = path);
  }

  SchoolRecord get school => widget.school;

  Color get _statusColor {
    if (school.isAccessible) return Colors.green;
    return switch (school.accessBlock) {
      SchoolAccessBlock.suspended => Colors.orange,
      SchoolAccessBlock.expired => Colors.deepOrange,
      SchoolAccessBlock.inactive => Colors.red,
      SchoolAccessBlock.notFound => Colors.grey,
      null => Colors.green,
    };
  }

  String get _statusLabel {
    if (school.isAccessible) return 'Active';
    return switch (school.accessBlock) {
      SchoolAccessBlock.suspended => 'Suspended',
      SchoolAccessBlock.expired => 'Expired',
      SchoolAccessBlock.inactive => 'Deactivated',
      SchoolAccessBlock.notFound => 'Unknown',
      null => 'Active',
    };
  }

  @override
  Widget build(BuildContext context) {
    final expiry = school.subscriptionExpiresAt;
    final expiryText = expiry == null
        ? 'No expiry set'
        : 'Renews / expires ${expiry.day}/${expiry.month}/${expiry.year}';
    final metrics = SchoolEnrollmentMetricsService.instance.forSchool(school.id);
    final enrolledLabel =
        '${SchoolEnrollmentMetricsService.formatCount(metrics.billableStudents)} enrolled';
    final creds = SchoolAdminCredentialsService.instance;
    final adminLogin = creds.adminLoginForSchool(school);
    final passwordLabel = creds.passwordLabel(school);
    final adminName = creds.adminNameForSchool(school);
    final insight = SchoolPlatformInsight.forSchool(school);
    final fmt = SchoolEnrollmentMetricsService.formatCount;

    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () async {
              final deleted = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => _PlatformSchoolDetailPage(schoolId: school.id),
                ),
              );
              widget.onChanged();
              _loadLogo();
              if (deleted == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${school.name} deleted'),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _logoThumb(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                school.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _statusLabel,
                                style: TextStyle(
                                  color: _statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${school.id} · ${school.city ?? '—'}',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        if (school.address != null && school.address!.isNotEmpty)
                          Text(
                            school.address!,
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 6),
                        SchoolOnboardingChecklistCard(school: school, compact: true),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.lightBlueAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.lightBlueAccent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.groups,
                                size: 14,
                                color: Colors.lightBlueAccent.shade100,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$enrolledLabel · billable',
                                style: TextStyle(
                                  color: Colors.lightBlueAccent.shade100,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(expiryText, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _miniChip(
                              insight.healthLabel,
                              insight.healthColor,
                            ),
                            _miniChip(
                              '~${fmt(insight.metrics.estimatedMonthlyBillEtb)} ETB/mo',
                              Colors.tealAccent,
                            ),
                            if (insight.daysUntilExpiry != null)
                              _miniChip(
                                insight.expirySummary,
                                insight.expiryWarning ? Colors.deepOrange : Colors.white54,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _adminCredentialsStrip(
                          login: adminLogin,
                          passwordLabel: passwordLabel,
                          adminName: adminName,
                          hasPassword: creds.schoolHasPassword(school),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: creds.credentialsClipboardText(school)),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Login details copied'),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy login'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: creds.adminPhoneForSchool(school) != null
                        ? () => showSendSchoolAdminCredentials(context, school)
                        : null,
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text('Send to admin'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amberAccent.shade100,
                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _adminCredentialsStrip({
    required String login,
    required String passwordLabel,
    String? adminName,
    required bool hasPassword,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (adminName != null && adminName.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.badge_outlined, size: 14, color: Colors.amber.shade200),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    adminName,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.amber.shade200),
              const SizedBox(width: 4),
              Text('Login: ', style: TextStyle(color: Colors.amber.shade200, fontSize: 11)),
              Expanded(
                child: Text(
                  login,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.key_outlined, size: 14, color: Colors.amber.shade200),
              const SizedBox(width: 4),
              Text('Temp password: ', style: TextStyle(color: Colors.amber.shade200, fontSize: 11)),
              Text(
                passwordLabel,
                style: TextStyle(
                  color: hasPassword ? Colors.amberAccent.shade100 : Colors.orangeAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: hasPassword ? 0.3 : 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _logoThumb() {
    return SizedBox(
      width: 56,
      height: 56,
      child: SchoolLogoDisplay(
        imagePath: _logoPath,
        networkUrl: school.logoUrl,
        style: school.logoStyle,
        height: 56,
        width: 56,
      ),
    );
  }
}

class _PlatformSchoolDetailPage extends StatefulWidget {
  const _PlatformSchoolDetailPage({required this.schoolId});

  final String schoolId;

  @override
  State<_PlatformSchoolDetailPage> createState() => _PlatformSchoolDetailPageState();
}

class _PlatformSchoolDetailPageState extends State<_PlatformSchoolDetailPage> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _officePhone = TextEditingController();
  final _notes = TextEditingController();
  final _contractedSeats = TextEditingController();
  final _ratePerStudent = TextEditingController();
  final _minimumMonthly = TextEditingController();
  final _adminTempPassword = TextEditingController();
  final Set<String> _selectedGrades = {};

  SchoolRecord? _school;
  String? _logoPath;
  Uint8List? _logoBytes;
  String _snapshot = '';
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _name,
      _city,
      _address,
      _officePhone,
      _notes,
      _contractedSeats,
      _ratePerStudent,
      _minimumMonthly,
      _adminTempPassword,
    ]) {
      c.addListener(_onFormChanged);
    }
    _load();
  }

  void _onFormChanged() {
    if (_editing) setState(() {});
  }

  String _formSnapshot() => [
        _name.text,
        _city.text,
        _address.text,
        _officePhone.text,
        _notes.text,
        _contractedSeats.text,
        _ratePerStudent.text,
        _minimumMonthly.text,
        _adminTempPassword.text,
        SchoolGradeCatalog.all.where(_selectedGrades.contains).join('|'),
      ].join('|');

  bool get _isDirty => _school != null && _formSnapshot() != _snapshot;

  Future<void> _loadLogo() async {
    final path = await SchoolLogoService.instance.resolvedLogoPath(
      widget.schoolId,
      storedPath: _school?.logoPath,
    );
    if (mounted) setState(() => _logoPath = path);
  }

  void _load() {
    final record = SchoolRegistryService.instance.lookup(widget.schoolId);
    _school = record;
    if (record != null) {
      _name.text = record.name;
      _city.text = record.city ?? '';
      _address.text = record.address ?? '';
      _officePhone.text = record.officePhone ?? '';
      _notes.text = record.notes ?? '';
      _contractedSeats.text = record.contractedSeats?.toString() ?? '';
      _ratePerStudent.text =
          (record.ratePerStudentMonthEtb ?? SchoolEnrollmentMetrics.defaultEtbPerStudentMonth)
              .toString();
      _minimumMonthly.text =
          (record.minimumMonthlyEtb ?? SchoolEnrollmentMetrics.defaultMinimumMonthlyEtb).toString();
      _adminTempPassword.text = record.adminInitialPassword ??
          SchoolAdminCredentialsService.instance.passwordForSchool(record) ??
          '';
      _selectedGrades
        ..clear()
        ..addAll(record.gradeLevels);
      _snapshot = _formSnapshot();
    }
    setState(() {});
    _loadLogo();
  }

  void _startEdit() => setState(() => _editing = true);

  Future<void> _cancelEdit() async {
    if (_isDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Unsaved edits will be lost.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    _load();
    setState(() => _editing = false);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _city,
      _address,
      _officePhone,
      _notes,
      _contractedSeats,
      _ratePerStudent,
      _minimumMonthly,
      _adminTempPassword,
    ]) {
      c
        ..removeListener(_onFormChanged)
        ..dispose();
    }
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final school = _school;
    if (school == null || !_editing) return;
    if (_name.text.trim().isEmpty) {
      _toast('School name is required', isError: true);
      return;
    }

    final seatsRaw = _contractedSeats.text.trim();
    if (seatsRaw.isNotEmpty && int.tryParse(seatsRaw) == null) {
      _toast('Contracted seats must be a number', isError: true);
      return;
    }

    final rateRaw = _ratePerStudent.text.trim();
    final rate = int.tryParse(rateRaw);
    if (rateRaw.isEmpty || rate == null || rate < 1) {
      _toast('Rate per student must be at least 1 ETB', isError: true);
      return;
    }

    final minRaw = _minimumMonthly.text.trim();
    final minBill = int.tryParse(minRaw);
    if (minRaw.isEmpty || minBill == null || minBill < 0) {
      _toast('Minimum monthly bill must be 0 or more ETB', isError: true);
      return;
    }

    final tempPwd = _adminTempPassword.text.trim();
    if (tempPwd.isNotEmpty) {
      AuthService.updateAdminPasswordForSchool(school.id, tempPwd);
    }

    final grades = SchoolGradeCatalog.all
        .where(_selectedGrades.contains)
        .toList();
    if (grades.isEmpty) {
      _toast('Select at least one grade level', isError: true);
      return;
    }

    final toSave = school.copyWith(
      name: _name.text.trim(),
      city: _city.text.trim().isEmpty ? null : _city.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      officePhone:
          _officePhone.text.trim().isEmpty ? null : _officePhone.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      contractedSeats: seatsRaw.isEmpty ? null : int.parse(seatsRaw),
      ratePerStudentMonthEtb: rate,
      minimumMonthlyEtb: minBill,
      adminInitialPassword:
          tempPwd.isNotEmpty ? tempPwd : school.adminInitialPassword,
      gradeLevels: grades,
    );

    final cloud = await SchoolRegistryService.instance.updateSchool(
      toSave,
      preferPlatformCloud: true,
      adminPassword: tempPwd.isNotEmpty ? tempPwd : null,
    );
    if (!cloud.ok) {
      _toast(
        cloud.errorMessage?.trim().isNotEmpty == true
            ? cloud.errorMessage!
            : 'Saved on this device only — cloud update failed '
                '(${cloud.errorCode ?? 'error'}). Check internet / owner PIN.',
        isError: true,
      );
      return;
    }
    _school = toSave;
    _snapshot = _formSnapshot();
    setState(() => _editing = false);
    _toast('Profile saved to cloud');
  }

  Future<void> _setStatus(SchoolLifecycleStatus status) async {
    final cloud = await SchoolRegistryService.instance.setStatus(
      widget.schoolId,
      status,
      preferPlatformCloud: true,
    );
    _load();
    if (!cloud.ok) {
      _toast(
        cloud.errorMessage ?? 'Status updated locally; cloud sync failed.',
        isError: true,
      );
      return;
    }
    _toast(status == SchoolLifecycleStatus.active ? 'School activated' : 'School updated');
  }

  Future<void> _pickExpiry() async {
    final school = _school;
    if (school == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: school.subscriptionExpiresAt ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    final cloud = await SchoolRegistryService.instance.setSubscriptionExpiry(
      widget.schoolId,
      picked,
      preferPlatformCloud: true,
    );
    _load();
    if (!cloud.ok) {
      _toast(
        cloud.errorMessage ?? 'Date updated locally; cloud sync failed.',
        isError: true,
      );
      return;
    }
    _toast('Subscription date updated');
  }

  Future<void> _renewQuick(int days) async {
    final cloud = await SchoolRegistryService.instance.renewSubscription(
      widget.schoolId,
      days: days,
      preferPlatformCloud: true,
    );
    _load();
    if (!cloud.ok) {
      _toast(
        cloud.errorMessage ?? 'Renewed locally; cloud sync failed.',
        isError: true,
      );
      return;
    }
    _toast('Renewed +$days days');
  }

  Future<void> _changeLogo(SchoolLogoStyle style) async {
    if (!_editing) return;
    await _saveSchoolLogoFromPicker(
      context: context,
      schoolId: widget.schoolId,
      style: style,
      onPreviewBytes: (bytes) {
        if (mounted) setState(() => _logoBytes = bytes);
      },
      onSaved: () {
        _load();
        _toast('School logo updated (${style.label})');
      },
      onError: (message) {
        if (message.contains('cancelled')) return;
        _toast(message);
      },
    );
  }

  Future<void> _removeLogo() async {
    if (!_editing) return;
    if (_logoPath == null &&
        _logoBytes == null &&
        (_school?.logoPath == null || _school!.logoPath!.isEmpty)) {
      _toast('No logo to remove');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove logo?'),
        content: const Text('The school logo will be removed from this account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove logo'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await SchoolRegistryService.instance.clearSchoolLogo(widget.schoolId);
    if (mounted) setState(() => _logoBytes = null);
    _load();
    _toast('Logo removed');
  }

  Future<void> _removeSchool() async {
    if (!_editing) return;
    final school = _school;
    if (school == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete school?'),
        content: Text(
          'Are you sure you want to delete "${school.name}" (${school.id})?\n\n'
          'All users will lose access. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final pinOk = await verifyOwnerPinPrompt(
      context,
      title: 'Confirm deletion',
      message: 'Enter your owner PIN to permanently delete this school.',
    );
    if (!pinOk || !mounted) return;

    await SchoolRegistryService.instance.removeSchool(widget.schoolId);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _openStudentList() async {
    final school = _school;
    if (school == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PlatformSchoolStudentsPage(
          schoolId: widget.schoolId,
          schoolName: school.name,
        ),
      ),
    );
    _load();
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Color _statusColor(SchoolRecord school) {
    if (school.status == SchoolLifecycleStatus.suspended) return Colors.orange;
    if (school.status == SchoolLifecycleStatus.inactive) return Colors.red;
    if (school.accessBlock == SchoolAccessBlock.expired) return Colors.deepOrange;
    if (school.isAccessible) return Colors.green;
    return Colors.red;
  }

  String _statusLabel(SchoolRecord school) {
    if (school.status == SchoolLifecycleStatus.suspended) return 'Suspended';
    if (school.status == SchoolLifecycleStatus.inactive) return 'Deactivated';
    if (school.accessBlock == SchoolAccessBlock.expired) return 'Expired';
    if (school.isAccessible) return 'Active';
    return 'Blocked';
  }

  Widget _statusBadge(SchoolRecord school) {
    final color = _statusColor(school);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _statusLabel(school),
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _profileHeader(SchoolRecord school) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A).withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(
              school.logoStyle == SchoolLogoStyle.circular ? 999 : 12,
            ),
            child: SchoolLogoDisplay(
              imagePath: _logoPath,
              imageBytes: _logoBytes,
              networkUrl: school.logoUrl,
              style: school.logoStyle,
              height: 72,
              width: 72,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  school.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${school.id} · ${school.city ?? '—'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 10),
                _statusBadge(school),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: rows),
    );
  }

  List<Widget> _joinedProfileRows(List<Widget> rows) {
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        out.add(Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)));
      }
      out.add(rows[i]);
    }
    return out;
  }

  Widget _profileRow(
    String label,
    String value, {
    Color? valueColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.35),
            ),
          ),
          Expanded(
            child: trailing ??
                Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                    color: valueColor ?? Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _adminErpHintCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14532D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.lightGreenAccent.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'Use these Admin login details on the SIGN IN page (role: Admin) '
        'to open the school ERP. Register Driver and Live GPS are in that ERP, '
        'not in this Owner console.',
        style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
      ),
    );
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildViewProfile(SchoolRecord school, DateTime? expiry, SchoolEnrollmentMetrics metrics) {
    final rate = school.ratePerStudentMonthEtb ?? SchoolEnrollmentMetrics.defaultEtbPerStudentMonth;
    final minBill = school.minimumMonthlyEtb ?? SchoolEnrollmentMetrics.defaultMinimumMonthlyEtb;
    final seats = school.contractedSeats;
    final notes = school.notes?.trim();
    final creds = SchoolAdminCredentialsService.instance;
    final adminLogin = creds.adminLoginForSchool(school);
    final passwordLabel = creds.passwordLabel(school);
    final adminName = creds.adminNameForSchool(school);
    final adminPhone = creds.adminPhoneForSchool(school);
    final insight = SchoolPlatformInsight.forSchool(school);
    final fmt = SchoolEnrollmentMetricsService.formatCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _profileHeader(school),
        const SizedBox(height: 16),
        _ownerInsightCard(insight, fmt),
        const SizedBox(height: 16),
        SchoolOnboardingChecklistCard(school: school),
        const SizedBox(height: 16),
        _sectionTitle('Admin access'),
        _adminErpHintCard(),
        const SizedBox(height: 10),
        _infoCard(_joinedProfileRows([
          if (adminName != null && adminName.isNotEmpty)
            _profileRow('Admin name', adminName),
          _profileRow('Admin login', adminLogin),
          _profileRow(
            'Temp password',
            passwordLabel,
            valueColor: creds.schoolHasPassword(school)
                ? Colors.amberAccent.shade100
                : Colors.orangeAccent,
          ),
        ])),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: creds.credentialsClipboardText(school)));
                _toast('Login details copied');
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy login'),
            ),
            FilledButton.icon(
              onPressed: adminPhone != null
                  ? () => showSendSchoolAdminCredentials(context, school)
                  : null,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Send to admin'),
              style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade800),
            ),
            if (adminPhone != null)
              OutlinedButton.icon(
                onPressed: () => _callAdmin(adminPhone),
                icon: const Icon(Icons.phone_outlined),
                label: const Text('Call admin'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _sectionTitle('School details'),
        _infoCard(_joinedProfileRows([
          _profileRow('School name', school.name),
          _profileRow('School ID', school.id),
          _profileRow('City', school.city ?? '—'),
          _profileRow('Address', school.address ?? '—'),
          _profileRow('Office phone', school.officePhone ?? '—'),
          _profileRow(
            'Registered',
            school.registeredAt == null
                ? '—'
                : '${school.registeredAt!.day}/${school.registeredAt!.month}/${school.registeredAt!.year}',
          ),
          _profileRow('Academic year', school.academicYear ?? '—'),
          _profileRow(
            'Grades',
            school.gradeLevels.isEmpty
                ? '—'
                : school.gradeLevels.join(', '),
          ),
          _profileRow('Sections', AppLocale.instance.strings.sectionsManagedByAdmin),
          _profileRow(
            'Subscription',
            expiry == null
                ? 'Open (no end date)'
                : '${expiry.day}/${expiry.month}/${expiry.year}',
          ),
          _profileRow('Status', '', trailing: _statusBadge(school)),
        ])),
        const SizedBox(height: 16),
        _sectionTitle('Billing terms'),
        _infoCard(_joinedProfileRows([
          _profileRow('Rate / student / mo', '$rate ETB'),
          _profileRow('Minimum monthly', '$minBill ETB'),
          _profileRow(
            'Contracted seats',
            seats == null ? 'No cap set' : '$seats seats',
          ),
        ])),
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle('Support notes', subtitle: 'Private — platform owner only'),
          _infoCard([
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                notes,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.45),
              ),
            ),
          ]),
        ],
        const SizedBox(height: 16),
        _billingCard(metrics),
        const SizedBox(height: 14),
        Text(
          'Tap Edit profile to update details, logo, access, or billing.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
        ),
      ],
    );
  }

  Future<void> _callAdmin(String phone) async {
    final normalized = PhoneUtils.smsUriPhone(phone);
    if (normalized.isEmpty) {
      _toast('Invalid admin phone', isError: true);
      return;
    }
    final uri = Uri(scheme: 'tel', path: normalized);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast('Could not open phone app', isError: true);
    }
  }

  Widget _ownerInsightCard(SchoolPlatformInsight insight, String Function(int) fmt) {
    final m = insight.metrics;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: insight.healthColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: insight.healthColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Owner snapshot',
                style: TextStyle(
                  color: insight.healthColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: insight.healthColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  insight.healthLabel,
                  style: TextStyle(color: insight.healthColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _insightStat('Students', fmt(m.billableStudents)),
              _insightStat('Est. bill', '${fmt(m.estimatedMonthlyBillEtb)} ETB'),
              _insightStat('Teachers', '${m.teachers}'),
              _insightStat('Staff total', '${m.totalStaff}'),
              _insightStat('Subscription', insight.expirySummary),
            ],
          ),
          if (insight.alerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Alerts', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 6),
            ...insight.alerts.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade300),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(a, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _insightStat(String label, String value) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildEditProfile(SchoolRecord school) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Editing profile', subtitle: 'Save when finished'),
        _infoCard([
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Column(
              children: [
                _editField('School name', _name),
                _editField('City', _city),
                SchoolGradeLevelPicker(
                  selected: _selectedGrades,
                  enabled: _editing,
                  onChanged: (next) => setState(() {
                    _selectedGrades
                      ..clear()
                      ..addAll(next);
                  }),
                ),
                const SizedBox(height: 8),
                _editField('Address', _address, maxLines: 2),
                _editField('Office phone', _officePhone, keyboard: TextInputType.phone),
                _editField(
                  'Rate per student / month (ETB)',
                  _ratePerStudent,
                  keyboard: TextInputType.number,
                ),
                _editField(
                  'Minimum monthly bill (ETB)',
                  _minimumMonthly,
                  keyboard: TextInputType.number,
                ),
                _editField(
                  'Contracted student seats',
                  _contractedSeats,
                  keyboard: TextInputType.number,
                  hint: 'Optional — leave empty for no cap',
                ),
                _editField(
                  'Admin temp password',
                  _adminTempPassword,
                  hint: 'Saved for owner reference & admin login',
                ),
                _editField('Support notes', _notes, maxLines: 4),
              ],
            ),
          ),
        ]),
        if (_isDirty) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.save),
              label: const Text('Save profile'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _sectionTitle('School logo'),
        if (_logoPath != null ||
            _logoBytes != null ||
            (school.logoPath != null && school.logoPath!.isNotEmpty)) ...[
          Center(
            child: SchoolLogoDisplay(
              imagePath: _logoPath,
              imageBytes: _logoBytes,
              networkUrl: school.logoUrl,
              style: school.logoStyle,
              height: school.logoStyle == SchoolLogoStyle.circular ? 100 : 90,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Shape: ${school.logoStyle.label}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _changeLogo(SchoolLogoStyle.rectangular),
              icon: const Icon(Icons.crop_landscape_outlined),
              label: const Text('Rectangular banner'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            ),
            OutlinedButton.icon(
              onPressed: () => _changeLogo(SchoolLogoStyle.circular),
              icon: const Icon(Icons.circle_outlined),
              label: const Text('Circular logo'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            ),
            if (_logoPath != null ||
                _logoBytes != null ||
                (school.logoPath != null && school.logoPath!.isNotEmpty))
              OutlinedButton.icon(
                onPressed: _removeLogo,
                icon: const Icon(Icons.delete_outline, color: Colors.orange),
                label: const Text('Remove logo', style: TextStyle(color: Colors.orange)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle('Access control'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!school.isAccessible || school.status != SchoolLifecycleStatus.active)
              FilledButton.icon(
                onPressed: () => _setStatus(SchoolLifecycleStatus.active),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Activate'),
              ),
            if (school.status == SchoolLifecycleStatus.active)
              OutlinedButton.icon(
                onPressed: () => _setStatus(SchoolLifecycleStatus.inactive),
                icon: const Icon(Icons.block),
                label: const Text('Deactivate'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            OutlinedButton.icon(
              onPressed: () => _setStatus(SchoolLifecycleStatus.suspended),
              icon: const Icon(Icons.pause_circle_outline),
              label: const Text('Suspend'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle('Subscription renewal'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(onPressed: () => _renewQuick(30), child: const Text('+30 days')),
            OutlinedButton(onPressed: () => _renewQuick(90), child: const Text('+90 days')),
            OutlinedButton(onPressed: () => _renewQuick(365), child: const Text('+1 year')),
            OutlinedButton(onPressed: _pickExpiry, child: const Text('Pick date')),
            TextButton(
              onPressed: () async {
                final cloud =
                    await SchoolRegistryService.instance.setSubscriptionExpiry(
                  widget.schoolId,
                  null,
                  preferPlatformCloud: true,
                );
                _load();
                if (!cloud.ok) {
                  _toast(
                    cloud.errorMessage ??
                        'Cleared locally; cloud sync failed.',
                    isError: true,
                  );
                  return;
                }
                _toast('Expiry cleared');
              },
              child: const Text('Clear expiry'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _removeSchool,
          icon: const Icon(Icons.delete_forever, color: Colors.red),
          label: const Text('Delete school permanently', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _editField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboard,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white54),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.lightBlueAccent.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final school = _school;
    if (school == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('School')),
        body: const Center(child: Text('School not found')),
      );
    }

    final expiry = school.subscriptionExpiresAt;
    final metrics = SchoolEnrollmentMetricsService.instance.forSchool(school.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(school.name),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          if (!_editing)
            TextButton.icon(
              onPressed: _startEdit,
              icon: const Icon(Icons.edit_outlined, color: Colors.white70),
              label: const Text('Edit profile', style: TextStyle(color: Colors.white70)),
            )
          else ...[
            TextButton(
              onPressed: _cancelEdit,
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.save, color: Colors.lightGreenAccent),
              label: const Text(
                'Save',
                style: TextStyle(color: Colors.lightGreenAccent, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: ListView(
        padding: listPagePadding(context, top: 16, bottom: 24),
        children: [
          if (_editing)
            _buildEditProfile(school)
          else
            _buildViewProfile(school, expiry, metrics),
        ],
      ),
    );
  }

  Widget _billingCard(SchoolEnrollmentMetrics metrics) {
    final fmt = SchoolEnrollmentMetricsService.formatCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.shade900.withValues(alpha: 0.9),
            const Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enrollment & billing',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            '${fmt(metrics.billableStudents)} students enrolled',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Billable active students · ${metrics.billingTierLabel}',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          if (metrics.inactiveStudents > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${fmt(metrics.inactiveStudents)} inactive (not billed)',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          if (metrics.hasSeatOverage)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Over contracted seats by ${fmt(metrics.seatOverage)}',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Est. monthly: ${fmt(metrics.estimatedMonthlyBillEtb)} ETB',
            style: TextStyle(
              color: Colors.tealAccent.shade100,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${metrics.ratePerStudentMonthEtb} ETB × active students (min ${metrics.minimumMonthlyEtb} ETB)',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Text(
            'Staff (not billed): ${metrics.teachers} teachers · '
            '${metrics.admins} admins · ${metrics.drivers} transport',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (metrics.gradeBreakdown.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: metrics.gradeBreakdown.entries.map((e) {
                return Chip(
                  label: Text('${e.key}: ${e.value}'),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _openStudentList,
                icon: const Icon(Icons.list_alt),
                label: const Text('View enrolled students'),
              ),
            ],
          ),
          if (metrics.contractedSeats != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Contract: ${fmt(metrics.contractedSeats!)} seats',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlatformCreateSchoolPage extends StatefulWidget {
  const _PlatformCreateSchoolPage();

  @override
  State<_PlatformCreateSchoolPage> createState() => _PlatformCreateSchoolPageState();
}

class _PlatformCreateSchoolPageState extends State<_PlatformCreateSchoolPage> {
  final _schoolName = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _officePhone = TextEditingController();
  final _academicYear = TextEditingController(text: '2025/2026');
  final _adminName = TextEditingController();
  final _adminPhone = TextEditingController();
  final _password = TextEditingController(text: AuthService.tempPassword);
  final _notes = TextEditingController();
  final _ratePerStudent = TextEditingController(text: '8');
  final _minimumMonthly = TextEditingController(text: '500');
  final Set<String> _selectedGrades = {
    'Grade 1',
    'Grade 2',
    'Grade 3',
  };
  int _renewDays = 365;
  String _message = '';
  String? _pendingLogoPath;
  Uint8List? _pendingLogoBytes;
  SchoolLogoStyle _pendingLogoStyle = SchoolLogoStyle.rectangular;
  bool _showPassword = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(_onCredentialsChanged);
    _adminPhone.addListener(_onCredentialsChanged);
  }

  void _onCredentialsChanged() => setState(() {});

  @override
  void dispose() {
    _password.removeListener(_onCredentialsChanged);
    _adminPhone.removeListener(_onCredentialsChanged);
    _schoolName.dispose();
    _city.dispose();
    _address.dispose();
    _officePhone.dispose();
    _academicYear.dispose();
    _adminName.dispose();
    _adminPhone.dispose();
    _password.dispose();
    _notes.dispose();
    _ratePerStudent.dispose();
    _minimumMonthly.dispose();
    super.dispose();
  }

  Future<void> _pickLogo(SchoolLogoStyle style) async {
    final logos = SchoolLogoService.instance;
    final picked = await logos.pickLogoXFile();
    if (picked == null) {
      final err = logos.lastError;
      if (err != null && !err.contains('cancelled') && !err.contains('No image')) {
        setState(() => _message = err);
      }
      return;
    }
    final raw = await picked.readAsBytes();
    final preview = await logos.normalizeToBytes(raw, style);
    if (preview == null) {
      if (mounted) {
        setState(() => _message = logos.lastError ?? 'Could not process image.');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _pendingLogoBytes = preview;
      _pendingLogoPath = null;
      _pendingLogoStyle = style;
      _message = '';
    });
  }

  Future<void> _create() async {
    if (_creating) return;
    setState(() {
      _message = '';
      _creating = true;
    });
    try {
      if (_schoolName.text.trim().isEmpty ||
          _adminName.text.trim().isEmpty ||
          _adminPhone.text.trim().isEmpty) {
        setState(() => _message = 'Fill school name, admin name, and phone.');
        return;
      }
      if (_password.text.length < AuthService.minPasswordLength) {
        setState(
          () => _message =
              'Password must be at least ${AuthService.minPasswordLength} characters.',
        );
        return;
      }

      final rate = int.tryParse(_ratePerStudent.text.trim());
      if (rate == null || rate < 1) {
        setState(() => _message = 'Rate per student must be at least 1 ETB.');
        return;
      }
      final minBill = int.tryParse(_minimumMonthly.text.trim());
      if (minBill == null || minBill < 0) {
        setState(() => _message = 'Minimum monthly bill must be 0 or more ETB.');
        return;
      }

      if (!PhoneUtils.isValidLoginPhone(_adminPhone.text.trim())) {
        setState(
          () => _message =
              'Admin phone must be a valid Ethiopian mobile (e.g. 09xxxxxxxx).',
        );
        return;
      }

      if (_selectedGrades.isEmpty) {
        setState(() => _message = 'Select at least one grade level.');
        return;
      }

      await PlatformOwnerService.instance.syncPinWithCloud();
      if (PlatformOwnerService.instance.sessionOwnerPin == null ||
          PlatformOwnerService.instance.sessionOwnerPin!.trim().length <
              PlatformOwnerService.minPinLength) {
        setState(
          () => _message =
              'Unlock the platform console with your Owner PIN, then try again.',
        );
        return;
      }

      final setup = SchoolSetup(
        academicYear: _academicYear.text.trim(),
        gradeLevels: SchoolGradeCatalog.all
            .where(_selectedGrades.contains)
            .toList(),
      );

      final expiry = DateTime.now().add(Duration(days: _renewDays));
      final loginKey = PhoneUtils.loginKey(_adminPhone.text.trim());
      final adminPhoneLocal =
          PhoneUtils.normalizeLocal(_adminPhone.text.trim()) ?? loginKey;
      final password = _password.text.trim();

      var draft = SchoolRegistryService.instance.draftSchool(
        name: _schoolName.text.trim(),
        city: _city.text.trim(),
        setup: setup,
        adminUsername: loginKey,
        adminContactPhone: adminPhoneLocal,
        address: _address.text.trim(),
        officePhone: _officePhone.text.trim(),
        subscriptionExpiresAt: expiry,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        ratePerStudentMonthEtb: rate,
        minimumMonthlyEtb: minBill,
        adminInitialPassword: password,
        adminFullName: _adminName.text.trim(),
      );

      // Cloud-first: do not show success unless school + admin exist in Supabase.
      var cloud = await PlatformSchoolsCloudService.instance.createSchoolInCloud(
        school: draft,
        adminUsername: loginKey,
        adminFullName: _adminName.text.trim(),
        adminPhone: adminPhoneLocal,
        password: password,
      );
      if (!cloud.ok && cloud.errorCode == 'school_exists') {
        draft = SchoolRegistryService.instance.draftSchool(
          name: draft.name,
          city: draft.city ?? '',
          setup: setup,
          adminUsername: loginKey,
          adminContactPhone: draft.adminContactPhone,
          address: draft.address,
          officePhone: draft.officePhone,
          subscriptionExpiresAt: expiry,
          notes: draft.notes,
          ratePerStudentMonthEtb: rate,
          minimumMonthlyEtb: minBill,
          adminInitialPassword: password,
          adminFullName: _adminName.text.trim(),
        );
        cloud = await PlatformSchoolsCloudService.instance.createSchoolInCloud(
          school: draft,
          adminUsername: loginKey,
          adminFullName: _adminName.text.trim(),
          adminPhone: adminPhoneLocal,
          password: password,
        );
      }
      if (!cloud.ok) {
        setState(() {
          _message = cloud.errorMessage?.trim().isNotEmpty == true
              ? cloud.errorMessage!
              : 'Cloud create failed (${cloud.errorCode ?? 'error'}). '
                  'Check internet / owner PIN, then try again. '
                  'School was NOT saved.';
        });
        return;
      }

      final school = await SchoolRegistryService.instance.commitSchool(
        draft,
        pushCloud: false,
      );

      final error = AuthService.registerSchoolAdmin(
        schoolName: school.name,
        city: school.city ?? '',
        adminFullName: _adminName.text.trim(),
        adminPhone: _adminPhone.text.trim(),
        password: password,
        schoolId: school.id,
      );

      if (error != null) {
        // Cloud already has the school/admin; keep local school and warn.
        setState(
          () => _message = error == 'exists'
              ? 'School is in cloud, but this phone is already registered on this device.'
              : 'School is in cloud, but local admin cache failed (invalid phone).',
        );
      }

      if (_pendingLogoBytes != null) {
        try {
          final logos = SchoolLogoService.instance;
          final saved = await logos.saveLogoBytes(
            school.id,
            _pendingLogoBytes!,
            style: _pendingLogoStyle,
          );
          if (saved != null) {
            final remoteUrl = await logos.uploadToServer(
              schoolId: school.id,
              localPath: saved,
              bytes: _pendingLogoBytes,
            );
            await SchoolRegistryService.instance.setSchoolLogo(
              school.id,
              localPath: saved,
              remoteUrl: remoteUrl,
              style: _pendingLogoStyle,
            );
          }
        } catch (_) {
          // Logo is optional — school is already created.
        }
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'School saved to cloud',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'This school is in Supabase. Admin login works on any phone/browser '
                  '(use School ID + phone + password).',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                _credentialLine('School ID', school.id),
                _credentialLine('Admin login', loginKey),
                _credentialLine('Password', password, highlight: true),
                const SizedBox(height: 8),
                Text(
                  'Billing: $rate ETB/student/mo (min $minBill ETB/mo)\n'
                  'Active until: ${expiry.day}/${expiry.month}/${expiry.year}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Saved in Supabase — other devices will see this school after refresh.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(
                  text:
                      'School ID: ${school.id}\nLogin: $loginKey\nPassword: $password',
                ));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Login details copied'),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              },
              child: const Text('Copy all'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('School ${school.id} created in cloud'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Could not create school. Please try again.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Create failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboard school'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: ListView(
        padding: listPagePadding(context).copyWith(bottom: 24),
        children: [
          _field('School name', _schoolName),
          _field('City', _city),
          _field('Address', _address, maxLines: 2),
          _field('Office phone', _officePhone, keyboard: TextInputType.phone),
          const SizedBox(height: 8),
          const Text(
            'Billing rate',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _field(
            'Rate per student / month (ETB)',
            _ratePerStudent,
            keyboard: TextInputType.number,
          ),
          _field(
            'Minimum monthly bill (ETB)',
            _minimumMonthly,
            keyboard: TextInputType.number,
          ),
          const SizedBox(height: 8),
          const Text(
            'School logo (optional)',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _creating
                    ? null
                    : () => _pickLogo(SchoolLogoStyle.rectangular),
                icon: const Icon(Icons.crop_landscape_outlined),
                label: const Text('Rectangular banner'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
              ),
              OutlinedButton.icon(
                onPressed: _creating
                    ? null
                    : () => _pickLogo(SchoolLogoStyle.circular),
                icon: const Icon(Icons.circle_outlined),
                label: const Text('Circular logo'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
              ),
              if (_pendingLogoBytes != null)
                TextButton.icon(
                  onPressed: _creating
                      ? null
                      : () => setState(() {
                            _pendingLogoBytes = null;
                            _pendingLogoPath = null;
                          }),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Remove logo'),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _pendingLogoBytes != null
                    ? Colors.tealAccent.withValues(alpha: 0.45)
                    : Colors.white12,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pendingLogoBytes == null
                      ? 'Logo preview'
                      : 'Logo preview · ${_pendingLogoStyle.label}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                if (_pendingLogoBytes != null)
                  Center(
                    child: SchoolLogoDisplay(
                      imageBytes: _pendingLogoBytes,
                      imagePath: _pendingLogoPath,
                      style: _pendingLogoStyle,
                      height: _pendingLogoStyle == SchoolLogoStyle.circular
                          ? 120
                          : 110,
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Text(
                      'No logo attached yet',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _field('Academic year', _academicYear),
          const SizedBox(height: 8),
          SchoolGradeLevelPicker(
            selected: _selectedGrades,
            enabled: !_creating,
            onChanged: (next) => setState(() {
              _selectedGrades
                ..clear()
                ..addAll(next);
            }),
          ),
          const SizedBox(height: 8),
          _field('Admin full name', _adminName),
          _field('Admin phone (login username)', _adminPhone, keyboard: TextInputType.phone),
          _passwordField(),
          _adminCredentialsPreview(),
          const SizedBox(height: 12),
          const Text('Initial subscription', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 30, label: Text('30d')),
              ButtonSegment(value: 90, label: Text('90d')),
              ButtonSegment(value: 365, label: Text('1y')),
            ],
            selected: {_renewDays},
            onSelectionChanged: _creating
                ? null
                : (v) => setState(() => _renewDays = v.first),
          ),
          const SizedBox(height: 12),
          _field('Private notes', _notes, maxLines: 2),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_message, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
      bottomNavigationBar: Material(
        color: const Color(0xFF1E293B),
        elevation: 12,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: FilledButton(
              onPressed: _creating ? null : _create,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _creating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create & activate school'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _password,
        obscureText: !_showPassword,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: 'Admin temp password',
          labelStyle: const TextStyle(color: Colors.white54),
          helperText: 'Shown on school profile after creation',
          helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          suffixIcon: IconButton(
            tooltip: _showPassword ? 'Hide password' : 'Show password',
            onPressed: () => setState(() => _showPassword = !_showPassword),
            icon: Icon(
              _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _adminCredentialsPreview() {
    final phone = _adminPhone.text.trim();
    final login = phone.isEmpty ? '—' : PhoneUtils.loginKey(phone);
    final password = _password.text;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key, size: 16, color: Colors.amber.shade200),
              const SizedBox(width: 6),
              Text(
                'Admin login preview',
                style: TextStyle(
                  color: Colors.amber.shade200,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _previewRow('Login', login),
          _previewRow('Password', password.isEmpty ? '—' : password, highlight: true),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: highlight ? Colors.amberAccent.shade100 : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _credentialLine(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: highlight ? Colors.amber.shade800 : null,
                fontSize: highlight ? 16 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

class _PlatformSchoolStudentsPage extends StatelessWidget {
  const _PlatformSchoolStudentsPage({
    required this.schoolId,
    required this.schoolName,
  });

  final String schoolId;
  final String schoolName;

  @override
  Widget build(BuildContext context) {
    final active = StudentRegistryService.instance.studentsForSchool(schoolId);
    final inactive =
        StudentRegistryService.instance.inactiveStudentsForSchool(schoolId);
    final fmt = SchoolEnrollmentMetricsService.formatCount;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('$schoolName · Students'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: listPagePadding(context),
        children: [
          Text(
            '${fmt(active.length)} active enrolled (billable)',
            style: const TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (inactive.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Text(
                '${fmt(inactive.length)} inactive — not counted for billing',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            )
          else
            const SizedBox(height: 12),
          ...active.map(
            (s) => Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade800,
                  child: Text(
                    s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(s.fullName, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  '${s.studentId} · ${s.grade} · ${s.className}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: const Icon(Icons.check_circle, color: Colors.green, size: 20),
              ),
            ),
          ),
          if (inactive.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Inactive',
              style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...inactive.map(
              (s) => Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(s.fullName, style: const TextStyle(color: Colors.white54)),
                  subtitle: Text(
                    '${s.studentId} · ${s.grade}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
