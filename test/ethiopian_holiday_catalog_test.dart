import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/services/ethiopian_holiday_catalog.dart';
import 'package:mayabela/services/school_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EthiopianHolidayCatalog', () {
    test('loads fixed national holidays for a year', () {
      final holidays = EthiopianHolidayCatalog.forYear(2026);
      expect(holidays.length, greaterThanOrEqualTo(8));
      expect(holidays.every((e) => e.isEthiopianHoliday), isTrue);
      expect(holidays.any((e) => e.id == 'eth-2026-genna'), isTrue);
      expect(
        holidays.firstWhere((e) => e.id == 'eth-2026-genna').date,
        DateTime(2026, 1, 7),
      );
    });

    test('Enkutatash shifts before a Gregorian leap year', () {
      // 2023 precedes leap 2024 → Sep 12; 2025 precedes non-leap 2026 → Sep 11
      final beforeLeap = EthiopianHolidayCatalog.forYear(2023)
          .firstWhere((e) => e.id.endsWith('enkutatash'));
      final normal = EthiopianHolidayCatalog.forYear(2025)
          .firstWhere((e) => e.id.endsWith('enkutatash'));
      expect(beforeLeap.date.day, 12);
      expect(normal.date.day, 11);
    });
  });

  group('School calendar sync', () {
    test('ensureEthiopianHolidaysSynced upserts multi-year holidays', () {
      final data = SchoolDataService.instance;
      data.ensureEthiopianHolidaysSynced(force: true);
      final year = DateTime.now().year;
      final events = data.getCalendarEvents()
          .where((e) => e.isEthiopianHoliday)
          .toList();
      expect(events.any((e) => e.id == 'eth-$year-genna'), isTrue);
      expect(events.any((e) => e.id == 'eth-${year + 1}-enkutatash'), isTrue);
      expect(events.where((e) => RegExp(r'^eth-\d+$').hasMatch(e.id)), isEmpty);
    });
  });
}
