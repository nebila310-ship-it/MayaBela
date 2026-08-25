import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrollment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('approved parent with cloud student IDs is not stuck pending', () {
    EnrollmentService.instance.replaceLinks([], nextId: 900);
    AuthService.currentUser = RegisteredUser(
      username: '0911880001',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      fullName: '0911880001',
      linkedStudentIds: const ['STU-8801'],
    );

    expect(AuthService.isParentAccessApproved(), isTrue);
    expect(AuthService.isParentPendingApproval(), isFalse);
  });

  test('parent without approval stays pending on a fresh device', () {
    EnrollmentService.instance.replaceLinks([], nextId: 901);
    AuthService.currentUser = RegisteredUser(
      username: '0911880002',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      fullName: '0911880002',
    );

    expect(AuthService.isParentAccessApproved(), isFalse);
    expect(AuthService.isParentPendingApproval(), isFalse);
  });

  test('enrollment approval still grants access by username / phone', () async {
    EnrollmentService.instance.replaceLinks([
      ParentLinkRequest(
        id: 'PL-TEST-1',
        parentUsername: '0911880003',
        parentFullName: 'Approved Parent',
        studentId: 'STU-8803',
        schoolId: 'TB-001',
        relationship: ParentRelationship.father,
        requestedAt: DateTime(2026, 1, 1),
        status: ParentLinkStatus.approved,
      ),
    ], nextId: 902);

    AuthService.currentUser = RegisteredUser(
      username: '0911880003',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      fullName: 'Approved Parent',
    );

    expect(AuthService.isParentAccessApproved(), isTrue);
    expect(
      EnrollmentService.instance.linksForParent('+251911880003'),
      hasLength(1),
    );
  });

  test('parent+child cloud link id is stable across devices', () {
    expect(
      EnrollmentService.cloudLinkId(
        schoolId: 'tb-001',
        parentUsername: '+251 911 880 001',
        studentId: 'stu-8801',
      ),
      EnrollmentService.cloudLinkId(
        schoolId: 'TB-001',
        parentUsername: '0911880001',
        studentId: 'STU-8801',
      ),
    );
  });
}
