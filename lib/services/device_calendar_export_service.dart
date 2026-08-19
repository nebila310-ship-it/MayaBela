import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';

import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/services/user_preferences_service.dart';

/// Exports school calendar events to the device calendar (Google / Apple).
///
/// Uses the system “add event” sheet — no permanent calendar permission needed.
/// No-ops on web and when the user disabled the preference.
class DeviceCalendarExportService {
  DeviceCalendarExportService._();
  static final instance = DeviceCalendarExportService._();

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<bool> exportEvent(CalendarEvent event) async {
    if (!isSupported) return false;
    if (!UserPreferencesService.instance.syncEventsToDeviceCalendar) {
      return false;
    }

    final start = _startDateTime(event);
    final end = start.add(
      event.time == null || event.time!.trim().isEmpty
          ? const Duration(hours: 24)
          : const Duration(hours: 1),
    );

    final ok = await Add2Calendar.addEvent2Cal(
      Event(
        title: event.title,
        description: event.description,
        location: 'MayaBela School',
        startDate: start,
        endDate: end,
        allDay: event.time == null || event.time!.trim().isEmpty,
      ),
    );
    return ok;
  }

  DateTime _startDateTime(CalendarEvent event) {
    final day = DateTime(event.date.year, event.date.month, event.date.day);
    final raw = (event.time ?? '').trim();
    if (raw.isEmpty) return day;

    // Accept "8:00 AM", "15:30", "3:00 PM".
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return day;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final ampm = match.group(3)?.toUpperCase();
    if (ampm == 'PM' && hour < 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }
}
