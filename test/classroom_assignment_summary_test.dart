import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/widgets/staff_role_labels.dart';
import 'package:mayabela/widgets/teacher_class_assignment_editor.dart';

void main() {
  test('classroom summary shows HR/ST with subjects', () {
    final teacher = AdminTeacherRecord(
      teacherId: 'TCH-TEST-1',
      fullName: 'Test Teacher',
      subject: 'Mathematics',
      assignedClass: 'Grade 2C',
      schoolId: 'TB-001',
      classAssignments: const [
        TeacherClassAssignment(
          className: 'Grade 2C',
          role: TeacherStaffRole.homeroomTeacher,
          teachingSlots: [
            SubjectTeachingSlot(
              slotId: 'STA-1',
              subjectId: 'MATH',
              subjectName: 'Mathematics',
            ),
          ],
        ),
      ],
      roles: const [TeacherStaffRole.homeroomTeacher],
      subjects: const ['Mathematics'],
    );

    final summary = classroomAssignmentSummary(
      teacher,
      AppLocale.instance.strings,
    );
    expect(summary, contains('Grade 2C'));
    expect(summary, contains('HR'));
    expect(summary, contains('Homeroom Teacher'));
    expect(summary, contains('Mathematics'));
  });

  test('buildTeacherClassAssignments keeps subjects for homeroom', () {
    final entry = TeacherClassAssignmentEntry()
      ..selectedGrade = 'Grade 2'
      ..roleType = TeacherStaffRole.homeroomTeacher
      ..selectedSubjects = const ['Mathematics', 'English'];
    entry.section.text = 'C';

    final built = buildTeacherClassAssignments([entry]);
    expect(built, hasLength(1));
    expect(built.first.role, TeacherStaffRole.homeroomTeacher);
    expect(built.first.subjectNames, containsAll(['Mathematics', 'English']));
    entry.dispose();
  });
}
