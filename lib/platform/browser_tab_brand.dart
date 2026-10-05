import 'package:mayabela/platform/browser_tab_brand_stub.dart'
    if (dart.library.html) 'package:mayabela/platform/browser_tab_brand_web.dart'
    as impl;

/// Browser tab title + favicon (web only).
abstract final class BrowserTabBrand {
  static String resolveTitle({
    String? sessionSchoolName,
    String? splashName,
    String? rememberedName,
    required String fallback,
  }) {
    for (final value in [sessionSchoolName, splashName, rememberedName]) {
      final name = value?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return fallback;
  }

  static void apply({
    String? title,
    String? iconDataUrl,
    String? iconUrl,
  }) {
    impl.applyBrowserTabBrand(
      title: title,
      iconDataUrl: iconDataUrl,
      iconUrl: iconUrl,
    );
  }
}
