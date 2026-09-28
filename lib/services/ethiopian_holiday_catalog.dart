import 'package:mayabela/models/calendar_event.dart';

/// Gregorian dates for Ethiopian national / school holidays.
///
/// Fixed civil holidays use the same Gregorian day every year. Enkutatash and
/// Meskel shift by one day in the Gregorian year preceding a leap year.
/// Orthodox Easter is computed (Julian Easter + 13 days in 1900–2099).
/// Islamic feasts use published civil dates and may move ±1 day on moon sighting.
class EthiopianHolidayCatalog {
  EthiopianHolidayCatalog._();

  static bool _gregorianLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  /// Enkutatash / Meskel fall on Sep 12 / Sep 28 when the *following*
  /// Gregorian year is a leap year (Ethiopian calendar leap rule).
  static bool _ethiopianLeapShift(int gregorianYear) =>
      _gregorianLeapYear(gregorianYear + 1);

  /// Civil dates for Mawlid / Eid (tentative; announced on moon sighting).
  static const _islamicByYear = <int, (int fitrM, int fitrD, int adhaM, int adhaD, int mawlidM, int mawlidD)>{
    2025: (3, 31, 6, 7, 9, 5),
    2026: (3, 20, 5, 27, 8, 26),
    2027: (3, 10, 5, 17, 8, 15),
    2028: (2, 27, 5, 6, 8, 4),
  };

  /// Orthodox / Ethiopian Fasika (Gregorian).
  static DateTime orthodoxEaster(int year) {
    final a = year % 4;
    final b = year % 7;
    final c = year % 19;
    final d = (19 * c + 15) % 30;
    final e = (2 * a + 4 * b - d + 34) % 7;
    final month = (d + e + 114) ~/ 31;
    final day = ((d + e + 114) % 31) + 1;
    return DateTime(year, month, day).add(const Duration(days: 13));
  }

  static List<CalendarEvent> forYear(int year) {
    final shift = _ethiopianLeapShift(year);
    final enkutatashDay = shift ? 12 : 11;
    final meskelDay = shift ? 28 : 27;
    final fasika = orthodoxEaster(year);
    final goodFriday = fasika.subtract(const Duration(days: 2));
    final islamic = _islamicByYear[year];

    return [
      _holiday(
        year: year,
        slug: 'genna',
        title: 'Ethiopian Christmas (Genna)',
        description: 'Nationwide holiday — school closed.',
        month: 1,
        day: 7,
      ),
      _holiday(
        year: year,
        slug: 'timket',
        title: 'Timket (Epiphany)',
        description: 'Ethiopian Orthodox Epiphany celebration.',
        month: 1,
        day: 19,
      ),
      _holiday(
        year: year,
        slug: 'adwa',
        title: 'Victory of Adwa',
        description: 'National victory day — commemorative programs may be held.',
        month: 3,
        day: 2,
      ),
      if (islamic != null)
        _holiday(
          year: year,
          slug: 'eid-fitr',
          title: 'Eid al-Fitr',
          description:
              'End of Ramadan — school closed. Date may shift ±1 day on moon sighting.',
          month: islamic.$1,
          day: islamic.$2,
        ),
      _holiday(
        year: year,
        slug: 'good-friday',
        title: 'Ethiopian Good Friday (Siklet)',
        description: 'Orthodox Good Friday — school closed.',
        month: goodFriday.month,
        day: goodFriday.day,
      ),
      _holiday(
        year: year,
        slug: 'fasika',
        title: 'Fasika (Ethiopian Easter)',
        description: 'Orthodox Easter — school closed.',
        month: fasika.month,
        day: fasika.day,
      ),
      _holiday(
        year: year,
        slug: 'labour',
        title: 'Labour Day',
        description: "International Workers' Day — school closed.",
        month: 5,
        day: 1,
      ),
      _holiday(
        year: year,
        slug: 'patriots',
        title: "Patriots' Victory Day",
        description: 'National holiday — school closed.',
        month: 5,
        day: 5,
      ),
      if (islamic != null)
        _holiday(
          year: year,
          slug: 'eid-adha',
          title: 'Eid al-Adha (Arefa)',
          description:
              'Feast of Sacrifice — school closed. Date may shift ±1 day on moon sighting.',
          month: islamic.$3,
          day: islamic.$4,
        ),
      _holiday(
        year: year,
        slug: 'derg',
        title: 'Downfall of the Derg',
        description: 'National holiday — school closed.',
        month: 5,
        day: 28,
      ),
      if (islamic != null)
        _holiday(
          year: year,
          slug: 'mawlid',
          title: "Mawlid (Prophet's Birthday)",
          description:
              'National public holiday — school closed. Date may shift ±1 day on moon sighting.',
          month: islamic.$5,
          day: islamic.$6,
        ),
      _holiday(
        year: year,
        slug: 'enkutatash',
        title: 'Ethiopian New Year (Enkutatash)',
        description: 'Ethiopian New Year — school closed.',
        month: 9,
        day: enkutatashDay,
      ),
      _holiday(
        year: year,
        slug: 'meskel',
        title: 'Meskel (Finding of the True Cross)',
        description: 'Major religious festival — school closed.',
        month: 9,
        day: meskelDay,
      ),
    ];
  }

  static List<CalendarEvent> forYearRange(int fromYear, int toYear) {
    final events = <CalendarEvent>[];
    for (var y = fromYear; y <= toYear; y++) {
      events.addAll(forYear(y));
    }
    return events;
  }

  static CalendarEvent _holiday({
    required int year,
    required String slug,
    required String title,
    required String description,
    required int month,
    required int day,
  }) {
    return CalendarEvent(
      id: 'eth-$year-$slug',
      title: title,
      description: description,
      date: DateTime(year, month, day),
      type: CalendarEventType.holiday,
      isEthiopianHoliday: true,
      autoAnnounce: true,
      audience: 'All',
    );
  }
}
