import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void signIn(String schoolId) {
    AuthService.currentUser = RegisteredUser(
      username: 'admin.$schoolId',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
      fullName: 'Admin $schoolId',
    );
  }

  AdminStudentRecord student({
    required String id,
    required String schoolId,
    required String name,
    String className = 'Grade 4A',
  }) {
    return AdminStudentRecord(
      studentId: id,
      fullName: name,
      grade: 'Grade 4',
      className: className,
      schoolId: schoolId,
      dateOfBirth: DateTime(2016, 1, 1),
    );
  }

  AdminTeacherRecord teacher({
    required String id,
    required String schoolId,
    required String name,
  }) {
    return AdminTeacherRecord(
      teacherId: id,
      fullName: name,
      assignedClass: 'Grade 4A',
      schoolId: schoolId,
      phone: '0911$id',
      loginUsername: 'teacher.$schoolId',
      classAssignments: const [
        TeacherClassAssignment(
          className: 'Grade 4A',
          role: TeacherStaffRole.homeroomTeacher,
        ),
      ],
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    AuthService.sessionSchoolId = null;
  });

  tearDown(() {
    AuthService.currentUser = null;
    AuthService.sessionSchoolId = null;
  });

  test('same student name and class stay on their own school', () {
    StudentRegistryService.instance.applyPersistedStudents([
      student(id: 'STU-ISO-A', schoolId: 'SCH-A', name: 'Abebe Lemma'),
      student(id: 'STU-ISO-B', schoolId: 'SCH-B', name: 'Abebe Lemma'),
    ]);

    signIn('SCH-A');
    expect(
      StudentRegistryService.instance.lookupByName('Abebe Lemma')?.studentId,
      'STU-ISO-A',
    );
    expect(
      StudentRegistryService.instance
          .studentsForClass('Grade 4A')
          .map((s) => s.studentId),
      contains('STU-ISO-A'),
    );
    expect(
      StudentRegistryService.instance
          .studentsForClass('Grade 4A')
          .map((s) => s.studentId),
      isNot(contains('STU-ISO-B')),
    );
    expect(
      StudentRegistryService.instance
          .visibleStudents()
          .map((s) => s.studentId),
      isNot(contains('STU-ISO-B')),
    );
    expect(
      StudentRegistryService.instance.lookupById('STU-ISO-B'),
      isNull,
    );

    signIn('SCH-B');
    expect(
      StudentRegistryService.instance.lookupByName('Abebe Lemma')?.studentId,
      'STU-ISO-B',
    );
    expect(
      StudentRegistryService.instance
          .studentsForClass('Grade 4A')
          .map((s) => s.studentId),
      ['STU-ISO-B'],
    );

    AuthService.currentUser = null;
    expect(
      StudentRegistryService.instance.lookupByName('Abebe Lemma'),
      isNull,
    );
    expect(
      StudentRegistryService.instance.studentsForClass('Grade 4A'),
      isEmpty,
    );
    expect(StudentRegistryService.instance.visibleStudents(), isEmpty);
  });

  test('same teacher name stays on their own school', () {
    TeacherRegistryService.instance.applyPersistedTeachers([
      teacher(id: 'TCH-ISO-A', schoolId: 'SCH-A', name: 'Miss Belen'),
      teacher(id: 'TCH-ISO-B', schoolId: 'SCH-B', name: 'Miss Belen'),
    ]);

    signIn('SCH-A');
    expect(
      TeacherRegistryService.instance.lookupByName('Miss Belen')?.teacherId,
      'TCH-ISO-A',
    );
    expect(
      TeacherRegistryService.instance.lookupById('TCH-ISO-B'),
      isNull,
    );
    expect(
      TeacherRegistryService.instance
          .visibleTeachers()
          .map((t) => t.teacherId),
      contains('TCH-ISO-A'),
    );
    expect(
      TeacherRegistryService.instance
          .visibleTeachers()
          .map((t) => t.teacherId),
      isNot(contains('TCH-ISO-B')),
    );

    signIn('SCH-B');
    expect(
      TeacherRegistryService.instance.lookupByName('Miss Belen')?.teacherId,
      'TCH-ISO-B',
    );

    AuthService.currentUser = null;
    expect(TeacherRegistryService.instance.lookupByName('Miss Belen'), isNull);
    expect(TeacherRegistryService.instance.visibleTeachers(), isEmpty);
  });

  test('cloud merge does not overwrite the same id at another school', () {
    StudentRegistryService.instance.applyPersistedStudents([
      student(id: 'STU-0001', schoolId: 'SCH-A', name: 'School A Child'),
      student(id: 'STU-0001', schoolId: 'SCH-B', name: 'School B Child'),
    ]);
    TeacherRegistryService.instance.applyPersistedTeachers([
      teacher(id: 'TCH-0001', schoolId: 'SCH-A', name: 'Teacher A'),
      teacher(id: 'TCH-0001', schoolId: 'SCH-B', name: 'Teacher B'),
    ]);

    StudentRegistryService.instance.applyPersistedStudents([
      student(id: 'STU-0001', schoolId: 'SCH-A', name: 'School A Updated'),
    ]);
    TeacherRegistryService.instance.applyPersistedTeachers([
      teacher(id: 'TCH-0001', schoolId: 'SCH-A', name: 'Teacher A Updated'),
    ]);

    signIn('SCH-A');
    expect(
      StudentRegistryService.instance.lookupById('STU-0001')?.fullName,
      'School A Updated',
    );
    expect(
      TeacherRegistryService.instance.lookupById('TCH-0001')?.fullName,
      'Teacher A Updated',
    );

    signIn('SCH-B');
    expect(
      StudentRegistryService.instance.lookupById('STU-0001')?.fullName,
      'School B Child',
    );
    expect(
      TeacherRegistryService.instance.lookupById('TCH-0001')?.fullName,
      'Teacher B',
    );
  });
}
