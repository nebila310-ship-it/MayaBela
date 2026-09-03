import 'package:mayabela/models/admission_application.dart';
import 'package:mayabela/services/admission_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class AdmissionPersistenceService {
  AdmissionPersistenceService._();
  static final instance = AdmissionPersistenceService._();

  static const _key = 'admission_applications_v1';

  Future<void> loadIntoService() async {
    final items = <AdmissionApplication>[];
    for (final map in await LocalJsonStore.readList(_key)) {
      try {
        items.add(AdmissionApplication.fromMap(map));
      } catch (_) {}
    }
    AdmissionService.instance.applyPersistedData(items);
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    await LocalJsonStore.writeList(
      _key,
      AdmissionService.instance.snapshotMaps(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllAdmissionApplications();
    }
  }
}
