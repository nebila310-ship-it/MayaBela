import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mayabela/web_erp/utils/ios_web_input.dart';

/// Real [TextField] on web. A stacked [HtmlElementView] for every login
/// field painted School ID and username on top of each other (platform
/// views inside the login card scroll view stay at the wrong offset).
/// Flutter's own focused-field overlay still accepts autofill.
Widget buildDomBackedTextField({
  required TextEditingController controller,
  required InputDecoration decoration,
  bool obscureText = false,
  bool readOnly = false,
  TextInputType? keyboardType,
  TextCapitalization textCapitalization = TextCapitalization.none,
  TextStyle? style,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
  FocusNode? focusNode,
  String? autofillHint,
  List<TextInputFormatter>? inputFormatters,
  TextInputAction? textInputAction,
}) {
  final fontSize = IosWebInput.fontSize(style?.fontSize);
  return TextField(
    controller: controller,
    focusNode: focusNode,
    obscureText: obscureText,
    readOnly: readOnly,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    style: (style ?? const TextStyle()).copyWith(fontSize: fontSize),
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    autofillHints: autofillHint == null ? null : <String>[autofillHint],
    inputFormatters: inputFormatters,
    textInputAction: textInputAction,
    decoration: decoration,
  );
}
