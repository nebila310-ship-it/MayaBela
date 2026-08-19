import 'package:mayabela/models/platform_audit_entry.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/platform_audit_persistence_service.dart';

class PlatformAuditLogService {
  PlatformAuditLogService._();
  static final instance = PlatformAuditLogService._();

  static const maxEntries = 200;

  final List<PlatformAuditEntry> _entries = [];
  bool _loaded = false;
  int _nextId = 1;

  Future<void> load() async {
    if (_loaded) return;
    await PlatformAuditPersistenceService.instance.loadIntoService();
    _loaded = true;
  }

  Future<void> _persist({bool pushCloud = true}) async {
    await PlatformAuditPersistenceService.instance.saveFromService(
      pushCloud: pushCloud,
    );
  }

  void applyPersistedEntries(List<PlatformAuditEntry> entries, {int? nextId}) {
    _entries
      ..clear()
      ..addAll(entries);
    if (nextId != null && nextId > _nextId) _nextId = nextId;
    _loaded = true;
  }

  List<PlatformAuditEntry> allEntriesSnapshot() => List.from(_entries);

  int nextIdSnapshot() => _nextId;

  Future<void> log({
    required String action,
    String? schoolId,
    String? schoolName,
    String? detail,
  }) async {
    await load();
    _entries.insert(
      0,
      PlatformAuditEntry(
        id: 'audit-${_nextId++}',
        at: DateTime.now(),
        action: action,
        schoolId: schoolId,
        schoolName: schoolName,
        detail: detail,
      ),
    );
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    await _persist(pushCloud: false);
    try {
      await CloudAppStore.instance.pushAllAuditEntries();
    } catch (_) {}
  }

  List<PlatformAuditEntry> recent({int limit = 100}) {
    return List.unmodifiable(_entries.take(limit));
  }
}
