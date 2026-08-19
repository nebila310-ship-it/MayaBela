import 'package:flutter/material.dart';

enum TimetableSlotKind { lesson, breakTime, lunch }

class TimetableSlot {
  const TimetableSlot({
    required this.id,
    required this.kind,
    this.subject,
    this.durationMinutes = 40,
  });

  final String id;
  final TimetableSlotKind kind;
  final String? subject;
  final int durationMinutes;

  TimetableSlot copyWith({
    String? id,
    TimetableSlotKind? kind,
    String? subject,
    int? durationMinutes,
  }) {
    return TimetableSlot(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      subject: subject ?? this.subject,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}

/// Minimal label surface for model display without importing full l10n.
abstract class AppStringsLike {
  String get timetableUntitledLesson;
  String get timetableBreak;
  String get timetableLunch;
}

extension TimetableSlotLabels on TimetableSlot {
  String displayLabel(AppStringsLike s) {
    return switch (kind) {
      TimetableSlotKind.lesson => subject?.trim().isNotEmpty == true
          ? subject!.trim()
          : s.timetableUntitledLesson,
      TimetableSlotKind.breakTime => s.timetableBreak,
      TimetableSlotKind.lunch => s.timetableLunch,
    };
  }
}

class DayTimetable {
  const DayTimetable({
    required this.dayKey,
    required this.slots,
    this.dayStart = const TimeOfDay(hour: 8, minute: 0),
  });

  final String dayKey;
  final List<TimetableSlot> slots;
  final TimeOfDay dayStart;

  DayTimetable copyWith({
    String? dayKey,
    List<TimetableSlot>? slots,
    TimeOfDay? dayStart,
  }) {
    return DayTimetable(
      dayKey: dayKey ?? this.dayKey,
      slots: slots ?? this.slots,
      dayStart: dayStart ?? this.dayStart,
    );
  }
}

class ClassTimetable {
  const ClassTimetable({
    required this.className,
    required this.homeroomTeacherId,
    required this.homeroomTeacherName,
    required this.days,
    required this.updatedAt,
  });

  final String className;
  final String homeroomTeacherId;
  final String homeroomTeacherName;
  final Map<String, DayTimetable> days;
  final DateTime updatedAt;

  DayTimetable day(String dayKey) =>
      days[dayKey] ?? DayTimetable(dayKey: dayKey, slots: const []);

  ClassTimetable copyWith({
    String? className,
    String? homeroomTeacherId,
    String? homeroomTeacherName,
    Map<String, DayTimetable>? days,
    DateTime? updatedAt,
  }) {
    return ClassTimetable(
      className: className ?? this.className,
      homeroomTeacherId: homeroomTeacherId ?? this.homeroomTeacherId,
      homeroomTeacherName: homeroomTeacherName ?? this.homeroomTeacherName,
      days: days ?? this.days,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Local draft copy for homeroom editing without mutating the published version.
  ClassTimetable duplicate() {
    return copyWith(
      days: {
        for (final entry in days.entries)
          entry.key: entry.value.copyWith(slots: [...entry.value.slots]),
      },
    );
  }
}

const kTimetableWeekdayKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
];

TimeOfDay addMinutesToTime(TimeOfDay time, int minutes) {
  final total = time.hour * 60 + time.minute + minutes;
  return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
}

String formatTimeOfDay(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}

TimeOfDay slotStartTime(DayTimetable day, int slotIndex) {
  var current = day.dayStart;
  for (var i = 0; i < slotIndex; i++) {
    current = addMinutesToTime(current, day.slots[i].durationMinutes);
  }
  return current;
}

/// Period number among lesson slots only (1 = first class, 2 = second class, …).
int? lessonPeriodAt(List<TimetableSlot> slots, int index) {
  if (index < 0 || index >= slots.length) return null;
  if (slots[index].kind != TimetableSlotKind.lesson) return null;
  var period = 0;
  for (var i = 0; i <= index; i++) {
    if (slots[i].kind == TimetableSlotKind.lesson) period++;
  }
  return period;
}
