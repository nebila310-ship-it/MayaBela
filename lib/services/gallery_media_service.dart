import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class GalleryMediaPick {
  const GalleryMediaPick({
    required this.filePath,
    required this.displayName,
  });

  final String filePath;
  final String displayName;
}

/// Picks photos/videos from device storage for class gallery posts.
class GalleryMediaService {
  GalleryMediaService._();
  static final instance = GalleryMediaService._();

  final _picker = ImagePicker();

  Future<GalleryMediaPick?> pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) return null;
    return _persistPick(picked, prefix: 'gallery_photo');
  }

  Future<GalleryMediaPick?> pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return null;
    return _persistPick(picked, prefix: 'gallery_video');
  }

  Future<GalleryMediaPick?> _persistPick(
    XFile picked, {
    required String prefix,
  }) async {
    final source = File(picked.path);
    if (!await source.exists()) return null;

    final dir = await _galleryDir();
    final ext = picked.name.contains('.')
        ? picked.name.split('.').last
        : (prefix.contains('video') ? 'mp4' : 'jpg');
    final id = DateTime.now().millisecondsSinceEpoch;
    final dest = File('${dir.path}/${prefix}_$id.$ext');
    await source.copy(dest.path);

    return GalleryMediaPick(
      filePath: dest.path,
      displayName: picked.name.isNotEmpty ? picked.name : dest.path.split('/').last,
    );
  }

  Future<Directory> _galleryDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/gallery_media');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
