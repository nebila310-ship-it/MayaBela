/// Ethiopian phone normalization for login and SMS.
class PhoneUtils {
  PhoneUtils._();

  static String digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// Local format used as login key, e.g. 0911234567.
  ///
  /// Accepts `0911234567`, `911234567`, `+251911234567`, and the common
  /// paste form `+251 0911234567` (leading 0 after country code).
  static String? normalizeLocal(String raw) {
    var digits = digitsOnly(raw);
    if (digits.isEmpty) return null;
    if (digits.startsWith('251')) {
      digits = digits.substring(3);
    }
    // Collapse accidental extra leading zeros from "+251 09..." pastes.
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    if (digits.length == 9 &&
        (digits.startsWith('9') || digits.startsWith('7'))) {
      digits = '0$digits';
    }
    if (!digits.startsWith('0') || digits.length != 10) return null;
    return digits;
  }

  static bool isValidLoginPhone(String raw) => normalizeLocal(raw) != null;

  static String loginKey(String raw) {
    final local = normalizeLocal(raw);
    if (local != null) return local;
    return digitsOnly(raw);
  }

  static bool matches(String? stored, String input) {
    if (stored == null || stored.trim().isEmpty) return false;
    final a = normalizeLocal(stored) ?? digitsOnly(stored);
    final b = normalizeLocal(input) ?? digitsOnly(input);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b;
  }

  /// E.164 for SMS / tel links, e.g. +251911234567.
  static String toE164Ethiopian(String raw) {
    final trimmed = raw.trim();
    final local = normalizeLocal(trimmed);
    if (local != null) return '+251${local.substring(1)}';

    var digits = digitsOnly(trimmed);
    if (digits.startsWith('251')) {
      digits = digits.substring(3);
    }
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    if (digits.length == 9 &&
        (digits.startsWith('9') || digits.startsWith('7'))) {
      return '+251$digits';
    }
    if (digits.isNotEmpty) {
      return '+251$digits';
    }
    return trimmed.startsWith('+') ? trimmed : '+251';
  }

  /// True when [toE164Ethiopian] produced a valid Ethiopian mobile in E.164 form.
  static bool isValidE164Ethiopian(String e164) {
    return RegExp(r'^\+251[79]\d{8}$').hasMatch(e164);
  }

  /// SMS URI path, e.g. +251911234567.
  static String smsUriPhone(String raw) => toE164Ethiopian(raw);

  /// tel: URI path without scheme prefix, e.g. +251911234567.
  static String telUriPhone(String raw) {
    return smsUriPhone(raw);
  }

  /// International digits for wa.me / WhatsApp (no +), e.g. 251911234567.
  static String whatsAppInternationalDigits(String raw) {
    final local = normalizeLocal(raw);
    if (local != null) {
      return '251${local.substring(1)}';
    }
    var digits = digitsOnly(raw);
    if (digits.startsWith('251') && digits.length >= 12) {
      return digits;
    }
    if (digits.startsWith('0') && digits.length >= 10) {
      return '251${digits.substring(1)}';
    }
    return digits;
  }

  /// Preferred storage format for Ethiopian mobiles, e.g. 0911234567.
  static String? normalizeStoredPhone(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return normalizeLocal(trimmed) ?? trimmed;
  }
}
