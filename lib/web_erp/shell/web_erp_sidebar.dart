import 'package:flutter/material.dart';

import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/web_erp/models/web_erp_nav_item.dart';
import 'package:mayabela/web_erp/services/web_erp_prefs_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

class WebErpSidebar extends StatelessWidget {
  const WebErpSidebar({
    super.key,
    required this.collapsed,
    required this.selectedId,
    required this.onSelect,
    required this.onToggleCollapse,
    this.inDrawer = false,
  });

  final bool collapsed;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggleCollapse;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final width = inDrawer
        ? WebErpTheme.sidebarExpanded
        : (collapsed ? WebErpTheme.sidebarCollapsed : WebErpTheme.sidebarExpanded);
    final items = webErpNavItemsForCurrentUser();
    final favorites = WebErpPrefsService.instance.favorites;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: width,
      color: WebErpTheme.sidebarBg,
      child: Column(
        children: [
          SizedBox(
            height: WebErpTheme.topBarHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 16),
              child: Row(
                children: [
                  const Icon(Icons.school, color: Colors.white, size: 28),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'MaJo Bridge',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  IconButton(
                    tooltip: inDrawer
                        ? 'Close menu'
                        : collapsed
                            ? 'Expand sidebar'
                            : 'Collapse sidebar',
                    onPressed: onToggleCollapse,
                    icon: Icon(
                      inDrawer
                          ? Icons.close
                          : collapsed
                              ? Icons.chevron_right
                              : Icons.chevron_left,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (!collapsed && favorites.isNotEmpty) ...[
                  _sectionLabel('Favorites'),
                  for (final id in favorites)
                    if (webErpNavItemById(id) != null &&
                        ModuleAccess.canView(id))
                      _NavTile(
                        item: webErpNavItemById(id)!,
                        collapsed: collapsed,
                        selected: selectedId == id,
                        onTap: () => onSelect(id),
                      ),
                  const SizedBox(height: 8),
                ],
                if (ModuleAccess.canView('add_driver') ||
                    ModuleAccess.canView('transport_live_gps')) ...[
                  if (!collapsed) _sectionLabel('School bus'),
                  if (ModuleAccess.canView('add_driver'))
                    _NavTile(
                      item: webErpNavItemById('add_driver') ??
                          const WebErpNavItem(
                            id: 'add_driver',
                            label: 'Register Driver',
                            icon: Icons.person_add_alt_1_outlined,
                          ),
                      collapsed: collapsed,
                      selected: selectedId == 'add_driver',
                      onTap: () => onSelect('add_driver'),
                    ),
                  if (ModuleAccess.canView('transport_live_gps'))
                    _NavTile(
                      item: webErpNavItemById('transport_live_gps') ??
                          const WebErpNavItem(
                            id: 'transport_live_gps',
                            label: 'Live GPS',
                            icon: Icons.gps_fixed,
                          ),
                      collapsed: collapsed,
                      selected: selectedId == 'transport_live_gps',
                      onTap: () => onSelect('transport_live_gps'),
                    ),
                  const SizedBox(height: 8),
                ],
                ..._sectionedTiles(items, selectedId, collapsed, onSelect),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sectionedTiles(
    List<WebErpNavItem> items,
    String selectedId,
    bool collapsed,
    ValueChanged<String> onSelect,
  ) {
    final out = <Widget>[];
    String? lastSection;
    for (final item in items) {
      final section = item.section;
      if (!collapsed &&
          section != null &&
          section.isNotEmpty &&
          section != lastSection) {
        out.add(_sectionLabel(section));
        lastSection = section;
      }
      out.add(
        _NavTile(
          item: item,
          collapsed: collapsed,
          selected: selectedId == item.id,
          onTap: () => onSelect(item.id),
        ),
      );
    }
    return out;
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.collapsed,
    required this.selected,
    required this.onTap,
  });

  final WebErpNavItem item;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (item.isLogout) {
      return _tile(
        icon: item.icon,
        label: item.label,
        color: Colors.redAccent.shade100,
        badge: 0,
      );
    }

    final badge = item.badgeId == null
        ? 0
        : DashboardBadgeService.instance.countFor(item.badgeId!);

    return _tile(
      icon: item.icon,
      label: item.label,
      badge: badge,
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    int badge = 0,
    Color? color,
  }) {
    final fg = color ?? (selected ? Colors.white : Colors.white70);
    final bg = selected ? WebErpTheme.sidebarActive : Colors.transparent;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 6 : 10,
        vertical: 2,
      ),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: WebErpTheme.sidebarHover,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 10 : 14,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 22),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
