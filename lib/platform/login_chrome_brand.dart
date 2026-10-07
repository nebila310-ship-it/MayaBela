import 'package:flutter/foundation.dart';

import 'package:mayabela/platform/browser_tab_brand.dart';
import 'package:mayabela/platform/school_splash_brand.dart';
import 'package:mayabela/services/login_prefs_service.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

/// Login/tab/splash chrome: MaJo until the school name is known, never the ID.
abstract final class LoginChromeBrand {
  static const productTitle = 'MaJo Bridge OS';

  static final ValueNotifier<String> tabTitle = ValueNotifier<String>(
    productTitle,
  );

  /// School display name, or null when only the ID is known.
  /// Never returns the school ID — that looked like the name on a fresh laptop.
  static String? resolvedSchoolName(String schoolId) {
    final id = schoolId.trim();
    if (id.isEmpty) return null;
    final record = SchoolRegistryService.instance.lookup(id);
    final splash = SchoolSplashBrand.readMeta(schoolId: id);
    final remembered = LoginPrefsService.instance.brandForSchool(id);
    final title = BrowserTabBrand.resolveTitle(
      sessionSchoolName: record?.name,
      splashName: splash?.name,
      rememberedName: remembered?.name,
      fallback: '',
    );
    final cleaned = title.trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.toUpperCase() == id.toUpperCase()) return null;
    return cleaned;
  }

  /// Tab / login title: school name when known, otherwise MaJo Bridge OS.
  static String resolveDisplayName(String schoolId) {
    return resolvedSchoolName(schoolId) ?? productTitle;
  }

  static void apply({required String schoolId}) {
    final id = schoolId.trim();
    if (id.isEmpty) {
      BrowserTabBrand.applyProduct();
      tabTitle.value = productTitle;
      return;
    }

    final record = SchoolRegistryService.instance.lookup(id);
    final splash = SchoolSplashBrand.readMeta(schoolId: id);
    final remembered = LoginPrefsService.instance.brandForSchool(id);
    final title = resolveDisplayName(id);
    final logoUrl =
        record?.displayLogoUrl ??
        remembered?.logoUrl ??
        splash?.logoUrl ??
        (id.trim().length >= 3 ? SchoolLogoService.publicUrl(id.trim()) : null);
    BrowserTabBrand.apply(
      title: title,
      iconDataUrl: SchoolSplashBrand.readDataUrl(schoolId: id),
      iconUrl: logoUrl,
    );
    tabTitle.value = title;
  }
}
