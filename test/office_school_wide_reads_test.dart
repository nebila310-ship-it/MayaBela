import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/staff_content_realtime_sync.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    AuthService.clearCloudAccessScope();
  });

  tearDown(() {
    AuthService.currentUser = null;
    AuthService.clearCloudAccessScope();
  });

  RegisteredUser signIn({
    required String roleKey,
    List<String> staffRoles = const [],
    String username = 'phase1.user',
    String? linkedStudentId,
    List<String> linkedStudentIds = const [],
  }) {
    final user = RegisteredUser(
      username: username,
      password: 'x',
      roleKey: roleKey,
      schoolId: 'TB-001',
      staffRoles: staffRoles,
      linkedStudentId: linkedStudentId,
      linkedStudentIds: linkedStudentIds,
    );
    AuthService.currentUser = user;
    return user;
  }

  test('school owner Admin already reads the whole school', () {
    signIn(roleKey: AuthService.roleAdmin);
    expect(AuthService.mayReadAllSchoolData, isTrue);
    expect(AuthService.usesScopedCloudReads, isFalse);
    expect(CloudAppStore.instance.classReadsAreSchoolWideForTest(), isTrue);
    expect(CloudAppStore.instance.studentIdReadsAreSchoolWideForTest(), isTrue);
  });

  test('VP with no homeroom still pulls school-wide attendance classes', () {
    signIn(
      roleKey: AuthService.roleTeacher,
      staffRoles: const [StaffRoles.vicePresident],
      username: 'vp.nohomeroom',
    );
    expect(AuthService.isAdministrationStaff, isTrue);
    expect(AuthService.mayReadAllSchoolData, isTrue);
    expect(AuthService.usesScopedCloudReads, isFalse);
    expect(AuthService.accessClassNamesForSync(), isEmpty);
    expect(CloudAppStore.instance.classReadsAreSchoolWideForTest(), isTrue);
    expect(CloudAppStore.instance.studentIdReadsAreSchoolWideForTest(), isTrue);
  });

  test('principal and registrar match the JWT school-wide read rule', () {
    signIn(
      roleKey: AuthService.roleTeacher,
      staffRoles: const [StaffRoles.principal],
    );
    expect(AuthService.mayReadAllSchoolData, isTrue);
    expect(AuthService.usesScopedCloudReads, isFalse);

    signIn(
      roleKey: AuthService.roleTeacher,
      staffRoles: const [StaffRoles.registrar],
      username: 'reg.office',
    );
    expect(AuthService.mayReadAllSchoolData, isTrue);
    expect(AuthService.usesScopedCloudReads, isFalse);
  });

  test('classroom teacher stays class-scoped even with no staff roles', () {
    TeacherRegistryService.instance.addTeacher(
      schoolId: 'TB-001',
      fullName: 'Homeroom Abebe',
      email: 'abebe@school.et',
      phone: '0911000001',
      assignedClass: '5B',
      roles: const [TeacherStaffRole.homeroomTeacher],
      loginUsername: 'abebe.homeroom',
    );
    signIn(
      roleKey: AuthService.roleTeacher,
      username: 'abebe.homeroom',
    );
    expect(AuthService.isClassroomTeacher, isTrue);
    expect(AuthService.mayReadAllSchoolData, isFalse);
    expect(AuthService.usesScopedCloudReads, isTrue);
    expect(AuthService.accessClassNamesForSync(), contains('5B'));
    expect(CloudAppStore.instance.classReadsAreSchoolWideForTest(), isFalse);
    expect(CloudAppStore.instance.studentIdReadsAreSchoolWideForTest(), isFalse);
  });

  test('Staff digital-ops role does not get school-wide student rows', () {
    signIn(
      roleKey: AuthService.roleTeacher,
      staffRoles: const [StaffRoles.staffs],
      username: 'ict.staff',
    );
    expect(AuthService.isAdministrationStaff, isTrue);
    expect(AuthService.mayReadAllSchoolData, isFalse);
    expect(AuthService.usesScopedCloudReads, isTrue);
    expect(CloudAppStore.instance.classReadsAreSchoolWideForTest(), isFalse);
  });

  test('student attendance pull uses the linked class, not an empty filter', () {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'Sara Bekele',
      grade: '5',
      className: '5B',
      dateOfBirth: DateTime(2014, 3, 4),
    );
    signIn(
      roleKey: AuthService.roleStudent,
      username: 'sara.student',
      linkedStudentId: student.studentId,
    );
    expect(AuthService.mayReadAllSchoolData, isFalse);
    expect(AuthService.usesScopedCloudReads, isTrue);
    expect(AuthService.accessClassNamesForSync(), ['5B']);
    expect(CloudAppStore.instance.classReadsAreSchoolWideForTest(), isFalse);
    expect(CloudAppStore.instance.studentIdReadsAreSchoolWideForTest(), isFalse);
  });

  test('student falls back to JWT class names before registry is ready', () {
    signIn(
      roleKey: AuthService.roleStudent,
      username: 'jwt.student',
      linkedStudentId: 'STU-9999',
    );
    AuthService.applyCloudAccessScope(linkedClassNames: const ['4A']);
    expect(AuthService.accessClassNamesForSync(), ['4A']);
  });

  test('parent stays child-scoped', () {
    signIn(
      roleKey: AuthService.roleParent,
      username: 'parent.a',
      linkedStudentIds: const ['STU-1001'],
    );
    expect(AuthService.mayReadAllSchoolData, isFalse);
    expect(AuthService.usesScopedCloudReads, isTrue);
    expect(CloudAppStore.instance.studentIdReadsAreSchoolWideForTest(), isFalse);
  });

  test('load reduction still watches only parent links for staff', () {
    expect(
      StaffContentRealtimeSync.watchedCollections,
      [AppCollections.parentLinkRequests],
    );
  });
}
