import 'package:mayabela/models/conference_models.dart';
import 'package:mayabela/services/conference_service.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class ConferencePersistenceService {
  ConferencePersistenceService._();
  static final instance = ConferencePersistenceService._();

  static const _key = 'conference_windows_v1';

  Future<void> loadIntoService() async {
    final windows = <ConferenceWindow>[];
    for (final map in await LocalJsonStore.readList(_key)) {
      try {
        windows.add(ConferenceWindow.fromMap(map));
      } catch (_) {}
    }
    ConferenceService.instance.applyPersistedData(windows);
  }

  Future<void> saveFromService() async {
    await LocalJsonStore.writeList(
      _key,
      ConferenceService.instance.snapshotMaps(),
    );
  }
}
