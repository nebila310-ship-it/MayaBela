import 'package:flutter/material.dart';

/// Visual theme for [ProfessionalQrScannerPanel] and advanced scanner shells.
class QrScannerTheme {
  const QrScannerTheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.pageGradient,
    required this.headerGradient,
    this.footerHint,
    this.bannerIcon = Icons.info_outline_rounded,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final LinearGradient pageGradient;
  final List<Color> headerGradient;
  final String? footerHint;
  final IconData bannerIcon;

  static const attendance = QrScannerTheme(
    primary: Color(0xFF4F46E5),
    secondary: Color(0xFF6366F1),
    accent: Color(0xFF22D3EE),
    pageGradient: LinearGradient(
      colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF), Color(0xFFFAFAFA)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    headerGradient: [Color(0xFF4338CA), Color(0xFF6366F1), Color(0xFF818CF8)],
    footerHint: 'Camera stays open — scan students one after another quickly',
    bannerIcon: Icons.school_rounded,
  );

  static const transport = QrScannerTheme(
    primary: Color(0xFF0D9488),
    secondary: Color(0xFF14B8A6),
    accent: Color(0xFF2DD4BF),
    pageGradient: LinearGradient(
      colors: [Color(0xFFF0FDFA), Color(0xFFECFEFF), Color(0xFFFAFAFA)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    headerGradient: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF2DD4BF)],
    footerHint: 'Onboard adds student to bus · Discharge removes from bus',
    bannerIcon: Icons.directions_bus_filled,
  );
}

class QrScannerModeOption {
  const QrScannerModeOption({
    required this.label,
    required this.icon,
    required this.activeColor,
  });

  final String label;
  final IconData icon;
  final Color activeColor;
}
