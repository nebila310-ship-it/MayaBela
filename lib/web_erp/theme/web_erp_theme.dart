import 'package:flutter/material.dart';

/// ERP shell accent and layout tokens.
/// Cards and page chrome use the same paper/notebook colors as the phone APK.
abstract final class WebErpTheme {
  static const Color primary = Color(0xFF4527A0);
  static const Color primaryLight = Color(0xFF7E57C2);
  static const Color sidebarBg = Color(0xFF1E1B2E);
  static const Color sidebarHover = Color(0xFF2D2942);
  static const Color sidebarActive = Color(0xFF4527A0);

  /// Cream notebook page — matches [AdminEducationalBackground].
  static const Color paper = Color(0xFFFBF6ED);
  static const Color paperEdge = Color(0xFFD9C7A8);
  static const Color paperInk = Color(0xFF3E3428);
  static const Color paperBackdrop = Color(0xFFCFDBEA);

  static const double sidebarExpanded = 260;
  static const double sidebarCollapsed = 72;
  static const double topBarHeight = 56;

  static BoxDecoration cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: paper.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: paperEdge.withValues(alpha: 0.75)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF5D4037).withValues(alpha: 0.10),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
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
