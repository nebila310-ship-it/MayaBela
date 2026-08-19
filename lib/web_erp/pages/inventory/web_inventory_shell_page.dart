import 'package:flutter/material.dart';

import 'package:mayabela/models/inventory_models.dart';
import 'package:mayabela/models/procurement_models.dart';
import 'package:mayabela/services/inventory_service.dart';
import 'package:mayabela/services/persistence/inventory_persistence_service.dart';
import 'package:mayabela/services/persistence/procurement_persistence_service.dart';
import 'package:mayabela/web_erp/pages/inventory/web_inventory_sections.dart';
import 'package:mayabela/web_erp/pages/inventory/web_procurement_sections.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

/// School ERP inventory module — dashboard, stock, assets, and reports.
///
/// Wide screens keep the side rail; narrow (mobile) uses a section picker.
class WebInventoryShellPage extends StatefulWidget {
  const WebInventoryShellPage({super.key, this.initialSection = 0});

  final int initialSection;

  @override
  State<WebInventoryShellPage> createState() => _WebInventoryShellPageState();
}

class _WebInventoryShellPageState extends State<WebInventoryShellPage> {
  late int _section;

  static const _navItems = [
    (0, 'Dashboard', Icons.dashboard_outlined),
    (10, 'Purchase Requests', Icons.receipt_long_outlined),
    (11, 'Issue Requests', Icons.outbox_outlined),
    (1, 'Items', Icons.inventory_2_outlined),
    (2, 'Stock In', Icons.add_box_outlined),
    (3, 'Stock Out', Icons.output_outlined),
    (4, 'Student Issued', Icons.school_outlined),
    (5, 'Classroom', Icons.meeting_room_outlined),
    (6, 'Assets', Icons.devices_outlined),
    (7, 'Suppliers', Icons.local_shipping_outlined),
    (8, 'Maintenance', Icons.build_circle_outlined),
    (9, 'Reports', Icons.assessment_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    InventoryPersistenceService.instance.loadIntoService();
    ProcurementPersistenceService.instance.loadIntoService();
  }

  List<(int, String, IconData)> get _visibleNav {
    return _navItems.where((item) {
      final id = item.$1;
      if (id == 4 && !InventoryPermissions.canViewIssuedItems) return false;
      if ((id == 1 || id == 6 || id == 7) &&
          !InventoryPermissions.canManageInventory &&
          !InventoryPermissions.canStockInOut) {
        if (id == 1) return true;
        return false;
      }
      if ((id == 2 || id == 3) && !InventoryPermissions.canStockInOut) {
        return false;
      }
      if (id == 5 && !InventoryPermissions.canViewClassroomInventory) {
        return false;
      }
      if (id == 9 && !InventoryPermissions.canViewReports) return false;
      if (id == 10 && !ProcurementPermissions.canSeePurchaseRequests) {
        return false;
      }
      if (id == 11 && !ProcurementPermissions.canSeeIssueRequests) {
        return false;
      }
      return true;
    }).toList();
  }

  String get _currentLabel {
    for (final item in _visibleNav) {
      if (item.$1 == _section) return item.$2;
    }
    return 'Inventory';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: InventoryService.instance,
      builder: (context, _) {
        final narrow = MediaQuery.sizeOf(context).width < 700;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: DropdownButtonFormField<int>(
                    initialValue: _visibleNav.any((e) => e.$1 == _section)
                        ? _section
                        : (_visibleNav.isEmpty ? null : _visibleNav.first.$1),
                    decoration: InputDecoration(
                      labelText: 'Section',
                      prefixIcon: Icon(
                        () {
                          for (final item in _visibleNav) {
                            if (item.$1 == _section) return item.$3;
                          }
                          return Icons.inventory_2_outlined;
                        }(),
                        color: WebErpTheme.primary,
                      ),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: [
                      for (final (id, label, icon) in _visibleNav)
                        DropdownMenuItem(
                          value: id,
                          child: Row(
                            children: [
                              Icon(icon, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(label)),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null) setState(() => _section = id);
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  _currentLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: WebErpTheme.primary,
                      ),
                ),
              ),
              Expanded(child: _sectionBody()),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 220,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Text(
                      'Inventory',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: WebErpTheme.primary,
                          ),
                    ),
                  ),
                  for (final (id, label, icon) in _visibleNav)
                    _navTile(id, label, icon),
                ],
              ),
            ),
            Expanded(child: _sectionBody()),
          ],
        );
      },
    );
  }

  Widget _navTile(int id, String label, IconData icon) {
    final selected = _section == id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected
            ? WebErpTheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _section = id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? WebErpTheme.primary : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                      color: selected ? WebErpTheme.primary : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionBody() {
    switch (_section) {
      case 0:
        return WebInventoryDashboardSection(
          onNavigate: (id) => setState(() => _section = id),
        );
      case 1:
        return const WebInventoryItemsSection();
      case 2:
        return const WebInventoryStockSection(
          direction: InventoryStockDirection.stockIn,
        );
      case 3:
        return const WebInventoryStockSection(
          direction: InventoryStockDirection.stockOut,
        );
      case 4:
        return const WebInventoryStudentIssuedSection();
      case 5:
        return const WebInventoryClassroomSection();
      case 6:
        return const WebInventoryAssetsSection();
      case 7:
        return const WebInventorySuppliersSection();
      case 8:
        return const WebInventoryMaintenanceSection();
      case 9:
        return const WebInventoryReportsSection();
      case 10:
        return const WebPurchaseRequestsSection();
      case 11:
        return const WebIssueRequestsSection();
      default:
        return WebInventoryDashboardSection(
          onNavigate: (id) => setState(() => _section = id),
        );
    }
  }
}
