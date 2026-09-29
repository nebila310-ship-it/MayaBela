import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/academic_term.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/device_calendar_export_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
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
      case CalendarEventType.collegeGuidance:
        return Colors.teal;
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
      case CalendarEventType.collegeGuidance:
        return Icons.school_outlined;
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


  Color get _chrome {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleTeacher) return TeacherTheme.primary;
    return WebErpTheme.primary;
  }

  Widget _academicTermsStrip() {
    final schoolId = AuthService.activeSchoolId;
    final terms = schoolId == null
        ? const <AcademicTerm>[]
        : (SchoolRegistryService.instance.lookup(schoolId)?.academicTerms ??
              const []);
    if (terms.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.teal.shade100),
        ),
        child: Text(
          'Academic terms: ${terms.map((term) {
            final window =
                '${term.startDate.day}/${term.startDate.month}–${term.endDate.day}/${term.endDate.month}';
            return '${term.name} ($window)';
          }).join(' · ')}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthEvents = _eventsForMonth(_focusedMonth);
    final dayEvents = _eventsForDay(_selectedDay);
    final upcoming = _data.getUpcomingEvents(days: 45);
    final ethiopianUpcoming =
        upcoming.where((e) => e.isEthiopianHoliday).toList();

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final monthName =
            '${s.monthName(_focusedMonth.month)} ${_focusedMonth.year}';
        final selectedDateStr =
            '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}';
        final chrome = _chrome;
        final wide = MediaQuery.sizeOf(context).width >= 840;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: chrome,
            foregroundColor: Colors.white,
            title: Text(s.schoolCalendar),
          ),
          floatingActionButton: _canSchedule && !wide
              ? FloatingActionButton.extended(
                  backgroundColor: chrome,
                  onPressed: _scheduleEvent,
                  icon: const Icon(Icons.add),
                  label: Text(s.scheduleEvent),
                )
              : null,
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      s.schoolCalendar,
                      style: WebErpTheme.sectionTitle(context),
                    ),
                    const Spacer(),
                    if (_canSchedule && wide)
                      FilledButton.icon(
                        onPressed: _scheduleEvent,
                        icon: const Icon(Icons.add),
                        label: Text(s.scheduleEvent),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _academicTermsStrip(),
                if (ethiopianUpcoming.isNotEmpty)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final next = ethiopianUpcoming.first;
                        setState(() {
                          _focusedMonth =
                              DateTime(next.date.year, next.date.month);
                          _selectedDay = DateTime(
                            next.date.year,
                            next.date.month,
                            next.date.day,
                          );
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.purple.shade100),
                        ),
                        child: Text(
                          '${s.upcomingEthiopianHolidays}: ${ethiopianUpcoming.take(3).map((e) => '${e.title} (${e.date.day}/${e.date.month})').join(' · ')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (ethiopianUpcoming.isNotEmpty) const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 840;
                      final monthCard = _monthCard(
                        context,
                        s: s,
                        monthName: monthName,
                        monthEvents: monthEvents,
                        chrome: chrome,
                      );
                      final eventsCard = _eventsCard(
                        context,
                        s: s,
                        selectedDateStr: selectedDateStr,
                        dayEvents: dayEvents,
                      );
                      if (!wide) {
                        return Column(
                          children: [
                            monthCard,
                            const SizedBox(height: 12),
                            Expanded(child: eventsCard),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: monthCard),
                          const SizedBox(width: 16),
                          Expanded(flex: 7, child: eventsCard),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _monthCard(
    BuildContext context, {
    required AppStrings s,
    required String monthName,
    required List<CalendarEvent> monthEvents,
    required Color chrome,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: WebErpTheme.cardDecoration(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final body = Column(
            mainAxisSize: MainAxisSize.min,
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
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
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
            children: List.generate(
              7,
              (i) => Expanded(
                child: Center(
                  child: Text(
                    s.calendarDayHeader(i),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 1.55,
            ),
            itemCount: _daysInMonthGrid().length,
            itemBuilder: (context, index) {
              final day = _daysInMonthGrid()[index];
              final inMonth = day.month == _focusedMonth.month;
              final isSelected = _isSameDay(day, _selectedDay);
              final isToday = _isSameDay(day, DateTime.now());
              final dayEvents =
                  inMonth ? _eventsForDay(day) : const <CalendarEvent>[];
              final hasEvents = dayEvents.isNotEmpty;
              final isHoliday = dayEvents.any((e) => e.isEthiopianHoliday);

              return InkWell(
                onTap: inMonth
                    ? () => setState(() => _selectedDay = day)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? chrome
                        : isHoliday
                            ? Colors.purple.withValues(alpha: 0.16)
                            : isToday
                                ? chrome.withValues(alpha: 0.12)
                                : null,
                    borderRadius: BorderRadius.circular(8),
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
                          fontWeight: isToday ? FontWeight.bold : null,
                        ),
                      ),
                      if (hasEvents)
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : isHoliday
                                    ? Colors.purple
                                    : chrome,
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
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                s.eventsThisMonth(monthEvents.length),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
          );
          if (constraints.maxHeight.isFinite) {
            return SingleChildScrollView(child: body);
          }
          return body;
        },
      ),
    );
  }

  Widget _eventsCard(
    BuildContext context, {
    required AppStrings s,
    required String selectedDateStr,
    required List<CalendarEvent> dayEvents,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Events · $selectedDateStr',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: dayEvents.isEmpty
                ? Center(child: Text(s.noEventsOnDay(selectedDateStr)))
                : ListView.separated(
                    padding: listPagePadding(context).copyWith(
                      left: 0,
                      right: 0,
                      top: 0,
                    ),
                    itemCount: dayEvents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final event = dayEvents[index];
                      final color = _typeColor(event.type);
                      return Material(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.16),
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
                              if (event.autoAnnounce)
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
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
