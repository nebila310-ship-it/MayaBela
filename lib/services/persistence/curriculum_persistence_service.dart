import 'package:mayabela/models/curriculum_models.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class CurriculumPersistenceService {
  CurriculumPersistenceService._();
  static final instance = CurriculumPersistenceService._();

  static const _unitsKey = 'curriculum_units_v1';
  static const _feedbackKey = 'curriculum_feedback_v1';
  static const _reviewsKey = 'lesson_plan_reviews_v1';
  static const _evalsKey = 'teacher_evaluations_v1';
  static const _meetingsKey = 'academic_meetings_v1';

  Future<void> loadIntoService() async {
    final units = <CurriculumUnit>[];
    for (final map in await LocalJsonStore.readList(_unitsKey)) {
      try {
        units.add(CurriculumUnit.fromMap(map));
      } catch (_) {}
    }
    final feedback = <CurriculumFeedback>[];
    for (final map in await LocalJsonStore.readList(_feedbackKey)) {
      try {
        feedback.add(CurriculumFeedback.fromMap(map));
      } catch (_) {}
    }
    final reviews = <LessonPlanReview>[];
    for (final map in await LocalJsonStore.readList(_reviewsKey)) {
      try {
        reviews.add(LessonPlanReview.fromMap(map));
      } catch (_) {}
    }
    final evals = <TeacherEvaluation>[];
    for (final map in await LocalJsonStore.readList(_evalsKey)) {
      try {
        evals.add(TeacherEvaluation.fromMap(map));
      } catch (_) {}
    }
    final meetings = <AcademicMeeting>[];
    for (final map in await LocalJsonStore.readList(_meetingsKey)) {
      try {
        meetings.add(AcademicMeeting.fromMap(map));
      } catch (_) {}
    }
    CurriculumService.instance.applyPersistedData(
      units: units,
      feedback: feedback,
      reviews: reviews,
      evaluations: evals,
      meetings: meetings,
    );
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final svc = CurriculumService.instance;
    await LocalJsonStore.writeList(_unitsKey, svc.unitMaps());
    await LocalJsonStore.writeList(_feedbackKey, svc.feedbackMaps());
    await LocalJsonStore.writeList(_reviewsKey, svc.reviewMaps());
    await LocalJsonStore.writeList(_evalsKey, svc.evaluationMaps());
    await LocalJsonStore.writeList(_meetingsKey, svc.meetingMaps());
    if (pushCloud) {
      await CloudAppStore.instance.pushAllCurriculumOffice();
    }
  }
}
