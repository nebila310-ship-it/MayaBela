import 'dart:typed_data';

import 'package:mayabela/services/profile_photo_codec.dart';

/// Community group photos — uploaded to school-files so other devices can load them.
class CommunityPhotoService {
  CommunityPhotoService._();
  static final instance = CommunityPhotoService._();

  final Map<String, Uint8List> _cachedBytes = {};
  final Map<String, String> _cachedPaths = {};

  Future<String?> pickAndSave() async {
    final bytes = await ProfilePhotoCodec.pickBytes();
    if (bytes == null || bytes.isEmpty) return null;
    final id = 'COM-${DateTime.now().millisecondsSinceEpoch}';
    return ProfilePhotoCodec.saveBytes(
      personId: id,
      sourceBytes: bytes,
      folder: 'community_photos',
      byteCache: _cachedBytes,
      pathCache: _cachedPaths,
    );
  }
}
