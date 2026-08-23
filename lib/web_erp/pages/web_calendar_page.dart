import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/widgets/calendar_event_editor.dart';

/// Compact scrollable calendar for the web ERP shell.
class WebCalendarPage extends StatefulWidget {
  const WebCalendarPage({super.key});

  @override
  State<WebCalendarPage> createState() => _WebCalendarPageState();
}

class _WebCalendarPageState extends State<WebCalendarPage> {
  final _data = SchoolDataService.instance;
  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  bool get _canManage => ModuleAccess.canManage('calendar');

  @override
  void initState() {
    super.initState();
    _data.publishDueCalendarAnnouncements();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  List<CalendarEvent> get _visibleEvents {
    return _data.getVisibleCalendarEventsForRole(
      AuthService.roleAdmin,
      includeEthiopian: UserPreferencesService.instance.showEthiopianHolidays,
    );
  }

  List<CalendarEvent> _eventsForDay(DateTime day) {
    return _visibleEvents.where((e) {
      return e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day;
    }).toList();
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
  }

  Widget _upcomingHolidayBanner(AppStrings s) {
    final upcoming = _data
        .getUpcomingEvents(days: 45)
        .where((e) => e.isEthiopianHoliday)
        .take(3)
        .toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final next = upcoming.first;
          setState(() {
            _focusedMonth = DateTime(next.date.year, next.date.month);
            _selectedDay =
                DateTime(next.date.year, next.date.month, next.date.day);
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.purple.shade100),
          ),
          child: Text(
            '${s.upcomingEthiopianHolidays}: ${upcoming.map((e) => '${e.title} (${e.date.day}/${e.date.month})').join(' · ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _scheduleEvent({CalendarEvent? existing}) async {
    final s = AppLocale.instance.strings;
    final draft = await showCalendarEventEditor(
      context: context,
      initialDate: existing?.date ?? _selectedDay,
      audienceOptions: const [
        'All',
        'Parents',
        'Teachers',
        'Students',
        'Staff',
      ],
      defaultAudience: existing?.audience ?? 'All',
      existing: existing,
      showDeviceExport: false,
    );
    if (draft == null || !mounted) return;

    if (existing == null) {
      _data.scheduleCalendarEvent(
        title: draft.title,
        description: draft.description,
        date: draft.date,
        type: draft.type,
        audience: draft.audience,
        autoAnnounce: draft.autoAnnounce,
        time: draft.time,
      );
    } else {
      _data.updateCalendarEvent(
        existing.copyWith(
          title: draft.title,
          description: draft.description,
          date: draft.date,
          type: draft.type,
          audience: draft.audience,
          autoAnnounce: draft.autoAnnounce,
          time: draft.time,
          clearTime: draft.time == null,
        ),
      );
    }
    _data.publishDueCalendarAnnouncements();
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
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final dayEvents = _eventsForDay(_selectedDay);
        final monthName =
            '${s.monthName(_focusedMonth.month)} ${_focusedMonth.year}';

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Calendar', style: WebErpTheme.sectionTitle(context)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _canManage ? () => _scheduleEvent() : null,
                    icon: const Icon(Icons.add),
                    label: Text(s.scheduleEvent),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (UserPreferencesService.instance.showEthiopianHolidays)
                _upcomingHolidayBanner(s),
              if (UserPreferencesService.instance.showEthiopianHolidays)
                const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: WebErpTheme.cardDecoration(context),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                      fontSize: 14,
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
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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
                                  childAspectRatio: 1.65,
                                ),
                                itemCount: _daysInMonthGrid().length,
                                itemBuilder: (context, index) {
                                  final day = _daysInMonthGrid()[index];
                                  final inMonth =
                                      day.month == _focusedMonth.month;
                                  final isSelected =
                                      _isSameDay(day, _selectedDay);
                                  final isToday =
                                      _isSameDay(day, DateTime.now());
                                  final hasEvents =
                                      inMonth && _eventsForDay(day).isNotEmpty;

                                  return InkWell(
                                    onTap: inMonth
                                        ? () =>
                                            setState(() => _selectedDay = day)
                                        : null,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.deepPurple
                                            : isToday
                                                ? Colors.deepPurple
                                                    .withValues(alpha: 0.12)
                                                : null,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                              fontWeight: isToday
                                                  ? FontWeight.bold
                                                  : null,
                                            ),
                                          ),
                                          if (hasEvents)
                                            Container(
                                              width: 4,
                                              height: 4,
                                              margin: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.deepPurple,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: WebErpTheme.cardDecoration(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Events on ${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (dayEvents.isEmpty)
                                Text(
                                  s.noEventsOnDay(
                                    '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
                                  ),
                                )
                              else
                                ...dayEvents.map(
                                  (e) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      e.isEthiopianHoliday
                                          ? Icons.flag
                                          : Icons.event,
                                      size: 20,
                                      color: e.isEthiopianHoliday
                                          ? Colors.purple
                                          : null,
                                    ),
                                    title: Text(
                                      e.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (e.time != null) e.time!,
                                        e.description,
                                      ].join(' · '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: _canManage &&
                                            !e.isEthiopianHoliday
                                        ? PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _scheduleEvent(existing: e);
                                              } else if (value == 'delete') {
                                                _deleteEvent(e);
                                              }
                                            },
                                            itemBuilder: (_) => [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text(s.editEvent),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text(s.delete),
                                              ),
                                            ],
                                          )
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
