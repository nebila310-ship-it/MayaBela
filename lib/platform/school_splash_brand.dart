import 'dart:convert';
import 'dart:typed_data';

import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/platform/school_splash_brand_stub.dart'
    if (dart.library.html) 'package:mayabela/platform/school_splash_brand_web.dart'
    as impl;
import 'package:mayabela/platform/web_attachment_cache.dart';

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
    final dataUrl = (jpegBytes != null &&
            jpegBytes.isNotEmpty &&
            jpegBytes.length < 700000)
        ? 'data:image/jpeg;base64,${base64Encode(jpegBytes)}'
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

  static Uint8List? readBytes({String? schoolId, SchoolLogoStyle? style}) {
    if (schoolId != null && style != null) {
      final cached = WebAttachmentCache.instance.read(cacheKey(schoolId, style));
      if (cached != null && cached.isNotEmpty) return cached;
    }
    return impl.readSchoolSplashBytes(schoolId: schoolId);
  }
}
