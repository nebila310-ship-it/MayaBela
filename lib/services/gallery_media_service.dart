import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/platform/platform_file_storage.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/profile_photo_codec.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/utils/attachment_path_utils.dart';
import 'package:mayabela/utils/attachment_size_limit.dart';

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

  String? lastPickError;
  int? lastRejectedMaxMb;

  Future<GalleryMediaPick?> pickPhoto() => _pick(images: true);

  Future<GalleryMediaPick?> pickVideo() => _pick(images: false);

  Future<GalleryMediaPick?> _pick({required bool images}) async {
    lastPickError = null;
    lastRejectedMaxMb = null;
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
    if (AttachmentSizeLimit.exceeds(file.name, bytes.length)) {
      lastRejectedMaxMb = AttachmentSizeLimit.maxMbForFileName(file.name);
      lastPickError =
          'That file is too large. Use a file under $lastRejectedMaxMb MB.';
      return null;
    }

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
    var payload = Uint8List.fromList(bytes);
    var safeName = fileName.trim().isEmpty ? 'gallery_media.bin' : fileName;
    if (attachmentPathIsImage(safeName)) {
      final jpeg = ProfilePhotoCodec.displayJpegOrOriginal(payload);
      if (jpeg.isNotEmpty) {
        payload = jpeg;
        safeName = _jpegFileNameIfNeeded(safeName);
      }
    }
    if (AttachmentSizeLimit.exceeds(safeName, payload.length)) {
      lastRejectedMaxMb = AttachmentSizeLimit.maxMbForFileName(safeName);
      lastPickError =
          'That file is too large. Use a file under $lastRejectedMaxMb MB.';
      return null;
    }

    AnnouncementAttachment? saved;
    try {
      saved = await saveAttachmentBytes(
        fileName: safeName,
        bytes: payload,
        subdir: 'gallery_media',
        size: payload.length,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GalleryMediaService persist failed: $e');
      }
    }

    final localPath = saved?.filePath ??
        WebAttachmentCache.instance.store(safeName, payload);
    final displayName = saved?.fileName ?? safeName;

    final uploaded = await AnnouncementAttachmentService.instance
        .uploadSavedAttachment(
      fileName: displayName,
      bytes: payload,
      localPath: localPath,
      subdir: 'gallery_media',
      attachmentId: saved?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
    );
    if (uploaded != null) {
      WebAttachmentCache.instance.remember(uploaded, payload);
      WebAttachmentCache.instance.remember(localPath, payload);
      return GalleryMediaPick(
        filePath: uploaded,
        displayName: displayName,
      );
    }

    return GalleryMediaPick(
      filePath: localPath,
      displayName: displayName,
    );
  }

  static String _jpegFileNameIfNeeded(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.heic') ||
        lower.endsWith('.heif') ||
        lower.endsWith('.tif') ||
        lower.endsWith('.tiff') ||
        lower.endsWith('.bmp')) {
      final dot = fileName.lastIndexOf('.');
      final base = dot > 0 ? fileName.substring(0, dot) : fileName;
      return '$base.jpg';
    }
    return fileName;
  }

  /// Re-upload gallery files that still only exist on this laptop.
  Future<void> promotePendingToCloud() async {
    final posts = SchoolDataService.instance.gallerySnapshot();
    var changed = false;
    final updated = <GalleryPost>[];
    for (final post in posts) {
      var media = post.mediaPath;
      if (media != null && ProfilePhotoCodec.isDeviceLocalPath(media)) {
        final cloud = await _promotePath(
          media,
          post.mediaLabel ?? attachmentFileName(media ?? 'gallery.jpg'),
        );
        if (cloud != null) {
          media = cloud;
          changed = true;
        }
      }
      final attachments = <String>[];
      for (final path in post.attachmentPaths) {
        if (ProfilePhotoCodec.isDeviceLocalPath(path)) {
          final cloud = await _promotePath(path, attachmentFileName(path));
          if (cloud != null) {
            attachments.add(cloud);
            changed = true;
            continue;
          }
        }
        attachments.add(path);
      }
      updated.add(
        post.copyWith(mediaPath: media, attachmentPaths: attachments),
      );
    }
    if (!changed) return;
    SchoolDataService.instance.applyPersistedGallery(updated);
    SchoolContentSyncService.instance.markDataChanged();
  }

  Future<String?> _promotePath(String? path, String fileName) async {
    if (path == null || path.trim().isEmpty) return null;
    final cached = WebAttachmentCache.instance.read(path);
    if (cached == null || cached.isEmpty) return null;
    final pick = await persistBytes(fileName: fileName, bytes: cached);
    if (pick == null) return null;
    if (ProfilePhotoCodec.isDeviceLocalPath(pick.filePath)) return null;
    return pick.filePath;
  }
}
