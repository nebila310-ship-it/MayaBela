import 'package:mayabela/models/inventory_models.dart';
import 'package:mayabela/services/inventory_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

/// Persists school inventory locally and syncs to Firestore.
class InventoryPersistenceService {
  InventoryPersistenceService._();
  static final instance = InventoryPersistenceService._();

  static const _itemsKey = 'inventory_items_v1';
  static const _transactionsKey = 'stock_transactions_v1';
  static const _studentIssuedKey = 'student_issued_items_v1';
  static const _classroomKey = 'classroom_inventory_v1';
  static const _assetsKey = 'inventory_assets_v1';
  static const _suppliersKey = 'inventory_suppliers_v1';
  static const _maintenanceKey = 'maintenance_reports_v1';
  static const _nextItemIdKey = 'inventory_next_item_id';
  static const _nextTxnIdKey = 'inventory_next_txn_id';
  static const _nextIssuedIdKey = 'inventory_next_issued_id';
  static const _nextClassroomIdKey = 'inventory_next_classroom_id';
  static const _nextAssetIdKey = 'inventory_next_asset_id';
  static const _nextSupplierIdKey = 'inventory_next_supplier_id';
  static const _nextReportIdKey = 'inventory_next_report_id';

  Future<void> loadIntoService() async {
    final items = await _readList(_itemsKey, InventoryItem.fromMap);
    final txns =
        await _readList(_transactionsKey, StockTransaction.fromMap);
    final issued =
        await _readList(_studentIssuedKey, StudentIssuedItem.fromMap);
    final classroom =
        await _readList(_classroomKey, ClassroomInventoryEntry.fromMap);
    final assets = await _readList(_assetsKey, SchoolAsset.fromMap);
    final suppliers =
        await _readList(_suppliersKey, InventorySupplier.fromMap);
    final maintenance =
        await _readList(_maintenanceKey, InventoryMaintenanceReport.fromMap);

    if (items.isEmpty &&
        txns.isEmpty &&
        issued.isEmpty &&
        classroom.isEmpty &&
        assets.isEmpty &&
        suppliers.isEmpty &&
        maintenance.isEmpty) {
      InventoryService.instance.seedDemoDataIfEmpty();
      return;
    }

    InventoryService.instance.applyPersistedData(
      items: items,
      transactions: txns,
      studentIssued: issued,
      classroom: classroom,
      assets: assets,
      suppliers: suppliers,
      maintenance: maintenance,
      nextItemId: await LocalJsonStore.readInt(_nextItemIdKey),
      nextTxnId: await LocalJsonStore.readInt(_nextTxnIdKey),
      nextIssuedId: await LocalJsonStore.readInt(_nextIssuedIdKey),
      nextClassroomId: await LocalJsonStore.readInt(_nextClassroomIdKey),
      nextAssetId: await LocalJsonStore.readInt(_nextAssetIdKey),
      nextSupplierId: await LocalJsonStore.readInt(_nextSupplierIdKey),
      nextReportId: await LocalJsonStore.readInt(_nextReportIdKey),
    );
  }

  Future<List<T>> _readList<T>(
    String key,
    T Function(Map<String, dynamic>) fromMap,
  ) async {
    final rows = await LocalJsonStore.readList(key);
    final out = <T>[];
    for (final map in rows) {
      try {
        out.add(fromMap(map));
      } catch (_) {}
    }
    return out;
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final svc = InventoryService.instance;
    await LocalJsonStore.writeList(
      _itemsKey,
      svc.itemsSnapshot().map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _transactionsKey,
      svc.transactionsSnapshot().map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _studentIssuedKey,
      svc.studentIssuedSnapshot().map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _classroomKey,
      svc.classroomSnapshot().map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _assetsKey,
      svc.assetsSnapshot().map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _suppliersKey,
      svc.suppliersSnapshot().map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeList(
      _maintenanceKey,
      svc.maintenanceSnapshot().map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeInt(_nextItemIdKey, svc.nextItemIdSnapshot());
    await LocalJsonStore.writeInt(_nextTxnIdKey, svc.nextTxnIdSnapshot());
    await LocalJsonStore.writeInt(_nextIssuedIdKey, svc.nextIssuedIdSnapshot());
    await LocalJsonStore.writeInt(
      _nextClassroomIdKey,
      svc.nextClassroomIdSnapshot(),
    );
    await LocalJsonStore.writeInt(_nextAssetIdKey, svc.nextAssetIdSnapshot());
    await LocalJsonStore.writeInt(
      _nextSupplierIdKey,
      svc.nextSupplierIdSnapshot(),
    );
    await LocalJsonStore.writeInt(_nextReportIdKey, svc.nextReportIdSnapshot());
    if (pushCloud) {
      await CloudAppStore.instance.pushAllInventory();
    }
  }
}
