import 'package:flutter/material.dart';

import 'package:mayabela/models/procurement_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/inventory_service.dart';
import 'package:mayabela/services/procurement_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/web_erp/pages/inventory/web_inventory_helpers.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

// ————————————————————————————————————————————————————————————————————————
// Shared helpers
// ————————————————————————————————————————————————————————————————————————

Color _statusColor(ApprovalStatus status) => switch (status) {
      ApprovalStatus.pending => Colors.orange.shade800,
      ApprovalStatus.approved => Colors.blue.shade700,
      ApprovalStatus.rejected => Colors.red.shade700,
      ApprovalStatus.received => Colors.green.shade700,
      ApprovalStatus.issued => Colors.green.shade700,
    };

String _statusLabel(ApprovalStatus status) => switch (status) {
      ApprovalStatus.pending => 'Pending',
      ApprovalStatus.approved => 'Approved',
      ApprovalStatus.rejected => 'Rejected',
      ApprovalStatus.received => 'Received',
      ApprovalStatus.issued => 'Issued',
    };

String _errorMessage(String code) => switch (code) {
      'self_approval_blocked' =>
        'You cannot approve your own request. The school owner can enable '
            'self-approval in the settings above.',
      'not_allowed' => 'Your roles do not allow this action.',
      'not_pending' => 'This request has already been decided.',
      'not_approved' => 'Only approved requests can be fulfilled.',
      'insufficient_stock' => 'Not enough stock available for this item.',
      'reason_required' => 'A rejection reason is required.',
      'stock_in_failed' => 'Could not record the stock movement.',
      'no_items' => 'Add at least one item line.',
      'invalid_quantity' => 'Quantity must be positive.',
      'item_not_found' => 'The selected item no longer exists.',
      _ => 'Action failed ($code). Please try again.',
    };

void _showResult(BuildContext context, String? error, String successMessage) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error == null ? successMessage : _errorMessage(error)),
      backgroundColor: error == null ? Colors.green.shade700 : Colors.red.shade700,
    ),
  );
}

Future<String?> _askRejectionReason(BuildContext context) async {
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reject request'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Reason for rejection',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Reject'),
        ),
      ],
    ),
  );
  return (reason == null || reason.isEmpty) ? null : reason;
}

/// Owner-only switch controlling whether requesters may approve their own
/// requests. Mirrored into school_registry so the SQL guard enforces it too.
class _SelfApprovalToggle extends StatefulWidget {
  const _SelfApprovalToggle();

  @override
  State<_SelfApprovalToggle> createState() => _SelfApprovalToggleState();
}

class _SelfApprovalToggleState extends State<_SelfApprovalToggle> {
  @override
  Widget build(BuildContext context) {
    if (AuthService.currentUser?.roleKey != AuthService.roleAdmin) {
      return const SizedBox.shrink();
    }
    final schoolId = AuthService.activeSchoolId;
    final school =
        schoolId == null ? null : SchoolRegistryService.instance.lookup(schoolId);
    if (school == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: WebErpTheme.cardDecoration(context),
      child: Row(
        children: [
          Icon(Icons.gavel_outlined, size: 18, color: Colors.blueGrey.shade600),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Allow self-approval — requesters may approve their own '
              'purchase and issue requests. Off keeps approvals with a '
              'second person (recommended).',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
          Switch(
            value: school.allowSelfApproval,
            onChanged: (v) async {
              final messenger = ScaffoldMessenger.of(context);
              await SchoolRegistryService.instance
                  .setAllowSelfApproval(school.id, v);
              if (!mounted) return;
              setState(() {});
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    v
                        ? 'Self-approval enabled for this school.'
                        : 'Self-approval disabled — approvals now require '
                            'a second person.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ————————————————————————————————————————————————————————————————————————
// Purchase requests
// ————————————————————————————————————————————————————————————————————————

class WebPurchaseRequestsSection extends StatefulWidget {
  const WebPurchaseRequestsSection({super.key});

  @override
  State<WebPurchaseRequestsSection> createState() =>
      _WebPurchaseRequestsSectionState();
}

class _WebPurchaseRequestsSectionState
    extends State<WebPurchaseRequestsSection> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProcurementService.instance,
      builder: (context, _) {
        var requests = ProcurementService.instance.purchasesForSchool();
        if (_statusFilter != 'all') {
          requests =
              requests.where((r) => r.status.name == _statusFilter).toList();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              inventoryPageHeader(
                context,
                title: 'Purchase Requests',
                subtitle:
                    'Request goods, get approval, then receive them into the store.',
                actions: [
                  if (ProcurementPermissions.canCreatePurchaseRequests)
                    FilledButton.icon(
                      onPressed: () => _showCreateDialog(context),
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: const Text('New Request'),
                    ),
                ],
              ),
              const _SelfApprovalToggle(),
              const SizedBox(height: 12),
              _statusFilterChips(),
              const SizedBox(height: 12),
              if (requests.isEmpty)
                SizedBox(
                  height: 260,
                  child: inventoryEmptyState(
                    context,
                    icon: Icons.receipt_long_outlined,
                    message: 'No purchase requests yet.',
                  ),
                )
              else
                inventoryDataCard(
                  context,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Items')),
                      DataColumn(label: Text('Reason')),
                      DataColumn(label: Text('Requested By')),
                      DataColumn(label: Text('Est. Total')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: [for (final r in requests) _row(context, r)],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusFilterChips() {
    const filters = [
      ('all', 'All'),
      ('pending', 'Pending'),
      ('approved', 'Approved'),
      ('received', 'Received'),
      ('rejected', 'Rejected'),
    ];
    return Wrap(
      spacing: 8,
      children: [
        for (final (value, label) in filters)
          ChoiceChip(
            label: Text(label),
            selected: _statusFilter == value,
            onSelected: (_) => setState(() => _statusFilter = value),
          ),
      ],
    );
  }

  DataRow _row(BuildContext context, PurchaseRequest r) {
    return DataRow(
      cells: [
        DataCell(Text(formatInventoryDate(r.createdAt))),
        DataCell(
          Tooltip(
            message: r.linesSummary,
            child: SizedBox(
              width: 220,
              child: Text(
                r.linesSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 160,
            child: Text(r.reason, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
        DataCell(Text(r.requestedByName.isNotEmpty
            ? r.requestedByName
            : r.requestedBy)),
        DataCell(Text(formatInventoryMoney(r.estimatedTotal))),
        DataCell(_statusCell(r.status, r.rejectionReason, r.approvedByName)),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (r.status == ApprovalStatus.pending &&
                ProcurementPermissions.canApprovePurchaseRequests) ...[
              IconButton(
                tooltip: 'Approve',
                icon: Icon(Icons.check_circle_outline,
                    color: Colors.green.shade700),
                onPressed: () async {
                  final error = await ProcurementService.instance
                      .approvePurchaseRequest(r.id);
                  if (context.mounted) {
                    _showResult(context, error, 'Request approved.');
                  }
                },
              ),
              IconButton(
                tooltip: 'Reject',
                icon: Icon(Icons.cancel_outlined, color: Colors.red.shade700),
                onPressed: () async {
                  final reason = await _askRejectionReason(context);
                  if (reason == null) return;
                  final error = await ProcurementService.instance
                      .rejectPurchaseRequest(r.id, reason);
                  if (context.mounted) {
                    _showResult(context, error, 'Request rejected.');
                  }
                },
              ),
            ],
            if (r.status == ApprovalStatus.approved &&
                ProcurementPermissions.canReceivePurchases)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.move_to_inbox_outlined, size: 18),
                label: const Text('Receive'),
                onPressed: () => _showReceiveDialog(context, r),
              ),
          ],
        )),
      ],
    );
  }

  Widget _statusCell(
    ApprovalStatus status,
    String? rejectionReason,
    String? approvedByName,
  ) {
    final chip = inventoryStatusChip(_statusLabel(status), _statusColor(status));
    if (status == ApprovalStatus.rejected &&
        (rejectionReason ?? '').isNotEmpty) {
      return Tooltip(message: 'Reason: $rejectionReason', child: chip);
    }
    if (status != ApprovalStatus.pending && (approvedByName ?? '').isNotEmpty) {
      return Tooltip(message: 'Decided by $approvedByName', child: chip);
    }
    return chip;
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final reasonController = TextEditingController();
    final departmentController = TextEditingController();
    final lines = <(TextEditingController, TextEditingController,
        TextEditingController, TextEditingController)>[];

    void addLine() {
      lines.add((
        TextEditingController(),
        TextEditingController(text: '1'),
        TextEditingController(text: 'piece'),
        TextEditingController(text: '0'),
      ));
    }

    addLine();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Purchase Request'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < lines.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: lines[i].$1,
                              decoration: const InputDecoration(
                                labelText: 'Item name',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: lines[i].$2,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Qty',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: lines[i].$3,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: lines[i].$4,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Est. price (ETB)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          if (lines.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () =>
                                  setDialogState(() => lines.removeAt(i)),
                            ),
                        ],
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => setDialogState(addLine),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add line'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason / justification',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Department (optional)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !context.mounted) return;
    final requestLines = [
      for (final (name, qty, unit, price) in lines)
        PurchaseRequestLine(
          name: name.text.trim(),
          quantity: int.tryParse(qty.text.trim()) ?? 0,
          unit: unit.text.trim().isEmpty ? 'piece' : unit.text.trim(),
          estimatedUnitPrice: double.tryParse(price.text.trim()) ?? 0,
        ),
    ];
    final error = await ProcurementService.instance.createPurchaseRequest(
      lines: requestLines,
      reason: reasonController.text,
      department: departmentController.text,
    );
    if (context.mounted) {
      _showResult(context, error, 'Purchase request submitted for approval.');
    }
  }

  Future<void> _showReceiveDialog(
    BuildContext context,
    PurchaseRequest r,
  ) async {
    final supplierController = TextEditingController(text: r.supplier ?? '');
    final invoiceController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receive Goods'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.linesSummary,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                'All lines will be stocked into the inventory. Items not in '
                'the catalog yet are added automatically.',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: supplierController,
                decoration: const InputDecoration(
                  labelText: 'Supplier',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: invoiceController,
                decoration: const InputDecoration(
                  labelText: 'Invoice number (optional)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Receipt'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final error = await ProcurementService.instance.receivePurchaseRequest(
      r.id,
      supplier: supplierController.text.trim().isEmpty
          ? null
          : supplierController.text.trim(),
      invoiceNumber: invoiceController.text.trim().isEmpty
          ? null
          : invoiceController.text.trim(),
    );
    if (context.mounted) {
      _showResult(context, error, 'Goods received and stocked in.');
    }
  }
}

// ————————————————————————————————————————————————————————————————————————
// Issue requests
// ————————————————————————————————————————————————————————————————————————

class WebIssueRequestsSection extends StatefulWidget {
  const WebIssueRequestsSection({super.key});

  @override
  State<WebIssueRequestsSection> createState() =>
      _WebIssueRequestsSectionState();
}

class _WebIssueRequestsSectionState extends State<WebIssueRequestsSection> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProcurementService.instance,
      builder: (context, _) {
        var requests = ProcurementService.instance.issuesForSchool();
        if (_statusFilter != 'all') {
          requests =
              requests.where((r) => r.status.name == _statusFilter).toList();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              inventoryPageHeader(
                context,
                title: 'Issue Requests',
                subtitle:
                    'Departments request items from the store; the storekeeper '
                    'hands them out after approval.',
                actions: [
                  if (ProcurementPermissions.canCreateIssueRequests)
                    FilledButton.icon(
                      onPressed: () => _showCreateDialog(context),
                      icon: const Icon(Icons.outbox_outlined),
                      label: const Text('New Request'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _statusFilterChips(),
              const SizedBox(height: 12),
              if (requests.isEmpty)
                SizedBox(
                  height: 260,
                  child: inventoryEmptyState(
                    context,
                    icon: Icons.outbox_outlined,
                    message: 'No issue requests yet.',
                  ),
                )
              else
                inventoryDataCard(
                  context,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Item')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Purpose')),
                      DataColumn(label: Text('Requested By')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: [for (final r in requests) _row(context, r)],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusFilterChips() {
    const filters = [
      ('all', 'All'),
      ('pending', 'Pending'),
      ('approved', 'Approved'),
      ('issued', 'Issued'),
      ('rejected', 'Rejected'),
    ];
    return Wrap(
      spacing: 8,
      children: [
        for (final (value, label) in filters)
          ChoiceChip(
            label: Text(label),
            selected: _statusFilter == value,
            onSelected: (_) => setState(() => _statusFilter = value),
          ),
      ],
    );
  }

  DataRow _row(BuildContext context, IssueRequest r) {
    final stock = InventoryService.instance.lookupItem(r.itemId);
    return DataRow(
      cells: [
        DataCell(Text(formatInventoryDate(r.createdAt))),
        DataCell(Text(r.itemName)),
        DataCell(Text(
          '${r.quantity}'
          '${stock != null ? ' / ${stock.quantityAvailable} in stock' : ''}',
        )),
        DataCell(
          SizedBox(
            width: 180,
            child:
                Text(r.purpose, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
        DataCell(Text(
          r.department.isNotEmpty
              ? '${r.requestedByName} (${r.department})'
              : (r.requestedByName.isNotEmpty
                  ? r.requestedByName
                  : r.requestedBy),
        )),
        DataCell(
          (r.status == ApprovalStatus.rejected &&
                  (r.rejectionReason ?? '').isNotEmpty)
              ? Tooltip(
                  message: 'Reason: ${r.rejectionReason}',
                  child: inventoryStatusChip(
                    _statusLabel(r.status),
                    _statusColor(r.status),
                  ),
                )
              : inventoryStatusChip(
                  _statusLabel(r.status),
                  _statusColor(r.status),
                ),
        ),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (r.status == ApprovalStatus.pending &&
                ProcurementPermissions.canApproveIssueRequests) ...[
              IconButton(
                tooltip: 'Approve',
                icon: Icon(Icons.check_circle_outline,
                    color: Colors.green.shade700),
                onPressed: () async {
                  final error = await ProcurementService.instance
                      .approveIssueRequest(r.id);
                  if (context.mounted) {
                    _showResult(context, error, 'Request approved.');
                  }
                },
              ),
              IconButton(
                tooltip: 'Reject',
                icon: Icon(Icons.cancel_outlined, color: Colors.red.shade700),
                onPressed: () async {
                  final reason = await _askRejectionReason(context);
                  if (reason == null) return;
                  final error = await ProcurementService.instance
                      .rejectIssueRequest(r.id, reason);
                  if (context.mounted) {
                    _showResult(context, error, 'Request rejected.');
                  }
                },
              ),
            ],
            if (r.status == ApprovalStatus.approved &&
                ProcurementPermissions.canIssueStock)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.output_outlined, size: 18),
                label: const Text('Issue'),
                onPressed: () async {
                  final error = await ProcurementService.instance
                      .fulfillIssueRequest(r.id);
                  if (context.mounted) {
                    _showResult(
                      context,
                      error,
                      'Stock issued and recorded.',
                    );
                  }
                },
              ),
          ],
        )),
      ],
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final items = InventoryService.instance.filteredItems();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add inventory items before requesting an issue.'),
        ),
      );
      return;
    }

    String? selectedItemId = items.first.id;
    final qtyController = TextEditingController(text: '1');
    final purposeController = TextEditingController();
    final departmentController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Issue Request'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedItemId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Item',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final item in items)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        '${item.name} (${item.quantityAvailable} ${item.unit})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => selectedItemId = v,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: purposeController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(
                  labelText: 'Department (optional)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );

    if (submitted != true || !context.mounted || selectedItemId == null) return;
    final error = await ProcurementService.instance.createIssueRequest(
      itemId: selectedItemId!,
      quantity: int.tryParse(qtyController.text.trim()) ?? 0,
      purpose: purposeController.text,
      department: departmentController.text,
    );
    if (context.mounted) {
      _showResult(context, error, 'Issue request submitted for approval.');
    }
  }
}
