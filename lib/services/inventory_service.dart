import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/models/inventory_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/inventory_persistence_service.dart';
import 'package:mayabela/services/platform_audit_log_service.dart';

class InventoryDashboardStats {
  const InventoryDashboardStats({
    required this.totalItems,
    required this.totalValue,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.recentTransactions,
  });

  final int totalItems;
  final double totalValue;
  final int lowStockCount;
  final int outOfStockCount;
  final List<StockTransaction> recentTransactions;
}

class InventoryService extends ChangeNotifier {
  InventoryService._();
  static final instance = InventoryService._();

  final List<InventoryItem> _items = [];
  final List<StockTransaction> _transactions = [];
  final List<StudentIssuedItem> _studentIssued = [];
  final List<ClassroomInventoryEntry> _classroom = [];
  final List<SchoolAsset> _assets = [];
  final List<InventorySupplier> _suppliers = [];
  final List<InventoryMaintenanceReport> _maintenance = [];

  int _nextItemId = 1;
  int _nextTxnId = 1;
  int _nextIssuedId = 1;
  int _nextClassroomId = 1;
  int _nextAssetId = 1;
  int _nextSupplierId = 1;
  int _nextReportId = 1;

  String? get _schoolId => AuthService.activeSchoolId;

  List<InventoryItem> itemsSnapshot() => List.unmodifiable(_items);
  List<StockTransaction> transactionsSnapshot() =>
      List.unmodifiable(_transactions);
  List<StudentIssuedItem> studentIssuedSnapshot() =>
      List.unmodifiable(_studentIssued);
  List<ClassroomInventoryEntry> classroomSnapshot() =>
      List.unmodifiable(_classroom);
  List<SchoolAsset> assetsSnapshot() => List.unmodifiable(_assets);
  List<InventorySupplier> suppliersSnapshot() => List.unmodifiable(_suppliers);
  List<InventoryMaintenanceReport> maintenanceSnapshot() =>
      List.unmodifiable(_maintenance);

  void applyPersistedData({
    required List<InventoryItem> items,
    required List<StockTransaction> transactions,
    required List<StudentIssuedItem> studentIssued,
    required List<ClassroomInventoryEntry> classroom,
    required List<SchoolAsset> assets,
    required List<InventorySupplier> suppliers,
    required List<InventoryMaintenanceReport> maintenance,
    int? nextItemId,
    int? nextTxnId,
    int? nextIssuedId,
    int? nextClassroomId,
    int? nextAssetId,
    int? nextSupplierId,
    int? nextReportId,
  }) {
    _items
      ..clear()
      ..addAll(items);
    _transactions
      ..clear()
      ..addAll(transactions);
    _studentIssued
      ..clear()
      ..addAll(studentIssued);
    _classroom
      ..clear()
      ..addAll(classroom);
    _assets
      ..clear()
      ..addAll(assets);
    _suppliers
      ..clear()
      ..addAll(suppliers);
    _maintenance
      ..clear()
      ..addAll(maintenance);
    _bumpIds(
      nextItemId: nextItemId,
      nextTxnId: nextTxnId,
      nextIssuedId: nextIssuedId,
      nextClassroomId: nextClassroomId,
      nextAssetId: nextAssetId,
      nextSupplierId: nextSupplierId,
      nextReportId: nextReportId,
    );
    notifyListeners();
  }

  void _bumpIds({
    int? nextItemId,
    int? nextTxnId,
    int? nextIssuedId,
    int? nextClassroomId,
    int? nextAssetId,
    int? nextSupplierId,
    int? nextReportId,
  }) {
    for (final item in _items) {
      final n = _idNum(item.id, 'inv-');
      if (n >= _nextItemId) _nextItemId = n + 1;
    }
    if (nextItemId != null && nextItemId > _nextItemId) _nextItemId = nextItemId;
    if (nextTxnId != null && nextTxnId > _nextTxnId) _nextTxnId = nextTxnId;
    if (nextIssuedId != null && nextIssuedId > _nextIssuedId) {
      _nextIssuedId = nextIssuedId;
    }
    if (nextClassroomId != null && nextClassroomId > _nextClassroomId) {
      _nextClassroomId = nextClassroomId;
    }
    if (nextAssetId != null && nextAssetId > _nextAssetId) _nextAssetId = nextAssetId;
    if (nextSupplierId != null && nextSupplierId > _nextSupplierId) {
      _nextSupplierId = nextSupplierId;
    }
    if (nextReportId != null && nextReportId > _nextReportId) {
      _nextReportId = nextReportId;
    }
  }

  int _idNum(String id, String prefix) {
    if (!id.startsWith(prefix)) return 0;
    return int.tryParse(id.substring(prefix.length)) ?? 0;
  }

  InventoryItem? lookupItem(String id) {
    try {
      return _items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  List<InventoryItem> filteredItems({
    String? query,
    InventoryItemCategory? category,
    String? stockFilter,
  }) {
    var list = _items.where((i) {
      final sid = _schoolId;
      if (sid != null && i.schoolId != null && i.schoolId != sid) return false;
      return true;
    });
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where(
        (i) =>
            i.name.toLowerCase().contains(q) ||
            i.id.toLowerCase().contains(q) ||
            i.description.toLowerCase().contains(q),
      );
    }
    if (category != null) {
      list = list.where((i) => i.category == category);
    }
    if (stockFilter == 'low') {
      list = list.where((i) => i.isLowStock);
    } else if (stockFilter == 'out') {
      list = list.where((i) => i.isOutOfStock);
    }
    return list.toList();
  }

  InventoryDashboardStats dashboardStats() {
    final active = filteredItems();
    return InventoryDashboardStats(
      totalItems: active.length,
      totalValue: active.fold(0.0, (s, i) => s + i.inventoryValue),
      lowStockCount: active.where((i) => i.isLowStock).length,
      outOfStockCount: active.where((i) => i.isOutOfStock).length,
      recentTransactions: _transactions.take(8).toList(),
    );
  }

  Future<void> _persist() async {
    await InventoryPersistenceService.instance.saveFromService();
    notifyListeners();
  }

  Future<void> _audit(String action, {String? detail}) async {
    await PlatformAuditLogService.instance.log(
      action: action,
      schoolId: _schoolId,
      detail: detail,
    );
  }

  Future<InventoryItem> addItem({
    required String name,
    required InventoryItemCategory category,
    required String description,
    required int quantityAvailable,
    required String unit,
    required int minimumStockLevel,
    required String storageLocation,
    required double purchasePrice,
    required String supplier,
    InventoryItemStatus status = InventoryItemStatus.active,
    String? imagePath,
  }) async {
    final item = InventoryItem(
      id: 'inv-${_nextItemId++}',
      name: name.trim(),
      category: category,
      description: description.trim(),
      quantityAvailable: quantityAvailable,
      unit: unit.trim(),
      minimumStockLevel: minimumStockLevel,
      storageLocation: storageLocation.trim(),
      purchasePrice: purchasePrice,
      supplier: supplier.trim(),
      dateAdded: DateTime.now(),
      status: status,
      schoolId: _schoolId,
      imagePath: imagePath,
    );
    _items.insert(0, item);
    await _audit('inventory_item_created', detail: '${item.id} ${item.name}');
    await _persist();
    return item;
  }

  Future<bool> updateItem(InventoryItem updated) async {
    final index = _items.indexWhere((i) => i.id == updated.id);
    if (index < 0) return false;
    _items[index] = updated;
    await _audit('inventory_item_updated', detail: updated.id);
    await _persist();
    return true;
  }

  Future<bool> deleteItem(String id) async {
    final before = _items.length;
    _items.removeWhere((i) => i.id == id);
    final removed = _items.length < before;
    if (!removed) return false;
    await _audit('inventory_item_deleted', detail: id);
    await _persist();
    return true;
  }

  Future<String?> recordStockIn({
    required String itemId,
    required int quantity,
    String? supplierOrDonor,
    String? invoiceNumber,
    String? receivedBy,
    String? notes,
    String? invoiceAttachmentPath,
  }) async {
    if (quantity <= 0) return 'Quantity must be positive';
    final item = lookupItem(itemId);
    if (item == null) return 'Item not found';

    item.quantityAvailable += quantity;
    final actor = AuthService.displayNameForRole(
      AuthService.currentUser?.roleKey ?? AuthService.roleAdmin,
    );
    _transactions.insert(
      0,
      StockTransaction(
        id: 'txn-in-${_nextTxnId++}',
        direction: InventoryStockDirection.stockIn,
        date: DateTime.now(),
        itemId: item.id,
        itemName: item.name,
        quantity: quantity,
        actorName: actor,
        supplierOrDonor: supplierOrDonor,
        invoiceNumber: invoiceNumber,
        receivedBy: receivedBy ?? actor,
        notes: notes,
        schoolId: _schoolId,
        invoiceAttachmentPath: invoiceAttachmentPath,
      ),
    );
    await _audit('inventory_stock_in', detail: '${item.name} +$quantity');
    await _persist();
    return null;
  }

  Future<bool> setTransactionInvoiceAttachment(
    String txnId,
    String attachmentPath,
  ) async {
    final index = _transactions.indexWhere((t) => t.id == txnId);
    if (index < 0) return false;
    final old = _transactions[index];
    _transactions[index] = StockTransaction(
      id: old.id,
      direction: old.direction,
      date: old.date,
      itemId: old.itemId,
      itemName: old.itemName,
      quantity: old.quantity,
      actorName: old.actorName,
      supplierOrDonor: old.supplierOrDonor,
      invoiceNumber: old.invoiceNumber,
      receivedBy: old.receivedBy,
      issuedTo: old.issuedTo,
      issueTarget: old.issueTarget,
      approvedBy: old.approvedBy,
      reason: old.reason,
      notes: old.notes,
      schoolId: old.schoolId,
      invoiceAttachmentPath: attachmentPath,
    );
    await _persist();
    return true;
  }

  Future<String?> recordStockOut({
    required String itemId,
    required int quantity,
    required String issuedTo,
    required InventoryIssueTarget issueTarget,
    String? approvedBy,
    String? reason,
    String? notes,
    bool linkStudentIssue = false,
    String? studentId,
    String? studentName,
    String? gradeClass,
  }) async {
    if (quantity <= 0) return 'Quantity must be positive';
    final item = lookupItem(itemId);
    if (item == null) return 'Item not found';
    if (item.quantityAvailable < quantity) {
      return 'Insufficient stock (${item.quantityAvailable} available)';
    }

    item.quantityAvailable -= quantity;
    final actor = AuthService.displayNameForRole(
      AuthService.currentUser?.roleKey ?? AuthService.roleAdmin,
    );
    _transactions.insert(
      0,
      StockTransaction(
        id: 'txn-out-${_nextTxnId++}',
        direction: InventoryStockDirection.stockOut,
        date: DateTime.now(),
        itemId: item.id,
        itemName: item.name,
        quantity: quantity,
        actorName: actor,
        issuedTo: issuedTo,
        issueTarget: issueTarget,
        approvedBy: approvedBy ?? actor,
        reason: reason,
        notes: notes,
        schoolId: _schoolId,
      ),
    );

    if (linkStudentIssue &&
        studentId != null &&
        studentName != null &&
        gradeClass != null) {
      _studentIssued.insert(
        0,
        StudentIssuedItem(
          id: 'iss-${_nextIssuedId++}',
          studentId: studentId,
          studentName: studentName,
          gradeClass: gradeClass,
          itemId: item.id,
          itemName: item.name,
          quantity: quantity,
          dateIssued: DateTime.now(),
          schoolId: _schoolId,
        ),
      );
    }

    await _audit('inventory_stock_out', detail: '${item.name} -$quantity');
    await _persist();
    return null;
  }

  Future<StudentIssuedItem> addStudentIssued({
    required String studentId,
    required String studentName,
    required String gradeClass,
    required String itemId,
    required int quantity,
  }) async {
    final item = lookupItem(itemId);
    final entry = StudentIssuedItem(
      id: 'iss-${_nextIssuedId++}',
      studentId: studentId,
      studentName: studentName,
      gradeClass: gradeClass,
      itemId: itemId,
      itemName: item?.name ?? itemId,
      quantity: quantity,
      dateIssued: DateTime.now(),
      schoolId: _schoolId,
    );
    _studentIssued.insert(0, entry);
    await _persist();
    return entry;
  }

  Future<bool> updateStudentIssuedStatus(
    String id,
    StudentIssueReturnStatus status,
  ) async {
    final index = _studentIssued.indexWhere((e) => e.id == id);
    if (index < 0) return false;
    _studentIssued[index].returnStatus = status;
    await _persist();
    return true;
  }

  Future<ClassroomInventoryEntry> addClassroomEntry({
    required String classroomName,
    required String grade,
    required String itemId,
    required int quantity,
    required String condition,
  }) async {
    final item = lookupItem(itemId);
    final entry = ClassroomInventoryEntry(
      id: 'cls-${_nextClassroomId++}',
      classroomName: classroomName,
      grade: grade,
      itemId: itemId,
      itemName: item?.name ?? itemId,
      quantity: quantity,
      condition: condition,
      schoolId: _schoolId,
    );
    _classroom.insert(0, entry);
    await _persist();
    return entry;
  }

  Future<SchoolAsset> addAsset({
    required String name,
    required String category,
    required String serialNumber,
    required DateTime purchaseDate,
    required double purchasePrice,
    required String location,
    required String assignedPerson,
    AssetCondition condition = AssetCondition.good,
    String? imagePath,
  }) async {
    final asset = SchoolAsset(
      id: 'ast-${_nextAssetId++}',
      name: name.trim(),
      category: category.trim(),
      serialNumber: serialNumber.trim(),
      purchaseDate: purchaseDate,
      purchasePrice: purchasePrice,
      location: location.trim(),
      assignedPerson: assignedPerson.trim(),
      condition: condition,
      schoolId: _schoolId,
      imagePath: imagePath,
    );
    _assets.insert(0, asset);
    await _audit('inventory_asset_added', detail: asset.name);
    await _persist();
    return asset;
  }

  Future<bool> updateAsset(SchoolAsset asset) async {
    final index = _assets.indexWhere((a) => a.id == asset.id);
    if (index < 0) return false;
    _assets[index] = asset;
    await _persist();
    return true;
  }

  Future<InventorySupplier> addSupplier({
    required String name,
    required String contact,
    required String address,
    required String productsSupplied,
  }) async {
    final supplier = InventorySupplier(
      id: 'sup-${_nextSupplierId++}',
      name: name.trim(),
      contact: contact.trim(),
      address: address.trim(),
      productsSupplied: productsSupplied.trim(),
      schoolId: _schoolId,
    );
    _suppliers.insert(0, supplier);
    await _persist();
    return supplier;
  }

  Future<InventoryMaintenanceReport> addMaintenanceReport({
    required String itemOrAsset,
    required String description,
  }) async {
    final actor = AuthService.displayNameForRole(
      AuthService.currentUser?.roleKey ?? AuthService.roleAdmin,
    );
    final report = InventoryMaintenanceReport(
      id: 'mnt-${_nextReportId++}',
      itemOrAsset: itemOrAsset.trim(),
      reportedBy: actor,
      date: DateTime.now(),
      description: description.trim(),
      schoolId: _schoolId,
    );
    _maintenance.insert(0, report);
    await _persist();
    return report;
  }

  Future<bool> updateMaintenanceStatus(
    String id,
    MaintenanceReportStatus status,
  ) async {
    final index = _maintenance.indexWhere((r) => r.id == id);
    if (index < 0) return false;
    _maintenance[index].status = status;
    await _persist();
    return true;
  }

  void seedDemoDataIfEmpty() {
    if (_items.isNotEmpty) return;
    final sid = _schoolId;
    _items.addAll([
      InventoryItem(
        id: 'inv-${_nextItemId++}',
        name: 'Mathematics Textbook Grade 5',
        category: InventoryItemCategory.booksLearning,
        description: 'Official curriculum mathematics book',
        quantityAvailable: 120,
        unit: 'piece',
        minimumStockLevel: 20,
        storageLocation: 'Library Store',
        purchasePrice: 85,
        supplier: 'Ethio Books PLC',
        dateAdded: DateTime.now().subtract(const Duration(days: 30)),
        schoolId: sid,
      ),
      InventoryItem(
        id: 'inv-${_nextItemId++}',
        name: 'Student Desk',
        category: InventoryItemCategory.furniture,
        description: 'Standard classroom desk',
        quantityAvailable: 8,
        unit: 'piece',
        minimumStockLevel: 10,
        storageLocation: 'Warehouse A',
        purchasePrice: 1200,
        supplier: 'Addis Furniture',
        dateAdded: DateTime.now().subtract(const Duration(days: 60)),
        schoolId: sid,
      ),
      InventoryItem(
        id: 'inv-${_nextItemId++}',
        name: 'A4 Exercise Book',
        category: InventoryItemCategory.stationery,
        description: '80-page ruled exercise book',
        quantityAvailable: 0,
        unit: 'box',
        minimumStockLevel: 15,
        storageLocation: 'Stationery Room',
        purchasePrice: 45,
        supplier: 'Paper World',
        dateAdded: DateTime.now().subtract(const Duration(days: 10)),
        schoolId: sid,
      ),
    ]);
    _assets.add(
      SchoolAsset(
        id: 'ast-${_nextAssetId++}',
        name: 'Epson Projector',
        category: 'Electronics',
        serialNumber: 'EP-2024-001',
        purchaseDate: DateTime(2024, 3, 1),
        purchasePrice: 18500,
        location: 'Grade 5A',
        assignedPerson: 'Science Department',
        condition: AssetCondition.good,
        schoolId: sid,
      ),
    );
    unawaited(_persist());
  }

  int nextItemIdSnapshot() => _nextItemId;
  int nextTxnIdSnapshot() => _nextTxnId;
  int nextIssuedIdSnapshot() => _nextIssuedId;
  int nextClassroomIdSnapshot() => _nextClassroomId;
  int nextAssetIdSnapshot() => _nextAssetId;
  int nextSupplierIdSnapshot() => _nextSupplierId;
  int nextReportIdSnapshot() => _nextReportId;
}
