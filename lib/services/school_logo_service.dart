import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/platform/platform_file_storage.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/platform_owner_service.dart';

/// School logos: pick → normalize → local/web cache → optional cloud upload.
class SchoolLogoService {
  SchoolLogoService._();
  static final instance = SchoolLogoService._();

  /// Last human-readable pick/save error (for owner console toasts).
  String? lastError;

  /// Picks a logo image. Prefers [FilePicker] (works on web); falls back to
  /// gallery [ImagePicker] on native if needed.
  Future<XFile?> pickLogoXFile() async {
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
      if (result == null || result.files.isEmpty) {
        lastError = 'No image selected.';
        return null;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        return XFile.fromData(
          bytes,
          name: file.name,
          mimeType: _mimeForName(file.name),
        );
      }
      if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
        return XFile(file.path!);
      }
      lastError = 'Could not read the selected image.';
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SchoolLogoService.pickLogoXFile FilePicker: $e');
      }
      // Native fallback — some devices block FilePicker for photos.
      if (!kIsWeb) {
        try {
          final picked = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            imageQuality: 95,
          );
          if (picked != null) return picked;
        } catch (e2) {
          lastError = 'Photo access denied. Allow photos in Settings.';
          if (kDebugMode) {
            debugPrint('SchoolLogoService.pickLogoXFile ImagePicker: $e2');
          }
          return null;
        }
      }
      lastError = 'Could not open the file picker. Try another image.';
      return null;
    }
  }

  String _mimeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  /// Normalize picked image to JPEG bytes for preview + save (works on web).
  Future<Uint8List?> normalizeToBytes(
    Uint8List sourceBytes,
    SchoolLogoStyle style,
  ) async {
    lastError = null;
    final out = await _normalizeBytesForFrame(sourceBytes, style);
    if (out == null) {
      lastError = 'Could not process that image. Try JPG or PNG.';
    }
    return out;
  }

  Future<Uint8List?> _normalizeBytesForFrame(
    Uint8List bytes,
    SchoolLogoStyle style,
  ) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final trimmed = _trimContentBounds(decoded);
    final (canvasWidth, canvasHeight) = style.exportSize;
    final canvas = _fitOnCanvas(
      trimmed,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      paddingFraction: style.exportPaddingFraction,
    );

    return Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
  }

  img.Image _trimContentBounds(img.Image source, {int threshold = 245}) {
    var minX = source.width;
    var minY = source.height;
    var maxX = 0;
    var maxY = 0;

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final alpha = pixel.a.toInt();
        if (alpha < 16) continue;

        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        if (r >= threshold && g >= threshold && b >= threshold) continue;

        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }

    if (maxX <= minX || maxY <= minY) return source;

    final pad = 2;
    minX = math.max(0, minX - pad);
    minY = math.max(0, minY - pad);
    maxX = math.min(source.width - 1, maxX + pad);
    maxY = math.min(source.height - 1, maxY + pad);

    return img.copyCrop(
      source,
      x: minX,
      y: minY,
      width: maxX - minX + 1,
      height: maxY - minY + 1,
    );
  }

  img.Image _fitOnCanvas(
    img.Image source, {
    required int canvasWidth,
    required int canvasHeight,
    required double paddingFraction,
  }) {
    final canvas = img.Image(width: canvasWidth, height: canvasHeight);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    final padX = (canvasWidth * paddingFraction).round();
    final padY = (canvasHeight * paddingFraction).round();
    final maxW = canvasWidth - padX * 2;
    final maxH = canvasHeight - padY * 2;

    final scale = math.min(maxW / source.width, maxH / source.height);
    final newW = math.max(1, (source.width * scale).round());
    final newH = math.max(1, (source.height * scale).round());

    final resized = img.copyResize(
      source,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.cubic,
    );

    final x = (canvasWidth - newW) ~/ 2;
    final y = (canvasHeight - newH) ~/ 2;
    img.compositeImage(canvas, resized, dstX: x, dstY: y);
    return canvas;
  }

  Future<String?> saveLogoBytes(
    String schoolId,
    Uint8List bytes, {
    SchoolLogoStyle style = SchoolLogoStyle.rectangular,
  }) async {
    lastError = null;
    final id = schoolId.trim().toUpperCase();
    if (id.isEmpty || bytes.isEmpty) {
      lastError = 'Missing school id or image data.';
      return null;
    }

    final saved = await saveAttachmentBytes(
      fileName: 'logo_$id.jpg',
      bytes: bytes,
      subdir: 'school_logos',
      size: bytes.length,
    );
    if (saved != null) {
      return saved.filePath;
    }

    // Fallback: keep bytes in memory cache (web).
    return WebAttachmentCache.instance.store('logo_$id.jpg', bytes);
  }

  Future<String?> resolvedLogoPath(String? schoolId, {String? storedPath}) async {
    if (storedPath != null && storedPath.isNotEmpty) {
      if (WebAttachmentCache.instance.isWebPath(storedPath)) {
        return storedPath;
      }
      if (storedPath.startsWith('http://') ||
          storedPath.startsWith('https://') ||
          storedPath.startsWith('data:')) {
        return null;
      }
      if (!kIsWeb) {
        final exists = await attachmentPathExists(storedPath);
        if (exists) return storedPath;
      }
    }
    return null;
  }

  Future<void> deleteLogo(String schoolId) async {
    // Local files / web cache are best-effort; registry clear is authoritative.
  }

  /// Uploads logo bytes to Supabase (platform edge function when no school JWT).
  Future<String?> uploadToServer({
    required String schoolId,
    required String localPath,
    Uint8List? bytes,
  }) async {
    lastError = null;
    final id = schoolId.trim().toUpperCase();
    if (id.isEmpty) return null;

    var payload = bytes;
    if ((payload == null || payload.isEmpty) &&
        WebAttachmentCache.instance.isWebPath(localPath)) {
      payload = WebAttachmentCache.instance.read(localPath);
    }
    if (payload == null || payload.isEmpty) {
      lastError = 'No logo bytes to upload.';
      return null;
    }

    // Prefer platform edge upload (works without school JWT).
    final viaPlatform = await _uploadViaPlatformFunction(id, payload);
    if (viaPlatform != null) return viaPlatform;

    // Fallback: direct storage when the session has school claims.
    return _uploadDirect(id, payload);
  }

  Future<String?> _uploadViaPlatformFunction(
    String schoolId,
    Uint8List bytes,
  ) async {
    try {
      await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
      if (!SupabaseBootstrap.isInitialized) return null;

      final ownerPin = PlatformOwnerService.instance.sessionOwnerPin?.trim();
      if (ownerPin == null ||
          ownerPin.length < PlatformOwnerService.minPinLength) {
        return null;
      }

      final res = await SupabaseBootstrap.client.functions.invoke(
        'platform-upload-logo',
        body: {
          'schoolId': schoolId,
          'bytesBase64': base64Encode(bytes),
          'ownerPin': ownerPin,
        },
      );
      final data = res.data;
      if (data is Map && data['ok'] == true && data['url'] is String) {
        return data['url'] as String;
      }
      if (kDebugMode) {
        debugPrint('platform-upload-logo failed: $data');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('platform-upload-logo error: $e');
      }
      return null;
    }
  }

  Future<String?> _uploadDirect(String schoolId, Uint8List bytes) async {
    try {
      if (!SupabaseBootstrap.isInitialized) return null;
      final storagePath = 'schools/$schoolId/branding/logo.jpg';
      await SupabaseBootstrap.client.storage.from('school-files').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return SupabaseBootstrap.client.storage
          .from('school-files')
          .getPublicUrl(storagePath);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SchoolLogoService._uploadDirect: $e');
      }
      lastError = 'Cloud logo upload was denied. Logo kept on this device.';
      return null;
    }
  }
}
