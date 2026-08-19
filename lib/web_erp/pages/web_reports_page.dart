import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_report_export_service.dart';
import 'package:mayabela/web_erp/pages/inventory/web_inventory_shell_page.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

class WebReportsPage extends StatefulWidget {
  const WebReportsPage({super.key});

  @override
  State<WebReportsPage> createState() => _WebReportsPageState();
}

class _WebReportsPageState extends State<WebReportsPage> {
  String? _busyKey;

  static const _reports = <_ReportTile>[
    _ReportTile(
      'Student Reports',
      Icons.groups_outlined,
      kind: SchoolReportKind.students,
      viewModules: ['students', 'attendance'],
    ),
    _ReportTile(
      'Attendance Reports',
      Icons.check_circle_outline,
      kind: SchoolReportKind.attendance,
      viewModules: ['attendance', 'students'],
    ),
    _ReportTile(
      'Academic Reports',
      Icons.school_outlined,
      kind: SchoolReportKind.academic,
      viewModules: ['academic', 'examinations'],
    ),
    _ReportTile(
      'Financial Reports',
      Icons.payments_outlined,
      kind: SchoolReportKind.finance,
      viewModules: ['finance'],
      requireAny: [
        SchoolPermissions.viewFinanceReports,
        SchoolPermissions.manageFees,
      ],
    ),
    _ReportTile(
      'Transport Reports',
      Icons.directions_bus_outlined,
      kind: SchoolReportKind.transport,
      viewModules: ['transport'],
    ),
    _ReportTile(
      'Teacher Reports',
      Icons.person_outline,
      kind: SchoolReportKind.teachers,
      viewModules: ['teachers'],
    ),
    _ReportTile(
      'Inventory Reports',
      Icons.inventory_2_outlined,
      kind: SchoolReportKind.inventory,
      viewModules: ['inventory'],
      inventorySection: 9,
    ),
  ];

  Future<void> _export(_ReportTile report, String format) async {
    final key = '${report.title}:$format';
    if (_busyKey != null) return;
    setState(() => _busyKey = key);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SchoolReportExportService.instance.export(
        kind: report.kind,
        format: format,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${report.title} · $format ready to share')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner =
        AuthService.currentUser?.roleKey == AuthService.roleAdmin ||
            AuthService.currentUser?.staffRoles.contains(StaffRoles.fullAccess) ==
                true;
    final visible = [
      for (final r in _reports)
        if (isOwner || r.isVisibleToCurrentUser) r,
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reports & Analytics', style: WebErpTheme.sectionTitle(context)),
          const SizedBox(height: 8),
          Text(
            isOwner
                ? 'Export school reports as Excel or CSV (PDF opens Excel).'
                : 'Reports for your assigned roles only.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.4,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final report = visible[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      final section = report.inventorySection;
                      if (section == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            body: WebInventoryShellPage(
                              initialSection: section,
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: WebErpTheme.cardDecoration(context),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(report.icon, color: WebErpTheme.primary, size: 28),
                          const Spacer(),
                          Text(
                            report.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final label in const [
                                'Excel',
                                'CSV',
                                'PDF',
                                'Print',
                              ])
                                _exportChip(report, label),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportChip(_ReportTile report, String label) {
    final key = '${report.title}:$label';
    final busy = _busyKey == key;
    return ActionChip(
      label: Text(
        busy ? '…' : label,
        style: const TextStyle(fontSize: 11),
      ),
      onPressed: busy ? null : () => _export(report, label),
    );
  }
}

class _ReportTile {
  const _ReportTile(
    this.title,
    this.icon, {
    required this.kind,
    this.viewModules = const [],
    this.requireAny = const [],
    this.inventorySection,
  });

  final String title;
  final IconData icon;
  final SchoolReportKind kind;
  final List<String> viewModules;
  final List<String> requireAny;
  final int? inventorySection;

  bool get isVisibleToCurrentUser {
    if (requireAny.isNotEmpty && AuthService.hasAnyPermission(requireAny)) {
      return true;
    }
    for (final id in viewModules) {
      if (ModuleAccess.canView(id)) return true;
    }
    return false;
  }
}
