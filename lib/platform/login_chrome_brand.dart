import 'package:flutter/foundation.dart';

import 'package:mayabela/platform/browser_tab_brand.dart';
import 'package:mayabela/platform/school_splash_brand.dart';
import 'package:mayabela/services/login_prefs_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

/// Login/tab/splash chrome: MaJo when School ID is empty, school once it is typed.
abstract final class LoginChromeBrand {
  static const productTitle = 'MaJo Bridge OS';

  static final ValueNotifier<String> tabTitle =
      ValueNotifier<String>(productTitle);

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
    final title = BrowserTabBrand.resolveTitle(
      sessionSchoolName: record?.name,
      splashName: splash?.name,
      rememberedName: remembered?.name,
      fallback: id.toUpperCase(),
    );
    BrowserTabBrand.apply(
      title: title,
      iconDataUrl: SchoolSplashBrand.readDataUrl(schoolId: id),
      iconUrl: record?.displayLogoUrl ??
          remembered?.logoUrl ??
          splash?.logoUrl,
    );
    tabTitle.value = title;
  }
}
