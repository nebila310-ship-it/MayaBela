import 'package:mayabela/models/calendar_event.dart';

/// Authoritative Gregorian dates for Ethiopian national / school holidays.
///
/// Fixed civil holidays use the same Gregorian day every year. Enkutatash and
/// Meskel shift by one day in the Gregorian year preceding a leap year.
/// Movable Islamic feasts are omitted (school can schedule those manually).
class EthiopianHolidayCatalog {
  EthiopianHolidayCatalog._();

  static bool _gregorianLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  /// Enkutatash / Meskel fall on Sep 12 / Sep 28 when the *following*
  /// Gregorian year is a leap year (Ethiopian calendar leap rule).
  static bool _ethiopianLeapShift(int gregorianYear) =>
      _gregorianLeapYear(gregorianYear + 1);

  static List<CalendarEvent> forYear(int year) {
    final shift = _ethiopianLeapShift(year);
    final enkutatashDay = shift ? 12 : 11;
    final meskelDay = shift ? 28 : 27;

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
      _holiday(
        year: year,
        slug: 'derg',
        title: 'Downfall of the Derg',
        description: 'National holiday — school closed.',
        month: 5,
        day: 28,
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
