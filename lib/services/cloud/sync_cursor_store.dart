import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-collection sync cursors (ISO-8601 UTC timestamps).
class SyncCursorStore {
  SyncCursorStore._();
  static final instance = SyncCursorStore._();

  static const _prefix = 'cloud_sync_cursor_v1_';

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

  Future<void> setCursor(String collection, DateTime at) async {
    final iso = at.toUtc().toIso8601String();
    _memory[collection] = iso;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$collection', iso);
  }

  Future<void> clearAll() async {
    _memory.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await prefs.remove(key);
    }
  }
}
