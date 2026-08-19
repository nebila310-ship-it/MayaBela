import 'package:mayabela/services/grade_audit_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

/// Persists grade approval audit entries locally and in Firestore.
class GradeAuditPersistenceService {
  GradeAuditPersistenceService._();
  static final instance = GradeAuditPersistenceService._();

  static const _key = 'grade_audit_v1';

  Future<void> loadIntoService() async {
    final rows = await LocalJsonStore.readList(_key);
    if (rows.isEmpty) return;
    GradeAuditService.instance.applyPersistedEntries(
      rows.map(GradeAuditService.entryFromMap).toList(),
    );
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    await LocalJsonStore.writeList(
      _key,
      GradeAuditService.instance.snapshotMaps(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllGradeAuditEntries();
    }
  }
}
