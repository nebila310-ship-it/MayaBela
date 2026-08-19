import 'package:flutter/material.dart';

import 'package:mayabela/models/inventory_models.dart';
import 'package:mayabela/services/inventory_service.dart';
import 'package:mayabela/services/inventory_storage_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';

void _showUploadFeedback(BuildContext context, InventoryUploadResult result) {
  if (!context.mounted || result.usedCloud || result.message == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(result.message!),
      duration: const Duration(seconds: 6),
    ),
  );
}

Future<void> showInventoryItemDialog(
  BuildContext context, {
  InventoryItem? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final descCtrl = TextEditingController(text: existing?.description ?? '');
  final qtyCtrl = TextEditingController(
    text: '${existing?.quantityAvailable ?? 0}',
  );
  final unitCtrl = TextEditingController(text: existing?.unit ?? 'piece');
  final minCtrl = TextEditingController(
    text: '${existing?.minimumStockLevel ?? 5}',
  );
  final locCtrl = TextEditingController(
    text: existing?.storageLocation ?? 'Main Store',
  );
  final priceCtrl = TextEditingController(
    text: '${existing?.purchasePrice ?? 0}',
  );
  final supplierCtrl = TextEditingController(text: existing?.supplier ?? '');
  var category =
      existing?.category ?? InventoryItemCategory.stationery;
  var status = existing?.status ?? InventoryItemStatus.active;
  InventoryPickResult? imagePick;
  var imagePath = existing?.imagePath;
  final storage = InventoryStorageService.instance;

  final saved = await showAdminFormDialog(
    context: context,
    title: existing == null ? 'Add Inventory Item' : 'Edit Item',
    accent: WebErpTheme.primary,
    icon: Icons.inventory_2_outlined,
    builder: (ctx, setDialogState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        adminDialogField(
          TextField(
            controller: nameCtrl,
            decoration: adminFieldDecoration(
              label: 'Item Name',
              icon: Icons.label_outline,
              accent: WebErpTheme.primary,
            ),
          ),
        ),
        adminDialogField(
          DropdownButtonFormField<InventoryItemCategory>(
            initialValue: category,
            decoration: adminFieldDecoration(
              label: 'Category',
              icon: Icons.category_outlined,
              accent: WebErpTheme.primary,
            ),
            items: InventoryItemCategory.values
                .map(
                  (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setDialogState(() => category = v);
            },
          ),
        ),
        adminDialogField(
          TextField(
            controller: descCtrl,
            maxLines: 2,
            decoration: adminFieldDecoration(
              label: 'Description',
              icon: Icons.notes_outlined,
              accent: WebErpTheme.primary,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: adminDialogField(
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: adminDialogField(
                TextField(
                  controller: unitCtrl,
                  decoration: adminFieldDecoration(
                    label: 'Unit',
                    icon: Icons.straighten_outlined,
                    accent: WebErpTheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: adminDialogField(
                TextField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: adminFieldDecoration(
                    label: 'Minimum Stock',
                    icon: Icons.warning_amber_outlined,
                    accent: WebErpTheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: adminDialogField(
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: adminFieldDecoration(
                    label: 'Purchase Price (ETB)',
                    icon: Icons.payments_outlined,
                    accent: WebErpTheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        adminDialogField(
          TextField(
            controller: locCtrl,
            decoration: adminFieldDecoration(
              label: 'Storage Location',
              icon: Icons.warehouse_outlined,
              accent: WebErpTheme.primary,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: supplierCtrl,
            decoration: adminFieldDecoration(
              label: 'Supplier',
              icon: Icons.local_shipping_outlined,
              accent: WebErpTheme.primary,
            ),
          ),
        ),
        adminDialogField(
          DropdownButtonFormField<InventoryItemStatus>(
            initialValue: status,
            decoration: adminFieldDecoration(
              label: 'Status',
              icon: Icons.toggle_on_outlined,
              accent: WebErpTheme.primary,
            ),
            items: InventoryItemStatus.values
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.name == 'active' ? 'Active' : 'Inactive'),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setDialogState(() => status = v);
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            imagePick = await storage.pickImage();
            if (imagePick != null) {
              setDialogState(() => imagePath = imagePick!.fileName);
            }
          },
          icon: const Icon(Icons.image_outlined),
          label: Text(
            imagePick != null
                ? 'Image: ${imagePick!.fileName}'
                : imagePath != null
                    ? storage.displayLabel(imagePath)
                    : 'Attach Item Image',
          ),
        ),
      ],
    ),
  );

  if (!saved || !context.mounted) return;

  final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
  final min = int.tryParse(minCtrl.text.trim()) ?? 5;
  final price = double.tryParse(priceCtrl.text.trim()) ?? 0;

  if (existing == null) {
    final item = await InventoryService.instance.addItem(
      name: nameCtrl.text,
      category: category,
      description: descCtrl.text,
      quantityAvailable: qty,
      unit: unitCtrl.text,
      minimumStockLevel: min,
      storageLocation: locCtrl.text,
      purchasePrice: price,
      supplier: supplierCtrl.text,
      status: status,
    );
    if (imagePick != null) {
      final upload = await storage.uploadForEntity(
        pick: imagePick!,
        kind: InventoryStorageKind.itemImage,
        entityId: item.id,
      );
      if (context.mounted) _showUploadFeedback(context, upload);
      if (upload.path != null) {
        await InventoryService.instance.updateItem(
          InventoryItem(
            id: item.id,
            name: item.name,
            category: item.category,
            description: item.description,
            quantityAvailable: item.quantityAvailable,
            unit: item.unit,
            minimumStockLevel: item.minimumStockLevel,
            storageLocation: item.storageLocation,
            purchasePrice: item.purchasePrice,
            supplier: item.supplier,
            dateAdded: item.dateAdded,
            status: item.status,
            schoolId: item.schoolId,
            imagePath: upload.path,
          ),
        );
      }
    }
  } else {
    var resolvedImage = existing.imagePath;
    if (imagePick != null) {
      final upload = await storage.uploadForEntity(
        pick: imagePick!,
        kind: InventoryStorageKind.itemImage,
        entityId: existing.id,
      );
      if (context.mounted) _showUploadFeedback(context, upload);
      resolvedImage = upload.path ?? resolvedImage;
    }
    await InventoryService.instance.updateItem(
      InventoryItem(
        id: existing.id,
        name: nameCtrl.text.trim(),
        category: category,
        description: descCtrl.text.trim(),
        quantityAvailable: qty,
        unit: unitCtrl.text.trim(),
        minimumStockLevel: min,
        storageLocation: locCtrl.text.trim(),
        purchasePrice: price,
        supplier: supplierCtrl.text.trim(),
        dateAdded: existing.dateAdded,
        status: status,
        schoolId: existing.schoolId,
        imagePath: resolvedImage,
      ),
    );
  }
}

Future<void> showStockInDialog(BuildContext context) async {
  final svc = InventoryService.instance;
  final items = svc.itemsSnapshot();
  if (items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add inventory items first')),
    );
    return;
  }

  var itemId = items.first.id;
  final qtyCtrl = TextEditingController(text: '1');
  final supplierCtrl = TextEditingController();
  final invoiceCtrl = TextEditingController();
  final receivedCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  InventoryPickResult? invoicePick;
  final storage = InventoryStorageService.instance;

  final saved = await showAdminFormDialog(
    context: context,
    title: 'Record Stock In',
    accent: Colors.green.shade700,
    icon: Icons.add_box_outlined,
    saveLabel: 'Receive Stock',
    builder: (ctx, setDialogState) => Column(
      children: [
        adminDialogField(
          DropdownButtonFormField<String>(
            initialValue: itemId,
            decoration: adminFieldDecoration(
              label: 'Item',
              icon: Icons.inventory_outlined,
              accent: Colors.green.shade700,
            ),
            items: items
                .map(
                  (i) => DropdownMenuItem(
                    value: i.id,
                    child: Text('${i.name} (${i.quantityAvailable})'),
                  ),
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
              label: 'Quantity Added',
              icon: Icons.add,
              accent: Colors.green.shade700,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: supplierCtrl,
            decoration: adminFieldDecoration(
              label: 'Supplier / Donor',
              icon: Icons.business_outlined,
              accent: Colors.green.shade700,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: invoiceCtrl,
            decoration: adminFieldDecoration(
              label: 'Invoice Number',
              icon: Icons.receipt_long_outlined,
              accent: Colors.green.shade700,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: receivedCtrl,
            decoration: adminFieldDecoration(
              label: 'Received By',
              icon: Icons.person_outline,
              accent: Colors.green.shade700,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: adminFieldDecoration(
              label: 'Notes',
              icon: Icons.notes_outlined,
              accent: Colors.green.shade700,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            invoicePick = await storage.pickInvoiceFile();
            if (invoicePick != null) setDialogState(() {});
          },
          icon: const Icon(Icons.attach_file),
          label: Text(
            invoicePick != null
                ? 'Invoice: ${invoicePick!.fileName}'
                : 'Attach Invoice (PDF/Image)',
          ),
        ),
      ],
    ),
  );

  if (!saved || !context.mounted) return;
  final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
  final err = await svc.recordStockIn(
    itemId: itemId,
    quantity: qty,
    supplierOrDonor: supplierCtrl.text.trim().isEmpty
        ? null
        : supplierCtrl.text.trim(),
    invoiceNumber:
        invoiceCtrl.text.trim().isEmpty ? null : invoiceCtrl.text.trim(),
    receivedBy:
        receivedCtrl.text.trim().isEmpty ? null : receivedCtrl.text.trim(),
    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
  );
  if (err != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
    return;
  }
  if (invoicePick != null) {
    final txn = svc.transactionsSnapshot().first;
    final upload = await storage.uploadForEntity(
      pick: invoicePick!,
      kind: InventoryStorageKind.invoiceAttachment,
      entityId: txn.id,
    );
    if (context.mounted) _showUploadFeedback(context, upload);
    if (upload.path != null) {
      await svc.setTransactionInvoiceAttachment(txn.id, upload.path!);
    }
  }
}

Future<void> showStockOutDialog(BuildContext context) async {
  final svc = InventoryService.instance;
  final items = svc.itemsSnapshot().where((i) => i.quantityAvailable > 0);
  final list = items.toList();
  if (list.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No items with available stock')),
    );
    return;
  }

  var itemId = list.first.id;
  final qtyCtrl = TextEditingController(text: '1');
  final issuedToCtrl = TextEditingController();
  final approvedCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  var issueTarget = InventoryIssueTarget.classroom;
  var linkStudent = false;
  final studentIdCtrl = TextEditingController();
  final studentNameCtrl = TextEditingController();
  final gradeCtrl = TextEditingController();

  final saved = await showAdminFormDialog(
    context: context,
    title: 'Record Stock Out',
    accent: Colors.orange.shade800,
    icon: Icons.remove_circle_outline,
    saveLabel: 'Issue Stock',
    builder: (ctx, setDialogState) => Column(
      children: [
        adminDialogField(
          DropdownButtonFormField<String>(
            initialValue: itemId,
            decoration: adminFieldDecoration(
              label: 'Item',
              icon: Icons.inventory_outlined,
              accent: Colors.orange.shade800,
            ),
            items: list
                .map(
                  (i) => DropdownMenuItem(
                    value: i.id,
                    child: Text('${i.name} (${i.quantityAvailable} left)'),
                  ),
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
              label: 'Quantity Issued',
              icon: Icons.remove,
              accent: Colors.orange.shade800,
            ),
          ),
        ),
        adminDialogField(
          DropdownButtonFormField<InventoryIssueTarget>(
            initialValue: issueTarget,
            decoration: adminFieldDecoration(
              label: 'Issued To Type',
              icon: Icons.group_outlined,
              accent: Colors.orange.shade800,
            ),
            items: InventoryIssueTarget.values
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name[0].toUpperCase() + t.name.substring(1)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setDialogState(() => issueTarget = v);
            },
          ),
        ),
        adminDialogField(
          TextField(
            controller: issuedToCtrl,
            decoration: adminFieldDecoration(
              label: 'Issued To (name / class / dept)',
              icon: Icons.person_pin_outlined,
              accent: Colors.orange.shade800,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: approvedCtrl,
            decoration: adminFieldDecoration(
              label: 'Approved By',
              icon: Icons.verified_user_outlined,
              accent: Colors.orange.shade800,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: reasonCtrl,
            decoration: adminFieldDecoration(
              label: 'Reason',
              icon: Icons.help_outline,
              accent: Colors.orange.shade800,
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Track as student issued item'),
          value: linkStudent,
          onChanged: (v) => setDialogState(() => linkStudent = v),
        ),
        if (linkStudent) ...[
          adminDialogField(
            TextField(
              controller: studentIdCtrl,
              decoration: adminFieldDecoration(
                label: 'Student ID',
                icon: Icons.badge_outlined,
                accent: Colors.orange.shade800,
              ),
            ),
          ),
          adminDialogField(
            TextField(
              controller: studentNameCtrl,
              decoration: adminFieldDecoration(
                label: 'Student Name',
                icon: Icons.person_outline,
                accent: Colors.orange.shade800,
              ),
            ),
          ),
          adminDialogField(
            TextField(
              controller: gradeCtrl,
              decoration: adminFieldDecoration(
                label: 'Grade / Class',
                icon: Icons.class_outlined,
                accent: Colors.orange.shade800,
              ),
            ),
          ),
        ],
        adminDialogField(
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: adminFieldDecoration(
              label: 'Notes',
              icon: Icons.notes_outlined,
              accent: Colors.orange.shade800,
            ),
          ),
        ),
      ],
    ),
  );

  if (!saved || !context.mounted) return;
  final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
  final err = await svc.recordStockOut(
    itemId: itemId,
    quantity: qty,
    issuedTo: issuedToCtrl.text.trim(),
    issueTarget: issueTarget,
    approvedBy:
        approvedCtrl.text.trim().isEmpty ? null : approvedCtrl.text.trim(),
    reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    linkStudentIssue: linkStudent,
    studentId: linkStudent ? studentIdCtrl.text.trim() : null,
    studentName: linkStudent ? studentNameCtrl.text.trim() : null,
    gradeClass: linkStudent ? gradeCtrl.text.trim() : null,
  );
  if (err != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }
}

Future<void> showAssetDialog(
  BuildContext context, {
  SchoolAsset? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final catCtrl = TextEditingController(text: existing?.category ?? 'Electronics');
  final serialCtrl = TextEditingController(text: existing?.serialNumber ?? '');
  final locCtrl = TextEditingController(text: existing?.location ?? '');
  final assignedCtrl =
      TextEditingController(text: existing?.assignedPerson ?? '');
  final priceCtrl =
      TextEditingController(text: '${existing?.purchasePrice ?? 0}');
  var purchaseDate = existing?.purchaseDate ?? DateTime.now();
  var condition = existing?.condition ?? AssetCondition.good;
  InventoryPickResult? photoPick;
  var imagePath = existing?.imagePath;
  final storage = InventoryStorageService.instance;

  final saved = await showAdminFormDialog(
    context: context,
    title: existing == null ? 'Add Asset' : 'Edit Asset',
    accent: WebErpTheme.primary,
    icon: Icons.devices_outlined,
    builder: (ctx, setDialogState) => Column(
      children: [
        adminDialogField(
          TextField(
            controller: nameCtrl,
            decoration: adminFieldDecoration(
              label: 'Asset Name',
              icon: Icons.devices_outlined,
              accent: WebErpTheme.primary,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: catCtrl,
            decoration: adminFieldDecoration(
              label: 'Category',
              icon: Icons.category_outlined,
              accent: WebErpTheme.primary,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: serialCtrl,
            decoration: adminFieldDecoration(
              label: 'Serial Number',
              icon: Icons.qr_code_2_outlined,
              accent: WebErpTheme.primary,
            ),
          ),
        ),
        ListTile(
          title: const Text('Purchase Date'),
          subtitle: Text(
            '${purchaseDate.year}-${purchaseDate.month.toString().padLeft(2, '0')}-${purchaseDate.day.toString().padLeft(2, '0')}',
          ),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: () async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: purchaseDate,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setDialogState(() => purchaseDate = picked);
          },
        ),
        adminDialogField(
          TextField(
            controller: priceCtrl,
            keyboardType: TextInputType.number,
            decoration: adminFieldDecoration(
              label: 'Purchase Price (ETB)',
              icon: Icons.payments_outlined,
              accent: WebErpTheme.primary,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: locCtrl,
            decoration: adminFieldDecoration(
              label: 'Location',
              icon: Icons.place_outlined,
              accent: WebErpTheme.primary,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: assignedCtrl,
            decoration: adminFieldDecoration(
              label: 'Assigned Person / Dept',
              icon: Icons.person_outline,
              accent: WebErpTheme.primary,
            ),
          ),
        ),
        adminDialogField(
          DropdownButtonFormField<AssetCondition>(
            initialValue: condition,
            decoration: adminFieldDecoration(
              label: 'Condition',
              icon: Icons.build_outlined,
              accent: WebErpTheme.primary,
            ),
            items: AssetCondition.values
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(switch (c) {
                      AssetCondition.newItem => 'New',
                      AssetCondition.good => 'Good',
                      AssetCondition.needsRepair => 'Needs Repair',
                      AssetCondition.damaged => 'Damaged',
                    }),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setDialogState(() => condition = v);
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            photoPick = await storage.pickImage();
            if (photoPick != null) {
              setDialogState(() => imagePath = photoPick!.fileName);
            }
          },
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(
            photoPick != null
                ? 'Photo: ${photoPick!.fileName}'
                : imagePath != null
                    ? storage.displayLabel(imagePath)
                    : 'Attach Asset Photo',
          ),
        ),
      ],
    ),
  );

  if (!saved || !context.mounted) return;
  final price = double.tryParse(priceCtrl.text.trim()) ?? 0;

  if (existing == null) {
    final asset = await InventoryService.instance.addAsset(
      name: nameCtrl.text,
      category: catCtrl.text,
      serialNumber: serialCtrl.text,
      purchaseDate: purchaseDate,
      purchasePrice: price,
      location: locCtrl.text,
      assignedPerson: assignedCtrl.text,
      condition: condition,
    );
    if (photoPick != null) {
      final upload = await storage.uploadForEntity(
        pick: photoPick!,
        kind: InventoryStorageKind.assetPhoto,
        entityId: asset.id,
      );
      if (context.mounted) _showUploadFeedback(context, upload);
      if (upload.path != null) {
        await InventoryService.instance.updateAsset(
          SchoolAsset(
            id: asset.id,
            name: asset.name,
            category: asset.category,
            serialNumber: asset.serialNumber,
            purchaseDate: asset.purchaseDate,
            purchasePrice: asset.purchasePrice,
            location: asset.location,
            assignedPerson: asset.assignedPerson,
            condition: asset.condition,
            schoolId: asset.schoolId,
            imagePath: upload.path,
          ),
        );
      }
    }
  } else {
    var resolvedImage = existing.imagePath;
    if (photoPick != null) {
      final upload = await storage.uploadForEntity(
        pick: photoPick!,
        kind: InventoryStorageKind.assetPhoto,
        entityId: existing.id,
      );
      if (context.mounted) _showUploadFeedback(context, upload);
      resolvedImage = upload.path ?? resolvedImage;
    }
    await InventoryService.instance.updateAsset(
      SchoolAsset(
        id: existing.id,
        name: nameCtrl.text.trim(),
        category: catCtrl.text.trim(),
        serialNumber: serialCtrl.text.trim(),
        purchaseDate: purchaseDate,
        purchasePrice: price,
        location: locCtrl.text.trim(),
        assignedPerson: assignedCtrl.text.trim(),
        condition: condition,
        schoolId: existing.schoolId,
        imagePath: resolvedImage,
      ),
    );
  }
}

Future<void> showSupplierDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final productsCtrl = TextEditingController();

  final saved = await showAdminFormDialog(
    context: context,
    title: 'Add Supplier',
    accent: WebErpTheme.primary,
    icon: Icons.local_shipping_outlined,
    builder: (ctx, setDialogState) => Column(
      children: [
        adminDialogField(
          TextField(
            controller: nameCtrl,
            decoration: adminFieldDecoration(
              label: 'Supplier Name',
              icon: Icons.business_outlined,
              accent: WebErpTheme.primary,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: contactCtrl,
            decoration: adminFieldDecoration(
              label: 'Contact Information',
              icon: Icons.phone_outlined,
              accent: WebErpTheme.primary,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: addressCtrl,
            decoration: adminFieldDecoration(
              label: 'Address',
              icon: Icons.location_on_outlined,
              accent: WebErpTheme.primary,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: productsCtrl,
            maxLines: 2,
            decoration: adminFieldDecoration(
              label: 'Products Supplied',
              icon: Icons.shopping_bag_outlined,
              accent: WebErpTheme.primary,
            ),
          ),
        ),
      ],
    ),
  );

  if (!saved || !context.mounted) return;
  await InventoryService.instance.addSupplier(
    name: nameCtrl.text,
    contact: contactCtrl.text,
    address: addressCtrl.text,
    productsSupplied: productsCtrl.text,
  );
}

Future<void> showMaintenanceDialog(BuildContext context) async {
  final itemCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  final saved = await showAdminFormDialog(
    context: context,
    title: 'Report Damage / Maintenance',
    accent: Colors.red.shade700,
    icon: Icons.report_problem_outlined,
    saveLabel: 'Submit Report',
    builder: (ctx, setDialogState) => Column(
      children: [
        adminDialogField(
          TextField(
            controller: itemCtrl,
            decoration: adminFieldDecoration(
              label: 'Item / Asset',
              icon: Icons.inventory_outlined,
              accent: Colors.red.shade700,
            ),
          ),
        ),
        adminDialogField(
          TextField(
            controller: descCtrl,
            maxLines: 3,
            decoration: adminFieldDecoration(
              label: 'Problem Description',
              icon: Icons.description_outlined,
              accent: Colors.red.shade700,
            ),
          ),
        ),
      ],
    ),
  );

  if (!saved || !context.mounted) return;
  await InventoryService.instance.addMaintenanceReport(
    itemOrAsset: itemCtrl.text,
    description: descCtrl.text,
  );
}
