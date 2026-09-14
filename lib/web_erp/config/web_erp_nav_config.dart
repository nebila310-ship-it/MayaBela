import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_items.dart';
import 'package:mayabela/web_erp/models/web_erp_nav_item.dart';

export 'package:mayabela/web_erp/config/web_erp_nav_items.dart';

/// Sidebar items the signed-in user may see.
///
/// School-level module packs (platform owner console) are applied inside
/// [ModuleAccess.canView], so disabled modules stay hidden even for the
/// school admin.
List<WebErpNavItem> webErpNavItemsForCurrentUser() {
  return webErpAllNavItems
      .where((item) => item.isLogout || ModuleAccess.canView(item.id))
      .toList();
}
