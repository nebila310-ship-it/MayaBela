import 'package:flutter/foundation.dart';

import 'package:mayabela/services/persistence/local_json_store.dart';

/// Campus CCTV sites shown in Admin → CCTV.
///
/// Live picture comes from the school's own NVR (Hik-Connect, RTSP, HLS).
/// MayaBela never uploads camera footage or NVR URLs to the school cloud.
class CctvCameraSite {
  const CctvCameraSite({
    required this.id,
    required this.name,
    required this.location,
    this.streamUrl,
  });

  final String id;
  final String name;
  final String location;

  /// HLS/HTTPS or RTSP URL from the school NVR. Stored on this device only.
  final String? streamUrl;

  bool get isWired => streamUrl != null && streamUrl!.trim().isNotEmpty;

  CctvCameraSite copyWith({String? streamUrl, bool clearStreamUrl = false}) {
    return CctvCameraSite(
      id: id,
      name: name,
      location: location,
      streamUrl: clearStreamUrl ? null : (streamUrl ?? this.streamUrl),
    );
  }
}

/// Local-only camera map. Does not touch CloudAppStore or the outbox.
class CctvCatalogService extends ChangeNotifier {
  CctvCatalogService._();
  static final instance = CctvCatalogService._();

  static const persistKey = 'cctv_local_stream_urls_v1';

  /// Hard rule used by tests: this module is not a MayaBela cloud collection.
  static const storesInMayaBelaCloud = false;

  bool _loaded = false;
  final Map<String, String> _localUrls = {};

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
    _loaded = true;
    notifyListeners();
  }

  /// Default campus camera map used for demos and as the wiring template.
  List<CctvCameraSite> sitesForSchool(String? schoolId) {
    final sid = (schoolId ?? 'school').trim().toUpperCase();
    return [
      CctvCameraSite(
        id: '$sid-gate',
        name: 'Main gate',
        location: 'Entrance / pickup',
        streamUrl: localStreamUrl('$sid-gate'),
      ),
      CctvCameraSite(
        id: '$sid-playground',
        name: 'Playground',
        location: 'Outdoor yard',
        streamUrl: localStreamUrl('$sid-playground'),
      ),
      CctvCameraSite(
        id: '$sid-corridor',
        name: 'Main corridor',
        location: 'Ground floor',
        streamUrl: localStreamUrl('$sid-corridor'),
      ),
      CctvCameraSite(
        id: '$sid-parking',
        name: 'Parking',
        location: 'Staff & bus park',
        streamUrl: localStreamUrl('$sid-parking'),
      ),
    ];
  }

  String? localStreamUrl(String siteId) {
    final url = _localUrls[siteId.trim()];
    if (url == null || url.isEmpty) return null;
    return url;
  }

  /// Save or clear an NVR URL on this device. Never enqueues a cloud write.
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
    await LocalJsonStore.writeMap(persistKey, Map<String, dynamic>.from(_localUrls));
    notifyListeners();
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    _loaded = false;
    _localUrls.clear();
  }
}
