import 'package:flutter/foundation.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/school_registry_service.dart';

/// Campus CCTV sites shown in Admin → CCTV.
///
/// Live picture stays on the school's NVR. Site URLs sync to staff desks
/// so every admin sees the same wiring. Footage is never stored here.
class CctvCameraSite {
  const CctvCameraSite({
    required this.id,
    required this.name,
    required this.location,
    this.campusName,
    this.streamUrl,
  });

  final String id;
  final String name;
  final String location;
  final String? campusName;

  /// HLS/HTTPS or RTSP URL from the school NVR.
  final String? streamUrl;

  bool get isWired => streamUrl != null && streamUrl!.trim().isNotEmpty;

  CctvCameraSite copyWith({
    String? name,
    String? location,
    String? campusName,
    String? streamUrl,
    bool clearStreamUrl = false,
  }) {
    return CctvCameraSite(
      id: id,
      name: name ?? this.name,
      location: location ?? this.location,
      campusName: campusName ?? this.campusName,
      streamUrl: clearStreamUrl ? null : (streamUrl ?? this.streamUrl),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'location': location,
        if (campusName != null) 'campusName': campusName,
        if (streamUrl != null) 'streamUrl': streamUrl,
        if (AuthService.activeSchoolId != null)
          'schoolId': AuthService.activeSchoolId,
      };

  static CctvCameraSite? fromMap(Map<String, dynamic> map) {
    try {
      return CctvCameraSite(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        location: map['location'] as String? ?? '',
        campusName: map['campusName'] as String?,
        streamUrl: map['streamUrl'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Camera map for the campus list. Footage is not a MayaBela cloud collection.
class CctvCatalogService extends ChangeNotifier {
  CctvCatalogService._();
  static final instance = CctvCatalogService._();

  static const persistKey = 'cctv_local_stream_urls_v1';
  static const sitesLocalKey = 'persisted_campus_cameras';
  static const collection = 'campus_cameras';

  /// Footage / NVR recordings are not a MayaBela cloud collection.
  static const storesInMayaBelaCloud = false;

  bool _loaded = false;
  final Map<String, String> _localUrls = {};
  final List<CctvCameraSite> _customSites = [];

  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final rows = await LocalJsonStore.readMap(persistKey);
    _localUrls
      ..clear()
      ..addEntries(
        (rows ?? {}).entries
            .where((e) => e.key.trim().isNotEmpty && '${e.value}'.trim().isNotEmpty)
            .map((e) => MapEntry(e.key.trim(), '${e.value}'.trim())),
      );
    final siteRows = await LocalJsonStore.readList(sitesLocalKey);
    _customSites
      ..clear()
      ..addAll(siteRows.map(CctvCameraSite.fromMap).whereType<CctvCameraSite>());

    final crud = DocumentStore();
    if (crud.available) {
      try {
        final cloud = await crud.readBySchool(
          collection,
          schoolId: AuthService.activeSchoolId,
        );
        applyPersisted(
          cloud.map(CctvCameraSite.fromMap).whereType<CctvCameraSite>().toList(),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('CctvCatalogService cloud load: $e');
      }
    }
    _loaded = true;
    notifyListeners();
  }

  void applyPersisted(List<CctvCameraSite> rows, {bool merge = true}) {
    if (!merge) {
      _customSites.clear();
      _localUrls.clear();
    }
    for (final site in rows) {
      final idx = _customSites.indexWhere((s) => s.id == site.id);
      if (idx >= 0) {
        _customSites[idx] = site;
      } else {
        _customSites.add(site);
      }
      final url = site.streamUrl?.trim() ?? '';
      if (url.isEmpty) {
        _localUrls.remove(site.id);
      } else {
        _localUrls[site.id] = url;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// Default campus camera map used for demos and as the wiring template.
  List<CctvCameraSite> sitesForSchool(String? schoolId) {
    final sid = (schoolId ?? 'school').trim().toUpperCase();
    final campus = SchoolRegistryService.instance.campusesForSchool(schoolId).first;
    final defaults = [
      CctvCameraSite(
        id: '$sid-gate',
        name: 'Main gate',
        location: 'Entrance / pickup',
        campusName: campus,
        streamUrl: localStreamUrl('$sid-gate'),
      ),
      CctvCameraSite(
        id: '$sid-playground',
        name: 'Playground',
        location: 'Outdoor yard',
        campusName: campus,
        streamUrl: localStreamUrl('$sid-playground'),
      ),
      CctvCameraSite(
        id: '$sid-corridor',
        name: 'Main corridor',
        location: 'Ground floor',
        campusName: campus,
        streamUrl: localStreamUrl('$sid-corridor'),
      ),
      CctvCameraSite(
        id: '$sid-parking',
        name: 'Parking',
        location: 'Staff & bus park',
        campusName: campus,
        streamUrl: localStreamUrl('$sid-parking'),
      ),
    ];
    if (_customSites.isEmpty) return defaults;
    return [
      for (final site in _customSites)
        site.copyWith(streamUrl: site.streamUrl ?? localStreamUrl(site.id)),
    ];
  }

  List<CctvCameraSite> sitesForCampus(String campusName, {String? schoolId}) {
    return sitesForSchool(schoolId)
        .where(
          (s) =>
              (s.campusName ?? '').toLowerCase() == campusName.toLowerCase(),
        )
        .toList(growable: false);
  }

  String? localStreamUrl(String siteId) {
    final url = _localUrls[siteId.trim()];
    if (url == null || url.isEmpty) return null;
    return url;
  }

  Future<CctvCameraSite> addSite({
    required String name,
    required String campusName,
    String location = '',
    String? streamUrl,
  }) async {
    await ensureLoaded();
    final site = CctvCameraSite(
      id: 'cam-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      location: location.trim().isEmpty ? campusName.trim() : location.trim(),
      campusName: campusName.trim(),
      streamUrl: streamUrl?.trim().isEmpty == true ? null : streamUrl?.trim(),
    );
    if (_customSites.isEmpty) {
      _customSites.addAll(
        sitesForSchool(AuthService.activeSchoolId).map(
          (s) => s.copyWith(streamUrl: localStreamUrl(s.id)),
        ),
      );
    }
    _customSites.add(site);
    if (site.isWired) _localUrls[site.id] = site.streamUrl!;
    notifyListeners();
    await _persistSite(site);
    return site;
  }

  /// Save or clear an NVR URL. Syncs to staff desks; never stores footage.
  Future<void> setLocalStreamUrl({
    required String siteId,
    String? streamUrl,
  }) async {
    await ensureLoaded();
    final id = siteId.trim();
    if (id.isEmpty) return;
    final url = streamUrl?.trim() ?? '';
    if (url.isEmpty) {
      _localUrls.remove(id);
    } else {
      _localUrls[id] = url;
    }
    final idx = _customSites.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      _customSites[idx] = _customSites[idx].copyWith(
        streamUrl: url.isEmpty ? null : url,
        clearStreamUrl: url.isEmpty,
      );
    } else if (url.isNotEmpty) {
      final match = sitesForSchool(AuthService.activeSchoolId)
          .where((s) => s.id == id)
          .firstOrNull;
      if (match != null) {
        if (_customSites.isEmpty) {
          _customSites.addAll(
            sitesForSchool(AuthService.activeSchoolId).map(
              (s) => s.id == id
                  ? s.copyWith(streamUrl: url)
                  : s.copyWith(streamUrl: localStreamUrl(s.id)),
            ),
          );
        } else {
          _customSites.add(match.copyWith(streamUrl: url));
        }
      }
    }
    await LocalJsonStore.writeMap(
      persistKey,
      Map<String, dynamic>.from(_localUrls),
    );
    CctvCameraSite? site;
    for (final row in _customSites) {
      if (row.id == id) site = row;
    }
    if (site != null) await _persistSite(site);
    notifyListeners();
  }

  Future<void> renameCampus({
    required String from,
    required String to,
  }) async {
    final target = to.trim();
    if (target.isEmpty || target == from) return;
    var changed = false;
    for (var i = 0; i < _customSites.length; i++) {
      if (_customSites[i].campusName == from) {
        _customSites[i] = _customSites[i].copyWith(campusName: target);
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    for (final site in _customSites.where((s) => s.campusName == target)) {
      await _persistSite(site);
    }
  }

  Future<void> _persistSite(CctvCameraSite site) async {
    await LocalJsonStore.writeList(
      sitesLocalKey,
      _customSites.map((s) => s.toMap()).toList(),
    );
    final crud = DocumentStore();
    if (!crud.available) return;
    try {
      await crud.createOrUpdate(
        collection: collection,
        docId: site.id,
        data: site.toMap(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('CctvCatalogService persist: $e');
    }
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    _loaded = false;
    _localUrls.clear();
    _customSites.clear();
  }
}
