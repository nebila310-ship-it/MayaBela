/// Shared email checks for signup, enrollment, and login identifiers.
class EmailUtils {
  EmailUtils._();

  static final _pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? normalize(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value.isEmpty || !_pattern.hasMatch(value)) return null;
    return value;
  }

  static bool isValid(String? raw) => normalize(raw) != null;
}
