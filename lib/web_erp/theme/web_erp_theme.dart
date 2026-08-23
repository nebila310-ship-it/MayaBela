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

  static BoxDecoration cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: paperEdge),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration classBanner(Color color) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          color,
          Color.lerp(color, Colors.black, 0.18)!,
        ],
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
