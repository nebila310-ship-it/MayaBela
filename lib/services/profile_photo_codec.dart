import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/utils/attachment_size_limit.dart';

/// Shared pick / normalize / save for student, teacher, staff, and driver photos.
class ProfilePhotoCodec {
  ProfilePhotoCodec._();

  static String? lastError;

  /// File picker first (web + “choose file”), then gallery on native.
  static Future<Uint8List?> pickBytes() async {
    lastError = null;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          'bmp',
          'heic',
          'heif',
        ],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      return _bytesFromPlatformFile(result.files.first);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePhotoCodec FilePicker: $e');
      }
    }

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        lastError = 'Could not read the selected image.';
        return null;
      }
      if (AttachmentSizeLimit.exceeds(picked.name, bytes.length)) {
        lastError =
            'That photo is too large. Use an image under ${AttachmentSizeLimit.maxMbForFileName(picked.name)} MB.';
        return null;
      }
      return bytes;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePhotoCodec ImagePicker: $e');
      }
      lastError = 'Could not open the photo picker. Try another image.';
      return null;
    }
  }

  static Uint8List? _bytesFromPlatformFile(PlatformFile file) {
    List<int>? bytes = file.bytes;
    if ((bytes == null || bytes.isEmpty) &&
        !kIsWeb &&
        file.path != null &&
        file.path!.isNotEmpty) {
      try {
        bytes = File(file.path!).readAsBytesSync();
      } catch (_) {
        bytes = null;
      }
    }
    if (bytes == null || bytes.isEmpty) {
      lastError = 'Could not read the selected image.';
      return null;
    }
    if (AttachmentSizeLimit.exceeds(file.name, bytes.length)) {
      lastError =
          'That photo is too large. Use an image under ${AttachmentSizeLimit.maxMbForFileName(file.name)} MB.';
      return null;
    }
    return Uint8List.fromList(bytes);
  }

  /// Square JPEG when the decoder understands the file; otherwise original bytes.
  static Uint8List squareJpegOrOriginal(Uint8List bytes) {
    if (bytes.isEmpty) return bytes;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      final size =
          decoded.width < decoded.height ? decoded.width : decoded.height;
      if (size <= 0) return bytes;
      final left = (decoded.width - size) ~/ 2;
      final top = (decoded.height - size) ~/ 2;
      final cropped = img.copyCrop(
        decoded,
        x: left,
        y: top,
        width: size,
        height: size,
      );
      final resized = img.copyResize(cropped, width: 512, height: 512);
      return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
    } catch (_) {
      return bytes;
    }
  }

  static Future<String?> saveBytes({
    required String personId,
    required Uint8List sourceBytes,
    required String folder,
    required Map<String, Uint8List> byteCache,
    required Map<String, String> pathCache,
  }) async {
    lastError = null;
    final id = personId.trim().toUpperCase();
    if (id.isEmpty || sourceBytes.isEmpty) {
      lastError = 'Missing photo data.';
      return null;
    }

    final encoded = squareJpegOrOriginal(sourceBytes);
    if (encoded.isEmpty) {
      lastError = 'Could not process that image. Try JPG or PNG.';
      return null;
    }

    byteCache[id] = encoded;
    var path = kIsWeb
        ? WebAttachmentCache.instance.store('$id.jpg', encoded)
        : await _writeNativeFile(id: id, folder: folder, bytes: encoded);
    if (path == null || path.isEmpty) {
      path = WebAttachmentCache.instance.store('$id.jpg', encoded);
    }
    pathCache[id] = path;
    WebAttachmentCache.instance.remember(path, encoded);

    final cloud = await AnnouncementAttachmentService.instance
        .uploadSavedAttachment(
      fileName: '$id.jpg',
      bytes: encoded,
      localPath: path,
      subdir: folder,
      attachmentId: id,
    );
    if (cloud != null && cloud.isNotEmpty) {
      pathCache[id] = cloud;
      WebAttachmentCache.instance.remember(cloud, encoded);
      return cloud;
    }
    return path;
  }

  static Future<String?> _writeNativeFile({
    required String id,
    required String folder,
    required Uint8List bytes,
  }) async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${dir.path}/$folder');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final file = File('${photosDir.path}/$id.jpg');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProfilePhotoCodec native save: $e');
      }
      return null;
    }
  }

  static Uint8List? lookupBytes({
    required String? personId,
    required Map<String, Uint8List> byteCache,
    required Map<String, String> pathCache,
    String? storedPath,
  }) {
    if (personId != null && personId.trim().isNotEmpty) {
      final id = personId.trim().toUpperCase();
      final cached = byteCache[id];
      if (cached != null && cached.isNotEmpty) return cached;
      final path = pathCache[id] ?? storedPath;
      final fromCache = WebAttachmentCache.instance.read(path);
      if (fromCache != null && fromCache.isNotEmpty) return fromCache;
    }
    return WebAttachmentCache.instance.read(storedPath);
  }

  static Future<String?> resolvePath({
    required String? personId,
    required String folder,
    required Map<String, String> pathCache,
    String? storedPath,
  }) async {
    if (personId == null || personId.trim().isEmpty) return storedPath;
    final id = personId.trim().toUpperCase();
    final cached = pathCache[id] ?? storedPath;
    if (cached != null && cached.isNotEmpty) {
      if (WebAttachmentCache.instance.isWebPath(cached)) return cached;
      if (cached.startsWith('http://') || cached.startsWith('https://')) {
        return cached;
      }
      if (!kIsWeb && File(cached).existsSync()) return cached;
    }
    if (kIsWeb) return cached;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$folder/$id.jpg');
      if (await file.exists()) {
        pathCache[id] = file.path;
        return file.path;
      }
    } catch (_) {}
    return cached;
  }
}
