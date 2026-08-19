import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/class_timetable.dart';
import 'package:mayabela/services/timetable_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/widgets/class_picker_bar.dart';

enum TimetableViewMode { teacher, parent, student, adminDetail }

class ClassTimetableScreen extends StatefulWidget {
  const ClassTimetableScreen({
    super.key,
    this.mode = TimetableViewMode.teacher,
    this.initialClass,
    this.readOnly = false,
  });

  final TimetableViewMode mode;
  final String? initialClass;
  final bool readOnly;

  @override
  State<ClassTimetableScreen> createState() => _ClassTimetableScreenState();
}

class _ClassTimetableScreenState extends State<ClassTimetableScreen>
    with SingleTickerProviderStateMixin {
  final _service = TimetableService.instance;
  late TabController _tabController;
  String? _selectedClass;
  ClassTimetable? _timetable;
  int _slotCounter = 1000;
  int _visibleDayIndex = 0;
  bool _hasUnsavedChanges = false;
  DateTime? _lastPublishedAt;

  List<String> get _classOptions {
    return switch (widget.mode) {
      TimetableViewMode.parent => _service.parentClassNames(),
      TimetableViewMode.student => _service.studentClassNames(),
      TimetableViewMode.adminDetail => widget.initialClass != null
          ? [widget.initialClass!]
          : const [],
      TimetableViewMode.teacher => _service.readableClassNamesForTeacher(),
    };
  }

  bool get _canEdit {
    if (widget.readOnly) return false;
    final className = _selectedClass;
    if (className == null) return false;
    return _service.canEdit(className);
  }

  String _newSlotId() => 'slot_${_slotCounter++}';

  @override
  void initState() {
    super.initState();
    SchoolContentSyncService.instance.addListener(_onCloudTimetableChanged);
    _tabController = TabController(length: kTimetableWeekdayKeys.length, vsync: this);
    final options = _classOptions;
    if (options.isNotEmpty) {
      _selectedClass = widget.initialClass ?? options.first;
      _loadTimetable();
    }
  }

  @override
  void dispose() {
    SchoolContentSyncService.instance.removeListener(_onCloudTimetableChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onCloudTimetableChanged() {
    if (!mounted) return;
    if (_hasUnsavedChanges && _canEdit) return;
    _loadTimetable();
  }

  void _loadTimetable() {
    final className = _selectedClass;
    if (className == null) return;
    final published = _service.getOrCreateForClass(className);
    _lastPublishedAt = published.updatedAt;
    _timetable = _canEdit ? published.duplicate() : published;
    _hasUnsavedChanges = false;
    setState(() {});
  }

  String _formatUpdatedAt(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day}/${date.month}/${date.year} · '
        '$hour:${date.minute.toString().padLeft(2, '0')} $suffix';
  }

  Future<bool> _confirmDiscardChanges() async {
    final s = AppLocale.instance.strings;
    return showAdminConfirmDialog(
          context: context,
          title: s.timetableDiscardChangesTitle,
          message: s.timetableDiscardChangesMessage,
          accent: TeacherTheme.primaryDark,
          icon: Icons.warning_amber_rounded,
          confirmLabel: s.timetableDiscardConfirm,
          destructive: true,
        );
  }

  Future<bool> _onAttemptLeave() async {
    if (!_hasUnsavedChanges || !_canEdit) return true;
    return _confirmDiscardChanges();
  }

  Future<void> _selectClass(String value) async {
    if (value == _selectedClass) return;
    if (!await _onAttemptLeave()) return;
    _selectedClass = value;
    _loadTimetable();
  }

  void _saveChanges() {
    final timetable = _timetable;
    final className = _selectedClass;
    if (timetable == null || className == null || !_canEdit || !_hasUnsavedChanges) {
      return;
    }
    _service.saveTimetable(timetable);
    final published = _service.getOrCreateForClass(className);
    setState(() {
      _timetable = published.duplicate();
      _lastPublishedAt = published.updatedAt;
      _hasUnsavedChanges = false;
    });
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocale.instance.strings.timetableSaved;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  DayTimetable _currentDay() {
    final key = kTimetableWeekdayKeys[_visibleDayIndex];
    return _timetable!.day(key);
  }

  void _onDayTabSelected(int index) {
    if (_visibleDayIndex == index) return;
    setState(() => _visibleDayIndex = index);
  }

  void _updateDay(DayTimetable day) {
    final timetable = _timetable!;
    setState(() {
      _timetable = timetable.copyWith(
        days: {...timetable.days, day.dayKey: day},
      );
      if (_canEdit) _hasUnsavedChanges = true;
    });
  }

  String _dayLabel(String key, AppStrings s) {
    return switch (key) {
      'monday' => s.timetableMonday,
      'tuesday' => s.timetableTuesday,
      'wednesday' => s.timetableWednesday,
      'thursday' => s.timetableThursday,
      'friday' => s.timetableFriday,
      _ => key,
    };
  }

  Color _slotColor(TimetableSlotKind kind) {
    return switch (kind) {
      TimetableSlotKind.lesson => const Color(0xFF5D4037),
      TimetableSlotKind.breakTime => const Color(0xFF78909C),
      TimetableSlotKind.lunch => const Color(0xFFEF6C00),
    };
  }

  IconData _slotIcon(TimetableSlotKind kind) {
    return switch (kind) {
      TimetableSlotKind.lesson => Icons.menu_book_outlined,
      TimetableSlotKind.breakTime => Icons.free_breakfast_outlined,
      TimetableSlotKind.lunch => Icons.restaurant_outlined,
    };
  }

  void _moveSlot({
    required DayTimetable day,
    required List<TimetableSlot> slots,
    required int index,
    required int delta,
  }) {
    final target = index + delta;
    if (target < 0 || target >= slots.length) return;
    final next = [...slots];
    final item = next.removeAt(index);
    next.insert(target, item);
    _updateDay(day.copyWith(slots: next));
  }

  Future<void> _editSlot({
    required TimetableSlot slot,
    required void Function(TimetableSlot updated) onApply,
  }) async {
    final s = AppLocale.instance.strings;
    final subjectController = TextEditingController(text: slot.subject ?? '');
    final durationController =
        TextEditingController(text: '${slot.durationMinutes}');
    var kind = slot.kind;

    final saved = await showAdminFormDialog(
      context: context,
      title: s.timetableEditSlot,
      subtitle: _selectedClass,
      accent: _slotColor(kind),
      icon: _slotIcon(kind),
      saveLabel: s.save,
      builder: (context, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          adminDialogField(
            DropdownButtonFormField<TimetableSlotKind>(
              key: ValueKey(kind),
              initialValue: kind,
              decoration: InputDecoration(labelText: s.timetableSlotType),
              items: [
                DropdownMenuItem(
                  value: TimetableSlotKind.lesson,
                  child: Text(s.timetableSlotLesson),
                ),
                DropdownMenuItem(
                  value: TimetableSlotKind.breakTime,
                  child: Text(s.timetableBreak),
                ),
                DropdownMenuItem(
                  value: TimetableSlotKind.lunch,
                  child: Text(s.timetableLunch),
                ),
              ],
              onChanged: (value) {
                if (value != null) setDialogState(() => kind = value);
              },
            ),
          ),
          if (kind == TimetableSlotKind.lesson)
            adminDialogField(
              TextField(
                controller: subjectController,
                decoration: InputDecoration(labelText: s.subject),
              ),
            ),
          adminDialogField(
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: s.timetableDurationMinutes),
            ),
          ),
        ],
      ),
      canSave: (_) {
        final minutes = int.tryParse(durationController.text.trim());
        return minutes != null && minutes >= 1;
      },
    );

    if (saved) {
      final minutes = int.parse(durationController.text.trim());
      final updated = slot.copyWith(
        kind: kind,
        subject: kind == TimetableSlotKind.lesson
            ? subjectController.text.trim()
            : null,
        durationMinutes: minutes,
      );
      subjectController.dispose();
      durationController.dispose();
      if (mounted) {
        onApply(updated);
      }
      return;
    }
    subjectController.dispose();
    durationController.dispose();
  }

  Future<void> _addSlot() async {
    final newSlot = TimetableSlot(id: _newSlotId(), kind: TimetableSlotKind.lesson);
    await _editSlot(
      slot: newSlot,
      onApply: (updated) {
        final day = _currentDay();
        _updateDay(day.copyWith(slots: [...day.slots, updated]));
      },
    );
  }

  Future<void> _editDayStart() async {
    final s = AppLocale.instance.strings;
    final day = _currentDay();
    var start = day.dayStart;

    final saved = await showAdminFormDialog(
      context: context,
      title: s.timetableDayStart,
      subtitle: _dayLabel(day.dayKey, s),
      accent: TeacherTheme.primaryDark,
      icon: Icons.schedule_outlined,
      saveLabel: s.save,
      builder: (context, setDialogState) => adminDialogField(
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(formatTimeOfDay(start)),
          trailing: const Icon(Icons.access_time),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: start,
            );
            if (picked != null) setDialogState(() => start = picked);
          },
        ),
      ),
    );

    if (saved) {
      _updateDay(day.copyWith(dayStart: start));
    }
  }

  Widget _slotTile({
    required TimetableSlot slot,
    required int index,
    required DayTimetable day,
    required List<TimetableSlot> slots,
    required AppStrings s,
  }) {
    final start = slotStartTime(day, index);
    final end = addMinutesToTime(start, slot.durationMinutes);
    final color = _slotColor(slot.kind);
    final period = lessonPeriodAt(slots, index);

    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: color.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (period != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(
                s.timetableClassPeriod(period),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(_slotIcon(slot.kind), color: color, size: 20),
            ),
            title: Text(
              slot.displayLabel(s),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${formatTimeOfDay(start)} – ${formatTimeOfDay(end)} · ${s.timetableMinutes(slot.durationMinutes)}',
            ),
            trailing: _canEdit
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index > 0)
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 20),
                          tooltip: s.timetableMoveUp,
                          onPressed: () => _moveSlot(
                            day: day,
                            slots: slots,
                            index: index,
                            delta: -1,
                          ),
                        ),
                      if (index < slots.length - 1)
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 20),
                          tooltip: s.timetableMoveDown,
                          onPressed: () => _moveSlot(
                            day: day,
                            slots: slots,
                            index: index,
                            delta: 1,
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _editSlot(
                          slot: slot,
                          onApply: (updated) {
                            final next = [...slots];
                            next[index] = updated;
                            _updateDay(day.copyWith(slots: next));
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 20, color: Colors.red.shade400),
                        onPressed: () {
                          final next = [...slots]..removeAt(index);
                          _updateDay(day.copyWith(slots: next));
                        },
                      ),
                    ],
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDayView(String dayKey) {
    final s = AppLocale.instance.strings;
    final timetable = _timetable;
    if (timetable == null) {
      return Center(child: Text(s.timetableNoClass));
    }

    final day = timetable.day(dayKey);
    final slots = day.slots;

    if (slots.isEmpty) {
      return Center(
        child: Text(
          s.timetableEmptyDay,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    final bottomPad = _canEdit ? (_hasUnsavedChanges ? 160.0 : 88.0) : 16.0;

    return ListView.separated(
      padding: listPagePadding(context).copyWith(bottom: bottomPad),
      itemCount: slots.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _slotTile(
        slot: slots[index],
        index: index,
        day: day,
        slots: slots,
        s: s,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final accent = TeacherTheme.primaryDark;
    final timetable = _timetable;
    final showClassPicker =
        widget.mode != TimetableViewMode.adminDetail && _classOptions.length > 1;

    return PopScope(
      canPop: !_hasUnsavedChanges || !_canEdit,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscardChanges() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFCFDBEA),
      appBar: AppBar(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        title: Text(s.timetableTitle),
        actions: [
          if (_canEdit && _hasUnsavedChanges)
            TextButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(
                s.timetableSaveChanges,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.schedule_outlined),
              tooltip: s.timetableDayStart,
              onPressed: _editDayStart,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          onTap: _onDayTabSelected,
          tabs: [
            for (final key in kTimetableWeekdayKeys)
              Tab(text: _dayLabel(key, s)),
          ],
        ),
      ),
      floatingActionButton: _canEdit
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_hasUnsavedChanges)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FloatingActionButton.extended(
                      heroTag: 'timetable_save',
                      onPressed: _saveChanges,
                      backgroundColor: const Color(0xFF2E7D32),
                      icon: const Icon(Icons.publish_outlined),
                      label: Text(s.timetableSaveChanges),
                    ),
                  ),
                FloatingActionButton.extended(
                  heroTag: 'timetable_add',
                  onPressed: _addSlot,
                  backgroundColor: accent,
                  icon: const Icon(Icons.add),
                  label: Text(s.timetableAddSlot),
                ),
              ],
            )
          : null,
      body: WarmScreenBody(
        accentColor: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showClassPicker)
              ClassPickerBar(
                label: s.className,
                options: _classOptions,
                selected: _selectedClass,
                accent: accent,
                onSelected: _selectClass,
              ),
            if (timetable != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_canEdit && _hasUnsavedChanges)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_note,
                                  color: Colors.orange.shade800,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s.timetableUnsavedChanges,
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Card(
                      elevation: 0,
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: accent.withValues(alpha: 0.15)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              timetable.className,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.timetableHomeroomBy(timetable.homeroomTeacherName),
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                            if (_lastPublishedAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                s.timetableLastUpdated(
                                  _formatUpdatedAt(_lastPublishedAt!),
                                ),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (_canEdit && !_hasUnsavedChanges)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  s.timetableSaveHint,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            if (!_canEdit)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  s.timetableReadOnlyHint,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _buildDayView(
                kTimetableWeekdayKeys[_visibleDayIndex],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

/// Admin hub listing every homeroom class timetable.
class AdminTimetablesScreen extends StatelessWidget {
  const AdminTimetablesScreen({super.key});

  static String _formatUpdatedAt(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day}/${date.month}/${date.year} · '
        '$hour:${date.minute.toString().padLeft(2, '0')} $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SchoolContentSyncService.instance,
      builder: (context, _) => _AdminTimetablesBody(
        formatUpdatedAt: _formatUpdatedAt,
      ),
    );
  }
}

class _AdminTimetablesBody extends StatelessWidget {
  const _AdminTimetablesBody({required this.formatUpdatedAt});

  final String Function(DateTime date) formatUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final timetables = TimetableService.instance.allTimetables();
    const accent = Color(0xFF4527A0);

    return Scaffold(
      backgroundColor: const Color(0xFFCFDBEA),
      appBar: AppBar(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        title: Text(s.timetableAdminTitle),
      ),
      body: WarmScreenBody(
        accentColor: accent,
        child: timetables.isEmpty
            ? Center(child: Text(s.timetableNoClass))
            : ListView.separated(
                padding: listPagePadding(context),
                itemCount: timetables.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = timetables[index];
                  return Card(
                    elevation: 0,
                    color: Colors.white.withValues(alpha: 0.95),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: accent.withValues(alpha: 0.12)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: accent.withValues(alpha: 0.12),
                        child: Icon(Icons.calendar_view_week, color: accent),
                      ),
                      title: Text(
                        item.className,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.timetableHomeroomBy(item.homeroomTeacherName)),
                          Text(
                            s.timetableLastUpdated(formatUpdatedAt(item.updatedAt)),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClassTimetableScreen(
                            mode: TimetableViewMode.adminDetail,
                            initialClass: item.className,
                            readOnly: true,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
