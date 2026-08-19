import 'package:mayabela/models/material_purchase_models.dart';
import 'package:mayabela/services/material_purchase_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class MaterialPurchasePersistenceService {
  MaterialPurchasePersistenceService._();
  static final instance = MaterialPurchasePersistenceService._();

  static const _key = 'material_purchase_requests_v1';

  Future<void> loadIntoService() async {
    final rows = await LocalJsonStore.readList(_key);
    final list = <MaterialPurchaseRequest>[];
    for (final map in rows) {
      try {
        list.add(MaterialPurchaseRequest.fromMap(map));
      } catch (_) {}
    }
    MaterialPurchaseService.instance.applyPersisted(list);
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final items = MaterialPurchaseService.instance
        .snapshot()
        .map((e) => e.toMap())
        .toList();
    await LocalJsonStore.writeList(_key, items);
    if (pushCloud) {
      await CloudAppStore.instance.pushAllMaterialPurchases();
    }
  }
}
