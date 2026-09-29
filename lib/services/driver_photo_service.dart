import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/profile_photo_codec.dart';

/// Saves square driver profile photos keyed by driver ID.
class DriverPhotoService {
  DriverPhotoService._();
  static final instance = DriverPhotoService._();

  final Map<String, String> _cachedPaths = {};
  final Map<String, Uint8List> _cachedBytes = {};

  bool get _canPick => AuthService.currentUser != null;

  String? get lastError => ProfilePhotoCodec.lastError;

  Future<Uint8List?> pickBytes() async {
    if (!_canPick) {
      ProfilePhotoCodec.lastError = 'You do not have permission to add photos.';
      return null;
    }
    return ProfilePhotoCodec.pickBytes();
  }

  Future<File?> pickFromGallery() async {
    if (kIsWeb) return null;
    final bytes = await pickBytes();
    if (bytes == null) return null;
    final file = File(
      '${Directory.systemTemp.path}/driver_pick_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<String?> saveForDriver(String driverId, File source) async {
    return saveBytesForDriver(driverId, await source.readAsBytes());
  }

  Future<String?> saveBytesForDriver(
    String driverId,
    Uint8List sourceBytes,
  ) async {
    return ProfilePhotoCodec.saveBytes(
      personId: driverId,
      sourceBytes: sourceBytes,
      folder: 'driver_photos',
      byteCache: _cachedBytes,
      pathCache: _cachedPaths,
    );
  }

  void rememberPath(String driverId, String path) {
    _cachedPaths[driverId.trim().toUpperCase()] = path;
  }

  void rememberBytes(String driverId, Uint8List bytes) {
    _cachedBytes[driverId.trim().toUpperCase()] = bytes;
  }

  Uint8List? lookupBytes(String? driverId, {String? storedPath}) {
    return ProfilePhotoCodec.lookupBytes(
      personId: driverId,
      byteCache: _cachedBytes,
      pathCache: _cachedPaths,
      storedPath: storedPath,
    );
  }

  String? lookupPath(String? driverId) {
    if (driverId == null || driverId.trim().isEmpty) return null;
    return _cachedPaths[driverId.trim().toUpperCase()];
  }

  Future<String?> resolvePath(String? driverId, {String? storedPath}) {
    return ProfilePhotoCodec.resolvePath(
      personId: driverId,
      folder: 'driver_photos',
      pathCache: _cachedPaths,
      storedPath: storedPath,
    );
  }

  Future<Uint8List?> hydrateBytes(String? driverId, {String? storedPath}) {
    return ProfilePhotoCodec.hydrateBytes(
      personId: driverId,
      byteCache: _cachedBytes,
      pathCache: _cachedPaths,
      storedPath: storedPath,
    );
  }
}
