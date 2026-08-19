import 'package:flutter/material.dart';

/// Shared light / dark themes for the whole app.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4338CA),
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      cardColor: Colors.white,
      iconTheme: const IconThemeData(),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      brightness: Brightness.light,
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF818CF8),
      brightness: Brightness.dark,
      surface: const Color(0xFF0F172A),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0B1220),
      cardColor: const Color(0xFF1E293B),
      iconTheme: const IconThemeData(),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      brightness: Brightness.dark,
    );
  }
}
