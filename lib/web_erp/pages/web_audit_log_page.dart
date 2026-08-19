import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:mayabela/models/platform_audit_entry.dart';
import 'package:mayabela/models/school_audit_entry.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/platform_audit_log_service.dart';
import 'package:mayabela/services/school_audit_log_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

/// School operational audit log (Phase F), with platform entries as secondary.
class WebAuditLogPage extends StatefulWidget {
  const WebAuditLogPage({super.key});

  @override
  State<WebAuditLogPage> createState() => _WebAuditLogPageState();
}

class _WebAuditLogPageState extends State<WebAuditLogPage> {
  bool _loading = true;
  String _query = '';
  String _entityType = 'all';
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    Future.wait([
      SchoolAuditLogService.instance.load(),
      PlatformAuditLogService.instance.load(),
    ]).then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListenableBuilder(
      listenable: SchoolAuditLogService.instance,
      builder: (context, _) {
        final schoolEntries = SchoolAuditLogService.instance.filtered(
          schoolId: AuthService.activeSchoolId,
          actionQuery: _query,
          entityType: _entityType == 'all' ? null : _entityType,
          limit: 200,
        );
        final isOwner =
            AuthService.currentUser?.roleKey == AuthService.roleAdmin;
        final me = AuthService.currentUser?.username.toLowerCase();
        final myRoles = AuthService.currentUser?.staffRoles
                .map((e) => e.toLowerCase())
                .toSet() ??
            {};
        final visibleSchoolEntries = isOwner
            ? schoolEntries
            : schoolEntries.where((e) {
                final actor = (e.actorId ?? '').toLowerCase();
                if (me != null && actor == me) return true;
                final role = (e.actorRole ?? '').toLowerCase();
                if (role.isNotEmpty && myRoles.contains(role)) return true;
                // Also show entries that mention this staff member as entity.
                final entity = (e.entityId ?? '').toLowerCase();
                return me != null && entity == me;
              }).toList();
        final platformEntries =
            PlatformAuditLogService.instance.recent(limit: 100).where((e) {
          if (!isOwner) return false;
          if (_query.trim().isEmpty) return true;
          final q = _query.trim().toLowerCase();
          return e.action.toLowerCase().contains(q) ||
              (e.detail ?? '').toLowerCase().contains(q) ||
              (e.schoolName ?? '').toLowerCase().contains(q);
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Audit Log', style: WebErpTheme.sectionTitle(context)),
              const SizedBox(height: 4),
              Text(
                'Who changed what — school operations with before/after, '
                'plus platform-level events.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('School'),
                    icon: Icon(Icons.school_outlined),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('Platform'),
                    icon: Icon(Icons.cloud_outlined),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search action, actor, entity…',
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  if (_tab == 0)
                    DropdownButton<String>(
                      value: _entityType,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All entities'),
                        ),
                        DropdownMenuItem(value: 'bus', child: Text('Buses')),
                        DropdownMenuItem(
                          value: 'transfer',
                          child: Text('Transfers'),
                        ),
                        DropdownMenuItem(value: 'staff', child: Text('Staff')),
                        DropdownMenuItem(
                          value: 'procurement',
                          child: Text('Procurement'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _entityType = v ?? 'all'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _tab == 0
                    ? _schoolList(visibleSchoolEntries)
                    : _platformList(platformEntries),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _schoolList(List<SchoolAuditEntry> entries) {
    if (entries.isEmpty) {
      return const Center(child: Text('No school audit entries yet.'));
    }
    return Container(
      decoration: WebErpTheme.cardDecoration(context),
      child: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final e = entries[index];
          final hasDiff = e.before != null || e.after != null;
          return ListTile(
            leading: Icon(
              _iconFor(e.entityType),
              color: WebErpTheme.primary,
            ),
            title: Text(e.action),
            subtitle: Text(
              [
                if (e.actorName != null && e.actorName!.isNotEmpty) e.actorName!,
                if (e.actorRole != null) e.actorRole!,
                if (e.entityType != null) e.entityType!,
                if (e.entityId != null) e.entityId!,
                if (e.detail != null) e.detail!,
                e.at.toLocal().toString().split('.').first,
              ].join(' · '),
            ),
            trailing: hasDiff
                ? const Icon(Icons.compare_arrows, size: 18)
                : null,
            onTap: hasDiff ? () => _showDiff(e) : null,
          );
        },
      ),
    );
  }

  Widget _platformList(List<PlatformAuditEntry> entries) {
    if (entries.isEmpty) {
      return const Center(child: Text('No platform audit entries yet.'));
    }
    return Container(
      decoration: WebErpTheme.cardDecoration(context),
      child: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final e = entries[index];
          return ListTile(
            leading: const Icon(Icons.history),
            title: Text(e.action),
            subtitle: Text(
              [
                if (e.schoolName != null) e.schoolName!,
                if (e.detail != null) e.detail!,
                e.at.toLocal().toString().split('.').first,
              ].join(' · '),
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(String? entityType) {
    switch (entityType) {
      case 'bus':
        return Icons.directions_bus_outlined;
      case 'transfer':
        return Icons.swap_horiz;
      case 'staff':
        return Icons.badge_outlined;
      case 'procurement':
        return Icons.inventory_2_outlined;
      default:
        return Icons.history;
    }
  }

  void _showDiff(SchoolAuditEntry e) {
    String pretty(Map<String, dynamic>? map) {
      if (map == null) return '(none)';
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(map);
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.action),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (e.actorName != null) 'Actor: ${e.actorName}',
                    if (e.entityId != null) 'Entity: ${e.entityId}',
                    if (e.detail != null) e.detail!,
                  ].join('\n'),
                ),
                const SizedBox(height: 16),
                Text('Before', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 4),
                SelectableText(
                  pretty(e.before),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 16),
                Text('After', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 4),
                SelectableText(
                  pretty(e.after),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
