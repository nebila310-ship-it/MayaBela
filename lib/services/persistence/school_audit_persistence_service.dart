import 'package:mayabela/models/school_audit_entry.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/school_audit_log_service.dart';

class SchoolAuditPersistenceService {
  SchoolAuditPersistenceService._();
  static final instance = SchoolAuditPersistenceService._();

  static const _key = 'school_audit_log_v1';

  Future<void> loadIntoService() async {
    final entries = <SchoolAuditEntry>[];
    for (final map in await LocalJsonStore.readList(_key)) {
      try {
        entries.add(SchoolAuditEntry.fromMap(map));
      } catch (_) {}
    }
    if (entries.isNotEmpty) {
      SchoolAuditLogService.instance.applyPersistedEntries(entries);
    }
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final svc = SchoolAuditLogService.instance;
    await LocalJsonStore.writeList(
      _key,
      svc.snapshot().map((e) => e.toMap()).toList(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllSchoolAudit();
    }
  }
}
