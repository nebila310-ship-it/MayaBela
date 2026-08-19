import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/utils/phone_utils.dart';

/// Local mobile entry with a fixed +251 prefix (Firebase SMS uses E.164).
class EthiopianPhoneField extends StatelessWidget {
  const EthiopianPhoneField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.onSubmitted,
    this.textInputAction,
    this.decoration,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final InputDecoration? decoration;

  /// Converts field text to local login format 0912345678.
  static String localFromInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final local = PhoneUtils.normalizeLocal(trimmed);
    if (local != null) return local;
    var digits = PhoneUtils.digitsOnly(trimmed);
    if (digits.startsWith('251') && digits.length >= 12) {
      return PhoneUtils.normalizeLocal(trimmed) ?? '';
    }
    if (digits.length == 9) return '0$digits';
    return trimmed;
  }

  static String e164FromInput(String raw) =>
      PhoneUtils.toE164Ethiopian(localFromInput(raw));

  @override
  Widget build(BuildContext context) {
    final base = decoration ?? const InputDecoration();
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-]')),
        LengthLimitingTextInputFormatter(14),
      ],
      decoration: base.copyWith(
        labelText: label ?? base.labelText,
        hintText: hintText ?? base.hintText ?? '911234567',
        prefixIcon: base.prefixIcon ?? const Icon(Icons.phone_outlined),
        prefixText: '+251 ',
        prefixStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          fontSize: 16,
        ),
      ),
    );
  }
}
