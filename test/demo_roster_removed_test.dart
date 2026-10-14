import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

void main() {
  test('built-in demo people are recognized and real names are kept', () {
    expect(
      StudentRegistryService.isBuiltInDemoStudent(
        AdminStudentRecord(
          studentId: 'STU-1001',
          fullName: 'Sara Bekele',
          grade: 'Grade 4',
          className: 'Grade 4A',
          schoolId: 'TB-001',
          dateOfBirth: DateTime(2016, 3, 15),
        ),
      ),
      isTrue,
    );
    expect(
      StudentRegistryService.isBuiltInDemoStudent(
        AdminStudentRecord(
          studentId: 'STU-1001',
          fullName: 'Maya Nabil',
          grade: 'Grade 1',
          className: 'Grade 1A',
          schoolId: 'MAJ840',
          dateOfBirth: DateTime(2018, 4, 4),
        ),
      ),
      isFalse,
    );
    expect(
      TeacherRegistryService.isBuiltInDemoTeacher(
        AdminTeacherRecord(
          teacherId: 'TCH-1001',
          fullName: 'Miss Belen',
          assignedClass: 'Grade 4A',
          schoolId: 'TB-001',
        ),
      ),
      isTrue,
    );
    expect(
      TeacherRegistryService.isBuiltInDemoTeacher(
        AdminTeacherRecord(
          teacherId: 'TCH-1001',
          fullName: 'Yared H/micheal',
          assignedClass: 'Grade 1A',
          schoolId: 'MAJ840',
        ),
      ),
      isFalse,
    );
  });
}
