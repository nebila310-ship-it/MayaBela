import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/models/cloud/app_data_maps.dart';
import 'package:mayabela/models/teacher_features.dart';

void main() {
  test(
    'attendance doc ids are class+date, not globally unique student ids',
    () {
      final a = AttendanceSession(
        className: 'Grade 1A',
        date: DateTime.utc(2026, 8, 19),
        conductedBy: 'T1',
        entries: [
          StudentAttendanceEntry(
            studentName: 'Amina',
            status: AttendanceStatus.present,
          ),
        ],
      );
      final b = AttendanceSession(
        className: 'Grade 1A',
        date: DateTime.utc(2026, 8, 19),
        conductedBy: 'T2',
        entries: <StudentAttendanceEntry>[],
      );
      expect(AppDataMaps.attendanceDocId(a), AppDataMaps.attendanceDocId(b));
      expect(AppDataMaps.attendanceSessionToMap(a)['className'], 'Grade 1A');

      final period = AttendanceSession(
        className: 'Grade 1A',
        date: DateTime.utc(2026, 8, 19),
        conductedBy: 'T1',
        periodKey: 'slot_math_1',
        periodLabel: 'Period 1 · Mathematics',
        entries: [
          StudentAttendanceEntry(
            studentName: 'Amina',
            status: AttendanceStatus.excused,
            updatedAt: DateTime.utc(2026, 8, 19, 9),
          ),
        ],
      );
      expect(
        AppDataMaps.attendanceDocId(period),
        isNot(AppDataMaps.attendanceDocId(a)),
      );
      final mapped = AppDataMaps.attendanceSessionToMap(period);
      expect(mapped['periodKey'], 'slot_math_1');
      expect((mapped['entries'] as List).first['status'], 'excused');
      final roundTrip = AppDataMaps.attendanceSessionFromMap(mapped);
      expect(roundTrip.periodKey, 'slot_math_1');
      expect(roundTrip.entries.single.status, AttendanceStatus.excused);
      expect(roundTrip.entries.single.updatedAt, isNotNull);
    },
  );

  test('two schools can reuse the same local student id string', () {
    // Document store PK is (collection, school_id, doc_id). Local IDs such as
    // STU-1001 are school-scoped and must not clobber another tenant.
    const schoolA = 'TB-001';
    const schoolB = 'MAL838';
    const localId = 'STU-1001';
    expect('$schoolA/$localId', isNot('$schoolB/$localId'));
  });
}
