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

/// Colorful classroom rail that opens, closes, and bounces.
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

  static const double expandedWidth = 248;
  static const double collapsedWidth = 80;
  static const Duration animDuration = Duration(milliseconds: 420);

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
    final hideLabels = collapsed && !inDrawer;
    final width = inDrawer
        ? expandedWidth
        : (hideLabels ? collapsedWidth : expandedWidth);
    final toggleTip = inDrawer
        ? s.closeClassroomMenu
        : hideLabels
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
            ? const BorderRadius.horizontal(right: Radius.circular(28))
            : BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: inDrawer ? 28 : 18,
            offset: const Offset(6, 0),
          ),
        ],
      ),
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: expandedWidth,
        maxWidth: expandedWidth,
        child: SizedBox(
          width: expandedWidth,
          child: Column(
          children: [
            _Header(
              title: title,
              accent: accent,
              collapsed: hideLabels,
              tooltip: toggleTip,
              onToggle: () {
                if (UserPreferencesService.instance.hapticFeedback) {
                  HapticFeedback.selectionClick();
                }
                onToggle();
              },
              inDrawer: inDrawer,
            ),
            SizedBox(
              height: 6,
              child: Row(
                children: [
                  for (final color in ClassroomPalette.classes.take(8))
                    Expanded(child: ColoredBox(color: color)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final item = destinations[index];
                  return _NavTile(
                    item: item,
                    selected: selectedIndex == index,
                    collapsed: hideLabels,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Row(
                children: [
                  for (var i = 0; i < 5; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.6, end: 1),
                      duration: Duration(milliseconds: 280 + (i * 70)),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: ClassroomPalette.at(i),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.accent,
    required this.collapsed,
    required this.tooltip,
    required this.onToggle,
    required this.inDrawer,
  });

  final String title;
  final Color accent;
  final bool collapsed;
  final String tooltip;
  final VoidCallback onToggle;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent,
            Color.lerp(accent, ClassroomPalette.cyan, 0.45)!,
            Color.lerp(accent, ClassroomPalette.grape, 0.28)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('classroom-sidebar-toggle'),
            tooltip: tooltip,
            onPressed: onToggle,
            icon: AnimatedRotation(
              turns: collapsed ? 0.03 : -0.08,
              duration: ClassroomSidebar.animDuration,
              curve: Curves.easeOutBack,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: Icon(
                  inDrawer ? Icons.close_rounded : Icons.auto_stories_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1.15,
              ),
            ),
          ),
          Icon(
            collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
        ],
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
    final bubble = Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? item.color : item.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.38),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            item.icon,
            color: selected ? Colors.white : item.color,
            size: 22,
          ),
        ),
        if (item.badge > 0)
          Positioned(
            right: -2,
            top: -2,
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Tooltip(
        message: item.label,
        waitDuration: collapsed ? Duration.zero : const Duration(seconds: 2),
        child: Material(
          color: selected ? item.color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: Key('classroom-nav-${item.id}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            hoverColor: item.color.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  bubble,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? item.color : ClassroomPalette.ink,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 13,
                      ),
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
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.badge > 99 ? '99+' : '${item.badge}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
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
