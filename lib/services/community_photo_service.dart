import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Stores optional community profile photos on device.
class CommunityPhotoService {
  CommunityPhotoService._();
  static final instance = CommunityPhotoService._();

  final _picker = ImagePicker();

  Future<String?> pickAndSave() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) return null;

    final source = File(picked.path);
    if (!await source.exists()) return null;

    final dir = await _photosDir();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final dest = File('${dir.path}/community_$id.jpg');
    await source.copy(dest.path);
    return dest.path;
  }

  Future<Directory> _photosDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/community_photos');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
