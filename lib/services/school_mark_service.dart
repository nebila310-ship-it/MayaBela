import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/platform/platform_file_storage.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/platform_owner_service.dart';
import 'package:mayabela/supabase_options.dart';

/// School stamp or principal signature used on official grade reports.
enum SchoolMarkKind {
  stamp,
  principalSignature;

  String get fileName => switch (this) {
        SchoolMarkKind.stamp => 'stamp.png',
        SchoolMarkKind.principalSignature => 'principal-signature.png',
      };

  String get cacheSuffix => switch (this) {
        SchoolMarkKind.stamp => 'stamp',
        SchoolMarkKind.principalSignature => 'signature',
      };

  String get uploadKind => switch (this) {
        SchoolMarkKind.stamp => 'stamp',
        SchoolMarkKind.principalSignature => 'signature',
      };

  (int width, int height) get maxBox => switch (this) {
        SchoolMarkKind.stamp => (480, 480),
        SchoolMarkKind.principalSignature => (720, 220),
      };
}

/// Transparent PNG stamp and principal signature for one school.
///
/// Paper-white backgrounds are knocked out so the stamp can sit on a photo.
/// Cloud storage is used when the owner upload function is available. Otherwise
/// the PNG is stored on the school record so other devices still receive it.
class SchoolMarkService {
  SchoolMarkService._();
  static final instance = SchoolMarkService._();

  String? lastError;

  /// Keep embedded copies small enough for the school record.
  static const maxEmbeddedBytes = 160000;

  static String cacheKey(String schoolId, SchoolMarkKind kind) =>
      'web://school-mark/${schoolId.trim().toUpperCase()}/${kind.cacheSuffix}';

  static String publicUrl(String schoolId, SchoolMarkKind kind) =>
      schoolBrandingPublicUrl(schoolId, file: kind.fileName);

  static String? decodeDataUrl(String? value) {
    final raw = value?.trim();
    if (raw == null || !raw.startsWith('data:')) return null;
    final comma = raw.indexOf(',');
    if (comma < 0 || comma + 1 >= raw.length) return null;
    return raw.substring(comma + 1);
  }

  static Uint8List? bytesFromStored(String? value) {
    final payload = decodeDataUrl(value);
    if (payload == null) return null;
    try {
      final bytes = base64Decode(payload);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  static String dataUrlFor(Uint8List png) =>
      'data:image/png;base64,${base64Encode(png)}';

  /// Fit the mark and keep transparency. Near-white paper becomes clear.
  Future<Uint8List?> normalizeToPng(
    Uint8List source,
    SchoolMarkKind kind,
  ) async {
    lastError = null;
    final decoded = img.decodeImage(source);
    if (decoded == null) {
      lastError = 'Could not process that image. Try PNG or JPG.';
      return null;
    }
    final ink = _trimContentBounds(_knockOutPaper(decoded));
    final (maxW, maxH) = kind.maxBox;
    var boxW = maxW;
    var boxH = maxH;
    Uint8List? png;
    for (var attempt = 0; attempt < 4; attempt++) {
      final fitted = _fitBox(ink, boxW, boxH);
      png = Uint8List.fromList(img.encodePng(fitted));
      if (png.length <= maxEmbeddedBytes) return png;
      boxW = math.max(64, (boxW * 0.72).round());
      boxH = math.max(48, (boxH * 0.72).round());
    }
    if (png != null && png.length <= maxEmbeddedBytes * 2) return png;
    lastError = 'That image is too large. Use a smaller stamp or signature.';
    return png != null && png.length <= 280000 ? png : null;
  }

  img.Image _knockOutPaper(img.Image source) {
    final out = source.numChannels >= 4
        ? img.Image.from(source)
        : source.convert(numChannels: 4);
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final pixel = out.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final alpha = pixel.a.toInt();
        if (alpha < 16 || (r >= 242 && g >= 242 && b >= 242)) {
          out.setPixel(x, y, img.ColorRgba8(r, g, b, 0));
        }
      }
    }
    return out;
  }

  img.Image _trimContentBounds(img.Image source) {
    var minX = source.width;
    var minY = source.height;
    var maxX = 0;
    var maxY = 0;
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        if (source.getPixel(x, y).a.toInt() < 16) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX <= minX || maxY <= minY) return source;
    const pad = 2;
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

  img.Image _fitBox(img.Image source, int maxW, int maxH) {
    final scale = math.min(maxW / source.width, maxH / source.height);
    if (scale >= 0.999) return source;
    return img.copyResize(
      source,
      width: math.max(1, (source.width * scale).round()),
      height: math.max(1, (source.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }

  Future<String?> saveLocal(
    String schoolId,
    SchoolMarkKind kind,
    Uint8List png,
  ) async {
    lastError = null;
    final id = schoolId.trim().toUpperCase();
    if (id.isEmpty || png.isEmpty) {
      lastError = 'Missing school id or image data.';
      return null;
    }
    final name = '${kind.cacheSuffix}_$id.png';
    final saved = await saveAttachmentBytes(
      fileName: name,
      bytes: png,
      subdir: 'school_marks',
      size: png.length,
    );
    final path = saved?.filePath ?? WebAttachmentCache.instance.store(name, png);
    WebAttachmentCache.instance.remember(cacheKey(id, kind), png);
    WebAttachmentCache.instance.remember(path, png);
    return path;
  }

  void forget(String schoolId, SchoolMarkKind kind) {
    WebAttachmentCache.instance.remove(cacheKey(schoolId, kind));
  }

  /// Public storage URL when the owner function is deployed, otherwise a
  /// data URL that travels with the school record.
  Future<String?> publish({
    required String schoolId,
    required SchoolMarkKind kind,
    required Uint8List png,
  }) async {
    lastError = null;
    final remote = await _uploadViaPlatformFunction(schoolId, kind, png);
    if (remote != null && remote.startsWith('http')) return remote;
    if (png.length > maxEmbeddedBytes * 2) {
      lastError =
          'Cloud upload is unavailable and the image is too large to store on the school.';
      return null;
    }
    return dataUrlFor(png);
  }

  Future<String?> _uploadViaPlatformFunction(
    String schoolId,
    SchoolMarkKind kind,
    Uint8List png,
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
        'platform-upload-mark',
        body: {
          'schoolId': schoolId.trim().toUpperCase(),
          'bytesBase64': base64Encode(png),
          'ownerPin': ownerPin,
          'kind': kind.uploadKind,
        },
      );
      final data = res.data;
      if (data is Map && data['ok'] == true && data['url'] is String) {
        final url = (data['url'] as String).trim();
        final returned = data['kind']?.toString() ?? '';
        if (url.startsWith('http') && returned == kind.fileName) return url;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('platform-upload-mark skipped: $e');
      }
      return null;
    }
  }

  Future<Uint8List?> resolve({
    required String schoolId,
    required SchoolMarkKind kind,
    String? storedUrl,
    String? storedPath,
  }) async {
    final embedded = bytesFromStored(storedUrl);
    if (_decodes(embedded)) {
      WebAttachmentCache.instance.remember(
        cacheKey(schoolId, kind),
        embedded!,
      );
      return embedded;
    }
    final url = storedUrl?.trim() ?? '';
    final path = storedPath?.trim() ?? '';
    final hasRemote = url.startsWith('http');
    final hasLocal = path.isNotEmpty;
    if (!hasRemote && !hasLocal) return null;

    final cached = WebAttachmentCache.instance.read(cacheKey(schoolId, kind));
    if (_decodes(cached)) return cached;
    if (hasLocal) {
      final local = WebAttachmentCache.instance.read(path);
      if (_decodes(local)) return local;
    }
    if (!hasRemote) return null;
    return _download(schoolId, kind);
  }

  bool _decodes(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return false;
    try {
      return img.decodeImage(bytes) != null;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> _download(String schoolId, SchoolMarkKind kind) async {
    try {
      if (!SupabaseBootstrap.isInitialized && kIsWeb) {
        await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
      }
      if (!SupabaseBootstrap.isInitialized) return null;
      final storagePath =
          'schools/${schoolId.trim().toUpperCase()}/branding/${kind.fileName}';
      for (final bucket in const ['school-branding', 'school-files']) {
        try {
          final bytes = await SupabaseBootstrap.client.storage
              .from(bucket)
              .download(storagePath);
          if (_decodes(bytes)) {
            WebAttachmentCache.instance.remember(
              cacheKey(schoolId, kind),
              bytes,
            );
            return bytes;
          }
        } catch (_) {}
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SchoolMarkService.download: $e');
      }
      return null;
    }
  }
}
