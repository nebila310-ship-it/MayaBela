/// Shared paging + name/ID search for teacher, staff, and student directories.
class PaginatedDirectory {
  static const int pageSize = 10;

  static bool matchesText(String query, Iterable<String?> fields) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    for (final field in fields) {
      final value = field?.trim().toLowerCase() ?? '';
      if (value.isNotEmpty && value.contains(q)) return true;
    }
    return false;
  }

  static int pageCount(int total, {int pageSize = PaginatedDirectory.pageSize}) {
    if (total <= 0) return 1;
    return ((total + pageSize - 1) ~/ pageSize);
  }

  static List<T> pageOf<T>(
    List<T> items,
    int page, {
    int pageSize = PaginatedDirectory.pageSize,
  }) {
    if (items.isEmpty) return const [];
    final count = pageCount(items.length, pageSize: pageSize);
    final safePage = page.clamp(0, count - 1);
    final start = safePage * pageSize;
    if (start >= items.length) return const [];
    return items.sublist(start, (start + pageSize).clamp(0, items.length));
  }
}
