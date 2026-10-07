import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/profile_photo_codec.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/student_registry_service.dart';

/// Saves square student profile photos keyed by student ID.
///
/// Bytes are uploaded to private school-files so other devices can load them.
class StudentPhotoService {
  StudentPhotoService._();
  static final instance = StudentPhotoService._();

  final Map<String, String> _cachedPaths = {};
  final Map<String, Uint8List> _cachedBytes = {};
  final Set<String> _promoting = {};

  bool get _canPick =>
      AuthService.currentUser != null &&
      (AuthService.currentUser?.roleKey == AuthService.roleAdmin ||
          AuthService.hasPermission(SchoolPermissions.manageStudents));

  String? get lastError => ProfilePhotoCodec.lastError;

  /// Gallery / file pick → bytes (works on mobile and web).
  Future<Uint8List?> pickBytes() async {
    if (!_canPick) {
      ProfilePhotoCodec.lastError = 'You do not have permission to add photos.';
      return null;
    }
    return ProfilePhotoCodec.pickBytes();
  }

  /// Legacy File picker for non-web callers. Prefer [pickBytes].
  Future<File?> pickFromGallery() async {
    if (kIsWeb) return null;
    final bytes = await pickBytes();
    if (bytes == null) return null;
    final file = File(
      '${Directory.systemTemp.path}/student_pick_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<String?> saveForStudent(String studentId, File source) async {
    return saveBytesForStudent(studentId, await source.readAsBytes());
  }

  Future<String?> saveBytesForStudent(
    String studentId,
    Uint8List sourceBytes,
  ) async {
    return ProfilePhotoCodec.saveBytes(
      personId: studentId,
      sourceBytes: sourceBytes,
      folder: 'student_photos',
      byteCache: _cachedBytes,
      pathCache: _cachedPaths,
    );
  }

  void rememberPath(String studentId, String path) {
    _cachedPaths[studentId.trim().toUpperCase()] = path;
  }

  void rememberBytes(String studentId, Uint8List bytes) {
    _cachedBytes[studentId.trim().toUpperCase()] = bytes;
  }

  Uint8List? lookupBytes(String? studentId, {String? storedPath}) {
    return ProfilePhotoCodec.lookupBytes(
      personId: studentId,
      byteCache: _cachedBytes,
      pathCache: _cachedPaths,
      storedPath: storedPath,
    );
  }

  Future<String?> resolvePath(String? studentId, {String? storedPath}) {
    return ProfilePhotoCodec.resolvePath(
      personId: studentId,
      folder: 'student_photos',
      pathCache: _cachedPaths,
      storedPath: storedPath,
    );
  }

  Future<Uint8List?> hydrateBytes(
    String? studentId, {
    String? storedPath,
  }) async {
    final bytes = await ProfilePhotoCodec.hydrateBytes(
      personId: studentId,
      byteCache: _cachedBytes,
      pathCache: _cachedPaths,
      storedPath: storedPath,
      folder: 'student_photos',
    );
    if (bytes != null && bytes.isNotEmpty) {
      unawaited(_promoteToCloud(studentId, bytes, storedPath: storedPath));
    }
    return bytes;
  }

  Future<void> promotePendingToCloud() async {
    for (final student in StudentRegistryService.instance.registrySnapshot()) {
      final path = student.photoPath;
      if (path == null || path.trim().isEmpty) continue;
      if (!ProfilePhotoCodec.isDeviceLocalPath(path)) continue;
      final bytes =
          lookupBytes(student.studentId, storedPath: path) ??
          await ProfilePhotoCodec.bytesFromStoredPath(path);
      if (bytes == null || bytes.isEmpty) continue;
      await _promoteToCloud(student.studentId, bytes, storedPath: path);
    }
  }

  Future<void> _promoteToCloud(
    String? studentId,
    Uint8List bytes, {
    String? storedPath,
  }) async {
    if (studentId == null || studentId.trim().isEmpty) return;
    final id = studentId.trim().toUpperCase();
    if (!_promoting.add(id)) return;
    try {
      var path = _cachedPaths[id] ?? storedPath;
      if (path == null || ProfilePhotoCodec.isDeviceLocalPath(path)) {
        final cloud = await ProfilePhotoCodec.uploadBytesToSchoolFiles(
          personId: id,
          folder: 'student_photos',
          bytes: bytes,
          reportError: false,
        );
        if (cloud == null || cloud.isEmpty) return;
        rememberPath(id, cloud);
        WebAttachmentCache.instance.remember(cloud, bytes);
        path = cloud;
      }
      final current = StudentRegistryService.instance
          .lookupAnyById(id)
          ?.photoPath;
      if (current == path) return;
      StudentRegistryService.instance.updatePhoto(id, path);
    } finally {
      _promoting.remove(id);
    }
  }
}
