import 'dart:async';

import 'package:mayabela/models/class_timetable.dart';
import 'package:mayabela/services/persistence/timetable_persistence_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// In-memory class timetables — homeroom teachers edit, others read.
class TimetableService {
  TimetableService._();

  static final instance = TimetableService._();

  int _nextSlotId = 100;
  final Map<String, ClassTimetable> _byClass = {};

  String _newSlotId() => 'slot_${_nextSlotId++}';

  List<TimetableSlot> _defaultDaySlots() {
    return [
      TimetableSlot(id: _newSlotId(), kind: TimetableSlotKind.lesson, subject: 'Mathematics'),
      TimetableSlot(id: _newSlotId(), kind: TimetableSlotKind.breakTime, durationMinutes: 10),
      TimetableSlot(id: _newSlotId(), kind: TimetableSlotKind.lesson, subject: 'English'),
      TimetableSlot(id: _newSlotId(), kind: TimetableSlotKind.breakTime, durationMinutes: 10),
      TimetableSlot(id: _newSlotId(), kind: TimetableSlotKind.lesson, subject: 'Science'),
      TimetableSlot(id: _newSlotId(), kind: TimetableSlotKind.lunch, durationMinutes: 45),
      TimetableSlot(id: _newSlotId(), kind: TimetableSlotKind.lesson, subject: 'Amharic'),
      TimetableSlot(id: _newSlotId(), kind: TimetableSlotKind.breakTime, durationMinutes: 10),
      TimetableSlot(id: _newSlotId(), kind: TimetableSlotKind.lesson, subject: 'Physical Education'),
    ];
  }

  Map<String, DayTimetable> _defaultWeek() {
    return {
      for (final day in kTimetableWeekdayKeys)
        day: DayTimetable(dayKey: day, slots: _defaultDaySlots()),
    };
  }

  ClassTimetable defaultForClass({
    required String className,
    required String homeroomTeacherId,
    required String homeroomTeacherName,
  }) {
    return ClassTimetable(
      className: className,
      homeroomTeacherId: homeroomTeacherId,
      homeroomTeacherName: homeroomTeacherName,
      days: _defaultWeek(),
      updatedAt: DateTime.now(),
    );
  }

  ClassTimetable? getTimetable(String className) {
    final direct = _byClass[className];
    if (direct != null) return direct;
    for (final entry in _byClass.entries) {
      if (StudentRegistryService.classNamesMatch(entry.key, className)) {
        return entry.value;
      }
    }
    return null;
  }

  void applyPersistedTimetables(List<ClassTimetable> timetables) {
    for (final timetable in timetables) {
      if (timetable.className.trim().isEmpty) continue;
      _byClass[timetable.className] = _withResolvedHomeroom(timetable);
    }
  }

  void cacheTimetable(ClassTimetable timetable) {
    _byClass[timetable.className] = timetable;
  }

  List<ClassTimetable> allPersistedTimetables() => List.unmodifiable(_byClass.values);

  ClassTimetable getOrCreateForClass(String className) {
    final existing = getTimetable(className);
    if (existing != null) return _withResolvedHomeroom(existing);

    final homeroom = _resolveHomeroomForClass(className);
    final created = defaultForClass(
      className: className,
      homeroomTeacherId: homeroom?.teacherId ?? '',
      homeroomTeacherName: homeroom?.fullName ?? 'Homeroom teacher',
    );
    _byClass[className] = created;
    return created;
  }

  ClassTimetable _withResolvedHomeroom(ClassTimetable timetable) {
    final homeroom = _resolveHomeroomForClass(timetable.className);
    if (homeroom == null) return timetable;
    if (timetable.homeroomTeacherId == homeroom.teacherId &&
        timetable.homeroomTeacherName == homeroom.fullName) {
      return timetable;
    }
    return timetable.copyWith(
      homeroomTeacherId: homeroom.teacherId,
      homeroomTeacherName: homeroom.fullName,
    );
  }

  AdminTeacherRecord? _resolveHomeroomForClass(String className) {
    final linkedId =
        SchoolDataService.instance.homeroomTeacherIdForClass(className);
    if (linkedId != null && linkedId.trim().isNotEmpty) {
      final teacher = TeacherRegistryService.instance.lookupById(linkedId);
      if (teacher != null) return teacher;
    }

    for (final teacher in TeacherRegistryService.instance.getAllTeachers()) {
      if (TeacherRegistryService.instance
          .homeroomClassesFor(teacher.teacherId)
          .any(
            (name) => StudentRegistryService.classNamesMatch(name, className),
          )) {
        return teacher;
      }
    }
    return null;
  }

  void saveTimetable(ClassTimetable timetable) {
    var toSave = timetable;
    final access = TeacherAccessService.instance;
    if (access.isHomeroomFor(timetable.className)) {
      toSave = timetable.copyWith(
        homeroomTeacherId: access.teacherId,
        homeroomTeacherName: access.teacherName,
      );
    }
    _byClass[timetable.className] =
        toSave.copyWith(updatedAt: DateTime.now());
    unawaited(TimetablePersistenceService.instance.saveFromService());
  }

  List<ClassTimetable> allTimetables() {
    final names = SchoolDataService.instance.getAllClassNames();
    return names.map(getOrCreateForClass).toList()
      ..sort((a, b) => a.className.compareTo(b.className));
  }

  List<String> parentClassNames() {
    return SchoolDataService.instance
        .getChildren()
        .map((child) => child.className)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> studentClassNames() => parentClassNames();

  bool canEdit(String className) =>
      TeacherAccessService.instance.isHomeroomFor(className);

  List<String> editableClassNames() =>
      TeacherAccessService.instance.homeroomClassNames;

  List<String> readableClassNamesForTeacher() =>
      TeacherAccessService.instance.myClasses.map((a) => a.className).toList();
}
