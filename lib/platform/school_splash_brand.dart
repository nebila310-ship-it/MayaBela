import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/platform/school_splash_brand_stub.dart'
    if (dart.library.html) 'package:mayabela/platform/school_splash_brand_web.dart'
    as impl;
import 'package:mayabela/platform/web_attachment_cache.dart';

class SchoolSplashMeta {
  const SchoolSplashMeta({
    required this.schoolId,
    required this.name,
    required this.logoStyle,
    this.logoUrl,
  });

  final String schoolId;
  final String name;
  final SchoolLogoStyle logoStyle;
  final String? logoUrl;
}

/// Browser splash/login brand so the HTML loading screen and login page can
/// show the school logo without a school JWT.
abstract final class SchoolSplashBrand {
  static const storageKey = 'mayabela_school_splash';

  static String cacheKey(String schoolId, SchoolLogoStyle style) =>
      'web://school-logo/${schoolId.trim().toUpperCase()}/${style.name}';

  static void remember({
    required String schoolId,
    required String name,
    required SchoolLogoStyle style,
    Uint8List? jpegBytes,
    String? logoUrl,
  }) {
    final id = schoolId.trim().toUpperCase();
    if (id.isEmpty) return;
    if (jpegBytes != null && jpegBytes.isNotEmpty) {
      WebAttachmentCache.instance.remember(cacheKey(id, style), jpegBytes);
    }
    final url = logoUrl?.trim() ?? '';
    final thumb = jpegBytes == null ? null : _thumbnail(jpegBytes);
    final dataUrl = (thumb != null && thumb.isNotEmpty)
        ? 'data:image/jpeg;base64,${base64Encode(thumb)}'
        : impl.readSchoolSplashDataUrl(schoolId: id);
    impl.persistSchoolSplashBrand(
      jsonEncode({
        'schoolId': id,
        'name': name.trim(),
        'logoStyle': style.name,
        if (url.isNotEmpty) 'logoUrl': url,
        if (dataUrl != null && dataUrl.isNotEmpty) 'dataUrl': dataUrl,
      }),
    );
  }

  static SchoolSplashMeta? readMeta({String? schoolId}) {
    final map = impl.readSchoolSplashMap(schoolId: schoolId);
    if (map == null) return null;
    final id = (map['schoolId'] as String? ?? '').trim().toUpperCase();
    final name = (map['name'] as String? ?? '').trim();
    if (id.isEmpty) return null;
    return SchoolSplashMeta(
      schoolId: id,
      name: name,
      logoStyle: SchoolLogoStyle.parse(map['logoStyle'] as String?),
      logoUrl: map['logoUrl'] as String?,
    );
  }

  static Uint8List? readBytes({String? schoolId, SchoolLogoStyle? style}) {
    if (schoolId != null && style != null) {
      final cached = WebAttachmentCache.instance.read(cacheKey(schoolId, style));
      if (cached != null && cached.isNotEmpty) return cached;
    }
    return impl.readSchoolSplashBytes(schoolId: schoolId);
  }

  /// Small JPEG so localStorage and the HTML splash can always hold the logo.
  @visibleForTesting
  static Uint8List? thumbnailForTest(Uint8List jpeg) => _thumbnail(jpeg);

  static Uint8List? _thumbnail(Uint8List jpeg) {
    try {
      final decoded = img.decodeImage(jpeg);
      if (decoded == null) {
        return jpeg.length < 180000 ? jpeg : null;
      }
      final longest = math.max(decoded.width, decoded.height);
      var out = decoded;
      if (longest > 320) {
        final scale = 320 / longest;
        out = img.copyResize(
          decoded,
          width: math.max(1, (decoded.width * scale).round()),
          height: math.max(1, (decoded.height * scale).round()),
        );
      }
      return Uint8List.fromList(img.encodeJpg(out, quality: 70));
    } catch (_) {
      return jpeg.length < 180000 ? jpeg : null;
    }
  }
}
