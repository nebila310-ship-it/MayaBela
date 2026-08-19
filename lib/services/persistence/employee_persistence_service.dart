import 'package:mayabela/services/employee_registry_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/staff_registry_notifier.dart';

/// Persists record-only employees (no login accounts).
class EmployeePersistenceService {
  EmployeePersistenceService._();
  static final instance = EmployeePersistenceService._();

  static const _registryKey = 'persisted_employee_registry';
  static const _nextIdKey = 'persisted_employee_next_id';

  Future<void> loadRegistryIntoService() async {
    final rows = await LocalJsonStore.readList(_registryKey);
    final nextId = await LocalJsonStore.readInt(_nextIdKey);
    if (rows.isEmpty) return;

    final parsed = <EmployeeRecord>[];
    for (final map in rows) {
      try {
        parsed.add(EmployeeRecord.fromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      EmployeeRegistryService.instance.applyPersistedEmployees(
        parsed,
        nextId: nextId,
      );
    }
  }

  Future<void> saveRegistryFromService({
    bool pushCloud = true,
    bool notifyStaff = true,
  }) async {
    final employees = EmployeeRegistryService.instance.registrySnapshot();
    await LocalJsonStore.writeList(
      _registryKey,
      employees.map((e) => e.toMap()).toList(),
    );
    await LocalJsonStore.writeInt(
      _nextIdKey,
      EmployeeRegistryService.instance.nextEmployeeIdCounter,
    );
    if (pushCloud) {
      for (final employee in employees) {
        await CloudAppStore.instance.pushEmployeeRegistryRecord(employee);
      }
    }
    if (notifyStaff) {
      StaffRegistryNotifier.instance.notifyChanged();
    }
  }
}
