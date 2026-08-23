import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/web_erp/utils/paginated_directory.dart';

void main() {
  test('pages are 10 items long', () {
    final items = List<int>.generate(24, (i) => i + 1);
    expect(PaginatedDirectory.pageCount(items.length), 3);
    expect(PaginatedDirectory.pageOf(items, 0), List<int>.generate(10, (i) => i + 1));
    expect(PaginatedDirectory.pageOf(items, 2), [21, 22, 23, 24]);
  });

  test('empty list is one empty page', () {
    expect(PaginatedDirectory.pageCount(0), 1);
    expect(PaginatedDirectory.pageOf<int>(const [], 4), isEmpty);
  });

  test('search matches name or staff ID', () {
    expect(
      PaginatedDirectory.matchesText('yared', ['Yared Bekele', 'TCH-1019']),
      isTrue,
    );
    expect(
      PaginatedDirectory.matchesText('TCH-1018', ['Eman', 'TCH-1018']),
      isTrue,
    );
    expect(
      PaginatedDirectory.matchesText('zzz', ['Eman', 'TCH-1018']),
      isFalse,
    );
  });
}
