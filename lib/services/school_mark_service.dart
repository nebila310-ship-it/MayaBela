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
    final ink = _trimContentBounds(_isolateInk(decoded, kind));
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

  /// Ink-only PNG for the report. Black scan backdrops and lined paper drop
  /// out, so a saved photo still looks stamped or signed.
  Uint8List forReport(Uint8List source, SchoolMarkKind kind) {
    final decoded = img.decodeImage(source);
    if (decoded == null) return source;
    final isolated = _trimContentBounds(_isolateInk(decoded, kind));
    if (_opaqueCount(isolated) < 12) return source;
    final fitted = _fitBox(isolated, kind.maxBox.$1, kind.maxBox.$2);
    return Uint8List.fromList(img.encodePng(fitted));
  }

  int _opaqueCount(img.Image image) {
    var count = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (image.getPixel(x, y).a.toInt() > 20) count++;
      }
    }
    return count;
  }

  /// Stamp keeps the colored seal. Signature keeps the pen strokes.
  img.Image _isolateInk(img.Image source, SchoolMarkKind kind) {
    if (kind == SchoolMarkKind.principalSignature) {
      return _signatureInk(source);
    }
    return _stampSeal(source);
  }

  /// Keeps the colored seal and clears the scanned backdrop around it,
  /// including a black photo surround connected to the edges.
  img.Image _stampSeal(img.Image source) {
    final width = source.width;
    final height = source.height;
    final strong = List.generate(
      height,
      (_) => List<bool>.filled(width, false),
    );
    final colors = List.generate(
      height,
      (_) => List<int>.filled(width, 0),
    );
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = source.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final alpha = pixel.a.toInt();
        if (alpha < 16) continue;
        final maxC = math.max(r, math.max(g, b));
        final minC = math.min(r, math.min(g, b));
        final sat = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
        final luma = (r * 299 + g * 587 + b * 114) / 1000.0;
        // Keep the colored letters as well as the ring. Near-black scan
        // noise stays out because it is not saturated.
        if (luma >= 42 && luma <= 215 && sat >= 0.28) {
          strong[y][x] = true;
          colors[y][x] = (_deeperInk(r) << 16) |
              (_deeperInk(g) << 8) |
              _deeperInk(b);
        }
      }
    }

    final backdrop = List.generate(
      height,
      (_) => List<bool>.filled(width, false),
    );
    final stack = <(int, int)>[];
    for (var x = 0; x < width; x++) {
      stack.add((x, 0));
      stack.add((x, height - 1));
    }
    for (var y = 0; y < height; y++) {
      stack.add((0, y));
      stack.add((width - 1, y));
    }
    while (stack.isNotEmpty) {
      final (x, y) = stack.removeLast();
      if (x < 0 || y < 0 || x >= width || y >= height) continue;
      if (backdrop[y][x] || strong[y][x]) continue;
      backdrop[y][x] = true;
      stack.add((x + 1, y));
      stack.add((x - 1, y));
      stack.add((x, y + 1));
      stack.add((x, y - 1));
    }

    final out = img.Image(width: width, height: height, numChannels: 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!strong[y][x] || backdrop[y][x]) continue;
        final packed = colors[y][x];
        out.setPixel(
          x,
          y,
          img.ColorRgba8(
            (packed >> 16) & 255,
            (packed >> 8) & 255,
            packed & 255,
            255,
          ),
        );
      }
    }
    return out;
  }

  /// Pulls scanned seal colors down so the wording stays readable.
  int _deeperInk(int channel) => (channel * 0.82).round().clamp(0, 255);

  /// Pulls a signature off lined paper. A scan's dark border and ruling
  /// lines are dropped, and the pen is laid down as blue ink.
  img.Image _signatureInk(img.Image source) {
    final width = source.width;
    final height = source.height;
    final out = img.Image(width: width, height: height, numChannels: 4);
    var clear = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (source.getPixel(x, y).a.toInt() < 16) clear++;
      }
    }
    final alreadyCutOut = clear > width * height * 0.35;
    if (alreadyCutOut) {
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final pixel = source.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          final alpha = pixel.a.toInt();
          final luma = (r * 299 + g * 587 + b * 114) ~/ 1000;
          if (alpha < 16 || luma > 210) {
            out.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
          } else {
            out.setPixel(x, y, img.ColorRgba8(22, 36, 120, alpha));
          }
        }
      }
      return out;
    }

    final luma = List.generate(height, (_) => List<int>.filled(width, 0));
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = source.getPixel(x, y);
        luma[y][x] = (pixel.r.toInt() * 299 +
                pixel.g.toInt() * 587 +
                pixel.b.toInt() * 114) ~/
            1000;
      }
    }
    final ink = List.generate(height, (_) => List<bool>.filled(width, false));
    final sampleFrom = (width * 0.22).floor();
    for (var y = 0; y < height; y++) {
      final sample = <int>[
        for (var x = sampleFrom; x < width; x++) luma[y][x],
      ];
      final paper = _median(sample);
      for (var x = 0; x < width; x++) {
        final value = luma[y][x];
        if (value > paper - 24 || value < 8) continue;
        ink[y][x] = true;
      }
    }
    for (var x = 0; x < width; x++) {
      var column = 0;
      for (var y = 0; y < height; y++) {
        if (ink[y][x]) column++;
      }
      if (column > height * 0.25) {
        for (var y = 0; y < height; y++) {
          ink[y][x] = false;
        }
      }
    }
    for (var y = 0; y < height; y++) {
      var x = 0;
      while (x < width) {
        if (!ink[y][x]) {
          x++;
          continue;
        }
        var end = x;
        while (end < width && ink[y][end]) {
          end++;
        }
        if (end - x > width * 0.42) {
          for (var i = x; i < end; i++) {
            ink[y][i] = false;
          }
        }
        x = end;
      }
    }

    final dilated = List.generate(height, (_) => List<bool>.filled(width, false));
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!ink[y][x]) continue;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            final ny = y + dy;
            if (nx >= 0 && ny >= 0 && nx < width && ny < height) {
              dilated[ny][nx] = true;
            }
          }
        }
      }
    }

    final seen = List.generate(height, (_) => List<bool>.filled(width, false));
    List<(int, int)>? best;
    var bestCount = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!dilated[y][x] || seen[y][x]) continue;
        final cells = <(int, int)>[];
        final stack = <(int, int)>[(x, y)];
        seen[y][x] = true;
        var touchesEdge = false;
        var minX = x;
        var maxX = x;
        var minY = y;
        var maxY = y;
        while (stack.isNotEmpty) {
          final (cx, cy) = stack.removeLast();
          cells.add((cx, cy));
          if (cx < 2 || cy < 2 || cx > width - 3 || cy > height - 3) {
            touchesEdge = true;
          }
          if (cx < minX) minX = cx;
          if (cx > maxX) maxX = cx;
          if (cy < minY) minY = cy;
          if (cy > maxY) maxY = cy;
          for (final (dx, dy) in const [
            (1, 0),
            (-1, 0),
            (0, 1),
            (0, -1),
            (1, 1),
            (-1, -1),
            (1, -1),
            (-1, 1),
          ]) {
            final nx = cx + dx;
            final ny = cy + dy;
            if (nx >= 0 &&
                ny >= 0 &&
                nx < width &&
                ny < height &&
                dilated[ny][nx] &&
                !seen[ny][nx]) {
              seen[ny][nx] = true;
              stack.add((nx, ny));
            }
          }
        }
        final boxW = maxX - minX + 1;
        final boxH = maxY - minY + 1;
        if (touchesEdge || boxW < 6 || boxH < 6) continue;
        if (cells.length > bestCount) {
          bestCount = cells.length;
          best = cells;
        }
      }
    }

    final paint = best ??
        <(int, int)>[
          for (var y = 0; y < height; y++)
            for (var x = 0; x < width; x++)
              if (ink[y][x]) (x, y),
        ];
    for (final (x, y) in paint) {
      out.setPixel(x, y, img.ColorRgba8(22, 36, 120, 230));
    }
    return out;
  }

  int _median(List<int> values) {
    if (values.isEmpty) return 255;
    final copy = List<int>.from(values)..sort();
    return copy[copy.length ~/ 2];
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
