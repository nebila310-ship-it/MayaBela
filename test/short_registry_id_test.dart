import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/utils/short_registry_id.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('formats and parses four-digit ids only', () {
    expect(ShortRegistryId.format('stu', 7), 'STU-0007');
    expect(ShortRegistryId.parseNumber('STU-0007'), 7);
    expect(ShortRegistryId.parseNumber('TCH-1739901234567'), isNull);
    expect(ShortRegistryId.clampCounter(1739901234567), 1);
    expect(ShortRegistryId.clampCounter(12), 12);
  });

  test('allocate skips timestamp leftovers and stays at 4 digits', () {
    final taken = <String>{'STU-1001', 'STU-1739901234567'};
    final next = ShortRegistryId.allocate(
      prefix: 'STU',
      existingIds: taken,
      isTaken: taken.contains,
      persistedNext: 1739901234567,
    );
    expect(next, 'STU-1002');
    expect(next, matches(RegExp(r'^[A-Z]{1,4}-\d{4}$')));
  });

  test('new student and staff ids are PREFIX-####', () {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'Four Digit Student',
      grade: 'Grade 1',
      className: 'Grade 1A',
      dateOfBirth: DateTime(2018, 1, 1),
    );
    expect(student.studentId, matches(RegExp(r'^STU-\d{4}$')));

    final qa = TeacherRegistryService.instance.addTeacher(
      schoolId: 'TB-001',
      fullName: 'Four Digit QA',
      email: '',
      phone: '0911222333',
      subjects: const [],
      assignedClass: '',
      roles: const [],
      loginUsername: 'four.digit.qa',
      staffRoles: const [StaffRoles.qualityAssurance],
    );
    expect(qa.teacherId, matches(RegExp(r'^QA-\d{4}$')));
    expect(qa.teacherId.length, 7);

    StudentRegistryService.instance.removeStudent(student.studentId);
    TeacherRegistryService.instance.removeTeacher(qa.teacherId);
  });
}
