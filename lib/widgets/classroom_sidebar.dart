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

/// Opaque icon rail that expands to labels. No leftover text under the page.
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

  static const double expandedWidth = 240;
  static const double collapsedWidth = 72;
  static const double headerHeight = 56;
  static const Duration animDuration = Duration(milliseconds: 280);

  final String title;
  final Color accent;
  final List<ClassroomNavDestination> destinations;
  final int selectedIndex;
  final bool collapsed;
  final VoidCallback onToggle;
  final ValueChanged<int> onSelect;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final iconOnly = collapsed && !inDrawer;
    final width = inDrawer
        ? expandedWidth
        : (iconOnly ? collapsedWidth : expandedWidth);
    final toggleTip = inDrawer
        ? s.closeClassroomMenu
        : iconOnly
            ? s.expandClassroomSidebar
            : s.collapseClassroomSidebar;

    return AnimatedContainer(
      key: const Key('classroom-sidebar'),
      duration: animDuration,
      curve: Curves.easeOutCubic,
      width: width,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: inDrawer
            ? const BorderRadius.horizontal(right: Radius.circular(24))
            : BorderRadius.zero,
        border: inDrawer
            ? null
            : const Border(right: BorderSide(color: ClassroomPalette.line)),
      ),
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
            _Header(
              title: title,
              accent: accent,
              iconOnly: iconOnly,
              tooltip: toggleTip,
              inDrawer: inDrawer,
              onToggle: () {
                if (UserPreferencesService.instance.hapticFeedback) {
                  HapticFeedback.selectionClick();
                }
                onToggle();
              },
            ),
            SizedBox(
              height: 4,
              child: Row(
                children: [
                  for (final color in ClassroomPalette.classes.take(8))
                    Expanded(child: ColoredBox(color: color)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final item = destinations[index];
                  return _NavTile(
                    item: item,
                    selected: selectedIndex == index,
                    iconOnly: iconOnly,
                    onTap: () {
                      if (UserPreferencesService.instance.hapticFeedback) {
                        HapticFeedback.lightImpact();
                      }
                      onSelect(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.accent,
    required this.iconOnly,
    required this.tooltip,
    required this.onToggle,
    required this.inDrawer,
  });

  final String title;
  final Color accent;
  final bool iconOnly;
  final String tooltip;
  final VoidCallback onToggle;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ClassroomSidebar.headerHeight,
      color: accent,
      child: iconOnly
          ? Center(
              child: IconButton(
                key: const Key('classroom-sidebar-toggle'),
                tooltip: tooltip,
                onPressed: onToggle,
                icon: Icon(
                  inDrawer ? Icons.close_rounded : Icons.menu_rounded,
                  color: Colors.white,
                ),
              ),
            )
          : Row(
              children: [
                IconButton(
                  key: const Key('classroom-sidebar-toggle'),
                  tooltip: tooltip,
                  onPressed: onToggle,
                  icon: Icon(
                    inDrawer ? Icons.close_rounded : Icons.menu_open_rounded,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: Text(
                      title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.iconOnly,
    required this.onTap,
  });

  final ClassroomNavDestination item;
  final bool selected;
  final bool iconOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bubble = Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: ClassroomSidebar.animDuration,
          curve: Curves.easeOutCubic,
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
        if (item.badge > 0)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: ClassroomPalette.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );

    return Tooltip(
      message: item.label,
      waitDuration: iconOnly ? Duration.zero : const Duration(seconds: 2),
      child: Material(
        color: selected ? item.color.withValues(alpha: 0.12) : Colors.transparent,
        child: InkWell(
          key: Key('classroom-nav-${item.id}'),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: iconOnly
                ? Center(child: bubble)
                : Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: bubble,
                      ),
                      Expanded(
                        child: ClipRect(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              color: selected
                                  ? item.color
                                  : ClassroomPalette.ink,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
