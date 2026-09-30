import 'package:flutter/material.dart';

import 'package:mayabela/theme/classroom_palette.dart';

/// ERP shell tokens — Google Classroom stream: white cards, colorful accents.
abstract final class WebErpTheme {
  static const Color primary = ClassroomPalette.teal;
  static const Color primaryLight = ClassroomPalette.cyan;
  static const Color sidebarBg = Color(0xFFFFFFFF);
  static const Color sidebarHover = Color(0xFFF1F3F4);
  static const Color sidebarActive = Color(0xFFE6F4EA);

  /// White class-card surface (kept as `paper` so existing pages pick it up).
  static const Color paper = ClassroomPalette.card;
  static const Color paperEdge = ClassroomPalette.line;
  static const Color paperInk = ClassroomPalette.ink;
  static const Color paperBackdrop = ClassroomPalette.stream;

  static const double sidebarExpanded = 260;
  static const double sidebarCollapsed = 72;
  static const double topBarHeight = 56;

  static Color paperOf(BuildContext context) =>
      ClassroomPalette.cardOf(context);

  static Color paperEdgeOf(BuildContext context) =>
      ClassroomPalette.lineOf(context);

  static Color paperInkOf(BuildContext context) =>
      ClassroomPalette.inkOf(context);

  static Color paperBackdropOf(BuildContext context) =>
      ClassroomPalette.streamOf(context);

  static Color sidebarBgOf(BuildContext context) =>
      ClassroomPalette.cardOf(context);

  static Color sidebarHoverOf(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClassroomPalette.isDark(context)
        ? scheme.surfaceContainerHighest
        : sidebarHover;
  }

  static Color sidebarActiveOf(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClassroomPalette.isDark(context)
        ? scheme.primary.withValues(alpha: 0.22)
        : sidebarActive;
  }

  static BoxDecoration cardDecoration(BuildContext context) {
    final dark = ClassroomPalette.isDark(context);
    return BoxDecoration(
      // Keep the light paper fill so existing ink text stays readable.
      color: paper,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: dark ? paperEdge.withValues(alpha: 0.35) : paperEdgeOf(context),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.42 : 0.06),
          blurRadius: dark ? 6 : 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration classBanner(Color color) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [color, Color.lerp(color, Colors.black, 0.18)!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: paperInk,
        ) ??
        const TextStyle(fontWeight: FontWeight.w700, color: paperInk);
  }
}
