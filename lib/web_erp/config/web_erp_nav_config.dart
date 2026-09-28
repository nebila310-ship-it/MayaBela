import 'package:flutter/material.dart';

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

/// Sidebar modules minus home chrome (Dashboard is the shell itself; Logout
/// lives in the account menu on phone tiles).
List<WebErpNavItem> webErpModuleNavItemsForCurrentUser() {
  return webErpNavItemsForCurrentUser()
      .where((item) => !item.isLogout && item.id != 'dashboard')
      .toList();
}

IconData webErpIconForSection(String section) {
  switch (section) {
    case 'Organization':
      return Icons.account_balance_outlined;
    case 'Academics':
      return Icons.menu_book_outlined;
    case 'Student Services':
      return Icons.groups_outlined;
    case 'Finance Branch':
      return Icons.payments_outlined;
    case 'HR Branch':
      return Icons.badge_outlined;
    case 'Learning Resources':
      return Icons.local_library_outlined;
    case 'Communication':
      return Icons.forum_outlined;
    case 'Quality & Insights':
      return Icons.insights_outlined;
    case 'System':
      return Icons.admin_panel_settings_outlined;
    case 'Account':
      return Icons.person_outlined;
    default:
      return Icons.apps_outlined;
  }
}
