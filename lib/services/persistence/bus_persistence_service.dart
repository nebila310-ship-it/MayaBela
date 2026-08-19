import 'package:mayabela/models/bus_record.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class BusPersistenceService {
  BusPersistenceService._();
  static final instance = BusPersistenceService._();

  static const _key = 'buses_v1';
  static const _nextIdKey = 'buses_next_id';

  Future<void> loadIntoService() async {
    final rows = await LocalJsonStore.readList(_key);
    final nextId = await LocalJsonStore.readInt(_nextIdKey);
    final buses = <BusRecord>[];
    for (final map in rows) {
      try {
        buses.add(BusRecord.fromMap(map));
      } catch (_) {}
    }
    if (buses.isNotEmpty) {
      BusRegistryService.instance.applyPersistedBuses(buses, nextId: nextId);
    } else {
      BusRegistryService.instance.seedFromDriversIfEmpty();
    }
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final svc = BusRegistryService.instance;
    await LocalJsonStore.writeList(
      _key,
      svc.registrySnapshot().map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeInt(_nextIdKey, svc.nextBusIdCounter);
    if (pushCloud) {
      await CloudAppStore.instance.pushAllBuses();
    }
  }
}
