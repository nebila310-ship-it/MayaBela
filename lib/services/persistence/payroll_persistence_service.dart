import 'package:mayabela/models/payroll_models.dart';
import 'package:mayabela/services/payroll_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class PayrollPersistenceService {
  PayrollPersistenceService._();
  static final instance = PayrollPersistenceService._();

  static const _profilesKey = 'payroll_profiles_v1';
  static const _runsKey = 'payroll_runs_v1';

  Future<void> loadIntoService() async {
    final profiles = <PayrollProfile>[];
    for (final map in await LocalJsonStore.readList(_profilesKey)) {
      try {
        profiles.add(PayrollProfile.fromMap(map));
      } catch (_) {}
    }
    final runs = <PayrollRun>[];
    for (final map in await LocalJsonStore.readList(_runsKey)) {
      try {
        runs.add(PayrollRun.fromMap(map));
      } catch (_) {}
    }
    PayrollService.instance.applyPersistedData(
      profiles: profiles,
      runs: runs,
    );
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final svc = PayrollService.instance;
    await LocalJsonStore.writeList(_profilesKey, svc.profileMaps());
    await LocalJsonStore.writeList(_runsKey, svc.runMaps());
    if (pushCloud) {
      await CloudAppStore.instance.pushAllPayroll();
    }
  }
}
