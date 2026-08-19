import 'package:mayabela/models/cloud/app_data_maps.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/timetable_service.dart';

class TimetablePersistenceService {
  TimetablePersistenceService._();
  static final instance = TimetablePersistenceService._();

  static const _key = 'persisted_class_timetables_v1';

  Future<void> loadIntoTimetableService() async {
    final rows = await LocalJsonStore.readList(_key);
    if (rows.isEmpty) return;
    final parsed = rows.map(AppDataMaps.classTimetableFromMap).toList();
    TimetableService.instance.applyPersistedTimetables(parsed);
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final items = TimetableService.instance.allPersistedTimetables();
    await LocalJsonStore.writeList(
      _key,
      items.map(AppDataMaps.classTimetableToMap).toList(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllClassTimetables();
    }
    SchoolContentSyncService.instance.markDataChanged();
  }
}
