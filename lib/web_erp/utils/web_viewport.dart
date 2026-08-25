import 'package:flutter/material.dart';

/// Breakpoints for responsive web / mobile-browser layouts.
abstract final class WebViewport {
  static const double narrowBreakpoint = 768;
  static const double compactPhoneBreakpoint = 520;

  static bool isNarrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < narrowBreakpoint;

  static bool isCompactPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactPhoneBreakpoint;

  /// Inner page padding. Keep smaller on phones so 12px shell + page still fits.
  static EdgeInsets pagePadding(BuildContext context) =>
      EdgeInsets.all(isNarrow(context) ? 12 : 20);
}
