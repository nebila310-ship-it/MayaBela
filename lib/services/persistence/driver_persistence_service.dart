import 'dart:async';

import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/staff_registry_notifier.dart';

/// Persists admin-created driver records and bus assignments.
class DriverPersistenceService {
  DriverPersistenceService._();
  static final instance = DriverPersistenceService._();

  static const _registryKey = 'persisted_driver_registry';
  static const _nextIdKey = 'persisted_driver_next_id';

  Future<void> loadRegistryIntoService() async {
    final rows = await LocalJsonStore.readList(_registryKey);
    final nextId = await LocalJsonStore.readInt(_nextIdKey);
    if (rows.isEmpty) return;

    final parsed = <AdminDriverRecord>[];
    for (final map in rows) {
      try {
        parsed.add(AdminDriverRecord.fromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      DriverRegistryService.instance.applyPersistedDrivers(
        parsed,
        nextId: nextId,
      );
    }
  }

  Future<void> saveRegistryFromService({
    bool pushCloud = true,
    bool notifyStaff = true,
  }) async {
    final drivers = DriverRegistryService.instance.registrySnapshot();
    await LocalJsonStore.writeList(
      _registryKey,
      drivers.map((driver) => driver.toMap()).toList(),
    );
    await LocalJsonStore.writeInt(
      _nextIdKey,
      DriverRegistryService.instance.nextDriverIdCounter,
    );
    if (pushCloud) {
      for (final driver in drivers) {
        await CloudAppStore.instance.pushDriverRegistryRecord(driver);
      }
    }
    if (notifyStaff) {
      StaffRegistryNotifier.instance.notifyChanged();
    }
    unawaited(AuthService.persistRegistryLoginAccounts());
  }
}
