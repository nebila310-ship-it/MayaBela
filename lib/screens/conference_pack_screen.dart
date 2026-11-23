import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/conference_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/conference_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/class_picker_bar.dart';

enum ConferencePackMode { teacher, parent }

/// Homeroom conference pack: slots, child snapshot, notes, home actions.
class ConferencePackScreen extends StatefulWidget {
  const ConferencePackScreen({
    super.key,
    this.mode = ConferencePackMode.teacher,
  });

  final ConferencePackMode mode;

  @override
  State<ConferencePackScreen> createState() => _ConferencePackScreenState();
}

class _ConferencePackScreenState extends State<ConferencePackScreen> {
  final _service = ConferenceService.instance;
  final _access = TeacherAccessService.instance;
  String? _selectedClass;

  bool get _isParent => widget.mode == ConferencePackMode.parent;

  List<String> get _classOptions {
    if (_isParent) {
      return SchoolDataService.instance
          .getChildren()
          .map((c) => c.className.trim())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    }
    return _access.myClasses
        .where((a) => a.isHomeroom)
        .map((a) => a.className)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _service.ensureLoaded();
    if (_classOptions.isNotEmpty) {
      _selectedClass = _classOptions.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6A1B9A);
    return ListenableBuilder(
      listenable: Listenable.merge([_service, AppLocale.instance]),
      builder: (context, _) {
        final className = _selectedClass;
        final windows = className == null
            ? const <ConferenceWindow>[]
            : _service.forClass(className);
        return Scaffold(
          backgroundColor: const Color(0xFFF3E5F5),
          appBar: AppBar(
            backgroundColor: accent,
            title: Text(
              AppLocale.instance.strings.dashboardTitle('conferences'),
            ),
          ),
          floatingActionButton: _isParent || className == null
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: accent,
                  onPressed: () => _createWindow(className),
                  icon: const Icon(Icons.event_available),
                  label: const Text('Open slots'),
                ),
          body: Column(
            children: [
              if (_classOptions.isNotEmpty)
                ClassPickerBar(
                  label: AppLocale.instance.strings.className,
                  options: _classOptions,
                  selected: _selectedClass,
                  accent: accent,
                  onSelected: (value) => setState(() => _selectedClass = value),
                )
              else
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No homeroom class is linked yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              if (_classOptions.isNotEmpty)
                Expanded(
                  child: windows.isEmpty
                      ? const Center(
                          child: Text('No conference windows yet.'),
                        )
                      : ListView.separated(
                          padding: listPagePadding(context),
                          itemCount: windows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _WindowCard(
                            window: windows[index],
                            isParent: _isParent,
                            accent: accent,
                            onBook: _bookSlot,
                            onComplete: _completeSlot,
                          ),
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createWindow(String className) async {
    final title = TextEditingController(text: 'Parent–teacher conference');
    final heldOn = TextEditingController(
      text: DateTime.now().toIso8601String().split('T').first,
    );
    final venue = TextEditingController(text: 'Homeroom');
    final start = TextEditingController(text: '16:00');
    final minutes = TextEditingController(text: '15');
    final count = TextEditingController(text: '8');
    final saved = await showAdminFormDialog(
      context: context,
      title: 'Open conference slots',
      subtitle: className,
      accent: TeacherTheme.primaryDark,
      icon: Icons.event_available,
      saveLabel: 'Open',
      builder: (context, _) => Column(
        children: [
          adminDialogField(
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
          ),
          adminDialogField(
            TextField(
              controller: heldOn,
              decoration: const InputDecoration(
                labelText: 'Date',
                hintText: 'YYYY-MM-DD',
              ),
            ),
          ),
          adminDialogField(
            TextField(
              controller: venue,
              decoration: const InputDecoration(labelText: 'Venue'),
            ),
          ),
          adminDialogField(
            TextField(
              controller: start,
              decoration: const InputDecoration(
                labelText: 'First slot',
                hintText: '16:00',
              ),
            ),
          ),
          adminDialogField(
            TextField(
              controller: minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minutes per slot'),
            ),
          ),
          adminDialogField(
            TextField(
              controller: count,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Number of slots'),
            ),
          ),
        ],
      ),
    );
    final titleText = title.text;
    final heldText = heldOn.text;
    final venueText = venue.text;
    final startText = start.text;
    final minutesText = minutes.text;
    final countText = count.text;
    title.dispose();
    heldOn.dispose();
    venue.dispose();
    start.dispose();
    minutes.dispose();
    count.dispose();
    if (!saved) return;
    await _service.createWindow(
      className: className,
      title: titleText,
      heldOn: heldText,
      venue: venueText,
      startTime: startText,
      slotMinutes: int.tryParse(minutesText.trim()) ?? 15,
      slotCount: int.tryParse(countText.trim()) ?? 8,
    );
  }

  Future<void> _bookSlot(ConferenceWindow window, ConferenceSlot slot) async {
    final children = SchoolDataService.instance.getChildren();
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No linked child to book for.')),
      );
      return;
    }
    final child = children.firstWhere(
      (c) => StudentRegistryService.classNamesMatch(
        c.className,
        window.className,
      ),
      orElse: () => children.first,
    );
    final booked = await _service.bookSlot(
      windowId: window.id,
      slotId: slot.id,
      studentId: (child.studentId ?? child.name).trim().toUpperCase(),
      studentName: child.name,
      parentName: AuthService.currentUser?.fullName ?? 'Parent',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          booked?.status == ConferenceSlotStatus.booked
              ? 'Booked ${slot.startsAt} for ${child.name}.'
              : 'That slot is no longer open.',
        ),
      ),
    );
  }

  Future<void> _completeSlot(
    ConferenceWindow window,
    ConferenceSlot slot,
  ) async {
    final notes = TextEditingController(text: slot.teacherNotes);
    final home = TextEditingController(text: slot.homeActions);
    final saved = await showAdminFormDialog(
      context: context,
      title: 'Close sitting',
      subtitle: slot.studentName.isEmpty ? slot.startsAt : slot.studentName,
      accent: TeacherTheme.primaryDark,
      icon: Icons.edit_note,
      saveLabel: 'Save notes',
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _service.packSummaryFor(
              studentId: slot.studentId,
              className: window.className,
            ),
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 12),
          adminDialogField(
            TextField(
              controller: notes,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Teacher notes'),
            ),
          ),
          adminDialogField(
            TextField(
              controller: home,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Home actions'),
            ),
          ),
        ],
      ),
    );
    final notesText = notes.text;
    final homeText = home.text;
    notes.dispose();
    home.dispose();
    if (!saved) return;
    await _service.completeSlot(
      windowId: window.id,
      slotId: slot.id,
      teacherNotes: notesText,
      homeActions: homeText,
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({
    required this.window,
    required this.isParent,
    required this.accent,
    required this.onBook,
    required this.onComplete,
  });

  final ConferenceWindow window;
  final bool isParent;
  final Color accent;
  final Future<void> Function(ConferenceWindow, ConferenceSlot) onBook;
  final Future<void> Function(ConferenceWindow, ConferenceSlot) onComplete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              window.title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                window.heldOn,
                if (window.venue.isNotEmpty) window.venue,
                '${window.openCount} open · ${window.bookedCount} booked',
                window.teacherName,
              ].join(' · '),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            for (final slot in window.slots)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${slot.startsAt} · ${ConferenceSlot.statusLabel(slot.status)}'),
                subtitle: Text(
                  [
                    if (slot.studentName.isNotEmpty) slot.studentName,
                    if (slot.packSummary.isNotEmpty) slot.packSummary,
                    if (slot.homeActions.isNotEmpty)
                      'Home: ${slot.homeActions}',
                    if (isParent && slot.teacherNotes.isNotEmpty)
                      slot.teacherNotes,
                  ].join('\n'),
                ),
                trailing: _trailing(slot),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _trailing(ConferenceSlot slot) {
    if (isParent && slot.status == ConferenceSlotStatus.open) {
      return TextButton(
        onPressed: () => onBook(window, slot),
        child: const Text('Book'),
      );
    }
    if (!isParent &&
        (slot.status == ConferenceSlotStatus.booked ||
            slot.status == ConferenceSlotStatus.completed)) {
      return TextButton(
        onPressed: () => onComplete(window, slot),
        child: Text(
          slot.status == ConferenceSlotStatus.completed ? 'Notes' : 'Close',
        ),
      );
    }
    return null;
  }
}
