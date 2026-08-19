import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/school_registry_service.dart';

/// Persists school registry locally and syncs to Firestore.
class SchoolRegistryPersistenceService {
  SchoolRegistryPersistenceService._();
  static final instance = SchoolRegistryPersistenceService._();

  static const _schoolsKey = 'school_registry_v1';

  Future<void> loadIntoService() async {
    final rows = await LocalJsonStore.readList(_schoolsKey);
    if (rows.isEmpty) return;

    final parsed = rows
        .map((m) => SchoolRecord.fromJson(m))
        .toList();
    if (parsed.isNotEmpty) {
      SchoolRegistryService.instance.applyPersistedSchools(parsed);
    }
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final schools = SchoolRegistryService.instance.allSchoolsSnapshot();
    await LocalJsonStore.writeList(
      _schoolsKey,
      schools.map((s) => s.toJson()).toList(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllSchools();
    }
  }
}
