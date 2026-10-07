import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/platform/school_splash_brand.dart';
import 'package:mayabela/services/login_prefs_service.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

class SchoolPublicBrand {
  const SchoolPublicBrand({
    required this.schoolId,
    required this.name,
    this.logoUrl,
    this.logoStyle = SchoolLogoStyle.rectangular,
  });

  final String schoolId;
  final String name;
  final String? logoUrl;
  final SchoolLogoStyle logoStyle;
}

/// Loads the public school name for login/tab chrome on a first visit.
///
/// Logos already work without a JWT (guessable public storage URL). Names live
/// in `school_registry`, so this calls the `school-public-brand` edge function.
class SchoolPublicBrandService {
  SchoolPublicBrandService._();
  static final instance = SchoolPublicBrandService._();

  final Map<String, SchoolPublicBrand> _cache = {};
  final Set<String> _misses = {};
  final Map<String, Future<SchoolPublicBrand?>> _inflight = {};

  /// Tests inject a brand without hitting Supabase.
  Future<SchoolPublicBrand?> Function(String schoolId)? debugFetchOverride;

  /// Widget tests leave this false so login chrome never opens a live socket.
  @visibleForTesting
  bool debugAllowNetwork = true;

  SchoolPublicBrand? cached(String schoolId) {
    final id = schoolId.trim().toUpperCase();
    if (id.isEmpty) return null;
    return _cache[id];
  }

  @visibleForTesting
  void debugReset() {
    _cache.clear();
    _misses.clear();
    _inflight.clear();
    debugFetchOverride = null;
    debugAllowNetwork = true;
  }

  @visibleForTesting
  void debugPut(SchoolPublicBrand brand) {
    final id = brand.schoolId.trim().toUpperCase();
    if (id.isEmpty || brand.name.trim().isEmpty) return;
    _cache[id] = SchoolPublicBrand(
      schoolId: id,
      name: brand.name.trim(),
      logoUrl: brand.logoUrl,
      logoStyle: brand.logoStyle,
    );
    _misses.remove(id);
  }

  /// Local name already known (registry, remembered prefs, splash, or fetch cache).
  String? localName(String schoolId) {
    final id = schoolId.trim();
    if (id.isEmpty) return null;
    final record = SchoolRegistryService.instance.lookup(id);
    final fromRecord = record?.name.trim() ?? '';
    if (fromRecord.isNotEmpty) return fromRecord;
    final remembered = LoginPrefsService.instance.brandForSchool(id);
    final fromRemembered = remembered?.name.trim() ?? '';
    if (fromRemembered.isNotEmpty) return fromRemembered;
    final splash = SchoolSplashBrand.readMeta(schoolId: id);
    final fromSplash = splash?.name.trim() ?? '';
    if (fromSplash.isNotEmpty) return fromSplash;
    final cachedName = cached(id)?.name.trim() ?? '';
    if (cachedName.isNotEmpty) return cachedName;
    return null;
  }

  /// Fetch the public name if needed and persist it for login/tab chrome.
  Future<SchoolPublicBrand?> loadAndRemember(String schoolId) async {
    final id = schoolId.trim().toUpperCase();
    if (id.length < 3) return null;

    final existingName = localName(id);
    if (existingName != null && existingName.isNotEmpty) {
      final remembered = LoginPrefsService.instance.brandForSchool(id);
      final record = SchoolRegistryService.instance.lookup(id);
      final splash = SchoolSplashBrand.readMeta(schoolId: id);
      final cachedBrand = cached(id);
      return SchoolPublicBrand(
        schoolId: id,
        name: existingName,
        logoUrl:
            record?.displayLogoUrl ??
            remembered?.logoUrl ??
            splash?.logoUrl ??
            cachedBrand?.logoUrl,
        logoStyle:
            record?.logoStyle ??
            remembered?.logoStyle ??
            splash?.logoStyle ??
            cachedBrand?.logoStyle ??
            SchoolLogoStyle.rectangular,
      );
    }

    final brand = await fetch(id);
    if (brand == null) return null;
    await LoginPrefsService.instance.rememberSchoolBrand(
      schoolId: brand.schoolId,
      name: brand.name,
      logoUrl:
          brand.logoUrl ??
          SchoolLogoService.publicUrl(brand.schoolId, style: brand.logoStyle),
      logoStyle: brand.logoStyle,
    );
    return brand;
  }

  Future<SchoolPublicBrand?> fetch(String schoolId) async {
    final id = schoolId.trim().toUpperCase();
    if (id.length < 3) return null;
    final hit = _cache[id];
    if (hit != null) return hit;
    if (_misses.contains(id)) return null;
    final pending = _inflight[id];
    if (pending != null) return pending;

    final future = _fetchUncached(id);
    _inflight[id] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(id);
    }
  }

  Future<SchoolPublicBrand?> _fetchUncached(String id) async {
    try {
      SchoolPublicBrand? parsed;
      if (debugFetchOverride != null) {
        parsed = await debugFetchOverride!(id);
      } else if (!debugAllowNetwork) {
        parsed = null;
      } else {
        parsed = await _invokeEdge(id);
      }
      if (parsed == null || parsed.name.trim().isEmpty) {
        _misses.add(id);
        return null;
      }
      final brand = SchoolPublicBrand(
        schoolId: id,
        name: parsed.name.trim(),
        logoUrl: parsed.logoUrl?.trim().isEmpty == true
            ? null
            : parsed.logoUrl?.trim(),
        logoStyle: parsed.logoStyle,
      );
      _cache[id] = brand;
      _misses.remove(id);
      return brand;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('school-public-brand failed: $e');
      }
      return null;
    }
  }

  Future<SchoolPublicBrand?> _invokeEdge(String id) async {
    await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
    if (!SupabaseBootstrap.isInitialized) return null;
    final res = await SupabaseBootstrap.client.functions.invoke(
      'school-public-brand',
      body: {'schoolId': id},
    );
    final data = res.data;
    if (data is! Map) return null;
    if (data['ok'] != true) return null;
    final name = data['name']?.toString().trim() ?? '';
    if (name.isEmpty) return null;
    return SchoolPublicBrand(
      schoolId: id,
      name: name,
      logoUrl: data['logoUrl']?.toString(),
      logoStyle: SchoolLogoStyle.parse(data['logoStyle']?.toString()),
    );
  }
}
