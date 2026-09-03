import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/student_support_service.dart';

class StudentSupportPersistenceService {
  StudentSupportPersistenceService._();
  static final instance = StudentSupportPersistenceService._();

  static const _healthKey = 'health_records_v1';
  static const _counselingKey = 'counseling_records_v1';
  static const _iepKey = 'iep_plans_v1';
  static const _collegeKey = 'college_guidance_v1';
  static const _requestsKey = 'support_requests_v1';
  static const _safeguardingKey = 'safeguarding_cases_v1';

  Future<void> loadIntoService() async {
    final health = <HealthRecord>[];
    for (final map in await LocalJsonStore.readList(_healthKey)) {
      try {
        health.add(HealthRecord.fromMap(map));
      } catch (_) {}
    }
    final counseling = <CounselingRecord>[];
    for (final map in await LocalJsonStore.readList(_counselingKey)) {
      try {
        counseling.add(CounselingRecord.fromMap(map));
      } catch (_) {}
    }
    final iep = <IepPlan>[];
    for (final map in await LocalJsonStore.readList(_iepKey)) {
      try {
        iep.add(IepPlan.fromMap(map));
      } catch (_) {}
    }
    final college = <CollegeGuidancePlan>[];
    for (final map in await LocalJsonStore.readList(_collegeKey)) {
      try {
        college.add(CollegeGuidancePlan.fromMap(map));
      } catch (_) {}
    }
    final requests = <SupportRequest>[];
    for (final map in await LocalJsonStore.readList(_requestsKey)) {
      try {
        requests.add(SupportRequest.fromMap(map));
      } catch (_) {}
    }
    final safeguarding = <SafeguardingCase>[];
    for (final map in await LocalJsonStore.readList(_safeguardingKey)) {
      try {
        safeguarding.add(SafeguardingCase.fromMap(map));
      } catch (_) {}
    }
    StudentSupportService.instance.applyPersistedData(
      health: health,
      counseling: counseling,
      iep: iep,
      college: college,
      requests: requests,
      safeguarding: safeguarding,
    );
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final svc = StudentSupportService.instance;
    await LocalJsonStore.writeList(_healthKey, svc.healthMaps());
    await LocalJsonStore.writeList(_counselingKey, svc.counselingMaps());
    await LocalJsonStore.writeList(_iepKey, svc.iepMaps());
    await LocalJsonStore.writeList(_collegeKey, svc.collegeMaps());
    await LocalJsonStore.writeList(_requestsKey, svc.requestMaps());
    await LocalJsonStore.writeList(_safeguardingKey, svc.safeguardingMaps());
    if (pushCloud) {
      await CloudAppStore.instance.pushAllStudentSupport();
    }
  }
}
