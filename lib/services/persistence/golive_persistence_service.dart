import 'package:mayabela/models/golive_models.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class GolivePersistenceService {
  GolivePersistenceService._();
  static final instance = GolivePersistenceService._();

  static const _mfaKey = 'mfa_enrollments_v1';
  static const _consentsKey = 'privacy_consents_v1';
  static const _rightsKey = 'data_rights_requests_v1';
  static const _backupsKey = 'school_backups_v1';

  Future<void> loadIntoService() async {
    final enrollments = <MfaEnrollment>[];
    for (final map in await LocalJsonStore.readList(_mfaKey)) {
      try {
        enrollments.add(MfaEnrollment.fromMap(map));
      } catch (_) {}
    }
    final consents = <PrivacyConsent>[];
    for (final map in await LocalJsonStore.readList(_consentsKey)) {
      try {
        consents.add(PrivacyConsent.fromMap(map));
      } catch (_) {}
    }
    final rights = <DataRightsRequest>[];
    for (final map in await LocalJsonStore.readList(_rightsKey)) {
      try {
        rights.add(DataRightsRequest.fromMap(map));
      } catch (_) {}
    }
    final backups = <SchoolBackupRecord>[];
    for (final map in await LocalJsonStore.readList(_backupsKey)) {
      try {
        backups.add(SchoolBackupRecord.fromMap(map));
      } catch (_) {}
    }
    GoliveService.instance.applyPersistedData(
      enrollments: enrollments,
      consents: consents,
      rights: rights,
      backups: backups,
    );
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final svc = GoliveService.instance;
    await LocalJsonStore.writeList(_mfaKey, svc.mfaMaps());
    await LocalJsonStore.writeList(_consentsKey, svc.consentMaps());
    await LocalJsonStore.writeList(_rightsKey, svc.rightsMaps());
    await LocalJsonStore.writeList(_backupsKey, svc.backupMaps());
    if (pushCloud) {
      await CloudAppStore.instance.pushAllGoLive();
    }
  }
}
