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
    final mine = _access.myClasses.map((a) => a.className).toList();
    if (mine.isNotEmpty) return mine;
    if (AuthService.mayReadAllSchoolData ||
        ModuleAccess.canManage('attendance')) {
      return _data.getAllClassNames();
    }
    return mine;
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
    final session = _data.getAttendanceSession(
      selectedClass,
      selectedDate,
      periodKey: selectedPeriodKey,
    );
    final roster = _data.getStudentsForClass(selectedClass);

    if (session != null) {
      entries = session.entries.map((entry) {
        String? id = entry.studentId;
        if (id == null || id.trim().isEmpty) {
          for (final student in roster) {
            if (student.name == entry.studentName) {
              id = student.inviteStudentId;
              break;
            }
          }
        }
        return StudentAttendanceEntry(
          studentName: entry.studentName,
          studentId: id,
          status: entry.status,
          updatedAt: entry.updatedAt,
        );
      }).toList();
      conductedBy = session.conductedBy;
      _locked = session.locked;
      if (session.periodLabel.trim().isNotEmpty) {
        selectedPeriodLabel = session.periodLabel;
      }
    } else {
      entries = roster
          .map(
            (student) => StudentAttendanceEntry(
              studentName: student.name,
              studentId: student.inviteStudentId,
              status: AttendanceStatus.present,
            ),
          )
          .toList();
      conductedBy = null;
      _locked = false;
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

  @override
  void initState() {
    super.initState();
    final options = _classOptions;
    selectedClass =
        widget.initialClass ?? (options.isNotEmpty ? options.first : '');
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
      _loadAttendance();
    }
  }

  void _setStatus(int index, AttendanceStatus status) {
    if (!_canEditRegister) return;
    final entry = entries[index];
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
        conductedBy: AuthService.displayNameForRole(AuthService.roleTeacher),
        entries: entries,
        notifyParents: false,
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
    final conductor = AuthService.displayNameForRole(AuthService.roleTeacher);
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
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.late:
        return Colors.orange;
      case AttendanceStatus.excused:
        return const Color(0xFF1565C0);
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
              : Column(
                  children: [
                    if (!widget.readOnly && _classOptions.isNotEmpty)
                      ClassPickerBar(
                        label: s.className,
                        options: _classOptions,
                        selected: selectedClass,
                        accent: TeacherTheme.primaryDark,
                        onSelected: (value) {
                          selectedClass = value;
                          _loadAttendance();
                        },
                      ),
                    Container(
                      width: double.infinity,
                      padding: listPagePadding(context),
                      child: Column(
                        children: [
                          ListTile(
                            tileColor: Colors.white.withValues(alpha: 0.92),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: TeacherTheme.primaryDark.withValues(
                                  alpha: 0.12,
                                ),
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
                                      value: _periodOptions(s).any(
                                            (item) =>
                                                item.key == selectedPeriodKey,
                                          )
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
                                        _loadAttendance();
                                      },
                                    ),
                                  ),
                              ],
                            ),
                            isThreeLine: !widget.readOnly,
                            trailing: widget.readOnly
                                ? null
                                : TextButton(
                                    onPressed: _pickDate,
                                    child: Text(s.change),
                                  ),
                          ),
                          if (_locked && !widget.readOnly) ...[
                            const SizedBox(height: 8),
                            ListTile(
                              dense: true,
                              tileColor: TeacherTheme.primaryDark.withValues(
                                alpha: 0.08,
                              ),
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
                                Colors.green,
                              ),
                              _summaryChip(s.absent, absentCount, Colors.red),
                              _summaryChip(s.late, lateCount, Colors.orange),
                              _summaryChip(
                                s.excused,
                                excusedCount,
                                const Color(0xFF1565C0),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: listPagePadding(context),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Card(
                            child: ListTile(
                              leading: StudentPhotoAvatar(
                                name: entry.studentName,
                                radius: 20,
                                fallbackColor: _statusColor(entry.status),
                              ),
                              title: Text(entry.studentName),
                              subtitle: Text(
                                _statusLabel(entry.status, s),
                                style: TextStyle(
                                  color: _statusColor(entry.status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: widget.readOnly
                                  ? Icon(
                                      Icons.circle,
                                      color: _statusColor(entry.status),
                                      size: 14,
                                    )
                                  : FittedBox(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _statusButton(
                                            index,
                                            AttendanceStatus.present,
                                            Icons.check,
                                          ),
                                          _statusButton(
                                            index,
                                            AttendanceStatus.late,
                                            Icons.schedule,
                                          ),
                                          _statusButton(
                                            index,
                                            AttendanceStatus.absent,
                                            Icons.close,
                                          ),
                                          _statusButton(
                                            index,
                                            AttendanceStatus.excused,
                                            Icons.event_available,
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: listPagePadding(context),
                      child: Row(
                        children: [
                          if (!widget.readOnly)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _canEditRegister
                                    ? _markAllPresent
                                    : null,
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
                    ),
                  ],
                ),
        );

        if (widget.embedded) {
          return Column(
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

  Widget _statusButton(int index, AttendanceStatus status, IconData icon) {
    final selected = entries[index].status == status;
    return IconButton(
      onPressed: () => _setStatus(index, status),
      icon: Icon(icon),
      color: selected ? _statusColor(status) : Colors.grey,
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
