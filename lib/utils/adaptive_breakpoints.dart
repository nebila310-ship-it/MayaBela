import 'package:flutter/widgets.dart';

/// Shared layout breakpoints — mobile UI unchanged below [desktopMin].
abstract final class AdaptiveBreakpoints {
  static const double mobileMax = 599;
  static const double tabletMin = 600;
  static const double desktopMin = 900;
  static const double wideDesktopMin = 1200;
  static const double contentMaxWidth = 1280;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < desktopMin;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopMin;

  static int dashboardCrossAxisCount(BuildContext context, {bool compact = false}) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < desktopMin) {
      return compact ? 3 : 2;
    }
    if (width < wideDesktopMin) {
      return compact ? 4 : 3;
    }
    return compact ? 5 : 4;
  }
}
