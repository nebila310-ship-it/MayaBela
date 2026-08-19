import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Campus management: add / rename (with cascade) / delete guards.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';
  final registry = SchoolRegistryService.instance;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await registry.load();
  });

  test('demo school starts with seeded campuses', () {
    final campuses = registry.campusesForSchool(schoolId);
    expect(campuses, contains('Main Campus'));
    expect(campuses.length, greaterThanOrEqualTo(1));
  });

  test('addCampus adds and rejects duplicates (case-insensitive)', () async {
    expect(await registry.addCampus(schoolId, 'East Campus'), isTrue);
    expect(
      registry.campusesForSchool(schoolId),
      contains('East Campus'),
    );
    expect(await registry.addCampus(schoolId, 'east campus'), isFalse);
    expect(await registry.addCampus(schoolId, '   '), isFalse);
  });

  test('new student can be enrolled onto a campus', () {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: schoolId,
      fullName: 'Campus Test Student',
      grade: 'Grade 1',
      className: 'Grade 1A',
      dateOfBirth: DateTime(2018, 1, 1),
      campus: 'East Campus',
    );
    expect(student.campus, 'East Campus');
  });

  test('removeCampus refuses while students are assigned', () async {
    expect(await registry.removeCampus(schoolId, 'East Campus'), isFalse);
    expect(registry.campusesForSchool(schoolId), contains('East Campus'));
  });

  test('renameCampus cascades to student and teacher records', () async {
    final teacher = TeacherRegistryService.instance.addTeacher(
      schoolId: schoolId,
      fullName: 'Campus Test Teacher',
      email: '',
      phone: '0911000099',
      assignedClass: 'Grade 1A',
      roles: const [],
      loginUsername: 'campus_test_teacher',
      campus: 'East Campus',
    );

    expect(
      await registry.renameCampus(schoolId, from: 'East Campus', to: 'North Campus'),
      isTrue,
    );

    final campuses = registry.campusesForSchool(schoolId);
    expect(campuses, contains('North Campus'));
    expect(campuses, isNot(contains('East Campus')));

    final student = StudentRegistryService.instance
        .studentsForSchool(schoolId)
        .firstWhere((s) => s.fullName == 'Campus Test Student');
    expect(student.campus, 'North Campus');

    final updatedTeacher =
        TeacherRegistryService.instance.lookupById(teacher.teacherId);
    expect(updatedTeacher?.campus, 'North Campus');
  });

  test('renameCampus rejects collisions and unknown campuses', () async {
    expect(
      await registry.renameCampus(schoolId, from: 'North Campus', to: 'main campus'),
      isFalse,
    );
    expect(
      await registry.renameCampus(schoolId, from: 'No Such Campus', to: 'X'),
      isFalse,
    );
  });

  test('removeCampus works once the campus is empty', () async {
    final studentRegistry = StudentRegistryService.instance;
    final teacherRegistry = TeacherRegistryService.instance;

    final student = studentRegistry
        .studentsForSchool(schoolId)
        .firstWhere((s) => s.fullName == 'Campus Test Student');
    studentRegistry.transferStudentCampus(
      studentId: student.studentId,
      toCampus: 'Main Campus',
    );
    final teacher = teacherRegistry
        .teachersForSchool(schoolId)
        .firstWhere((t) => t.fullName == 'Campus Test Teacher');
    teacherRegistry.transferTeacherCampus(
      teacherId: teacher.teacherId,
      toCampus: 'Main Campus',
    );

    expect(await registry.removeCampus(schoolId, 'North Campus'), isTrue);
    expect(
      registry.campusesForSchool(schoolId),
      isNot(contains('North Campus')),
    );
  });

  test('the last campus can never be deleted', () async {
    var campuses = registry.campusesForSchool(schoolId).toList();
    for (final campus in campuses) {
      await registry.removeCampus(schoolId, campus);
    }
    campuses = registry.campusesForSchool(schoolId).toList();
    expect(campuses.length, greaterThanOrEqualTo(1));
    expect(await registry.removeCampus(schoolId, campuses.single), isFalse);
  });
}
