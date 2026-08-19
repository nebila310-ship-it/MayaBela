import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/school_data_service.dart';

/// Persists teacher-uploaded books and learning materials per class.
class LearningMaterialsPersistenceService {
  LearningMaterialsPersistenceService._();
  static final instance = LearningMaterialsPersistenceService._();

  static const _itemsKey = 'persisted_learning_materials';

  Future<void> loadIntoSchoolDataService() async {
    final rows = await LocalJsonStore.readList(_itemsKey);
    if (rows.isNotEmpty) {
      final parsed = <LearningMaterialItem>[];
      for (final map in rows) {
        try {
          parsed.add(LearningMaterialItemPersistence.fromMap(map));
        } catch (_) {}
      }
      if (parsed.isNotEmpty) {
        SchoolDataService.instance.applyPersistedLearningMaterials(parsed);
      }
    }
    SchoolDataService.instance.ensureSampleLearningMaterials();
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final items = SchoolDataService.instance.learningMaterialsSnapshot();
    await LocalJsonStore.writeList(
      _itemsKey,
      items.map((item) => item.toMap()).toList(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllLearningMaterials();
    }
  }

  Future<void> deleteFromCloud(String id) async {
    await CloudAppStore.instance.deleteLearningMaterialItem(id);
  }
}
