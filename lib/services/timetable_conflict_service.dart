import 'package:flutter/material.dart';

import 'package:mayabela/models/class_timetable.dart';

class TimetableConflict {
  const TimetableConflict({
    required this.teacherId,
    required this.teacherName,
    required this.dayKey,
    required this.classA,
    required this.classB,
    required this.subjectA,
    required this.subjectB,
    required this.startMinutes,
    required this.durationMinutes,
  });

  final String teacherId;
  final String teacherName;
  final String dayKey;
  final String classA;
  final String classB;
  final String subjectA;
  final String subjectB;
  final int startMinutes;
  final int durationMinutes;

  String get dayLabel => dayKey.isEmpty
      ? dayKey
      : '${dayKey[0].toUpperCase()}${dayKey.substring(1)}';

  String get timeLabel {
    final start = TimeOfDay(
      hour: startMinutes ~/ 60,
      minute: startMinutes % 60,
    );
    final endTotal = startMinutes + durationMinutes;
    final end = TimeOfDay(hour: (endTotal ~/ 60) % 24, minute: endTotal % 60);
    return '${formatTimeOfDay(start)}–${formatTimeOfDay(end)}';
  }
}

/// Teacher double-booking across class timetables.
abstract final class TimetableConflictService {
  static List<TimetableConflict> detect(Iterable<ClassTimetable> tables) {
    final bookings = <_Booking>[];
    for (final table in tables) {
      for (final dayKey in kTimetableWeekdayKeys) {
        final day = table.day(dayKey);
        for (var i = 0; i < day.slots.length; i++) {
          final slot = day.slots[i];
          if (slot.kind != TimetableSlotKind.lesson) continue;
          final teacherKey = slot.teacherId?.trim().isNotEmpty == true
              ? slot.teacherId!.trim().toUpperCase()
              : (slot.teacherName?.trim().isNotEmpty == true
                    ? slot.teacherName!.trim().toLowerCase()
                    : '');
          if (teacherKey.isEmpty) continue;
          final start = slotStartTime(day, i);
          bookings.add(
            _Booking(
              teacherKey: teacherKey,
              teacherName: (slot.teacherName ?? slot.teacherId ?? '').trim(),
              teacherId: slot.teacherId?.trim() ?? '',
              dayKey: dayKey,
              className: table.className,
              subject: slot.subject?.trim().isNotEmpty == true
                  ? slot.subject!.trim()
                  : 'Lesson',
              startMinutes: start.hour * 60 + start.minute,
              durationMinutes: slot.durationMinutes,
            ),
          );
        }
      }
    }

    final conflicts = <TimetableConflict>[];
    for (var i = 0; i < bookings.length; i++) {
      for (var j = i + 1; j < bookings.length; j++) {
        final a = bookings[i];
        final b = bookings[j];
        if (a.teacherKey != b.teacherKey || a.dayKey != b.dayKey) continue;
        if (a.className == b.className && a.startMinutes == b.startMinutes) {
          continue;
        }
        if (!_overlaps(a, b)) continue;
        conflicts.add(
          TimetableConflict(
            teacherId: a.teacherId.isNotEmpty ? a.teacherId : a.teacherKey,
            teacherName: a.teacherName,
            dayKey: a.dayKey,
            classA: a.className,
            classB: b.className,
            subjectA: a.subject,
            subjectB: b.subject,
            startMinutes: a.startMinutes < b.startMinutes
                ? a.startMinutes
                : b.startMinutes,
            durationMinutes: a.durationMinutes,
          ),
        );
      }
    }
    return conflicts;
  }

  static bool _overlaps(_Booking a, _Booking b) {
    return a.startMinutes < b.startMinutes + b.durationMinutes &&
        b.startMinutes < a.startMinutes + a.durationMinutes;
  }
}

class _Booking {
  const _Booking({
    required this.teacherKey,
    required this.teacherName,
    required this.teacherId,
    required this.dayKey,
    required this.className,
    required this.subject,
    required this.startMinutes,
    required this.durationMinutes,
  });

  final String teacherKey;
  final String teacherName;
  final String teacherId;
  final String dayKey;
  final String className;
  final String subject;
  final int startMinutes;
  final int durationMinutes;
}
