import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Extra space at the end of scrollable content (above the system nav bar).
const double kScrollBottomSpacing = 16;

/// Bottom inset from the physical display (works even inside [SafeArea]).
double viewBottomInset(BuildContext context) {
  return MediaQuery.viewPaddingOf(context).bottom;
}

/// Padding for [SingleChildScrollView] / [ListView] page content.
EdgeInsets scrollPagePadding(
  BuildContext context, {
  double horizontal = 16,
  double top = 16,
  double bottomSpacing = kScrollBottomSpacing,
}) {
  final systemBottom = math.max(viewBottomInset(context), 24.0);
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    systemBottom + bottomSpacing,
  );
}

/// Bottom padding for lists that already sit inside a global safe scope.
EdgeInsets listPagePadding(
  BuildContext context, {
  double horizontal = 16,
  double top = 16,
  double bottom = kScrollBottomSpacing,
}) {
  return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
}
