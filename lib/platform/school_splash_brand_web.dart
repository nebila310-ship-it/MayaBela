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
  } catch (_) {}
}

Map<String, dynamic>? readSchoolSplashMap({String? schoolId}) {
  try {
    final map = _splashMap();
    if (map == null) return null;
    final storedId = (map['schoolId'] as String? ?? '').trim().toUpperCase();
    final want = schoolId?.trim().toUpperCase();
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
