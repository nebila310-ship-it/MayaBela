import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedLoginEntry {
  const SavedLoginEntry({
    required this.schoolId,
    required this.roleKey,
    required this.identifier,
    required this.password,
  });

  final String schoolId;
  final String roleKey;
  final String identifier;
  final String password;

  Map<String, dynamic> toJson() => {
        'schoolId': schoolId,
        'roleKey': roleKey,
        'identifier': identifier,
        'password': password,
      };

  factory SavedLoginEntry.fromJson(Map<String, dynamic> json) {
    return SavedLoginEntry(
      schoolId: json['schoolId'] as String? ?? '',
      roleKey: json['roleKey'] as String? ?? '',
      identifier: json['identifier'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }
}

class LoginPrefsService {
  LoginPrefsService._();
  static final instance = LoginPrefsService._();

  static const _rememberKey = 'login_remember_enabled';
  static const _entriesKey = 'login_saved_entries';
  static const _lastSchoolIdKey = 'login_last_school_id';

  bool _rememberEnabled = false;
  List<SavedLoginEntry> _entries = [];
  String? _lastSchoolId;
  bool _loaded = false;

  bool get rememberEnabled => _rememberEnabled;
  List<SavedLoginEntry> get entries => List.unmodifiable(_entries);
  String? get lastSchoolId => _lastSchoolId;

  List<String> get savedSchoolIds {
    final ids = _entries.map((e) => e.schoolId.trim().toUpperCase()).toSet().toList();
    ids.sort();
    return ids;
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _rememberEnabled = prefs.getBool(_rememberKey) ?? false;
    _lastSchoolId = prefs.getString(_lastSchoolIdKey);
    final raw = prefs.getString(_entriesKey);
    if (raw == null || raw.isEmpty) {
      _entries = [];
      _loaded = true;
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _entries = list
          .map((item) => SavedLoginEntry.fromJson(item as Map<String, dynamic>))
          .where((e) => e.schoolId.isNotEmpty)
          .toList();
    } catch (_) {
      _entries = [];
    }
    _loaded = true;
  }

  SavedLoginEntry? findEntry({required String schoolId, String? roleKey}) {
    final id = schoolId.trim().toUpperCase();
    if (roleKey != null) {
      try {
        return _entries.firstWhere(
          (e) =>
              e.schoolId.trim().toUpperCase() == id &&
              e.roleKey == roleKey,
        );
      } catch (_) {}
    }
    try {
      return _entries.firstWhere(
        (e) => e.schoolId.trim().toUpperCase() == id,
      );
    } catch (_) {
      return null;
    }
  }

  SavedLoginEntry? get latestEntry => _entries.isEmpty ? null : _entries.last;

  Future<void> saveLastSchoolId(String schoolId) async {
    final id = schoolId.trim().toUpperCase();
    if (id.isEmpty) return;
    _lastSchoolId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSchoolIdKey, id);
  }

  Future<void> saveLogin({
    required bool remember,
    required String schoolId,
    required String roleKey,
    required String identifier,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _rememberEnabled = remember;
    await prefs.setBool(_rememberKey, remember);

    if (!remember) return;

    final entry = SavedLoginEntry(
      schoolId: schoolId.trim().toUpperCase(),
      roleKey: roleKey,
      identifier: identifier.trim(),
      // Never persist passwords on device ("remember me" = identifier only).
      password: '',
    );

    _entries.removeWhere(
      (e) =>
          e.schoolId.trim().toUpperCase() == entry.schoolId &&
          e.roleKey == entry.roleKey &&
          e.identifier == entry.identifier,
    );
    _entries.add(entry);
    await saveLastSchoolId(entry.schoolId);
    await prefs.setString(
      _entriesKey,
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    _rememberEnabled = false;
    _entries = [];
    await prefs.remove(_rememberKey);
    await prefs.remove(_entriesKey);
  }
}
