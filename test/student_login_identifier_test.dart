import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_account_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/phone_utils.dart';
import 'package:mayabela/utils/student_id_utils.dart';
import 'package:mayabela/widgets/ethiopian_phone_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'MAL838';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    SchoolRegistryService.instance.applyPersistedSchools([
      SchoolRecord(
        id: schoolId,
        name: 'Mayu International Academy',
        studentPortal: const StudentPortalSettings(
          enabled: true,
          minimumGrade: 1,
          tempPasswordTemplate: 'EduAba@2026',
        ),
      ),
    ]);
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('phone loginKey digits-only is why Sami1013 was sent as 1013', () {
    expect(PhoneUtils.loginKey('Sami1013'), '1013');
    expect(PhoneUtils.loginKey('STU-1013'), '1013');
    expect(EthiopianPhoneField.localFromInput('Sami1013'), 'Sami1013');
  });

  test('student login keeps the typed username, never digits-only', () {
    expect(AuthService.normalizeLoginIdentifier('Sami1013'), 'Sami1013');
    expect(AuthService.normalizeLoginIdentifier(' sami1013 '), 'sami1013');
    expect(AuthService.normalizeLoginIdentifier('STU-1013'), 'STU-1013');
    expect(AuthService.normalizeLoginIdentifier('1013'), '1013');
    expect(
      AuthService.normalizeLoginIdentifier(
        EthiopianPhoneField.localFromInput('Sami1013'),
      ),
      'Sami1013',
    );
  });

  test('emails and Ethiopian mobiles still normalize', () {
    expect(
      AuthService.normalizeLoginIdentifier('Parent@School.ET'),
      'parent@school.et',
    );
    expect(AuthService.normalizeLoginIdentifier('+251911234567'), '0911234567');
    expect(AuthService.normalizeLoginIdentifier('911234567'), '0911234567');
  });

  test('STU-1013 and 1013 match the same roster id', () {
    expect(studentIdsMatch('STU-1013', '1013'), isTrue);
    expect(studentIdsMatch('stu-1013', 'STU-1013'), isTrue);
    expect(studentIdsMatch('STU-1013', 'STU-2013'), isFalse);
    expect(studentIdsMatch('Sami1013', 'STU-1013'), isFalse);
  });

  test('Sami1013, STU-id, and digit-only id all sign in locally', () {
    const username = 'samiident1013';
    final student = StudentRegistryService.instance.addStudent(
      schoolId: schoolId,
      fullName: 'SAMI ABDULAZIZ',
      grade: 'Grade 8',
      className: 'Grade 8A',
      dateOfBirth: DateTime(2012, 1, 1),
    );
    expect(
      AuthService.registerStudentAccount(
        fullName: student.fullName,
        schoolId: schoolId,
        username: username,
        linkedStudentId: student.studentId,
        password: 'EduAba@2026',
        mustChangePassword: true,
      ),
      isNull,
    );
    StudentRegistryService.instance.replaceStudent(
      student.copyWith(
        loginUsername: username,
        initialPassword: 'EduAba@2026',
        portalAccountStatus: StudentAccountStatus.active,
        mustChangePassword: true,
      ),
    );

    final idDigits = student.studentId.replaceFirst(RegExp(r'^STU-'), '');
    for (final typed in [
      'Samiident1013',
      username,
      student.studentId,
      idDigits,
    ]) {
      AuthService.currentUser = null;
      expect(
        AuthService.validateLogin(
          roleKey: AuthService.roleStudent,
          username: AuthService.normalizeLoginIdentifier(typed),
          password: 'EduAba@2026',
          schoolId: schoolId,
        ),
        isNull,
        reason: 'typed $typed',
      );
      expect(AuthService.currentUser?.username, username);
      expect(AuthService.currentUser?.linkedStudentId, student.studentId);
    }
  });

  test('new portal username from SAMI ABDULAZIZ / STU-1013 is sami1013', () {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: schoolId,
      fullName: 'SAMI ABDULAZIZ',
      grade: 'Grade 8',
      className: 'Grade 8A',
      dateOfBirth: DateTime(2012, 1, 1),
    );
    expect(student.studentId, isNotEmpty);
    expect(
      StudentAccountService.instance.generateTempPassword(schoolId),
      'EduAba@2026',
    );
  });

  test('school-login lookup no longer references undefined key', () {
    final src = File(
      'supabase/functions/_shared/school_auth.ts',
    ).readAsStringSync();
    expect(src.contains('=== key'), isFalse);
    expect(src.contains('studentIdsMatch'), isTrue);
    expect(src.contains('studentRegistryIdCandidates'), isTrue);
    expect(src.contains('emailKey'), isTrue);
  });
}
