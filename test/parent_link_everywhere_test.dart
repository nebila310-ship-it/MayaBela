import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/parent_invite_link.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/services/parent_student_verify_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ParentStudentVerifyService.instance.debugReset();
    ParentStudentVerifyService.instance.debugAllowNetwork = false;
  });

  tearDown(() {
    ParentStudentVerifyService.instance.debugReset();
  });

  test('invite link is a live URL with school, student, and DOB', () {
    final url = ParentInviteLink.build(
      schoolId: 'mal838',
      studentId: 'stu-1013',
      dateOfBirth: DateTime(2014, 10, 13),
      origin: ParentInviteLink.liveOrigin,
    );
    expect(url, startsWith('https://majobridge.com/?'));
    final parsed = ParentInviteLink.parse(Uri.parse(url));
    expect(parsed?.schoolId, 'MAL838');
    expect(parsed?.studentId, 'STU-1013');
    expect(parsed?.dobText, '13/10/2014');
  });

  test('invite link parses hash-style query used by some phones', () {
    final parsed = ParentInviteLink.parse(
      Uri.parse(
        'https://mayabela.pages.dev/#/?role=parent&school=MAL838&student=1013&dob=13-10-2014',
      ),
    );
    expect(parsed?.schoolId, 'MAL838');
    expect(parsed?.studentId, '1013');
    expect(parsed?.dobText, '13/10/2014');
  });

  test('parent invite SMS/email no longer points at the dead app URL', () {
    final message = ParentInviteService.instance.buildMessage(
      schoolId: 'MAL838',
      studentId: 'STU-1013',
      childName: 'SAMI ABDULAZIZ',
      schoolName: 'Mayu International Academy',
      childDateOfBirth: DateTime(2014, 10, 13),
    );
    expect(message, contains('https://majobridge.com/'));
    expect(message, contains('role=parent'));
    expect(message, contains('school=MAL838'));
    expect(message, contains('student=STU-1013'));
    expect(message, contains('dob=13%2F10%2F2014'));
    expect(message, isNot(contains('mayaschool.et/app')));
    expect(message, contains('any phone or computer'));
  });

  test('cloud verify remembers the child so a fresh phone can link', () async {
    const schoolId = 'MAL838';
    const studentId = 'STU-8809';
    final dob = DateTime(2015, 3, 21);
    expect(
      StudentRegistryService.instance.verifyStudent(
        schoolId: schoolId,
        studentId: studentId,
        dateOfBirth: dob,
      ),
      isFalse,
    );

    ParentStudentVerifyService.instance.debugCloudOverride =
        ({
          required String schoolId,
          required String studentId,
          required DateTime dateOfBirth,
        }) async {
          return AdminStudentRecord(
            studentId: studentId,
            fullName: 'Cloud Child',
            grade: 'Grade 4',
            className: 'Grade 4A',
            schoolId: schoolId,
            dateOfBirth: dateOfBirth,
            fatherName: 'Parent Cloud',
            fatherPhone: '0911880009',
          );
        };

    final found = await ParentStudentVerifyService.instance.verify(
      schoolId: schoolId,
      studentId: studentId,
      dateOfBirth: dob,
    );
    expect(found?.fullName, 'Cloud Child');
    expect(found?.fatherPhone, '0911880009');
    expect(
      StudentRegistryService.instance.verifyStudent(
        schoolId: schoolId,
        studentId: '8809',
        dateOfBirth: dob,
      ),
      isTrue,
    );
    expect(
      StudentRegistryService.instance.lookupById('8809')?.fullName,
      'Cloud Child',
    );
  });

  test('cloud payload parser keeps contact fields and drops empty names', () {
    final record = ParentStudentVerifyService.recordFromCloud({
      'ok': true,
      'schoolId': 'mal838',
      'studentId': 'stu-1013',
      'fullName': 'SAMI ABDULAZIZ',
      'className': 'Grade 8A',
      'grade': 'Grade 8',
      'dateOfBirth': '2014-10-13',
      'fatherName': 'Abdulaziz',
      'fatherPhone': '0911000001',
      'motherName': '',
      'motherPhone': null,
    });
    expect(record?.studentId, 'STU-1013');
    expect(record?.schoolId, 'MAL838');
    expect(record?.dateOfBirth, DateTime(2014, 10, 13));
    expect(record?.fatherName, 'Abdulaziz');
    expect(record?.motherName, isNull);
    expect(ParentStudentVerifyService.recordFromCloud({'ok': false}), isNull);
  });
}
