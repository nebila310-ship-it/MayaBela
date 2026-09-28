import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-collection sync cursors (ISO-8601 UTC timestamps).
class SyncCursorStore {
  SyncCursorStore._();
  static final instance = SyncCursorStore._();

  static const _prefix = 'cloud_sync_cursor_v1_';
  static const bootCursorKey = '_role_boot';
  static const schoolCursorKey = '_school_id';

  final Map<String, String> _memory = {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) {
        _memory[key.substring(_prefix.length)] = value;
      }
    }
    _loaded = true;
  }

  String? cursorFor(String collection) => _memory[collection];

  String? get boundSchoolId => _memory[schoolCursorKey];

  Future<void> setCursor(String collection, DateTime at) async {
    await _setRaw(collection, at.toUtc().toIso8601String());
  }

  Future<void> _setRaw(String key, String value) async {
    _memory[key] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', value);
  }

  /// Keep cursors on the same school. Wipe only when the signed-in school
  /// actually changes so a normal login does not force a second full download.
  Future<void> bindToSchool(String? schoolId) async {
    await ensureLoaded();
    final sid = schoolId?.trim().toUpperCase() ?? '';
    if (sid.isEmpty) return;
    final previous = _memory[schoolCursorKey];
    if (previous == sid) return;
    if (previous != null && previous.isNotEmpty && previous != sid) {
      await clearAll();
    }
    await _setRaw(schoolCursorKey, sid);
  }

  /// After a successful login pack, mark the engine as already booted.
  Future<void> markRoleBoot(Iterable<String> collections) async {
    await ensureLoaded();
    final now = DateTime.now().toUtc();
    for (final collection in collections) {
      await setCursor(collection, now);
    }
    await setCursor(bootCursorKey, now);
  }

  Future<void> clearAll() async {
    _memory.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await prefs.remove(key);
    }
  }

  @visibleForTesting
  void resetForTests() {
    _memory.clear();
    _loaded = false;
  }
}
