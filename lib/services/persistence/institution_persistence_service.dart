import 'package:mayabela/models/institution_models.dart';
import 'package:mayabela/services/institution_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class InstitutionPersistenceService {
  InstitutionPersistenceService._();
  static final instance = InstitutionPersistenceService._();

  static const _key = 'institution_records_v1';

  Future<void> loadIntoService() async {
    final rows = <InstitutionRecord>[];
    for (final map in await LocalJsonStore.readList(_key)) {
      try {
        rows.add(InstitutionRecord.fromMap(map));
      } catch (_) {}
    }
    InstitutionService.instance.applyPersistedData(rows);
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    await LocalJsonStore.writeList(
      _key,
      InstitutionService.instance.snapshotMaps(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllInstitutionRecords();
    }
  }
}
