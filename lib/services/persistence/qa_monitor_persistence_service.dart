import 'package:mayabela/models/qa_monitor_models.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/qa_monitor_service.dart';

class QaMonitorPersistenceService {
  QaMonitorPersistenceService._();
  static final instance = QaMonitorPersistenceService._();

  static const _observationsKey = 'teaching_observations_v1';
  static const _auditsKey = 'academic_audits_v1';
  static const _surveysKey = 'qa_surveys_v1';
  static const _responsesKey = 'qa_survey_responses_v1';
  static const _researchKey = 'action_research_v1';

  Future<void> loadIntoService() async {
    final observations = <TeachingObservation>[];
    for (final map in await LocalJsonStore.readList(_observationsKey)) {
      try {
        observations.add(TeachingObservation.fromMap(map));
      } catch (_) {}
    }
    final audits = <AcademicAudit>[];
    for (final map in await LocalJsonStore.readList(_auditsKey)) {
      try {
        audits.add(AcademicAudit.fromMap(map));
      } catch (_) {}
    }
    final surveys = <QaSurvey>[];
    for (final map in await LocalJsonStore.readList(_surveysKey)) {
      try {
        surveys.add(QaSurvey.fromMap(map));
      } catch (_) {}
    }
    final responses = <QaSurveyResponse>[];
    for (final map in await LocalJsonStore.readList(_responsesKey)) {
      try {
        responses.add(QaSurveyResponse.fromMap(map));
      } catch (_) {}
    }
    final research = <ActionResearch>[];
    for (final map in await LocalJsonStore.readList(_researchKey)) {
      try {
        research.add(ActionResearch.fromMap(map));
      } catch (_) {}
    }
    QaMonitorService.instance.applyPersistedData(
      observations: observations,
      audits: audits,
      surveys: surveys,
      responses: responses,
      research: research,
    );
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final svc = QaMonitorService.instance;
    await LocalJsonStore.writeList(_observationsKey, svc.observationMaps());
    await LocalJsonStore.writeList(_auditsKey, svc.auditMaps());
    await LocalJsonStore.writeList(_surveysKey, svc.surveyMaps());
    await LocalJsonStore.writeList(_responsesKey, svc.responseMaps());
    await LocalJsonStore.writeList(_researchKey, svc.researchMaps());
    if (pushCloud) {
      await CloudAppStore.instance.pushAllQaMonitor();
    }
  }
}
