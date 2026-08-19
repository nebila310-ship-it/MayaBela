import 'package:flutter/foundation.dart';

import 'package:mayabela/models/school_audit_entry.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/school_audit_persistence_service.dart';

/// School operational audit log (Phase F). Append-only; mirrors the SQL
/// `school_audit_log` insert-only guard.
class SchoolAuditLogService extends ChangeNotifier {
  SchoolAuditLogService._();
  static final instance = SchoolAuditLogService._();

  static const maxEntries = 2000;

  final List<SchoolAuditEntry> _entries = [];
  int _nextId = 1;
  bool _loaded = false;

  List<SchoolAuditEntry> snapshot() => List.unmodifiable(_entries);
  int nextIdSnapshot() => _nextId;

  Future<void> load() async {
    if (_loaded) return;
    await SchoolAuditPersistenceService.instance.loadIntoService();
    _loaded = true;
  }

  void applyPersistedEntries(
    List<SchoolAuditEntry> entries, {
    bool replace = false,
  }) {
    if (replace) {
      _entries
        ..clear()
        ..addAll(entries);
      _nextId = 1;
    } else {
      for (final entry in entries) {
        final index = _entries.indexWhere((e) => e.id == entry.id);
        if (index >= 0) {
          _entries[index] = entry;
        } else {
          _entries.add(entry);
        }
        final n = int.tryParse(entry.id.replaceAll(RegExp(r'\D'), '')) ?? 0;
        if (n >= _nextId) _nextId = n + 1;
      }
    }
    for (final entry in _entries) {
      final n = int.tryParse(entry.id.replaceAll(RegExp(r'\D'), '')) ?? 0;
      if (n >= _nextId) _nextId = n + 1;
    }
    _entries.sort((a, b) => b.at.compareTo(a.at));
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    _loaded = true;
    notifyListeners();
  }

  List<SchoolAuditEntry> recentForSchool(String? schoolId, {int limit = 100}) {
    final sid = schoolId?.trim().toUpperCase();
    final list = _entries.where((e) {
      if (sid == null || sid.isEmpty) return true;
      return e.schoolId == sid;
    });
    return list.take(limit).toList();
  }

  List<SchoolAuditEntry> filtered({
    String? schoolId,
    String? actionQuery,
    String? entityType,
    int limit = 200,
  }) {
    final sid = schoolId?.trim().toUpperCase();
    final q = (actionQuery ?? '').trim().toLowerCase();
    final et = (entityType ?? '').trim().toLowerCase();
    return _entries.where((e) {
      if (sid != null && sid.isNotEmpty && e.schoolId != sid) return false;
      if (et.isNotEmpty && (e.entityType ?? '').toLowerCase() != et) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay = [
          e.action,
          e.detail ?? '',
          e.actorName ?? '',
          e.entityId ?? '',
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).take(limit).toList();
  }

  Future<void> log({
    required String action,
    String? schoolId,
    String? entityType,
    String? entityId,
    String? detail,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    final user = AuthService.currentUser;
    final sid = (schoolId ?? AuthService.activeSchoolId ?? '').trim().toUpperCase();
    if (sid.isEmpty) return;

    final entry = SchoolAuditEntry(
      id: 'saudit-${_nextId++}',
      at: DateTime.now(),
      action: action,
      schoolId: sid,
      actorId: user?.username,
      actorName: (user?.fullName ?? '').trim().isNotEmpty
          ? user!.fullName
          : user?.username,
      actorRole: user?.roleKey,
      entityType: entityType,
      entityId: entityId,
      detail: detail,
      before: before,
      after: after,
    );
    _entries.insert(0, entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    await SchoolAuditPersistenceService.instance.saveFromService();
    notifyListeners();
  }
}
