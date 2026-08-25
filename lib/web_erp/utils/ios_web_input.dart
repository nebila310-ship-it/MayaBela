/// iOS Safari auto-zooms the page when a focused `<input>` is under 16px.
/// Flutter web then eats pinch gestures, so the user cannot zoom back out.
abstract final class IosWebInput {
  static const double minFontSize = 16;

  static double fontSize(double? requested) {
    final value = requested ?? minFontSize;
    return value < minFontSize ? minFontSize : value;
  }
}
