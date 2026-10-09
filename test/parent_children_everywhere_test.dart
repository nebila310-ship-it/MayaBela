import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/parent_invite_link.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    AuthService.clearCloudAccessScope();
    EnrollmentService.instance.replaceLinks([], nextId: 920);
  });

  tearDown(() {
    AuthService.currentUser = null;
    AuthService.clearCloudAccessScope();
  });

  test('fresh-phone parent sees the approved child from the login token', () {
    AuthService.currentUser = RegisteredUser(
      username: '0911999001',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'MAL838',
      fullName: 'Girma Kidane',
      linkedStudentIds: const ['STU-8809'],
    );
    AuthService.applyCloudAccessScope(
      linkedStudentNames: const ['Cloud Child'],
      linkedClassNames: const ['Grade 4A'],
      linkedStudentIds: const ['STU-8809'],
    );

    expect(AuthService.activeLinkedStudentIds(), contains('STU-8809'));
    final children = SchoolDataService.instance.getChildren();
    expect(children.map((c) => c.studentId), contains('STU-8809'));
    expect(
      children.firstWhere((c) => c.studentId == 'STU-8809').name,
      'Cloud Child',
    );
    expect(
      children.firstWhere((c) => c.studentId == 'STU-8809').className,
      'Grade 4A',
    );
  });

  test('login token ids are kept even when local approval rows are missing', () {
    AuthService.currentUser = RegisteredUser(
      username: '0911999002',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'MAL838',
      linkedStudentIds: const ['STU-1013'],
    );
    expect(EnrollmentService.instance.hasApprovedAccess('0911999002'), isFalse);
    expect(AuthService.activeLinkedStudentIds(), ['STU-1013']);
    expect(AuthService.isParentAccessApproved(), isTrue);
  });

  test('registry child upgrades the token placeholder on a later pull', () {
    AuthService.currentUser = RegisteredUser(
      username: '0911999003',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'MAL838',
      linkedStudentIds: const ['STU-8810'],
    );
    AuthService.applyCloudAccessScope(
      linkedStudentNames: const ['Placeholder'],
      linkedClassNames: const ['Grade 1A'],
      linkedStudentIds: const ['STU-8810'],
    );
    SchoolDataService.instance.ensureLinkedChildrenVisible();
    expect(
      SchoolDataService.instance.getChildById('8810')?.name,
      'Placeholder',
    );

    StudentRegistryService.instance.rememberVerifiedStudent(
      AdminStudentRecord(
        studentId: 'STU-8810',
        fullName: 'Pulled Child',
        grade: 'Grade 5',
        className: 'Grade 5B',
        schoolId: 'MAL838',
        dateOfBirth: DateTime(2015, 1, 2),
      ),
    );
    SchoolDataService.instance.syncChildFromRegistry('STU-8810');
    expect(
      SchoolDataService.instance.getChildById('STU-8810')?.name,
      'Pulled Child',
    );
    expect(
      SchoolDataService.instance.getChildren().map((c) => c.name),
      contains('Pulled Child'),
    );
  });

  test('enroll invite URL is visible and copyable', () {
    final url = ParentInviteLink.build(
      schoolId: 'MAL838',
      studentId: 'STU-1013',
      dateOfBirth: DateTime(2014, 10, 13),
    );
    expect(url, contains('role=parent'));
    expect(url, contains('school=MAL838'));
    expect(url, contains('student=STU-1013'));
  });
}
