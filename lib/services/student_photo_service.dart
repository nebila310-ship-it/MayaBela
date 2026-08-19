import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';

/// Saves square student profile photos keyed by student ID.
///
/// On web, bytes live in [WebAttachmentCache] under a `web://` path.
class StudentPhotoService {
  StudentPhotoService._();
  static final instance = StudentPhotoService._();

  final _picker = ImagePicker();
  final Map<String, String> _cachedPaths = {};
  final Map<String, Uint8List> _cachedBytes = {};

  bool get _canPick =>
      AuthService.currentUser?.roleKey == AuthService.roleAdmin ||
      AuthService.hasPermission(SchoolPermissions.manageStudents);

  /// Gallery pick → JPEG-ready bytes (works on mobile and web).
  Future<Uint8List?> pickBytes() async {
    if (!_canPick) return null;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 90,
      );
      if (picked == null) return null;
      return await picked.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Legacy File picker for non-web callers. Prefer [pickBytes].
  Future<File?> pickFromGallery() async {
    if (kIsWeb) return null;
    final bytes = await pickBytes();
    if (bytes == null) return null;
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/student_pick_${DateTime.now().millisecondsSinceEpoch}.jpg',
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
    final id = studentId.trim().toUpperCase();
    if (id.isEmpty || sourceBytes.isEmpty) return null;

    final encoded = _normalizeSquareJpeg(sourceBytes);
    if (encoded == null) return null;

    if (kIsWeb) {
      final path = WebAttachmentCache.instance.store('$id.jpg', encoded);
      rememberPath(id, path);
      _cachedBytes[id] = encoded;
      return path;
    }

    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${dir.path}/student_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final file = File('${photosDir.path}/$id.jpg');
    await file.writeAsBytes(encoded);
    rememberPath(id, file.path);
    _cachedBytes[id] = encoded;
    return file.path;
  }

  Uint8List? _normalizeSquareJpeg(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final size =
        decoded.width < decoded.height ? decoded.width : decoded.height;
    final left = (decoded.width - size) ~/ 2;
    final top = (decoded.height - size) ~/ 2;
    final cropped =
        img.copyCrop(decoded, x: left, y: top, width: size, height: size);
    final resized = img.copyResize(cropped, width: 512, height: 512);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
  }

  void rememberPath(String studentId, String path) {
    _cachedPaths[studentId.trim().toUpperCase()] = path;
  }

  void rememberBytes(String studentId, Uint8List bytes) {
    _cachedBytes[studentId.trim().toUpperCase()] = bytes;
  }

  Uint8List? lookupBytes(String? studentId) {
    if (studentId == null || studentId.trim().isEmpty) return null;
    final id = studentId.trim().toUpperCase();
    final cached = _cachedBytes[id];
    if (cached != null) return cached;
    final path = _cachedPaths[id];
    if (path != null && WebAttachmentCache.instance.isWebPath(path)) {
      return WebAttachmentCache.instance.read(path);
    }
    return null;
  }

  Future<String?> resolvePath(String? studentId) async {
    if (studentId == null || studentId.trim().isEmpty) return null;
    final id = studentId.trim().toUpperCase();
    final cached = _cachedPaths[id];
    if (cached != null) {
      if (WebAttachmentCache.instance.isWebPath(cached)) return cached;
      if (!kIsWeb && File(cached).existsSync()) return cached;
    }

    if (kIsWeb) return null;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/student_photos/$id.jpg');
    if (await file.exists()) {
      _cachedPaths[id] = file.path;
      return file.path;
    }
    return null;
  }
}
