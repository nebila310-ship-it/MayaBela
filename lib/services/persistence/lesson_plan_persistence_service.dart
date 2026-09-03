import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class LessonPlanPersistenceService {
  LessonPlanPersistenceService._();
  static final instance = LessonPlanPersistenceService._();

  static const _key = 'lesson_plans_v1';

  Future<void> loadIntoService() async {
    final plans = <LessonPlan>[];
    for (final map in await LocalJsonStore.readList(_key)) {
      try {
        plans.add(LessonPlan.fromMap(map));
      } catch (_) {}
    }
    LessonPlanService.instance.applyPersistedData(plans);
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    await LocalJsonStore.writeList(_key, LessonPlanService.instance.snapshotMaps());
    if (pushCloud) {
      await CloudAppStore.instance.pushAllLessonPlans();
    }
  }
}
