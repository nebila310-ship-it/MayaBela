import 'package:flutter/material.dart';

/// ERP shell accent and layout tokens (web-only).
abstract final class WebErpTheme {
  static const Color primary = Color(0xFF4527A0);
  static const Color primaryLight = Color(0xFF7E57C2);
  static const Color sidebarBg = Color(0xFF1E1B2E);
  static const Color sidebarHover = Color(0xFF2D2942);
  static const Color sidebarActive = Color(0xFF4527A0);

  static const double sidebarExpanded = 260;
  static const double sidebarCollapsed = 72;
  static const double topBarHeight = 56;

  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? Colors.white12 : Colors.black12,
      ),
      boxShadow: [
        if (!isDark)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
      ],
    );
  }

  static TextStyle sectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ) ??
        const TextStyle(fontWeight: FontWeight.w700);
  }
}
