import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mayabela/services/auth_service.dart';

/// Saves square teacher profile photos on device keyed by teacher ID.
class TeacherPhotoService {
  TeacherPhotoService._();
  static final instance = TeacherPhotoService._();

  final _picker = ImagePicker();

  Future<File?> pickFromGallery() async {
    if (AuthService.currentUser?.roleKey != AuthService.roleAdmin) {
      return null;
    }
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 90,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  Future<String?> saveForTeacher(String teacherId, File source) async {
    final id = teacherId.trim().toUpperCase();
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final size = decoded.width < decoded.height ? decoded.width : decoded.height;
    final left = (decoded.width - size) ~/ 2;
    final top = (decoded.height - size) ~/ 2;
    final cropped = img.copyCrop(decoded, x: left, y: top, width: size, height: size);
    final resized = img.copyResize(cropped, width: 512, height: 512);
    final encoded = img.encodeJpg(resized, quality: 88);

    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${dir.path}/teacher_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    final file = File('${photosDir.path}/$id.jpg');
    await file.writeAsBytes(encoded);
    return file.path;
  }

  final Map<String, String> _cachedPaths = {};

  void rememberPath(String teacherId, String path) {
    _cachedPaths[teacherId.trim().toUpperCase()] = path;
  }

  String? lookupPath(String? teacherId) {
    if (teacherId == null || teacherId.trim().isEmpty) return null;
    final id = teacherId.trim().toUpperCase();
    final cached = _cachedPaths[id];
    if (cached != null && File(cached).existsSync()) return cached;
    return null;
  }

  Future<String?> resolvePath(String? teacherId) async {
    if (teacherId == null || teacherId.trim().isEmpty) return null;
    final id = teacherId.trim().toUpperCase();
    final cached = lookupPath(id);
    if (cached != null) return cached;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/teacher_photos/$id.jpg');
    if (await file.exists()) {
      _cachedPaths[id] = file.path;
      return file.path;
    }
    return null;
  }
}
