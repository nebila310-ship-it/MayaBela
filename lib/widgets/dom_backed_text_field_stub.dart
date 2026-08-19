import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  return TextField(
    controller: controller,
    focusNode: focusNode,
    obscureText: obscureText,
    readOnly: readOnly,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    style: style,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    autofillHints: autofillHint == null ? null : <String>[autofillHint],
    inputFormatters: inputFormatters,
    textInputAction: textInputAction,
    decoration: decoration,
  );
}
