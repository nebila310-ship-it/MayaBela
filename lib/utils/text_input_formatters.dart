import 'package:flutter/services.dart';

/// Formats input as DD/MM/YYYY with automatic `/` separators.
class DateSlashFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final clipped =
        digitsOnly.length > 8 ? digitsOnly.substring(0, 8) : digitsOnly;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      buffer.write(clipped[i]);
      if (i == 1 || i == 3) buffer.write('/');
    }
    final text = buffer.toString();

    final digitCursor = newValue.text
        .substring(0, newValue.selection.end.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'\D'), '')
        .length;
    var offset = digitCursor;
    if (digitCursor > 2) offset++;
    if (digitCursor > 4) offset++;
    offset = offset.clamp(0, text.length);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Capitalizes the first letter of each word while typing.
class CapitalizeWordsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final buffer = StringBuffer();
    var capitalizeNext = true;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (capitalizeNext && RegExp(r'[a-zA-Z]').hasMatch(char)) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char);
        capitalizeNext = char == ' ' || char == '-' || char == '\'';
      }
    }

    final formatted = buffer.toString();
    if (formatted == text) return newValue;

    return TextEditingValue(
      text: formatted,
      selection: newValue.selection,
    );
  }
}

final dateSlashFormatters = [DateSlashFormatter()];
final nameInputFormatters = [CapitalizeWordsFormatter()];
