import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/platform/platform_file_storage.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';

class GalleryMediaPick {
  const GalleryMediaPick({
    required this.filePath,
    required this.displayName,
  });

  final String filePath;
  final String displayName;
}

/// Picks photos/videos for class gallery posts on web and native.
class GalleryMediaService {
  GalleryMediaService._();
  static final instance = GalleryMediaService._();

  Future<GalleryMediaPick?> pickPhoto() => _pick(images: true);

  Future<GalleryMediaPick?> pickVideo() => _pick(images: false);

  Future<GalleryMediaPick?> _pick({required bool images}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: images ? FileType.image : FileType.video,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      return await persistPlatformFile(result.files.first, images: images);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GalleryMediaService pick failed: $e');
      }
      return null;
    }
  }

  Future<GalleryMediaPick?> persistPlatformFile(
    PlatformFile file, {
    required bool images,
  }) async {
    List<int>? bytes = file.bytes;
    if ((bytes == null || bytes.isEmpty) &&
        !kIsWeb &&
        file.path != null &&
        file.path!.isNotEmpty) {
      try {
        bytes = await File(file.path!).readAsBytes();
      } catch (_) {
        bytes = null;
      }
    }
    if (bytes == null || bytes.isEmpty) return null;

    final name = file.name.trim().isNotEmpty
        ? file.name
        : (images ? 'gallery_photo.jpg' : 'gallery_video.mp4');
    return persistBytes(fileName: name, bytes: bytes);
  }

  Future<GalleryMediaPick?> persistBytes({
    required String fileName,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty) return null;
    final safeName = fileName.trim().isEmpty ? 'gallery_media.bin' : fileName;

    AnnouncementAttachment? saved;
    try {
      saved = await saveAttachmentBytes(
        fileName: safeName,
        bytes: bytes,
        subdir: 'gallery_media',
        size: bytes.length,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GalleryMediaService persist failed: $e');
      }
    }

    final localPath = saved?.filePath ??
        WebAttachmentCache.instance.store(safeName, bytes);
    final displayName = saved?.fileName ?? safeName;

    final uploaded = await AnnouncementAttachmentService.instance
        .uploadSavedAttachment(
      fileName: displayName,
      bytes: bytes,
      localPath: localPath,
      subdir: 'gallery_media',
      attachmentId: saved?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
    );

    return GalleryMediaPick(
      filePath: uploaded ?? localPath,
      displayName: displayName,
    );
  }
}
