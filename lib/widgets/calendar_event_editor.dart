import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/services/device_calendar_export_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';

class CalendarEventDraft {
  const CalendarEventDraft({
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    required this.audience,
    required this.autoAnnounce,
    this.time,
    this.exportToDevice = true,
  });

  final String title;
  final String description;
  final DateTime date;
  final CalendarEventType type;
  final String audience;
  final bool autoAnnounce;
  final String? time;
  final bool exportToDevice;
}

Future<CalendarEventDraft?> showCalendarEventEditor({
  required BuildContext context,
  required DateTime initialDate,
  required List<String> audienceOptions,
  String defaultAudience = 'All',
  CalendarEvent? existing,
  bool showDeviceExport = true,
}) async {
  final s = AppLocale.instance.strings;
  final titleController =
      TextEditingController(text: existing?.title ?? '');
  final bodyController =
      TextEditingController(text: existing?.description ?? '');
  var date = existing?.date ?? initialDate;
  var type = existing?.type ?? CalendarEventType.other;
  var audience = existing?.audience ?? defaultAudience;
  if (!audienceOptions.contains(audience)) {
    audience = defaultAudience;
  }
  var autoAnnounce = existing?.autoAnnounce ?? true;
  var timeOfDay = _parseTime(existing?.time);
  var exportToDevice = showDeviceExport &&
      DeviceCalendarExportService.instance.isSupported &&
      UserPreferencesService.instance.syncEventsToDeviceCalendar;

  final saved = await showAdminFormDialog(
    context: context,
    title: existing == null ? s.scheduleEvent : s.editEvent,
    accent: Colors.deepPurple,
    icon: Icons.event_available_outlined,
    canSave: (_) =>
        titleController.text.trim().isNotEmpty &&
        bodyController.text.trim().isNotEmpty,
    saveBlockedReason: (_) {
      if (titleController.text.trim().isEmpty ||
          bodyController.text.trim().isEmpty) {
        return s.titleMessageRequired;
      }
      return null;
    },
    builder: (context, setDialogState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminFormDialogSection(
          title: s.titleLabel,
          icon: Icons.edit_note_outlined,
          color: Colors.deepPurple,
          children: [
            adminDialogField(
              TextField(
                controller: titleController,
                onChanged: (_) => setDialogState(() {}),
                decoration: adminFieldDecoration(
                  label: s.titleLabel,
                  icon: Icons.title_outlined,
                  accent: Colors.deepPurple,
                ),
              ),
            ),
            adminDialogField(
              TextField(
                controller: bodyController,
                onChanged: (_) => setDialogState(() {}),
                maxLines: 3,
                decoration: adminFieldDecoration(
                  label: s.description,
                  icon: Icons.notes_outlined,
                  accent: Colors.deepPurple,
                ),
              ),
            ),
          ],
        ),
        AdminFormDialogSection(
          title: s.dateLabel,
          icon: Icons.calendar_month_outlined,
          color: Colors.deepPurple.shade400,
          children: [
            adminDialogField(
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(DateTime.now().year - 1),
                    lastDate: DateTime(DateTime.now().year + 5),
                  );
                  if (picked != null) {
                    setDialogState(() => date = picked);
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(
                    color: Colors.deepPurple.withValues(alpha: 0.35),
                  ),
                ),
                icon: const Icon(Icons.date_range_rounded),
                label: Text('${date.day}/${date.month}/${date.year}'),
              ),
            ),
            adminDialogField(
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: timeOfDay ?? const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (picked != null) {
                    setDialogState(() => timeOfDay = picked);
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                  timeOfDay == null
                      ? s.allDayEvent
                      : timeOfDay!.format(context),
                ),
              ),
            ),
            if (timeOfDay != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setDialogState(() => timeOfDay = null),
                  child: Text(s.clearEventTime),
                ),
              ),
          ],
        ),
        AdminFormDialogSection(
          title: s.audience,
          icon: Icons.groups_outlined,
          color: Colors.deepPurple.shade300,
          children: [
            adminDialogField(
              InputDecorator(
                decoration: adminFieldDecoration(
                  label: s.typeLabel,
                  icon: Icons.category_outlined,
                  accent: Colors.deepPurple,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<CalendarEventType>(
                    value: type,
                    isExpanded: true,
                    items: CalendarEventType.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(s.calendarEventTypeLabel(item.name)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => type = value);
                    },
                  ),
                ),
              ),
            ),
            adminDialogField(
              InputDecorator(
                decoration: adminFieldDecoration(
                  label: s.audience,
                  icon: Icons.people_outline,
                  accent: Colors.deepPurple,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: audience,
                    isExpanded: true,
                    items: audienceOptions
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(s.audienceLabel(item)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => audience = value);
                      }
                    },
                  ),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: autoAnnounce,
              activeTrackColor: Colors.deepPurple.withValues(alpha: 0.45),
              activeThumbColor: Colors.deepPurple,
              onChanged: (value) {
                setDialogState(() => autoAnnounce = value);
              },
              title: Text(s.autoPostAnnouncements),
              subtitle: Text(
                s.willPostToAnnouncements,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            if (showDeviceExport &&
                DeviceCalendarExportService.instance.isSupported)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: exportToDevice,
                onChanged: (value) {
                  setDialogState(() => exportToDevice = value);
                },
                title: Text(s.addToDeviceCalendar),
                subtitle: Text(
                  s.addToDeviceCalendarHint,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  final title = titleController.text.trim();
  final body = bodyController.text.trim();
  titleController.dispose();
  bodyController.dispose();

  if (saved != true) return null;

  return CalendarEventDraft(
    title: title,
    description: body,
    date: date,
    type: type,
    audience: audience,
    autoAnnounce: autoAnnounce,
    time: timeOfDay == null ? null : _formatTime(timeOfDay!),
    exportToDevice: exportToDevice,
  );
}

TimeOfDay? _parseTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$',
    caseSensitive: false,
  ).firstMatch(raw.trim());
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final ampm = match.group(3)?.toUpperCase();
  if (ampm == 'PM' && hour < 12) hour += 12;
  if (ampm == 'AM' && hour == 12) hour = 0;
  if (hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatTime(TimeOfDay t) {
  final hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final mm = t.minute.toString().padLeft(2, '0');
  final suffix = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour12:$mm $suffix';
}
