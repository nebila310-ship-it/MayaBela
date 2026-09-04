import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/cloud_save_honesty.dart';
import 'package:mayabela/services/persistence/school_content_persistence_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/widgets/class_picker_bar.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    this.readOnly = false,
    this.childName,
    this.initialClass,
  });

  final bool readOnly;
  final String? childName;
  final String? initialClass;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _data = SchoolDataService.instance;
  final _access = TeacherAccessService.instance;

  late String selectedClass;
  DateTime selectedDate = DateTime.now();
  List<StudentAttendanceEntry> entries = [];
  String? conductedBy;
  bool _showHistory = false;

  List<String> get _classOptions {
    if (widget.readOnly) {
      final children = _data.getChildren();
      if (children.isNotEmpty) {
        return children.map((c) => c.className).toSet().toList();
      }
      if (widget.initialClass != null) return [widget.initialClass!];
      return ['Grade 4A'];
    }
    return _access.myClasses.map((a) => a.className).toList();
  }

  void _loadAttendance() {
    final session = _data.getAttendanceSession(selectedClass, selectedDate);
    final roster = _data.getStudentsForClass(selectedClass);

    if (session != null) {
      entries = session.entries
          .map(
            (entry) => StudentAttendanceEntry(
              studentName: entry.studentName,
              status: entry.status,
            ),
          )
          .toList();
      conductedBy = session.conductedBy;
    } else {
      entries = roster
          .map(
            (student) => StudentAttendanceEntry(
              studentName: student.name,
              status: AttendanceStatus.present,
            ),
          )
          .toList();
      conductedBy = null;
    }

    if (widget.readOnly && widget.childName != null) {
      entries = entries
          .where((entry) => entry.studentName == widget.childName)
          .toList();
    }

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final options = _classOptions;
    selectedClass = widget.initialClass ??
        (options.isNotEmpty ? options.first : 'Grade 4A');
    _loadAttendance();
  }

  int get presentCount =>
      entries.where((entry) => entry.status == AttendanceStatus.present).length;

  int get absentCount =>
      entries.where((entry) => entry.status == AttendanceStatus.absent).length;

  int get lateCount =>
      entries.where((entry) => entry.status == AttendanceStatus.late).length;

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
    setState(() => entries[index].status = status);
  }

  void _markAllPresent() {
    setState(() {
      for (final entry in entries) {
        entry.status = AttendanceStatus.present;
      }
    });
  }

  Future<void> _saveAttendance() async {
    final s = AppLocale.instance.strings;
    final conductor = AuthService.displayNameForRole(AuthService.roleTeacher);
    _data.saveAttendanceSession(
      className: selectedClass,
      date: selectedDate,
      conductedBy: conductor,
      entries: entries,
    );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = _data.getAttendanceHistory(selectedClass);

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final title = widget.readOnly
            ? s.childAttendanceTitle(widget.childName ?? s.parentLabel)
            : s.takeAttendance;

        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: TeacherTheme.primaryDark,
            title: Text(title),
            actions: [
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
          body: WarmScreenBody(
            accentColor: TeacherTheme.primaryDark,
            child: _showHistory && !widget.readOnly
                ? _HistoryView(
                    history: history,
                    className: selectedClass,
                  )
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
                            subtitle: conductedBy != null
                                ? Text(s.conductedByName(conductedBy!))
                                : Text(s.selectedDate),
                            trailing: widget.readOnly
                                ? null
                                : TextButton(
                                    onPressed: _pickDate,
                                    child: Text(s.change),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _summaryChip(s.present, presentCount, Colors.green),
                              _summaryChip(s.absent, absentCount, Colors.red),
                              _summaryChip(s.late, lateCount, Colors.orange),
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
                              leading: CircleAvatar(
                                backgroundColor: _statusColor(entry.status)
                                    .withValues(alpha: 0.2),
                                child: Text('${index + 1}'),
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
                                  : Row(
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
                                      ],
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
                                onPressed: _markAllPresent,
                                child: Text(s.markAllPresent),
                              ),
                            ),
                          if (!widget.readOnly) const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: widget.readOnly
                                  ? () => Navigator.pop(context)
                                  : _saveAttendance,
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
          ),
        );
      },
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12)),
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
  const _HistoryView({
    required this.history,
    required this.className,
  });

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

            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.check_circle),
                ),
                title: Text(
                  '${session.date.day}/${session.date.month}/${session.date.year}',
                ),
                subtitle: Text(
                  '${s.historyConductedBy(session.conductedBy)}\n'
                  '${s.historyPresentLateAbsent(present, late, absent)}',
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
