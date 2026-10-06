import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/remembered_school_brand.dart';
import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/platform/school_splash_brand.dart';

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
  static const _brandKey = 'login_last_school_brand';
  static const _brandsKey = 'login_school_brands_v1';

  bool _rememberEnabled = false;
  List<SavedLoginEntry> _entries = [];
  String? _lastSchoolId;
  final Map<String, RememberedSchoolBrand> _brands = {};
  bool _loaded = false;

  bool get rememberEnabled => _rememberEnabled;
  List<SavedLoginEntry> get entries => List.unmodifiable(_entries);
  String? get lastSchoolId => _lastSchoolId;
  RememberedSchoolBrand? get rememberedBrand => brandForSchool(_lastSchoolId);

  RememberedSchoolBrand? brandForSchool(String? schoolId) {
    final id = schoolId?.trim().toUpperCase();
    if (id == null || id.isEmpty) return null;
    return _brands[id];
  }

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
    _brands
      ..clear()
      ..addAll(_readBrands(prefs.getString(_brandsKey)));
    final legacy = _readBrand(prefs.getString(_brandKey));
    if (legacy != null) {
      _brands.putIfAbsent(legacy.schoolId, () => legacy);
    }
    if (_lastSchoolId == null || _lastSchoolId!.isEmpty) {
      _lastSchoolId = rememberedBrand?.schoolId;
    }
    SchoolSplashBrand.persistActiveSchoolId(_lastSchoolId);
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
    SchoolSplashBrand.persistActiveSchoolId(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSchoolIdKey, id);
    final cached = _brands[id];
    if (cached != null) {
      await prefs.setString(_brandKey, jsonEncode(cached.toJson()));
      try {
        SchoolSplashBrand.remember(
          schoolId: cached.schoolId,
          name: cached.name,
          style: cached.logoStyle,
          jpegBytes: SchoolSplashBrand.readBytes(
            schoolId: cached.schoolId,
            style: cached.logoStyle,
          ),
          logoUrl: cached.logoUrl,
        );
      } catch (_) {}
    }
  }

  Future<void> rememberSchoolBrand({
    required String schoolId,
    required String name,
    String? logoUrl,
    String? logoPath,
    SchoolLogoStyle logoStyle = SchoolLogoStyle.rectangular,
  }) async {
    final id = schoolId.trim().toUpperCase();
    final trimmedName = name.trim();
    if (id.isEmpty || trimmedName.isEmpty) return;
    final brand = RememberedSchoolBrand(
      schoolId: id,
      name: trimmedName,
      logoUrl: logoUrl?.trim().isEmpty == true ? null : logoUrl?.trim(),
      logoPath: logoPath?.trim().isEmpty == true ? null : logoPath?.trim(),
      logoStyle: logoStyle,
    );
    _lastSchoolId = id;
    _brands[id] = brand;
    SchoolSplashBrand.persistActiveSchoolId(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSchoolIdKey, id);
    await prefs.setString(_brandKey, jsonEncode(brand.toJson()));
    await prefs.setString(
      _brandsKey,
      jsonEncode({
        for (final entry in _brands.entries) entry.key: entry.value.toJson(),
      }),
    );
    try {
      SchoolSplashBrand.remember(
        schoolId: id,
        name: trimmedName,
        style: logoStyle,
        jpegBytes: SchoolSplashBrand.readBytes(schoolId: id, style: logoStyle),
        logoUrl: brand.logoUrl,
      );
    } catch (_) {}
  }

  RememberedSchoolBrand? _readBrand(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final brand = RememberedSchoolBrand.fromJson(
        Map<String, dynamic>.from(map),
      );
      if (brand.schoolId.isEmpty || brand.name.isEmpty) return null;
      return brand;
    } catch (_) {
      return null;
    }
  }

  Map<String, RememberedSchoolBrand> _readBrands(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, RememberedSchoolBrand>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final brand = RememberedSchoolBrand.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (brand.schoolId.isEmpty || brand.name.isEmpty) continue;
        out[brand.schoolId] = brand;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  @visibleForTesting
  void debugReset() {
    _rememberEnabled = false;
    _entries = [];
    _lastSchoolId = null;
    _brands.clear();
    _loaded = false;
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
