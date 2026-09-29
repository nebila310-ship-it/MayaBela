import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/profile_photo_codec.dart';
import 'package:mayabela/services/rbac/module_access.dart';

/// Saves square teacher / staff profile photos keyed by teacher ID.
class TeacherPhotoService {
  TeacherPhotoService._();
  static final instance = TeacherPhotoService._();

  final Map<String, String> _cachedPaths = {};
  final Map<String, Uint8List> _cachedBytes = {};

  bool get _canPick =>
      AuthService.currentUser != null &&
      (AuthService.currentUser?.roleKey == AuthService.roleAdmin ||
          ModuleAccess.canHireStaff);

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
      '${Directory.systemTemp.path}/teacher_pick_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<String?> saveForTeacher(String teacherId, File source) async {
    return saveBytesForTeacher(teacherId, await source.readAsBytes());
  }

  Future<String?> saveBytesForTeacher(
    String teacherId,
    Uint8List sourceBytes,
  ) async {
    return ProfilePhotoCodec.saveBytes(
      personId: teacherId,
      sourceBytes: sourceBytes,
      folder: 'teacher_photos',
      byteCache: _cachedBytes,
      pathCache: _cachedPaths,
    );
  }

  void rememberPath(String teacherId, String path) {
    _cachedPaths[teacherId.trim().toUpperCase()] = path;
  }

  void rememberBytes(String teacherId, Uint8List bytes) {
    _cachedBytes[teacherId.trim().toUpperCase()] = bytes;
  }

  Uint8List? lookupBytes(String? teacherId, {String? storedPath}) {
    return ProfilePhotoCodec.lookupBytes(
      personId: teacherId,
      byteCache: _cachedBytes,
      pathCache: _cachedPaths,
      storedPath: storedPath,
    );
  }

  String? lookupPath(String? teacherId) {
    if (teacherId == null || teacherId.trim().isEmpty) return null;
    final id = teacherId.trim().toUpperCase();
    return _cachedPaths[id];
  }

  Future<String?> resolvePath(String? teacherId, {String? storedPath}) {
    return ProfilePhotoCodec.resolvePath(
      personId: teacherId,
      folder: 'teacher_photos',
      pathCache: _cachedPaths,
      storedPath: storedPath,
    );
  }
}
