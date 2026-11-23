import 'package:flutter/foundation.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/conference_models.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/persistence/conference_persistence_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';

/// Homeroom conference pack: slots, child snapshot, notes, home actions.
class ConferenceService extends ChangeNotifier {
  ConferenceService._();
  static final instance = ConferenceService._();

  final List<ConferenceWindow> _windows = [];
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await ConferencePersistenceService.instance.loadIntoService();
  }

  @visibleForTesting
  void resetForTests() {
    _windows.clear();
    _loaded = true;
  }

  String get _schoolId =>
      (AuthService.activeSchoolId ?? '').trim().toUpperCase();

  List<ConferenceWindow> forSchool([String? schoolId]) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    return _windows.where((w) => w.schoolId == sid || sid.isEmpty).toList();
  }

  List<ConferenceWindow> forClass(String className, {String? schoolId}) {
    return forSchool(schoolId)
        .where(
          (w) => StudentRegistryService.classNamesMatch(w.className, className),
        )
        .toList();
  }

  List<ConferenceSlot> slotsForStudent(String studentId, {String? schoolId}) {
    final id = studentId.trim().toUpperCase();
    if (id.isEmpty) return const [];
    return [
      for (final window in forSchool(schoolId))
        for (final slot in window.slots)
          if (slot.studentId.trim().toUpperCase() == id) slot,
    ];
  }

  ConferenceWindow? windowById(String id) {
    for (final window in _windows) {
      if (window.id == id) return window;
    }
    return null;
  }

  Future<ConferenceWindow> createWindow({
    required String className,
    required String heldOn,
    String title = 'Parent–teacher conference',
    String venue = '',
    String startTime = '16:00',
    int slotMinutes = 15,
    int slotCount = 8,
    String? schoolId,
  }) async {
    final access = TeacherAccessService.instance;
    final minutes = slotMinutes < 5 ? 15 : slotMinutes;
    final count = slotCount.clamp(1, 24);
    final parts = startTime.split(':');
    var hour = int.tryParse(parts.first) ?? 16;
    var minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final slots = <ConferenceSlot>[];
    for (var i = 0; i < count; i++) {
      final label =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      slots.add(
        ConferenceSlot(
          id: 'slot-${DateTime.now().microsecondsSinceEpoch}-$i',
          startsAt: label,
        ),
      );
      minute += minutes;
      while (minute >= 60) {
        minute -= 60;
        hour = (hour + 1) % 24;
      }
    }
    final window = ConferenceWindow(
      id: 'cnf-${DateTime.now().millisecondsSinceEpoch}',
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      className: className.trim(),
      teacherId: access.teacherId,
      teacherName: access.teacherName,
      title: title.trim().isEmpty ? 'Parent–teacher conference' : title.trim(),
      heldOn: heldOn.trim(),
      venue: venue.trim(),
      slotMinutes: minutes,
      slots: slots,
    );
    _windows.insert(0, window);
    await _persist();
    SchoolDataService.instance.notifyClassUpdate(
      className: window.className,
      title: 'Conference slots open',
      body:
          '${window.teacherName} opened ${window.title} on ${window.heldOn}. '
          'Book a slot from Conferences.',
      type: NotificationType.calendar,
    );
    return window;
  }

  Future<ConferenceSlot?> bookSlot({
    required String windowId,
    required String slotId,
    required String studentId,
    required String studentName,
    String parentName = '',
  }) async {
    final index = _windows.indexWhere((w) => w.id == windowId);
    if (index < 0) return null;
    final window = _windows[index];
    final next = [...window.slots];
    final slotIndex = next.indexWhere((s) => s.id == slotId);
    if (slotIndex < 0) return null;
    final slot = next[slotIndex];
    if (slot.status != ConferenceSlotStatus.open) return slot;
    final already = next.any(
      (s) =>
          s.studentId.trim().toUpperCase() == studentId.trim().toUpperCase() &&
          s.status != ConferenceSlotStatus.cancelled,
    );
    if (already) return slot;
    next[slotIndex] = slot.copyWith(
      status: ConferenceSlotStatus.booked,
      studentId: studentId.trim().toUpperCase(),
      studentName: studentName.trim(),
      parentName: parentName.trim(),
    );
    _windows[index] = window.copyWith(slots: next);
    await _persist();
    return next[slotIndex];
  }

  Future<ConferenceSlot?> completeSlot({
    required String windowId,
    required String slotId,
    String teacherNotes = '',
    String homeActions = '',
  }) async {
    final index = _windows.indexWhere((w) => w.id == windowId);
    if (index < 0) return null;
    final window = _windows[index];
    final next = [...window.slots];
    final slotIndex = next.indexWhere((s) => s.id == slotId);
    if (slotIndex < 0) return null;
    final slot = next[slotIndex];
    if (slot.status != ConferenceSlotStatus.booked &&
        slot.status != ConferenceSlotStatus.completed) {
      return slot;
    }
    next[slotIndex] = slot.copyWith(
      status: ConferenceSlotStatus.completed,
      teacherNotes: teacherNotes,
      homeActions: homeActions,
      packSummary: packSummaryFor(
        studentId: slot.studentId,
        className: window.className,
      ),
    );
    _windows[index] = window.copyWith(slots: next);
    await _persist();
    if (slot.studentId.isNotEmpty) {
      NotificationService.instance.push(
        title: 'Conference notes ready',
        body:
            '${window.teacherName} closed the sitting for ${slot.studentName}. '
            'See home actions on Conferences.',
        type: NotificationType.calendar,
        fromRole: AuthService.roleTeacher,
        fromName: window.teacherName,
        recipientRole: AuthService.roleParent,
        targetStudentId: slot.studentId,
        targetClassName: window.className,
      );
    }
    return next[slotIndex];
  }

  String packSummaryFor({
    required String studentId,
    required String className,
  }) {
    final data = SchoolDataService.instance;
    var missing = 0;
    var submitted = 0;
    for (final item in data.getHomeworkForClass(className)) {
      switch (item.completionFor(studentId)) {
        case HomeworkCompletion.missing:
        case HomeworkCompletion.late:
          missing++;
        case HomeworkCompletion.submitted:
        case HomeworkCompletion.done:
          submitted++;
        case HomeworkCompletion.notStarted:
          break;
      }
    }
    return [
      if (missing > 0) '$missing homework gap${missing == 1 ? '' : 's'}',
      if (submitted > 0) '$submitted task${submitted == 1 ? '' : 's'} in',
      'Open attendance and grades for the full child pack.',
    ].join(' · ');
  }

  void applyPersistedData(List<ConferenceWindow> windows) {
    _windows
      ..clear()
      ..addAll(windows);
    _loaded = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> snapshotMaps() =>
      _windows.map((w) => w.toMap()).toList();

  Future<void> _persist() async {
    notifyListeners();
    await ConferencePersistenceService.instance.saveFromService();
  }
}
