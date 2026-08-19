import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/device_calendar_export_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/calendar_event_editor.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.initialDate,
  });

  final DateTime? initialDate;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _data = SchoolDataService.instance;
  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  bool get _canSchedule {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleAdmin || role == AuthService.roleDriver) {
      return true;
    }
    if (role == AuthService.roleTeacher) {
      return TeacherAccessService.instance.canCreateCalendarEvents;
    }
    return false;
  }

  List<CalendarEvent> get _visibleEvents {
    return _data.getVisibleCalendarEventsForRole(
      AuthService.currentUser?.roleKey,
      includeEthiopian: UserPreferencesService.instance.showEthiopianHolidays,
    );
  }

  List<String> get _scheduleAudienceOptions {
    final role = AuthService.currentUser?.roleKey;
    final options = <String>['All', 'Parents', 'Teachers', 'Students', 'Staff'];
    if (role == AuthService.roleTeacher) {
      final homeroomClasses = TeacherAccessService.instance.homeroomClassNames;
      for (final className in homeroomClasses) {
        if (!options.contains(className)) {
          options.add(className);
        }
      }
    }
    return options;
  }

  String get _defaultScheduleAudience {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleTeacher) {
      final homeroomClasses = TeacherAccessService.instance.homeroomClassNames;
      if (homeroomClasses.length == 1) return homeroomClasses.first;
    }
    return 'All';
  }

  List<CalendarEvent> _eventsForDay(DateTime day) {
    return _visibleEvents.where((event) {
      return event.date.year == day.year &&
          event.date.month == day.month &&
          event.date.day == day.day;
    }).toList();
  }

  List<CalendarEvent> _eventsForMonth(DateTime month) {
    return _visibleEvents.where((event) {
      return event.date.year == month.year && event.date.month == month.month;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _data.publishDueCalendarAnnouncements();
    final initial = widget.initialDate ?? DateTime.now();
    _focusedMonth = DateTime(initial.year, initial.month);
    _selectedDay = DateTime(initial.year, initial.month, initial.day);
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
  }

  List<DateTime> _daysInMonthGrid() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startOffset = firstDay.weekday % 7;
    final days = <DateTime>[];

    for (var i = 0; i < startOffset; i++) {
      days.add(firstDay.subtract(Duration(days: startOffset - i)));
    }
    for (var day = 1; day <= lastDay.day; day++) {
      days.add(DateTime(_focusedMonth.year, _focusedMonth.month, day));
    }
    while (days.length % 7 != 0) {
      days.add(days.last.add(const Duration(days: 1)));
    }
    return days;
  }

  Color _typeColor(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.exam:
        return Colors.red;
      case CalendarEventType.holiday:
        return Colors.purple;
      case CalendarEventType.meeting:
        return Colors.indigo;
      case CalendarEventType.sports:
        return Colors.green;
      case CalendarEventType.classEvent:
        return Colors.blue;
      case CalendarEventType.other:
        return Colors.grey;
    }
  }

  IconData _typeIcon(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.exam:
        return Icons.edit_note;
      case CalendarEventType.holiday:
        return Icons.beach_access;
      case CalendarEventType.meeting:
        return Icons.groups;
      case CalendarEventType.sports:
        return Icons.sports_soccer;
      case CalendarEventType.classEvent:
        return Icons.class_;
      case CalendarEventType.other:
        return Icons.event;
    }
  }

  Future<void> _scheduleEvent({CalendarEvent? existing}) async {
    final s = AppLocale.instance.strings;
    final draft = await showCalendarEventEditor(
      context: context,
      initialDate: existing?.date ?? _selectedDay,
      audienceOptions: _scheduleAudienceOptions,
      defaultAudience: existing?.audience ?? _defaultScheduleAudience,
      existing: existing,
    );
    if (draft == null || !mounted) return;

    CalendarEvent savedEvent;
    if (existing == null) {
      savedEvent = _data.scheduleCalendarEvent(
        title: draft.title,
        description: draft.description,
        date: draft.date,
        type: draft.type,
        audience: draft.audience,
        autoAnnounce: draft.autoAnnounce,
        time: draft.time,
      );
    } else {
      final updated = existing.copyWith(
        title: draft.title,
        description: draft.description,
        date: draft.date,
        type: draft.type,
        audience: draft.audience,
        autoAnnounce: draft.autoAnnounce,
        time: draft.time,
        clearTime: draft.time == null,
      );
      final ok = _data.updateCalendarEvent(updated);
      if (!ok) return;
      savedEvent = updated;
    }

    _data.publishDueCalendarAnnouncements();
    if (draft.exportToDevice) {
      await DeviceCalendarExportService.instance.exportEvent(savedEvent);
    }
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existing == null ? s.eventScheduled : s.eventUpdated),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    final s = AppLocale.instance.strings;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteEventConfirm),
        content: Text(event.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _data.deleteCalendarEvent(event.id);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.eventDeleted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthEvents = _eventsForMonth(_focusedMonth);
    final dayEvents = _eventsForDay(_selectedDay);
    final upcoming = _data.getUpcomingEvents(days: 45);
    final ethiopianUpcoming = upcoming.where((e) => e.isEthiopianHoliday).toList();

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final monthName =
            '${s.monthName(_focusedMonth.month)} ${_focusedMonth.year}';
        final selectedDateStr =
            '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}';

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.purple,
            title: Text(s.schoolCalendar),
          ),
          floatingActionButton: _canSchedule
              ? FloatingActionButton.extended(
                  onPressed: _scheduleEvent,
                  icon: const Icon(Icons.add),
                  label: Text(s.scheduleEvent),
                )
              : null,
          body: Column(
            children: [
              if (ethiopianUpcoming.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade100),
                  ),
                  child: Text(
                    '${s.upcomingEthiopianHolidays}: ${ethiopianUpcoming.take(2).map((e) => e.title).join(' · ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              Container(
                color: Colors.purple.shade50,
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _changeMonth(-1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          monthName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _changeMonth(1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(
                        7,
                        (i) => Text(
                          s.calendarDayHeader(i),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                        // Compact month grid so day events stay visible below.
                        childAspectRatio: 1.7,
                      ),
                      itemCount: _daysInMonthGrid().length,
                      itemBuilder: (context, index) {
                        final day = _daysInMonthGrid()[index];
                        final inMonth = day.month == _focusedMonth.month;
                        final isSelected = day.year == _selectedDay.year &&
                            day.month == _selectedDay.month &&
                            day.day == _selectedDay.day;
                        final isToday = _isSameDay(day, DateTime.now());
                        final hasEvents =
                            inMonth && _eventsForDay(day).isNotEmpty;
                        final isHoliday = inMonth &&
                            _eventsForDay(day).any((e) => e.isEthiopianHoliday);

                        return InkWell(
                          onTap: inMonth
                              ? () => setState(() => _selectedDay = day)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.purple
                                  : isHoliday
                                      ? Colors.purple.withValues(alpha: 0.2)
                                      : isToday
                                          ? Colors.purple.withValues(alpha: 0.15)
                                          : null,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : inMonth
                                            ? Colors.black
                                            : Colors.grey,
                                    fontWeight:
                                        isToday ? FontWeight.bold : null,
                                  ),
                                ),
                                if (hasEvents)
                                  Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.only(top: 1),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.purple,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    if (monthEvents.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          s.eventsThisMonth(monthEvents.length),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Events · $selectedDateStr',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: dayEvents.isEmpty
                    ? Center(child: Text(s.noEventsOnDay(selectedDateStr)))
                    : ListView.separated(
                        padding: listPagePadding(context),
                        itemCount: dayEvents.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final event = dayEvents[index];
                          final color = _typeColor(event.type);
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.15),
                                child: Icon(_typeIcon(event.type), color: color),
                              ),
                              title: Text(
                                event.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: _canSchedule && !event.isEthiopianHoliday
                                  ? PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _scheduleEvent(existing: event);
                                        } else if (value == 'delete') {
                                          _deleteEvent(event);
                                        } else if (value == 'device') {
                                          DeviceCalendarExportService.instance
                                              .exportEvent(event);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text(s.editEvent),
                                        ),
                                        if (DeviceCalendarExportService
                                            .instance.isSupported)
                                          PopupMenuItem(
                                            value: 'device',
                                            child: Text(s.addToDeviceCalendar),
                                          ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text(s.delete),
                                        ),
                                      ],
                                    )
                                  : (DeviceCalendarExportService
                                              .instance.isSupported
                                          ? IconButton(
                                              tooltip: s.addToDeviceCalendar,
                                              icon: const Icon(
                                                Icons.event_available_outlined,
                                              ),
                                              onPressed: () =>
                                                  DeviceCalendarExportService
                                                      .instance
                                                      .exportEvent(event),
                                            )
                                          : null),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (event.isEthiopianHoliday)
                                    Text(
                                      s.ethiopianHolidayLabel,
                                      style: const TextStyle(
                                        color: Colors.purple,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (event.time != null)
                                    Text('${s.timeLabel}: ${event.time}'),
                                  Text(event.description),
                                  Text(
                                    '${s.audience}: ${s.audienceLabel(event.audience)}',
                                  ),
                                  if (event.autoAnnounce) ...[
                                    Text(
                                      event.announcementReminderPublished
                                          ? s.postedReminderToAnnouncements
                                          : s.willPostReminderToAnnouncements,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: event.announcementReminderPublished
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
