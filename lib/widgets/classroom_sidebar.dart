import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/dashboard_navigation_store.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/theme/classroom_palette.dart';

class ClassroomNavDestination {
  const ClassroomNavDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.badge = 0,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final int badge;
}

List<ClassroomNavDestination> classroomNavDestinations({
  required String roleKey,
  required AppStrings s,
}) {
  return [
    ClassroomNavDestination(
      id: 'home',
      label: s.classroomHome,
      icon: Icons.home_rounded,
      color: ClassroomPalette.blue,
    ),
    ...DashboardRegistry.visibleEntriesFor(roleKey).map(
      (entry) => ClassroomNavDestination(
        id: entry.id,
        label: s.dashboardTitle(entry.id, roleKey: roleKey),
        icon: entry.icon,
        color: entry.color,
        badge: DashboardBadgeService.instance.countFor(
          entry.id,
          roleKey: roleKey,
        ),
      ),
    ),
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

/// Material [NavigationRail] — labels slide with the rail instead of leaking
/// under the page. Desktop has no second header; the shell owns the top bar.
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

  static const double expandedWidth = 256;
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
    final iconOnly = collapsed && !inDrawer;
    final rail = NavigationRail(
      extended: !iconOnly,
      minWidth: collapsedWidth,
      minExtendedWidth: expandedWidth,
      backgroundColor: Colors.white,
      indicatorColor: accent.withValues(alpha: 0.12),
      selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
      groupAlignment: -1,
      labelType: NavigationRailLabelType.none,
      onDestinationSelected: _hapticSelect,
      leading: inDrawer
          ? const SizedBox.shrink()
          : IconButton(
              key: const Key('classroom-sidebar-toggle'),
              tooltip: iconOnly
                  ? s.expandClassroomSidebar
                  : s.collapseClassroomSidebar,
              onPressed: _hapticToggle,
              icon: Icon(
                iconOnly
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                color: accent,
              ),
            ),
      destinations: [
        for (final item in destinations)
          NavigationRailDestination(
            icon: _RailIcon(
              key: Key('classroom-nav-${item.id}'),
              item: item,
              selected: false,
            ),
            selectedIcon: _RailIcon(item: item, selected: true),
            label: Text(item.label),
          ),
      ],
    );

    if (!inDrawer) {
      return Material(
        key: const Key('classroom-sidebar'),
        color: Colors.white,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: ClassroomPalette.line)),
          ),
          child: rail,
        ),
      );
    }

    return Material(
      key: const Key('classroom-sidebar'),
      color: Colors.white,
      child: SizedBox(
        width: expandedWidth,
        child: Column(
          children: [
            Container(
              height: headerHeight,
              color: accent,
              child: Row(
                children: [
                  IconButton(
                    key: const Key('classroom-sidebar-toggle'),
                    tooltip: s.closeClassroomMenu,
                    onPressed: _hapticToggle,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
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
              ),
            ),
            Expanded(child: rail),
          ],
        ),
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({
    super.key,
    required this.item,
    required this.selected,
  });

  final ClassroomNavDestination item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: item.badge > 0,
      smallSize: 8,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected ? item.color : item.color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          item.icon,
          color: selected ? Colors.white : item.color,
          size: 22,
        ),
      ),
    );
  }
}
