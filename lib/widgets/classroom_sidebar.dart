import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/dashboard_navigation_store.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/setup/dashboard_setup.dart';
import 'package:mayabela/theme/classroom_palette.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

class ClassroomNavDestination {
  const ClassroomNavDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.badge = 0,
    this.section,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final int badge;
  final String? section;
}

List<ClassroomNavDestination> classroomNavDestinations({
  required String roleKey,
  required AppStrings s,
}) {
  final visible = DashboardRegistry.visibleEntriesFor(roleKey);
  final byId = {for (final entry in visible) entry.id: entry};
  final ordered = <DashboardEntry>[];
  final used = <String>{};
  final sectionById = <String, String>{};

  for (final section in sectionDefinitionsFor(roleKey)) {
    for (final id in section.entryIds) {
      final entry = byId[id];
      if (entry == null || !used.add(id)) continue;
      ordered.add(entry);
      sectionById[id] = section.title;
    }
  }
  for (final entry in visible) {
    if (used.add(entry.id)) ordered.add(entry);
  }

  ClassroomNavDestination destFor(DashboardEntry entry) {
    return ClassroomNavDestination(
      id: entry.id,
      label: s.dashboardTitle(entry.id, roleKey: roleKey),
      icon: entry.icon,
      color: entry.color,
      badge: DashboardBadgeService.instance.countFor(
        entry.id,
        roleKey: roleKey,
      ),
      section: sectionById[entry.id],
    );
  }

  return [
    ClassroomNavDestination(
      id: 'home',
      label: s.classroomHome,
      icon: Icons.home_rounded,
      color: ClassroomPalette.blue,
    ),
    ...ordered.map(destFor),
  ];
}

void selectClassroomDestination({
  required int index,
  required String roleKey,
  required List<ClassroomNavDestination> destinations,
  required ValueChanged<int> onIndex,
}) {
  onIndex(index);
  if (index <= 0 || index >= destinations.length) return;
  DashboardNavigationStore.instance
      .actionFor(roleKey, destinations[index].id)
      ?.call();
}

/// ERP-style categorized, scrollable classroom sidebar.
class ClassroomSidebar extends StatelessWidget {
  const ClassroomSidebar({
    super.key,
    required this.title,
    required this.accent,
    required this.destinations,
    required this.selectedIndex,
    required this.collapsed,
    required this.onToggle,
    required this.onSelect,
    this.inDrawer = false,
  });

  static const double expandedWidth = 260;
  static const double collapsedWidth = 80;
  static const double headerHeight = 56;

  final String title;
  final Color accent;
  final List<ClassroomNavDestination> destinations;
  final int selectedIndex;
  final bool collapsed;
  final VoidCallback onToggle;
  final ValueChanged<int> onSelect;
  final bool inDrawer;

  void _hapticToggle() {
    if (UserPreferencesService.instance.hapticFeedback) {
      HapticFeedback.selectionClick();
    }
    onToggle();
  }

  void _hapticSelect(int index) {
    if (UserPreferencesService.instance.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    onSelect(index);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final width = inDrawer
        ? expandedWidth
        : (collapsed ? collapsedWidth : expandedWidth);

    return Material(
      key: const Key('classroom-sidebar'),
      color: WebErpTheme.sidebarBg,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        width: width,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: WebErpTheme.sidebarBg,
          border: Border(right: BorderSide(color: ClassroomPalette.line)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final iconOnly = !inDrawer && constraints.maxWidth < 140;
            final safeIndex = destinations.isEmpty
                ? 0
                : selectedIndex.clamp(0, destinations.length - 1);
            return Column(
              children: [
                _SidebarHeader(
                  title: title,
                  accent: accent,
                  iconOnly: iconOnly,
                  inDrawer: inDrawer,
                  expandTooltip: s.expandClassroomSidebar,
                  collapseTooltip: inDrawer
                      ? s.closeClassroomMenu
                      : s.collapseClassroomSidebar,
                  onToggle: _hapticToggle,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (var i = 0; i < destinations.length; i++) ...[
                        if (!iconOnly && _shouldShowSection(i))
                          _SectionLabel(destinations[i].section!),
                        _NavTile(
                          item: destinations[i],
                          selected: i == safeIndex,
                          collapsed: iconOnly,
                          onTap: () => _hapticSelect(i),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _shouldShowSection(int index) {
    final section = destinations[index].section;
    if (section == null || section.isEmpty) return false;
    if (index == 0) return true;
    return destinations[index - 1].section != section;
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({
    required this.title,
    required this.accent,
    required this.iconOnly,
    required this.inDrawer,
    required this.expandTooltip,
    required this.collapseTooltip,
    required this.onToggle,
  });

  final String title;
  final Color accent;
  final bool iconOnly;
  final bool inDrawer;
  final String expandTooltip;
  final String collapseTooltip;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return Container(
        height: ClassroomSidebar.headerHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent,
              Color.lerp(accent, ClassroomPalette.cyan, 0.45)!,
            ],
          ),
        ),
        child: Center(
          child: IconButton(
            key: const Key('classroom-sidebar-toggle'),
            tooltip: expandTooltip,
            onPressed: onToggle,
            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ),
        ),
      );
    }

    return Container(
      height: ClassroomSidebar.headerHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent,
            Color.lerp(accent, ClassroomPalette.cyan, 0.45)!,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: iconOnly ? 8 : 12),
        child: Row(
          children: [
            const Icon(Icons.school, color: Colors.white, size: 26),
            if (!iconOnly) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
            IconButton(
              key: const Key('classroom-sidebar-toggle'),
              tooltip: iconOnly ? expandTooltip : collapseTooltip,
              onPressed: onToggle,
              icon: Icon(
                inDrawer
                    ? Icons.close_rounded
                    : iconOnly
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: ClassroomPalette.muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final ClassroomNavDestination item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? WebErpTheme.primary : ClassroomPalette.ink;
    final bg = selected ? WebErpTheme.sidebarActive : Colors.transparent;
    final iconColor = selected ? WebErpTheme.primary : item.color;
    final iconBox = Badge(
      isLabelVisible: item.badge > 0 && collapsed,
      smallSize: 8,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        key: Key('classroom-nav-${item.id}'),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected ? iconColor : iconColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          item.icon,
          color: selected ? Colors.white : iconColor,
          size: 20,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 4 : 10,
        vertical: 2,
      ),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: WebErpTheme.sidebarHover,
          child: Tooltip(
            message: collapsed ? item.label : '',
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 4 : 12,
                vertical: 8,
              ),
              child: collapsed
                  ? Center(child: iconBox)
                  : Row(
                      children: [
                        iconBox,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: fg,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.badge > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ClassroomPalette.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item.badge > 99 ? '99+' : '${item.badge}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
