import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/school_data_service.dart';

/// Persists teacher-posted homework so assignments accumulate across sessions.
class HomeworkPersistenceService {
  HomeworkPersistenceService._();
  static final instance = HomeworkPersistenceService._();

  static const _itemsKey = 'persisted_homework';

  Future<void> loadIntoSchoolDataService() async {
    final rows = await LocalJsonStore.readList(_itemsKey);
    if (rows.isEmpty) return;

    final parsed = <HomeworkItem>[];
    for (final map in rows) {
      try {
        parsed.add(HomeworkItemPersistence.fromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      SchoolDataService.instance.applyPersistedHomework(parsed);
    }
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final items = SchoolDataService.instance.homeworkSnapshot();
    await LocalJsonStore.writeList(
      _itemsKey,
      items.map((item) => item.toMap()).toList(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllHomework();
    }
  }
}
