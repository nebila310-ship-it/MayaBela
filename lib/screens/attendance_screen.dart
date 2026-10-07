import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/class_timetable.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/cloud_save_honesty.dart';
import 'package:mayabela/services/persistence/school_content_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/services/timetable_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/theme/classroom_palette.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/widgets/class_picker_bar.dart';
import 'package:mayabela/widgets/student_photo_avatar.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    this.readOnly = false,
    this.childName,
    this.initialClass,
    this.embedded = false,
  });

  static const registerPageSize = 10;

  final bool readOnly;
  final String? childName;
  final String? initialClass;
  final bool embedded;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _data = SchoolDataService.instance;
  final _access = TeacherAccessService.instance;

  late String selectedClass;
  DateTime selectedDate = DateTime.now();
  String selectedPeriodKey = '';
  String selectedPeriodLabel = '';
  List<StudentAttendanceEntry> entries = [];
  String? conductedBy;
  bool _showHistory = false;
  bool _locked = false;
  var _page = 0;

  int _pageIndex(int length) {
    if (length <= 0) return 0;
    final maxPage = (length - 1) ~/ AttendanceScreen.registerPageSize;
    return _page.clamp(0, maxPage);
  }

  List<StudentAttendanceEntry> _pageSlice(List<StudentAttendanceEntry> items) {
    if (items.isEmpty) return items;
    final start = _pageIndex(items.length) * AttendanceScreen.registerPageSize;
    final end = (start + AttendanceScreen.registerPageSize).clamp(
      0,
      items.length,
    );
    return items.sublist(start, end);
  }

  String _entryKey(StudentAttendanceEntry entry) {
    final id = entry.studentId?.trim();
    if (id != null && id.isNotEmpty) return id;
    return entry.studentName.trim();
  }

  List<String> get _classOptions {
    if (widget.readOnly) {
      final children = _data.getChildren();
      if (children.isNotEmpty) {
        return children.map((c) => c.className).toSet().toList();
      }
      if (widget.initialClass != null &&
          widget.initialClass!.trim().isNotEmpty) {
        return [widget.initialClass!];
      }
      return const [];
    }
    if (AuthService.mayReadAllSchoolData ||
        ModuleAccess.canManage('attendance')) {
      return _data.getAllClassNames();
    }
    return _access.myClasses.map((a) => a.className).toList();
  }

  bool get _canMarkSelectedClass {
    if (widget.readOnly || selectedClass.trim().isEmpty) return false;
    return _data.canWriteAttendanceRegister(selectedClass);
  }

  bool get _canEditRegister =>
      _canMarkSelectedClass &&
      (!_locked || _data.canUnlockAttendanceRegister());

  List<({String key, String label})> _periodOptions(AppStrings s) {
    final options = <({String key, String label})>[
      (key: '', label: s.dailyRegister),
    ];
    if (selectedClass.trim().isEmpty) return options;
    final weekday = selectedDate.weekday;
    if (weekday < DateTime.monday || weekday > DateTime.friday) {
      return options;
    }
    final dayKey = kTimetableWeekdayKeys[weekday - DateTime.monday];
    final timetable = TimetableService.instance.getOrCreateForClass(
      selectedClass,
    );
    final day = timetable.day(dayKey);
    for (var i = 0; i < day.slots.length; i++) {
      final period = lessonPeriodAt(day.slots, i);
      if (period == null) continue;
      final slot = day.slots[i];
      final subject = slot.subject?.trim().isNotEmpty == true
          ? slot.subject!.trim()
          : s.timetableUntitledLesson;
      options.add((key: slot.id, label: s.periodLessonLabel(period, subject)));
    }
    return options;
  }

  void _syncPeriodSelection(AppStrings s) {
    final options = _periodOptions(s);
    final match = options.where((item) => item.key == selectedPeriodKey);
    if (match.isEmpty) {
      selectedPeriodKey = '';
      selectedPeriodLabel = s.dailyRegister;
      return;
    }
    selectedPeriodLabel = match.first.label;
  }

  void _loadAttendance() {
    final s = AppLocale.instance.strings;
    _syncPeriodSelection(s);
    final view = _data.attendanceRegisterView(
      className: selectedClass,
      date: selectedDate,
      periodKey: selectedPeriodKey,
    );
    entries = view.entries;
    conductedBy = view.conductedBy;
    _locked = view.locked;
    if (view.periodLabel.trim().isNotEmpty) {
      selectedPeriodLabel = view.periodLabel;
    }
    _data.overlayApprovedLeaveOnEntries(
      entries: entries,
      className: selectedClass,
      date: selectedDate,
      periodKey: selectedPeriodKey,
    );

    if (widget.readOnly && widget.childName != null) {
      final child = _data.getChildByName(widget.childName!);
      entries = entries
          .where(
            (entry) => entry.matches(
              studentId: child?.studentId,
              studentName: widget.childName,
            ),
          )
          .toList();
    }

    setState(() {});
  }

  String _preferredClass(List<String> options) {
    if (options.isEmpty) return '';
    for (final name in options) {
      if (_data.getStudentsForClass(name).isNotEmpty) return name;
    }
    return options.first;
  }

  @override
  void initState() {
    super.initState();
    final options = _classOptions;
    final initial = widget.initialClass?.trim();
    selectedClass = (initial != null && initial.isNotEmpty)
        ? initial
        : _preferredClass(options);
    _loadAttendance();
  }

  int get presentCount =>
      entries.where((entry) => entry.status == AttendanceStatus.present).length;

  int get absentCount =>
      entries.where((entry) => entry.status == AttendanceStatus.absent).length;

  int get lateCount =>
      entries.where((entry) => entry.status == AttendanceStatus.late).length;

  int get excusedCount =>
      entries.where((entry) => entry.status == AttendanceStatus.excused).length;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      selectedDate = picked;
      _page = 0;
      _loadAttendance();
    }
  }

  void _setStatus(StudentAttendanceEntry entry, AttendanceStatus status) {
    if (!_canEditRegister) return;
    if (entry.status == status) return;
    setState(() {
      entry.status = status;
      entry.updatedAt = DateTime.now();
    });
  }

  void _markAllPresent() {
    if (!_canEditRegister) return;
    final now = DateTime.now();
    setState(() {
      for (final entry in entries) {
        if (entry.status == AttendanceStatus.present) continue;
        entry.status = AttendanceStatus.present;
        entry.updatedAt = now;
      }
    });
  }

  Widget _lockButton(AppStrings s) {
    final canToggle = _locked
        ? _data.canUnlockAttendanceRegister()
        : _canMarkSelectedClass;
    return IconButton(
      icon: Icon(_locked ? Icons.lock : Icons.lock_open_outlined),
      tooltip: _locked ? s.unlockAttendanceRegister : s.lockAttendanceRegister,
      onPressed: canToggle ? _toggleLock : null,
    );
  }

  Future<void> _toggleLock() async {
    if (selectedClass.trim().isEmpty) return;
    final s = AppLocale.instance.strings;
    if (!_locked &&
        _data.getAttendanceSession(
              selectedClass,
              selectedDate,
              periodKey: selectedPeriodKey,
            ) ==
            null) {
      final saved = _data.saveAttendanceSession(
        className: selectedClass,
        date: selectedDate,
        conductedBy: AuthService.currentPersonName(),
        entries: entries,
        periodKey: selectedPeriodKey,
        periodLabel: selectedPeriodLabel,
      );
      if (!saved) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.attendanceSaveDenied)));
        return;
      }
    }
    final ok = _locked
        ? _data.unlockAttendanceSession(
            className: selectedClass,
            date: selectedDate,
            periodKey: selectedPeriodKey,
          )
        : _data.lockAttendanceSession(
            className: selectedClass,
            date: selectedDate,
            periodKey: selectedPeriodKey,
          );
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.attendanceSaveDenied)));
      return;
    }
    _loadAttendance();
  }

  Future<void> _saveAttendance() async {
    if (!_canEditRegister) return;
    final s = AppLocale.instance.strings;
    final conductor = AuthService.currentPersonName();
    final saved = _data.saveAttendanceSession(
      className: selectedClass,
      date: selectedDate,
      conductedBy: conductor,
      entries: entries,
      periodKey: selectedPeriodKey,
      periodLabel: selectedPeriodLabel,
    );
    if (!saved) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.attendanceSaveDenied)));
      return;
    }
    conductedBy = conductor;
    final outcome = await CloudSaveHonesty.settle(
      persist: SchoolContentPersistenceService.instance.saveFromService(),
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      CloudSaveHonesty.snackBar(
        savedOk: s.attendanceSavedFor(selectedClass, conductor),
        outcome: outcome,
        strings: s,
      ),
    );
  }

  Color _statusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return ClassroomPalette.green;
      case AttendanceStatus.absent:
        return ClassroomPalette.red;
      case AttendanceStatus.late:
        return ClassroomPalette.orange;
      case AttendanceStatus.excused:
        return ClassroomPalette.blue;
    }
  }

  String _statusLabel(AttendanceStatus status, AppStrings s) {
    switch (status) {
      case AttendanceStatus.present:
        return s.present;
      case AttendanceStatus.absent:
        return s.absent;
      case AttendanceStatus.late:
        return s.late;
      case AttendanceStatus.excused:
        return s.excused;
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = _data.getAttendanceHistory(selectedClass, dailyOnly: false);

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final title = widget.readOnly
            ? s.childAttendanceTitle(widget.childName ?? s.parentLabel)
            : s.takeAttendance;

        final body = WarmScreenBody(
          accentColor: TeacherTheme.primaryDark,
          child: _showHistory && !widget.readOnly
              ? _HistoryView(history: history, className: selectedClass)
              : selectedClass.trim().isEmpty
              ? Center(child: Text(s.noClassesAssigned))
              : _register(s),
        );

        if (widget.embedded) {
          return SizedBox.expand(
            child: Column(
              children: [
                if (!widget.readOnly)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        _lockButton(s),
                        IconButton(
                          icon: Icon(_showHistory ? Icons.edit : Icons.history),
                          onPressed: () =>
                              setState(() => _showHistory = !_showHistory),
                          tooltip: _showHistory
                              ? s.takeAttendanceTooltip
                              : s.viewHistoryTooltip,
                        ),
                      ],
                    ),
                  ),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: TeacherTheme.primaryDark,
            title: Text(title),
            actions: [
              if (!widget.readOnly) _lockButton(s),
              if (!widget.readOnly)
                IconButton(
                  icon: Icon(_showHistory ? Icons.edit : Icons.history),
                  onPressed: () => setState(() => _showHistory = !_showHistory),
                  tooltip: _showHistory
                      ? s.takeAttendanceTooltip
                      : s.viewHistoryTooltip,
                ),
            ],
          ),
          body: body,
        );
      },
    );
  }

  Widget _register(AppStrings s) {
    final pageRows = _pageSlice(entries);
    return SingleChildScrollView(
      key: const ValueKey('attendance-register'),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.readOnly && _classOptions.isNotEmpty)
            ClassPickerBar(
              label: s.className,
              options: _classOptions,
              selected: selectedClass,
              accent: TeacherTheme.primaryDark,
              onSelected: (value) {
                selectedClass = value;
                _page = 0;
                _loadAttendance();
              },
            ),
          Padding(
            padding: listPagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  tileColor: Colors.white.withValues(alpha: 0.92),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: TeacherTheme.primaryDark.withValues(alpha: 0.12),
                    ),
                  ),
                  leading: const Icon(
                    Icons.calendar_today,
                    color: TeacherTheme.primaryDark,
                  ),
                  title: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conductedBy != null
                            ? s.conductedByName(conductedBy!)
                            : s.selectedDate,
                      ),
                      if (!widget.readOnly)
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isDense: true,
                            isExpanded: true,
                            value:
                                _periodOptions(
                                  s,
                                ).any((item) => item.key == selectedPeriodKey)
                                ? selectedPeriodKey
                                : '',
                            items: [
                              for (final option in _periodOptions(s))
                                DropdownMenuItem(
                                  value: option.key,
                                  child: Text(option.label),
                                ),
                            ],
                            onChanged: (value) {
                              selectedPeriodKey = value ?? '';
                              _page = 0;
                              _loadAttendance();
                            },
                          ),
                        ),
                    ],
                  ),
                  isThreeLine: !widget.readOnly,
                  trailing: widget.readOnly
                      ? null
                      : TextButton(onPressed: _pickDate, child: Text(s.change)),
                ),
                if (_locked && !widget.readOnly) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    dense: true,
                    tileColor: TeacherTheme.primaryDark.withValues(alpha: 0.08),
                    leading: const Icon(Icons.lock_outline),
                    title: Text(s.attendanceRegisterLocked),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _summaryChip(
                      s.present,
                      presentCount,
                      ClassroomPalette.green,
                    ),
                    _summaryChip(s.absent, absentCount, ClassroomPalette.red),
                    _summaryChip(s.late, lateCount, ClassroomPalette.orange),
                    _summaryChip(
                      s.excused,
                      excusedCount,
                      ClassroomPalette.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'No students on this class register.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  )
                else ...[
                  for (final entry in pageRows) ...[
                    _studentBar(entry, s),
                    const SizedBox(height: 8),
                  ],
                  _pager(total: entries.length),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!widget.readOnly)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _canEditRegister ? _markAllPresent : null,
                          child: Text(s.markAllPresent),
                        ),
                      ),
                    if (!widget.readOnly) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.readOnly
                            ? () => Navigator.pop(context)
                            : (_canEditRegister ? _saveAttendance : null),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TeacherTheme.primaryDark,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          widget.readOnly ? s.close : s.saveAttendance,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentBar(StudentAttendanceEntry entry, AppStrings s) {
    final color = _statusColor(entry.status);
    final key = _entryKey(entry);
    return Material(
      key: ValueKey('attendance-student-$key'),
      color: color,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        child: Row(
          children: [
            StudentPhotoAvatar(
              studentId: entry.studentId,
              name: entry.studentName,
              radius: 20,
              fallbackColor: Colors.white70,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    _statusLabel(entry.status, s),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.readOnly)
              const Icon(Icons.circle, color: Colors.white, size: 12)
            else
              FittedBox(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _statusButton(
                      entry,
                      AttendanceStatus.present,
                      Icons.check,
                      s,
                    ),
                    _statusButton(
                      entry,
                      AttendanceStatus.late,
                      Icons.schedule,
                      s,
                    ),
                    _statusButton(
                      entry,
                      AttendanceStatus.absent,
                      Icons.close,
                      s,
                    ),
                    _statusButton(
                      entry,
                      AttendanceStatus.excused,
                      Icons.event_available,
                      s,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pager({required int total}) {
    if (total <= AttendanceScreen.registerPageSize) {
      return const SizedBox.shrink();
    }
    final page = _pageIndex(total);
    final size = AttendanceScreen.registerPageSize;
    final start = page * size + 1;
    final end = ((page + 1) * size).clamp(0, total);
    final lastPage = (total - 1) ~/ size;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$start–$end of $total students',
            key: const ValueKey('attendance-page-label'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          TextButton(
            key: const ValueKey('attendance-page-prev'),
            onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
            child: const Text('Previous'),
          ),
          TextButton(
            key: const ValueKey('attendance-page-next'),
            onPressed: page < lastPage
                ? () => setState(() => _page = page + 1)
                : null,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          '$count',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      label: Text(label),
    );
  }

  Widget _statusButton(
    StudentAttendanceEntry entry,
    AttendanceStatus status,
    IconData icon,
    AppStrings s,
  ) {
    final selected = entry.status == status;
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: _statusLabel(status, s),
      onPressed: () => _setStatus(entry, status),
      icon: Icon(icon, size: 22),
      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.55),
      style: IconButton.styleFrom(
        backgroundColor: selected ? Colors.black26 : null,
      ),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.history, required this.className});

  final List<AttendanceSession> history;
  final String className;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        if (history.isEmpty) {
          return Center(child: Text(s.noAttendanceHistory(className)));
        }

        return ListView.separated(
          padding: listPagePadding(context),
          itemCount: history.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final session = history[index];
            final present = session.entries
                .where((entry) => entry.status == AttendanceStatus.present)
                .length;
            final absent = session.entries
                .where((entry) => entry.status == AttendanceStatus.absent)
                .length;
            final late = session.entries
                .where((entry) => entry.status == AttendanceStatus.late)
                .length;
            final excused = session.entries
                .where((entry) => entry.status == AttendanceStatus.excused)
                .length;
            final period = session.isDaily
                ? s.dailyRegister
                : (session.periodLabel.trim().isNotEmpty
                      ? session.periodLabel
                      : session.periodKey);

            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.check_circle)),
                title: Text(
                  '${session.date.day}/${session.date.month}/${session.date.year}'
                  ' · $period',
                ),
                subtitle: Text(
                  '${s.historyConductedBy(session.conductedBy)}\n'
                  '${s.historyPresentLateAbsent(present, late, absent, excused)}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}
