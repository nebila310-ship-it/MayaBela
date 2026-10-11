import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/student_sis_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'admin.funding',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
      fullName: 'Funding Admin',
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('existing student maps default to regular when funding type is missing', () {
    final student = AdminStudentRecord(
      studentId: 'STU-FUND-1',
      fullName: 'Legacy Child',
      grade: 'Grade 3',
      className: 'Grade 3A',
      schoolId: 'TB-001',
      dateOfBirth: DateTime(2017, 2, 2),
    );
    expect(student.fundingType, StudentFundingType.regular);

    final map = student.toMap()..remove('fundingType');
    expect(
      AdminStudentRecord.fromMap(map).fundingType,
      StudentFundingType.regular,
    );
    expect(
      StudentFundingTypeX.parse(true),
      StudentFundingType.scholarship,
    );
    expect(
      StudentFundingTypeX.parse('scholarship'),
      StudentFundingType.scholarship,
    );
  });

  test('addStudent and copyWith persist scholarship through toMap', () {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'Scholarship Child',
      grade: 'Grade 5',
      className: 'Grade 5B',
      dateOfBirth: DateTime(2015, 6, 6),
      house: 'Green',
      fundingType: StudentFundingType.scholarship,
    );
    expect(student.fundingType, StudentFundingType.scholarship);
    expect(student.toMap()['fundingType'], 'scholarship');

    final restored = AdminStudentRecord.fromMap(student.toMap());
    expect(restored.fundingType, StudentFundingType.scholarship);
    expect(restored.house, 'Green');

    StudentRegistryService.instance.updateStudent(
      student.copyWith(fundingType: StudentFundingType.regular),
    );
    expect(
      StudentRegistryService.instance
          .lookupById(student.studentId)
          ?.fundingType,
      StudentFundingType.regular,
    );

    StudentRegistryService.instance.updateStudent(
      student.copyWith(fundingType: StudentFundingType.scholarship),
    );
    expect(
      StudentRegistryService.instance
          .lookupById(student.studentId)
          ?.fundingType
          .isScholarship,
      isTrue,
    );
  });

  test('SIS grouping shows scholarship on the student profile', () {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'SIS Scholarship Child',
      grade: 'Grade 4',
      className: 'Grade 4A',
      dateOfBirth: DateTime(2016, 3, 1),
      house: 'Blue',
      fundingType: StudentFundingType.scholarship,
    );

    final sis = StudentSisProfile.load(student.studentId);
    expect(sis, isNotNull);
    expect(sis!.groupingSummary, contains('Scholarship student'));
    expect(sis.groupingSummary, contains('House Blue'));
    expect(sis.student.fundingType.label, 'Scholarship student');
  });
}
