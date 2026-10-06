import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:mayabela/platform/school_splash_brand.dart';

Map<String, dynamic>? _splashMap() {
  final raw = web.window.localStorage.getItem(SchoolSplashBrand.storageKey);
  if (raw == null || raw.isEmpty) return null;
  final map = jsonDecode(raw);
  if (map is! Map) return null;
  return Map<String, dynamic>.from(map);
}

void persistSchoolSplashBrand(String json) {
  try {
    web.window.localStorage.setItem(SchoolSplashBrand.storageKey, json);
    final decoded = jsonDecode(json);
    if (decoded is! Map) return;
    final id = (decoded['schoolId'] ?? '').toString().trim().toUpperCase();
    if (id.isEmpty) return;
    final name = (decoded['name'] ?? '').toString().trim();
    if (name.isEmpty &&
        (decoded['dataUrl'] == null || decoded['dataUrl'].toString().isEmpty) &&
        (decoded['logoUrl'] == null || decoded['logoUrl'].toString().isEmpty)) {
      return;
    }
    Map<String, dynamic> all = {};
    final raw = web.window.localStorage.getItem(SchoolSplashBrand.brandsKey);
    if (raw != null && raw.isNotEmpty) {
      final parsed = jsonDecode(raw);
      if (parsed is Map) {
        all = Map<String, dynamic>.from(parsed);
      }
    }
    all[id] = Map<String, dynamic>.from(decoded);
    web.window.localStorage.setItem(
      SchoolSplashBrand.brandsKey,
      jsonEncode(all),
    );
  } catch (_) {}
}

void persistActiveSchoolId(String? schoolId) {
  try {
    final id = schoolId?.trim().toUpperCase() ?? '';
    if (id.isEmpty) {
      web.window.localStorage.removeItem(SchoolSplashBrand.activeSchoolIdKey);
    } else {
      web.window.localStorage.setItem(
        SchoolSplashBrand.activeSchoolIdKey,
        id,
      );
    }
  } catch (_) {}
}

Map<String, dynamic>? readSchoolSplashMap({String? schoolId}) {
  try {
    final want = schoolId?.trim().toUpperCase();
    if (want != null && want.isNotEmpty) {
      final rawAll = web.window.localStorage.getItem(SchoolSplashBrand.brandsKey);
      if (rawAll != null && rawAll.isNotEmpty) {
        final parsed = jsonDecode(rawAll);
        if (parsed is Map && parsed[want] is Map) {
          return Map<String, dynamic>.from(parsed[want] as Map);
        }
      }
    }
    final map = _splashMap();
    if (map == null) return null;
    final storedId = (map['schoolId'] as String? ?? '').trim().toUpperCase();
    if (want != null && want.isNotEmpty && storedId != want) return null;
    return map;
  } catch (_) {
    return null;
  }
}

String? readSchoolSplashDataUrl({String? schoolId}) {
  final map = readSchoolSplashMap(schoolId: schoolId);
  final dataUrl = map?['dataUrl'] as String?;
  if (dataUrl == null || !dataUrl.startsWith('data:image')) return null;
  return dataUrl;
}

Uint8List? readSchoolSplashBytes({String? schoolId}) {
  try {
    final dataUrl = readSchoolSplashDataUrl(schoolId: schoolId);
    if (dataUrl == null) return null;
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    return Uint8List.fromList(base64Decode(dataUrl.substring(comma + 1)));
  } catch (_) {
    return null;
  }
}
