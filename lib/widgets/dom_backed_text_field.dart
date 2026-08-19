import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/widgets/dom_backed_text_field_stub.dart'
    if (dart.library.html) 'package:mayabela/widgets/dom_backed_text_field_web.dart'
    as platform;

/// Text field that uses a real HTML `<input>` on web so browser autofill,
/// password managers, and UI automation can write into Flutter controllers.
///
/// Non-web builds use a normal [TextField].
class DomBackedTextField extends StatelessWidget {
  const DomBackedTextField({
    super.key,
    required this.controller,
    required this.decoration,
    this.obscureText = false,
    this.readOnly = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofillHint,
    this.inputFormatters,
    this.textInputAction,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final bool obscureText;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final String? autofillHint;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return platform.buildDomBackedTextField(
      controller: controller,
      decoration: decoration,
      obscureText: obscureText,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: style,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      focusNode: focusNode,
      autofillHint: autofillHint,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
    );
  }
}
