import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mayabela/models/inventory_models.dart';
import 'package:mayabela/services/inventory_service.dart';
import 'package:mayabela/services/inventory_storage_service.dart';
import 'package:mayabela/web_erp/pages/inventory/web_inventory_dialogs.dart';
import 'package:mayabela/web_erp/pages/inventory/web_inventory_helpers.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/widgets/web_stat_card.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';

/// Inventory dashboard with KPIs, alerts, and quick actions.
class WebInventoryDashboardSection extends StatelessWidget {
  const WebInventoryDashboardSection({
    super.key,
    required this.onNavigate,
  });

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final stats = InventoryService.instance.dashboardStats();
    final lowStock = InventoryService.instance
        .filteredItems(stockFilter: 'low')
        .take(6)
        .toList();
    final outStock = InventoryService.instance
        .filteredItems(stockFilter: 'out')
        .take(6)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          inventoryPageHeader(
            context,
            title: 'Inventory Dashboard',
            subtitle:
                'School resources, stock movement, and asset overview.',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 1100
                  ? 4
                  : c.maxWidth > 700
                      ? 2
                      : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: cols == 1 ? 3.2 : 2.8,
                children: [
                  WebStatCard(
                    label: 'Total Items',
                    value: '${stats.totalItems}',
                    icon: Icons.inventory_2_outlined,
                    color: WebErpTheme.primary,
                  ),
                  WebStatCard(
                    label: 'Inventory Value',
                    value: formatInventoryMoney(stats.totalValue),
                    icon: Icons.account_balance_wallet_outlined,
                    color: Colors.teal.shade700,
                  ),
                  WebStatCard(
                    label: 'Low Stock',
                    value: '${stats.lowStockCount}',
                    icon: Icons.warning_amber_outlined,
                    color: Colors.orange.shade700,
                    onTap: () => onNavigate(1),
                  ),
                  WebStatCard(
                    label: 'Out of Stock',
                    value: '${stats.outOfStockCount}',
                    icon: Icons.remove_shopping_cart_outlined,
                    color: Colors.red.shade700,
                    onTap: () => onNavigate(1),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (InventoryPermissions.canManageInventory)
                FilledButton.icon(
                  onPressed: () => showInventoryItemDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              if (InventoryPermissions.canStockInOut) ...[
                FilledButton.icon(
                  onPressed: () => showStockInDialog(context),
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Stock In'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => showStockOutDialog(context),
                  icon: const Icon(Icons.output_outlined),
                  label: const Text('Stock Out'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                  ),
                ),
              ],
              if (InventoryPermissions.canViewReports)
                OutlinedButton.icon(
                  onPressed: () => onNavigate(9),
                  icon: const Icon(Icons.assessment_outlined),
                  label: const Text('View Reports'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 900;
              return Flex(
                direction: wide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _alertPanel(
                      context,
                      title: 'Low Stock Items',
                      icon: Icons.warning_amber_outlined,
                      color: Colors.orange,
                      items: lowStock
                          .map(
                            (i) =>
                                '${i.name}: ${i.quantityAvailable} ${i.unit} (min ${i.minimumStockLevel})',
                          )
                          .toList(),
                      empty: 'No low stock items',
                    ),
                  ),
                  SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
                  Expanded(
                    child: _alertPanel(
                      context,
                      title: 'Out of Stock',
                      icon: Icons.error_outline,
                      color: Colors.red,
                      items: outStock.map((i) => i.name).toList(),
                      empty: 'All items in stock',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Recent Stock Activity', style: WebErpTheme.sectionTitle(context)),
          const SizedBox(height: 12),
          inventoryDataCard(
            context,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Qty')),
                DataColumn(label: Text('Details')),
              ],
              rows: [
                for (final t in stats.recentTransactions)
                  DataRow(
                    cells: [
                      DataCell(Text(formatInventoryDate(t.date))),
                      DataCell(
                        inventoryStatusChip(
                          t.direction == InventoryStockDirection.stockIn
                              ? 'Stock In'
                              : 'Stock Out',
                          t.direction == InventoryStockDirection.stockIn
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      DataCell(Text(t.itemName)),
                      DataCell(Text('${t.quantity}')),
                      DataCell(
                        Text(
                          t.direction == InventoryStockDirection.stockIn
                              ? (t.supplierOrDonor ?? t.receivedBy ?? '—')
                              : (t.issuedTo ?? t.reason ?? '—'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertPanel(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
    required String empty,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              empty,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            for (final line in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 6, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Main inventory item database with search and filters.
class WebInventoryItemsSection extends StatefulWidget {
  const WebInventoryItemsSection({super.key});

  @override
  State<WebInventoryItemsSection> createState() =>
      _WebInventoryItemsSectionState();
}

class _WebInventoryItemsSectionState extends State<WebInventoryItemsSection> {
  String _query = '';
  InventoryItemCategory? _category;
  String? _stockFilter;

  @override
  Widget build(BuildContext context) {
    final items = InventoryService.instance.filteredItems(
      query: _query,
      category: _category,
      stockFilter: _stockFilter,
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          inventoryPageHeader(
            context,
            title: 'Item Management',
            subtitle: 'School inventory database — books, uniforms, supplies, and equipment.',
            actions: [
              if (InventoryPermissions.canManageInventory)
                FilledButton.icon(
                  onPressed: () => showInventoryItemDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              inventorySearchField(
                hint: 'Search items…',
                onChanged: (v) => setState(() => _query = v),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<InventoryItemCategory?>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    for (final c in InventoryItemCategory.values)
                      DropdownMenuItem(value: c, child: Text(c.label)),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: _stockFilter,
                  decoration: const InputDecoration(
                    labelText: 'Stock Status',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 'low', child: Text('Low Stock')),
                    DropdownMenuItem(value: 'out', child: Text('Out of Stock')),
                  ],
                  onChanged: (v) => setState(() => _stockFilter = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: items.isEmpty
                ? inventoryEmptyState(
                    context,
                    icon: Icons.inventory_2_outlined,
                    message: 'No inventory items found',
                  )
                : inventoryDataCard(
                    context,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Image')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Qty')),
                        DataColumn(label: Text('Unit')),
                        DataColumn(label: Text('Min')),
                        DataColumn(label: Text('Location')),
                        DataColumn(label: Text('Price')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final i in items)
                          DataRow(
                            cells: [
                              DataCell(Text(i.id)),
                              DataCell(Text(i.name)),
                              DataCell(_imageThumb(i.imagePath)),
                              DataCell(Text(i.category.label)),
                              DataCell(
                                Text(
                                  '${i.quantityAvailable}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: i.isOutOfStock
                                        ? Colors.red
                                        : i.isLowStock
                                            ? Colors.orange
                                            : null,
                                  ),
                                ),
                              ),
                              DataCell(Text(i.unit)),
                              DataCell(Text('${i.minimumStockLevel}')),
                              DataCell(Text(i.storageLocation)),
                              DataCell(Text(formatInventoryMoney(i.purchasePrice))),
                              DataCell(
                                inventoryStatusChip(
                                  i.status.name == 'active' ? 'Active' : 'Inactive',
                                  i.status == InventoryItemStatus.active
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              DataCell(
                                InventoryPermissions.canManageInventory
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 18),
                                            tooltip: 'Edit',
                                            onPressed: () => showInventoryItemDialog(
                                              context,
                                              existing: i,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18),
                                            tooltip: 'Delete',
                                            onPressed: () async {
                                              final ok = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Delete item?'),
                                                  content: Text('Remove ${i.name}?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(ctx, false),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    FilledButton(
                                                      onPressed: () =>
                                                          Navigator.pop(ctx, true),
                                                      child: const Text('Delete'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (ok == true) {
                                                await InventoryService.instance
                                                    .deleteItem(i.id);
                                              }
                                            },
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Stock in or stock out transaction history.
class WebInventoryStockSection extends StatelessWidget {
  const WebInventoryStockSection({
    super.key,
    required this.direction,
  });

  final InventoryStockDirection direction;

  bool get isStockIn => direction == InventoryStockDirection.stockIn;

  @override
  Widget build(BuildContext context) {
    final txns = InventoryService.instance
        .transactionsSnapshot()
        .where((t) => t.direction == direction)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          inventoryPageHeader(
            context,
            title: isStockIn ? 'Stock In Management' : 'Stock Out Management',
            subtitle: isStockIn
                ? 'Record items entering the school — purchases, donations, and deliveries.'
                : 'Record items leaving inventory — issued to students, teachers, and departments.',
            actions: [
              if (InventoryPermissions.canStockInOut)
                FilledButton.icon(
                  onPressed: () => isStockIn
                      ? showStockInDialog(context)
                      : showStockOutDialog(context),
                  icon: Icon(isStockIn ? Icons.add_box_outlined : Icons.output_outlined),
                  label: Text(isStockIn ? 'Record Stock In' : 'Record Stock Out'),
                  style: isStockIn
                      ? FilledButton.styleFrom(backgroundColor: Colors.green.shade700)
                      : FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: txns.isEmpty
                ? inventoryEmptyState(
                    context,
                    icon: isStockIn ? Icons.add_box_outlined : Icons.output_outlined,
                    message: 'No ${isStockIn ? 'stock in' : 'stock out'} transactions yet',
                  )
                : inventoryDataCard(
                    context,
                    child: DataTable(
                      columns: isStockIn
                          ? const [
                              DataColumn(label: Text('Txn ID')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Item')),
                              DataColumn(label: Text('Qty')),
                              DataColumn(label: Text('Supplier/Donor')),
                              DataColumn(label: Text('Invoice')),
                              DataColumn(label: Text('Attachment')),
                              DataColumn(label: Text('Received By')),
                              DataColumn(label: Text('Notes')),
                            ]
                          : const [
                              DataColumn(label: Text('Txn ID')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Item')),
                              DataColumn(label: Text('Qty')),
                              DataColumn(label: Text('Issued To')),
                              DataColumn(label: Text('Type')),
                              DataColumn(label: Text('Approved By')),
                              DataColumn(label: Text('Reason')),
                            ],
                      rows: [
                        for (final t in txns)
                          DataRow(
                            cells: isStockIn
                                ? [
                                    DataCell(Text(t.id)),
                                    DataCell(Text(formatInventoryDate(t.date))),
                                    DataCell(Text(t.itemName)),
                                    DataCell(Text('${t.quantity}')),
                                    DataCell(Text(t.supplierOrDonor ?? '—')),
                                    DataCell(Text(t.invoiceNumber ?? '—')),
                                    DataCell(_attachmentCell(context, t.invoiceAttachmentPath)),
                                    DataCell(Text(t.receivedBy ?? '—')),
                                    DataCell(Text(t.notes ?? '—')),
                                  ]
                                : [
                                    DataCell(Text(t.id)),
                                    DataCell(Text(formatInventoryDate(t.date))),
                                    DataCell(Text(t.itemName)),
                                    DataCell(Text('${t.quantity}')),
                                    DataCell(Text(t.issuedTo ?? '—')),
                                    DataCell(Text(t.issueTarget?.name ?? '—')),
                                    DataCell(Text(t.approvedBy ?? '—')),
                                    DataCell(Text(t.reason ?? '—')),
                                  ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Items assigned to students with return tracking.
class WebInventoryStudentIssuedSection extends StatefulWidget {
  const WebInventoryStudentIssuedSection({super.key});

  @override
  State<WebInventoryStudentIssuedSection> createState() =>
      _WebInventoryStudentIssuedSectionState();
}

class _WebInventoryStudentIssuedSectionState
    extends State<WebInventoryStudentIssuedSection> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    var items = InventoryService.instance.studentIssuedSnapshot();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      items = items
          .where(
            (e) =>
                e.studentName.toLowerCase().contains(q) ||
                e.studentId.toLowerCase().contains(q) ||
                e.itemName.toLowerCase().contains(q) ||
                e.gradeClass.toLowerCase().contains(q),
          )
          .toList();
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          inventoryPageHeader(
            context,
            title: 'Student Issued Items',
            subtitle:
                'Track textbooks, uniforms, and materials assigned to students.',
            actions: [
              if (InventoryPermissions.canManageInventory)
                FilledButton.icon(
                  onPressed: () => _addStudentIssue(context),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Issue to Student'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          inventorySearchField(
            hint: 'Search student or item…',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: items.isEmpty
                ? inventoryEmptyState(
                    context,
                    icon: Icons.school_outlined,
                    message: 'No student issued items recorded',
                  )
                : inventoryDataCard(
                    context,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Student ID')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Grade/Class')),
                        DataColumn(label: Text('Item')),
                        DataColumn(label: Text('Qty')),
                        DataColumn(label: Text('Date Issued')),
                        DataColumn(label: Text('Return Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final e in items)
                          DataRow(
                            cells: [
                              DataCell(Text(e.studentId)),
                              DataCell(Text(e.studentName)),
                              DataCell(Text(e.gradeClass)),
                              DataCell(Text(e.itemName)),
                              DataCell(Text('${e.quantity}')),
                              DataCell(Text(formatInventoryDate(e.dateIssued))),
                              DataCell(_returnChip(e.returnStatus)),
                              DataCell(
                                InventoryPermissions.canManageInventory
                                    ? DropdownButton<StudentIssueReturnStatus>(
                                        value: e.returnStatus,
                                        isDense: true,
                                        underline: const SizedBox.shrink(),
                                        items: StudentIssueReturnStatus.values
                                            .map(
                                              (s) => DropdownMenuItem(
                                                value: s,
                                                child: Text(_returnLabel(s)),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) async {
                                          if (v != null) {
                                            await InventoryService.instance
                                                .updateStudentIssuedStatus(
                                              e.id,
                                              v,
                                            );
                                          }
                                        },
                                      )
                                    : Text(_returnLabel(e.returnStatus)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addStudentIssue(BuildContext context) async {
    final items = InventoryService.instance.itemsSnapshot();
    if (items.isEmpty) return;

    var itemId = items.first.id;
    final studentIdCtrl = TextEditingController();
    final studentNameCtrl = TextEditingController();
    final gradeCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    final saved = await showAdminFormDialog(
      context: context,
      title: 'Issue Item to Student',
      accent: WebErpTheme.primary,
      icon: Icons.school_outlined,
      builder: (ctx, setDialogState) => Column(
        children: [
          adminDialogField(
            TextField(
              controller: studentIdCtrl,
              decoration: adminFieldDecoration(
                label: 'Student ID',
                icon: Icons.badge_outlined,
                accent: WebErpTheme.primary,
              ),
            ),
          ),
          adminDialogField(
            TextField(
              controller: studentNameCtrl,
              decoration: adminFieldDecoration(
                label: 'Student Name',
                icon: Icons.person_outline,
                accent: WebErpTheme.primary,
              ),
            ),
          ),
          adminDialogField(
            TextField(
              controller: gradeCtrl,
              decoration: adminFieldDecoration(
                label: 'Grade / Class',
                icon: Icons.class_outlined,
                accent: WebErpTheme.primary,
              ),
            ),
          ),
          adminDialogField(
            DropdownButtonFormField<String>(
              initialValue: itemId,
              decoration: adminFieldDecoration(
                label: 'Item',
                icon: Icons.inventory_outlined,
                accent: WebErpTheme.primary,
              ),
              items: items
                  .map(
                    (i) => DropdownMenuItem(value: i.id, child: Text(i.name)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setDialogState(() => itemId = v);
              },
            ),
          ),
          adminDialogField(
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: adminFieldDecoration(
                label: 'Quantity',
                icon: Icons.numbers,
                accent: WebErpTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );

    if (!saved || !context.mounted) return;
    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
    await InventoryService.instance.addStudentIssued(
      studentId: studentIdCtrl.text.trim(),
      studentName: studentNameCtrl.text.trim(),
      gradeClass: gradeCtrl.text.trim(),
      itemId: itemId,
      quantity: qty,
    );
  }

  String _returnLabel(StudentIssueReturnStatus s) => switch (s) {
        StudentIssueReturnStatus.returned => 'Returned',
        StudentIssueReturnStatus.notReturned => 'Not Returned',
        StudentIssueReturnStatus.damaged => 'Damaged',
        StudentIssueReturnStatus.lost => 'Lost',
      };

  Widget _returnChip(StudentIssueReturnStatus s) {
    final color = switch (s) {
      StudentIssueReturnStatus.returned => Colors.green,
      StudentIssueReturnStatus.notReturned => Colors.blue,
      StudentIssueReturnStatus.damaged => Colors.orange,
      StudentIssueReturnStatus.lost => Colors.red,
    };
    return inventoryStatusChip(_returnLabel(s), color);
  }
}

/// Classroom-assigned furniture and equipment.
class WebInventoryClassroomSection extends StatefulWidget {
  const WebInventoryClassroomSection({super.key});

  @override
  State<WebInventoryClassroomSection> createState() =>
      _WebInventoryClassroomSectionState();
}

class _WebInventoryClassroomSectionState
    extends State<WebInventoryClassroomSection> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    if (!InventoryPermissions.canViewClassroomInventory) {
      return inventoryEmptyState(
        context,
        icon: Icons.lock_outline,
        message: 'You do not have permission to view classroom inventory',
      );
    }

    var entries = InventoryService.instance.classroomSnapshot();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      entries = entries
          .where(
            (e) =>
                e.classroomName.toLowerCase().contains(q) ||
                e.grade.toLowerCase().contains(q) ||
                e.itemName.toLowerCase().contains(q),
          )
          .toList();
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          inventoryPageHeader(
            context,
            title: 'Classroom Inventory',
            subtitle: 'Items assigned to classrooms — desks, chairs, projectors, and supplies.',
            actions: [
              if (InventoryPermissions.canManageInventory)
                FilledButton.icon(
                  onPressed: () => _addEntry(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Assign Item'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          inventorySearchField(
            hint: 'Search classroom or item…',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: entries.isEmpty
                ? inventoryEmptyState(
                    context,
                    icon: Icons.meeting_room_outlined,
                    message: 'No classroom inventory entries',
                  )
                : inventoryDataCard(
                    context,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Classroom')),
                        DataColumn(label: Text('Grade')),
                        DataColumn(label: Text('Item')),
                        DataColumn(label: Text('Quantity')),
                        DataColumn(label: Text('Condition')),
                      ],
                      rows: [
                        for (final e in entries)
                          DataRow(
                            cells: [
                              DataCell(Text(e.classroomName)),
                              DataCell(Text(e.grade)),
                              DataCell(Text(e.itemName)),
                              DataCell(Text('${e.quantity}')),
                              DataCell(Text(e.condition)),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addEntry(BuildContext context) async {
    final items = InventoryService.instance.itemsSnapshot();
    if (items.isEmpty) return;

    var itemId = items.first.id;
    final classroomCtrl = TextEditingController();
    final gradeCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final conditionCtrl = TextEditingController(text: 'Good');

    final saved = await showAdminFormDialog(
      context: context,
      title: 'Assign Item to Classroom',
      accent: WebErpTheme.primary,
      icon: Icons.meeting_room_outlined,
      builder: (ctx, setDialogState) => Column(
        children: [
          adminDialogField(
            TextField(
              controller: classroomCtrl,
              decoration: adminFieldDecoration(
                label: 'Classroom Name',
                icon: Icons.meeting_room_outlined,
                accent: WebErpTheme.primary,
              ),
            ),
          ),
          adminDialogField(
            TextField(
              controller: gradeCtrl,
              decoration: adminFieldDecoration(
                label: 'Grade',
                icon: Icons.grade_outlined,
                accent: WebErpTheme.primary,
              ),
            ),
          ),
          adminDialogField(
            DropdownButtonFormField<String>(
              initialValue: itemId,
              decoration: adminFieldDecoration(
                label: 'Item',
                icon: Icons.inventory_outlined,
                accent: WebErpTheme.primary,
              ),
              items: items
                  .map(
                    (i) => DropdownMenuItem(value: i.id, child: Text(i.name)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setDialogState(() => itemId = v);
              },
            ),
          ),
          adminDialogField(
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: adminFieldDecoration(
                label: 'Quantity',
                icon: Icons.numbers,
                accent: WebErpTheme.primary,
              ),
            ),
          ),
          adminDialogField(
            TextField(
              controller: conditionCtrl,
              decoration: adminFieldDecoration(
                label: 'Condition',
                icon: Icons.build_outlined,
                accent: WebErpTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );

    if (!saved || !context.mounted) return;
    await InventoryService.instance.addClassroomEntry(
      classroomName: classroomCtrl.text.trim(),
      grade: gradeCtrl.text.trim(),
      itemId: itemId,
      quantity: int.tryParse(qtyCtrl.text.trim()) ?? 1,
      condition: conditionCtrl.text.trim(),
    );
  }
}

/// Long-term school property tracking.
class WebInventoryAssetsSection extends StatefulWidget {
  const WebInventoryAssetsSection({super.key});

  @override
  State<WebInventoryAssetsSection> createState() =>
      _WebInventoryAssetsSectionState();
}

class _WebInventoryAssetsSectionState extends State<WebInventoryAssetsSection> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    var assets = InventoryService.instance.assetsSnapshot();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      assets = assets
          .where(
            (a) =>
                a.name.toLowerCase().contains(q) ||
                a.serialNumber.toLowerCase().contains(q) ||
                a.location.toLowerCase().contains(q),
          )
          .toList();
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          inventoryPageHeader(
            context,
            title: 'Asset Management',
            subtitle:
                'Long-term school property — computers, projectors, vehicles, and furniture.',
            actions: [
              if (InventoryPermissions.canManageInventory)
                FilledButton.icon(
                  onPressed: () => showAssetDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Asset'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          inventorySearchField(
            hint: 'Search assets…',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: assets.isEmpty
                ? inventoryEmptyState(
                    context,
                    icon: Icons.devices_outlined,
                    message: 'No assets registered',
                  )
                : inventoryDataCard(
                    context,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Asset ID')),
                        DataColumn(label: Text('Photo')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Serial')),
                        DataColumn(label: Text('Purchase Date')),
                        DataColumn(label: Text('Price')),
                        DataColumn(label: Text('Location')),
                        DataColumn(label: Text('Assigned')),
                        DataColumn(label: Text('Condition')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final a in assets)
                          DataRow(
                            cells: [
                              DataCell(Text(a.id)),
                              DataCell(_imageThumb(a.imagePath)),
                              DataCell(Text(a.name)),
                              DataCell(Text(a.category)),
                              DataCell(Text(a.serialNumber)),
                              DataCell(Text(formatInventoryDate(a.purchaseDate))),
                              DataCell(Text(formatInventoryMoney(a.purchasePrice))),
                              DataCell(Text(a.location)),
                              DataCell(Text(a.assignedPerson)),
                              DataCell(Text(_assetConditionLabel(a.condition))),
                              DataCell(
                                InventoryPermissions.canManageInventory
                                    ? IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        onPressed: () =>
                                            showAssetDialog(context, existing: a),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _assetConditionLabel(AssetCondition c) => switch (c) {
        AssetCondition.newItem => 'New',
        AssetCondition.good => 'Good',
        AssetCondition.needsRepair => 'Needs Repair',
        AssetCondition.damaged => 'Damaged',
      };
}

/// Supplier directory and purchase history.
class WebInventorySuppliersSection extends StatelessWidget {
  const WebInventorySuppliersSection({super.key});

  @override
  Widget build(BuildContext context) {
    final suppliers = InventoryService.instance.suppliersSnapshot();
    final stockIns = InventoryService.instance
        .transactionsSnapshot()
        .where((t) => t.direction == InventoryStockDirection.stockIn)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          inventoryPageHeader(
            context,
            title: 'Suppliers Management',
            subtitle: 'Vendor records, contacts, and purchase history.',
            actions: [
              if (InventoryPermissions.canManageInventory)
                FilledButton.icon(
                  onPressed: () => showSupplierDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Supplier'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: suppliers.isEmpty
                ? inventoryEmptyState(
                    context,
                    icon: Icons.local_shipping_outlined,
                    message: 'No suppliers registered',
                  )
                : inventoryDataCard(
                    context,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Contact')),
                        DataColumn(label: Text('Address')),
                        DataColumn(label: Text('Products Supplied')),
                        DataColumn(label: Text('Recent Purchases')),
                      ],
                      rows: [
                        for (final s in suppliers)
                          DataRow(
                            cells: [
                              DataCell(Text(s.name)),
                              DataCell(Text(s.contact)),
                              DataCell(Text(s.address)),
                              DataCell(Text(s.productsSupplied)),
                              DataCell(
                                Text(
                                  _purchaseCount(stockIns, s.name).toString(),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  int _purchaseCount(List<StockTransaction> txns, String supplierName) {
    final key = supplierName.toLowerCase();
    return txns
        .where(
          (t) => (t.supplierOrDonor ?? '').toLowerCase().contains(key),
        )
        .length;
  }
}

/// Damage and maintenance issue reports.
class WebInventoryMaintenanceSection extends StatelessWidget {
  const WebInventoryMaintenanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = InventoryService.instance.maintenanceSnapshot();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          inventoryPageHeader(
            context,
            title: 'Maintenance & Damage Reports',
            subtitle: 'Track reported issues, repairs, and resolution status.',
            actions: [
              FilledButton.icon(
                onPressed: () => showMaintenanceDialog(context),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Report Issue'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: reports.isEmpty
                ? inventoryEmptyState(
                    context,
                    icon: Icons.build_circle_outlined,
                    message: 'No maintenance reports',
                  )
                : inventoryDataCard(
                    context,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Report ID')),
                        DataColumn(label: Text('Item/Asset')),
                        DataColumn(label: Text('Reported By')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Description')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final r in reports)
                          DataRow(
                            cells: [
                              DataCell(Text(r.id)),
                              DataCell(Text(r.itemOrAsset)),
                              DataCell(Text(r.reportedBy)),
                              DataCell(Text(formatInventoryDate(r.date))),
                              DataCell(
                                Text(
                                  r.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DataCell(_statusChip(r.status)),
                              DataCell(
                                InventoryPermissions.canManageInventory
                                    ? DropdownButton<MaintenanceReportStatus>(
                                        value: r.status,
                                        isDense: true,
                                        underline: const SizedBox.shrink(),
                                        items: MaintenanceReportStatus.values
                                            .map(
                                              (s) => DropdownMenuItem(
                                                value: s,
                                                child: Text(_statusLabel(s)),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) async {
                                          if (v != null) {
                                            await InventoryService.instance
                                                .updateMaintenanceStatus(
                                              r.id,
                                              v,
                                            );
                                          }
                                        },
                                      )
                                    : Text(_statusLabel(r.status)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(MaintenanceReportStatus s) => switch (s) {
        MaintenanceReportStatus.pending => 'Pending',
        MaintenanceReportStatus.inProgress => 'In Progress',
        MaintenanceReportStatus.completed => 'Completed',
      };

  Widget _statusChip(MaintenanceReportStatus s) {
    final color = switch (s) {
      MaintenanceReportStatus.pending => Colors.orange,
      MaintenanceReportStatus.inProgress => Colors.blue,
      MaintenanceReportStatus.completed => Colors.green,
    };
    return inventoryStatusChip(_statusLabel(s), color);
  }
}

/// Inventory reports and export summaries.
class WebInventoryReportsSection extends StatelessWidget {
  const WebInventoryReportsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = InventoryService.instance;
    final items = svc.filteredItems();
    final lowStock = svc.filteredItems(stockFilter: 'low');
    final txns = svc.transactionsSnapshot();
    final issued = svc.studentIssuedSnapshot();
    final assets = svc.assetsSnapshot();
    final damaged = issued
        .where(
          (e) =>
              e.returnStatus == StudentIssueReturnStatus.damaged ||
              e.returnStatus == StudentIssueReturnStatus.lost,
        )
        .toList();
    final stockIns = txns
        .where((t) => t.direction == InventoryStockDirection.stockIn)
        .toList();

    final reports = [
      (
        'Current Stock Report',
        '${items.length} items · ${formatInventoryMoney(items.fold(0.0, (s, i) => s + i.inventoryValue))} total value',
        Icons.inventory_2_outlined,
      ),
      (
        'Low Stock Report',
        '${lowStock.length} items below minimum level',
        Icons.warning_amber_outlined,
      ),
      (
        'Stock Movement History',
        '${txns.length} transactions recorded',
        Icons.swap_horiz,
      ),
      (
        'Items Issued to Students',
        '${issued.length} student issue records',
        Icons.school_outlined,
      ),
      (
        'Asset Report',
        '${assets.length} assets · ${formatInventoryMoney(assets.fold(0.0, (s, a) => s + a.purchasePrice))}',
        Icons.devices_outlined,
      ),
      (
        'Purchase History',
        '${stockIns.length} stock-in transactions',
        Icons.receipt_long_outlined,
      ),
      (
        'Damaged / Lost Items',
        '${damaged.length} damaged or lost student items',
        Icons.broken_image_outlined,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          inventoryPageHeader(
            context,
            title: 'Inventory Reports',
            subtitle: 'Generate summaries for stock, assets, purchases, and losses.',
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final (title, summary, icon) = reports[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: WebErpTheme.cardDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: WebErpTheme.primary, size: 28),
                    const Spacer(),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      summary,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final fmt in ['PDF', 'Excel', 'CSV', 'Print'])
                          ActionChip(
                            label: Text(fmt, style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Generating $title ($fmt)…')),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Widget _imageThumb(String? path) {
  final storage = InventoryStorageService.instance;
  if (path == null || path.isEmpty) {
    return const Icon(Icons.image_not_supported_outlined, size: 18, color: Colors.grey);
  }
  if (storage.isCloudUrl(path)) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        path,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.broken_image_outlined, size: 18),
      ),
    );
  }
  return const Icon(Icons.attach_file, size: 18, color: Colors.teal);
}

Widget _attachmentCell(BuildContext context, String? path) {
  if (path == null || path.isEmpty) return const Text('—');
  final storage = InventoryStorageService.instance;
  return TextButton(
    onPressed: () async {
      if (storage.isCloudUrl(path)) {
        final uri = Uri.tryParse(path);
        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(storage.displayLabel(path))),
        );
      }
    },
    child: Text(
      storage.isCloudUrl(path) ? 'View' : 'Local file',
      style: const TextStyle(fontSize: 12),
    ),
  );
}
