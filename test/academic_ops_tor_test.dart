import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/academic_term.dart';
import 'package:mayabela/models/class_timetable.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/services/timetable_conflict_service.dart';
import 'package:mayabela/services/timetable_service.dart';
import 'package:mayabela/widgets/school_grade_level_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('grades map onto KG, Primary, Middle, and High School', () {
    expect(SchoolGradeCatalog.levelForGrade('UKG'), SchoolLevel.kindergarten);
    expect(
      SchoolGradeCatalog.levelForGrade('Kindergarten A'),
      SchoolLevel.kindergarten,
    );
    expect(SchoolGradeCatalog.levelForGrade('Grade 3'), SchoolLevel.primary);
    expect(SchoolGradeCatalog.levelForGrade('7'), SchoolLevel.middle);
    expect(
      SchoolGradeCatalog.levelForGrade('Grade 10'),
      SchoolLevel.highSchool,
    );
    final grouped = SchoolGradeCatalog.group([
      'UKG',
      'Grade 2',
      'Grade 8',
      'Grade 11',
    ]);
    expect(grouped[SchoolLevel.kindergarten], ['UKG']);
    expect(grouped[SchoolLevel.primary], ['Grade 2']);
    expect(grouped[SchoolLevel.middle], ['Grade 8']);
    expect(grouped[SchoolLevel.highSchool], ['Grade 11']);
  });

  test('academic terms persist on the school record', () {
    final term = AcademicTerm(
      id: 'term-1',
      name: 'Term 1',
      startDate: DateTime(2026, 9, 8),
      endDate: DateTime(2026, 12, 20),
      examStart: DateTime(2026, 12, 8),
      examEnd: DateTime(2026, 12, 18),
    );
    expect(term.contains(DateTime(2026, 10, 1)), isTrue);
    expect(term.contains(DateTime(2027, 1, 5)), isFalse);

    final school = SchoolRecord(
      id: 'AC-001',
      name: 'Academic Test School',
      academicTerms: [term],
    );
    final restored = SchoolRecord.fromJson(school.toJson());
    expect(restored.academicTerms, hasLength(1));
    expect(restored.academicTerms.first.name, 'Term 1');
    expect(restored.academicTerms.first.hasExamWindow, isTrue);
  });

  test(
    'timetable generation fills subjects from allocations and flags clashes',
    () {
      TeacherRegistryService.instance.applyPersistedTeachers([
        AdminTeacherRecord(
          teacherId: 'TCH-ACAD-1',
          fullName: 'Math Teacher',
          subject: 'Mathematics',
          assignedClass: 'Grade 4A',
          schoolId: 'AC-001',
          classAssignments: const [
            TeacherClassAssignment(
              className: 'Grade 4A',
              role: TeacherStaffRole.subjectTeacher,
              teachingSlots: [
                SubjectTeachingSlot(
                  slotId: 'STA-MATH',
                  subjectId: 'MATH',
                  subjectName: 'Mathematics',
                ),
              ],
            ),
            TeacherClassAssignment(
              className: 'Grade 4B',
              role: TeacherStaffRole.subjectTeacher,
              teachingSlots: [
                SubjectTeachingSlot(
                  slotId: 'STA-MATH-B',
                  subjectId: 'MATH',
                  subjectName: 'Mathematics',
                ),
              ],
            ),
          ],
        ),
      ]);

      final first = TimetableService.instance.generateFromAllocations(
        'Grade 4A',
      );
      final second = TimetableService.instance.generateFromAllocations(
        'Grade 4B',
      );
      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(
        first!
            .day('monday')
            .slots
            .any(
              (slot) =>
                  slot.kind == TimetableSlotKind.lesson &&
                  slot.subject == 'Mathematics' &&
                  slot.teacherId == 'TCH-ACAD-1',
            ),
        isTrue,
      );

      final conflicts = TimetableConflictService.detect([first, second!]);
      expect(conflicts, isNotEmpty);
      expect(conflicts.first.teacherId, 'TCH-ACAD-1');
      expect({
        conflicts.first.classA,
        conflicts.first.classB,
      }, containsAll(['Grade 4A', 'Grade 4B']));
    },
  );

  test('no conflict when the same teacher teaches at different times', () {
    const monday = DayTimetable(
      dayKey: 'monday',
      dayStart: TimeOfDay(hour: 8, minute: 0),
      slots: [
        TimetableSlot(
          id: 'a',
          kind: TimetableSlotKind.lesson,
          subject: 'Math',
          teacherId: 'T1',
          teacherName: 'One',
          durationMinutes: 40,
        ),
      ],
    );
    const laterMonday = DayTimetable(
      dayKey: 'monday',
      dayStart: TimeOfDay(hour: 10, minute: 0),
      slots: [
        TimetableSlot(
          id: 'b',
          kind: TimetableSlotKind.lesson,
          subject: 'Science',
          teacherId: 'T1',
          teacherName: 'One',
          durationMinutes: 40,
        ),
      ],
    );
    final conflicts = TimetableConflictService.detect([
      ClassTimetable(
        className: 'A',
        homeroomTeacherId: '',
        homeroomTeacherName: '',
        days: const {'monday': monday},
        updatedAt: DateTime(2026, 1, 1),
      ),
      ClassTimetable(
        className: 'B',
        homeroomTeacherId: '',
        homeroomTeacherName: '',
        days: const {'monday': laterMonday},
        updatedAt: DateTime(2026, 1, 1),
      ),
    ]);
    expect(conflicts, isEmpty);
  });
}
