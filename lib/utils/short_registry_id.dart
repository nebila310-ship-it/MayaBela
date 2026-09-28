/// Human-facing registry ids: a short prefix plus exactly four digits.
///
/// Examples: `STU-0001`, `TCH-1006`, `QA-0001`, `DRV-0003`.
/// Legacy timestamp ids (`TCH-17399…`) stay valid for lookup but are ignored
/// when choosing the next number, so new people never get a long id.
abstract final class ShortRegistryId {
  static const maxValue = 9999;

  static final RegExp pattern = RegExp(r'^([A-Z]{1,4})-(\d{1,4})$');

  static ({String prefix, int number})? parse(String raw) {
    final match = pattern.firstMatch(raw.trim().toUpperCase());
    if (match == null) return null;
    final n = int.tryParse(match.group(2)!);
    if (n == null || n < 1 || n > maxValue) return null;
    return (prefix: match.group(1)!, number: n);
  }

  static int? parseNumber(String raw, {String? prefix}) {
    final parsed = parse(raw);
    if (parsed == null) return null;
    if (prefix != null && parsed.prefix != prefix.toUpperCase()) return null;
    return parsed.number;
  }

  static String format(String prefix, int number) {
    final n = number.clamp(1, maxValue);
    return '${prefix.trim().toUpperCase()}-${n.toString().padLeft(4, '0')}';
  }

  /// Drop leftover timestamp counters (13+ digits) from old allocators.
  static int clampCounter(int? nextId, {int fallback = 1}) {
    if (nextId == null || nextId < 1 || nextId > maxValue + 1) return fallback;
    return nextId;
  }

  static String allocate({
    required String prefix,
    required Iterable<String> existingIds,
    required bool Function(String id) isTaken,
    int persistedNext = 1,
  }) {
    final p = prefix.trim().toUpperCase();
    var highest = 0;
    for (final id in existingIds) {
      final n = parseNumber(id, prefix: p);
      if (n != null && n > highest) highest = n;
    }
    var candidate = highest + 1;
    final persisted = clampCounter(persistedNext, fallback: 1);
    if (persisted > candidate) candidate = persisted;
    if (candidate < 1) candidate = 1;

    String idFor(int n) => format(p, n);

    while (candidate <= maxValue && isTaken(idFor(candidate))) {
      candidate++;
    }
    if (candidate <= maxValue) return idFor(candidate);

    for (var i = 1; i <= maxValue; i++) {
      if (!isTaken(idFor(i))) return idFor(i);
    }
    throw StateError('No free 4-digit $p id left');
  }
}
