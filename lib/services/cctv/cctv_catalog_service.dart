/// Campus CCTV sites shown in Admin → CCTV.
///
/// Live streams are not wired yet. When a school NVR/cloud (Hik-Connect,
/// RTSP, HLS, …) is linked, set [CctvCameraSite.streamUrl] and the player
/// on [WebCctvPage] can start without changing the module layout.
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

  /// HLS/HTTPS snapshot or player URL from the school NVR. Null = mapped only.
  final String? streamUrl;

  bool get isWired => streamUrl != null && streamUrl!.trim().isNotEmpty;
}

class CctvCatalogService {
  CctvCatalogService._();
  static final instance = CctvCatalogService._();

  /// Default campus camera map used for demos and as the wiring template.
  List<CctvCameraSite> sitesForSchool(String? schoolId) {
    final sid = (schoolId ?? 'school').trim().toUpperCase();
    return [
      CctvCameraSite(
        id: '$sid-gate',
        name: 'Main gate',
        location: 'Entrance / pickup',
      ),
      CctvCameraSite(
        id: '$sid-playground',
        name: 'Playground',
        location: 'Outdoor yard',
      ),
      CctvCameraSite(
        id: '$sid-corridor',
        name: 'Main corridor',
        location: 'Ground floor',
      ),
      CctvCameraSite(
        id: '$sid-parking',
        name: 'Parking',
        location: 'Staff & bus park',
      ),
    ];
  }
}
