import 'package:mayabela/models/discipline_case.dart';
import 'package:mayabela/services/discipline_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

/// Persists Student Affairs discipline cases locally and syncs to Supabase.
class DisciplinePersistenceService {
  DisciplinePersistenceService._();
  static final instance = DisciplinePersistenceService._();

  static const _key = 'discipline_cases_v1';

  Future<void> loadIntoService() async {
    final cases = <DisciplineCase>[];
    for (final map in await LocalJsonStore.readList(_key)) {
      try {
        cases.add(DisciplineCase.fromMap(map));
      } catch (_) {}
    }
    DisciplineService.instance.applyPersistedData(cases);
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    await LocalJsonStore.writeList(
      _key,
      DisciplineService.instance.snapshotMaps(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllDisciplineCases();
    }
  }
}
