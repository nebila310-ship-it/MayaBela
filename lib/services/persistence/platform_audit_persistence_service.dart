import 'package:mayabela/models/platform_audit_entry.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/platform_audit_log_service.dart';

/// Persists platform audit log locally and syncs to Firestore.
class PlatformAuditPersistenceService {
  PlatformAuditPersistenceService._();
  static final instance = PlatformAuditPersistenceService._();

  static const _entriesKey = 'platform_audit_log_v1';
  static const _nextIdKey = 'platform_audit_next_id';

  Future<void> loadIntoService() async {
    final rows = await LocalJsonStore.readList(_entriesKey);
    if (rows.isEmpty) return;
    final nextId = await LocalJsonStore.readInt(_nextIdKey);

    final parsed = <PlatformAuditEntry>[];
    for (final map in rows) {
      try {
        parsed.add(PlatformAuditEntry.fromJson(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      PlatformAuditLogService.instance.applyPersistedEntries(
        parsed,
        nextId: (nextId ?? 0) > 0 ? nextId : null,
      );
    }
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final entries = PlatformAuditLogService.instance.allEntriesSnapshot();
    await LocalJsonStore.writeList(
      _entriesKey,
      entries.map((e) => e.toJson()).toList(),
    );
    await LocalJsonStore.writeInt(
      _nextIdKey,
      PlatformAuditLogService.instance.nextIdSnapshot(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllAuditEntries();
    }
  }
}
