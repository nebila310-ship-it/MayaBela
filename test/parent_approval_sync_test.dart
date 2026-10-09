import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

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

  test('parent signup stamps className on the pending request', () {
    EnrollmentService.instance.replaceLinks([], nextId: 903);
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-8804',
        fullName: 'Pending Child',
        grade: 'Grade 2',
        className: 'Grade 2B',
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2018, 4, 4),
      ),
    ], replace: true);

    final err = EnrollmentService.instance.verifyAndCreateParentLink(
      schoolId: 'TB-001',
      studentId: 'STU-8804',
      dateOfBirth: DateTime(2018, 4, 4),
      parentUsername: '0911880004',
      parentFullName: 'New Parent',
      relationship: ParentRelationship.mother,
      persist: false,
    );
    expect(err, isNull);
    expect(
      EnrollmentService.instance.linksForParent('0911880004').single.className,
      'Grade 2B',
    );
  });

  test('upserting one parent does not wipe another parent pending request', () {
    EnrollmentService.instance.replaceLinks([
      ParentLinkRequest(
        id: 'PL-A',
        parentUsername: '0911880005',
        parentFullName: 'Parent A',
        studentId: 'STU-8805',
        schoolId: 'TB-001',
        relationship: ParentRelationship.father,
        requestedAt: DateTime(2026, 1, 1),
        status: ParentLinkStatus.pending,
      ),
    ], nextId: 904);

    EnrollmentService.instance.upsertLinks([
      ParentLinkRequest(
        id: 'PL-B',
        parentUsername: '0911880006',
        parentFullName: 'Parent B',
        studentId: 'STU-8806',
        schoolId: 'TB-001',
        relationship: ParentRelationship.mother,
        requestedAt: DateTime(2026, 1, 2),
        status: ParentLinkStatus.approved,
      ),
    ]);

    expect(EnrollmentService.instance.allLinksSnapshot(), hasLength(2));
    expect(
      EnrollmentService.instance.linksForParent('0911880005'),
      hasLength(1),
    );
  });

  test(
    're-registering an approved parent+student reopens pending for teacher',
    () {
      EnrollmentService.instance.replaceLinks([
        ParentLinkRequest(
          id: 'PL-OLD',
          parentUsername: '0911880007',
          parentFullName: 'Returning Parent',
          studentId: 'STU-8807',
          schoolId: 'TB-001',
          relationship: ParentRelationship.father,
          requestedAt: DateTime(2026, 1, 1),
          status: ParentLinkStatus.approved,
          reviewedBy: 'Admin',
          reviewedAt: DateTime(2026, 1, 2),
          className: 'Grade 3A',
        ),
      ], nextId: 905);

      StudentRegistryService.instance.applyPersistedStudents([
        AdminStudentRecord(
          studentId: 'STU-8807',
          fullName: 'Returning Child',
          grade: 'Grade 3',
          className: 'Grade 3A',
          schoolId: 'TB-001',
          dateOfBirth: DateTime(2017, 5, 5),
        ),
      ], replace: true);

      final err = EnrollmentService.instance.verifyAndCreateParentLink(
        schoolId: 'TB-001',
        studentId: 'STU-8807',
        dateOfBirth: DateTime(2017, 5, 5),
        parentUsername: '+251911880007',
        parentFullName: 'Returning Parent',
        relationship: ParentRelationship.father,
        persist: false,
      );
      expect(err, isNull);
      final link = EnrollmentService.instance
          .linksForParent('0911880007')
          .single;
      expect(link.status, ParentLinkStatus.pending);
      expect(link.id, 'PL-OLD');
    },
  );

  void seedHomeroomApprovalFixture() {
    EnrollmentService.instance.replaceLinks([
      ParentLinkRequest(
        id: 'PL-6A',
        parentUsername: '0911880008',
        parentFullName: 'Class Parent',
        studentId: 'STU-8808',
        schoolId: 'TB-001',
        relationship: ParentRelationship.mother,
        requestedAt: DateTime(2026, 1, 1),
        status: ParentLinkStatus.pending,
        className: 'Grade 6 A',
      ),
      ParentLinkRequest(
        id: 'PL-5B',
        parentUsername: '0911880009',
        parentFullName: 'Other Class Parent',
        studentId: 'STU-8809',
        schoolId: 'TB-001',
        relationship: ParentRelationship.father,
        requestedAt: DateTime(2026, 1, 2),
        status: ParentLinkStatus.pending,
        className: 'Grade 5B',
      ),
    ], nextId: 906);

    TeacherRegistryService.instance.applyPersistedTeachers([
      AdminTeacherRecord(
        teacherId: 'TCH-8808',
        fullName: 'Subject Teacher',
        assignedClass: 'Grade 6A',
        schoolId: 'TB-001',
        subject: 'English',
        loginUsername: 'teacher.eng',
        roles: const [TeacherStaffRole.subjectTeacher],
        classAssignments: const [
          TeacherClassAssignment(
            className: 'Grade 6A',
            role: TeacherStaffRole.subjectTeacher,
          ),
        ],
      ),
      AdminTeacherRecord(
        teacherId: 'TCH-8809',
        fullName: 'Homeroom 6A',
        assignedClass: 'Grade 6A, Grade 5B',
        schoolId: 'TB-001',
        subject: 'Mathematics',
        loginUsername: 'teacher.hr6a',
        roles: const [
          TeacherStaffRole.homeroomTeacher,
          TeacherStaffRole.subjectTeacher,
        ],
        classAssignments: const [
          TeacherClassAssignment(
            className: 'Grade 6A',
            role: TeacherStaffRole.homeroomTeacher,
          ),
          TeacherClassAssignment(
            className: 'Grade 5B',
            role: TeacherStaffRole.subjectTeacher,
          ),
        ],
      ),
      AdminTeacherRecord(
        teacherId: 'TCH-8810',
        fullName: 'Homeroom 7A',
        assignedClass: 'Grade 7A',
        schoolId: 'TB-001',
        subject: 'Science',
        loginUsername: 'teacher.hr7a',
        roles: const [TeacherStaffRole.homeroomTeacher],
        classAssignments: const [
          TeacherClassAssignment(
            className: 'Grade 7A',
            role: TeacherStaffRole.homeroomTeacher,
          ),
        ],
      ),
    ]);
  }

  test('subject teacher does not see pending for an assigned class', () {
    seedHomeroomApprovalFixture();

    AuthService.currentUser = RegisteredUser(
      username: 'teacher.eng',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      fullName: 'Subject Teacher',
      linkedTeacherId: 'TCH-8808',
    );

    expect(EnrollmentService.instance.pendingCountForCurrentUser(), 0);
    expect(
      EnrollmentService.instance.canCurrentUserManageParentLink(
        EnrollmentService.instance.findLink('PL-6A')!,
      ),
      isFalse,
    );
  });

  test('homeroom teacher sees only that class, not subject classes', () {
    seedHomeroomApprovalFixture();

    AuthService.currentUser = RegisteredUser(
      username: 'teacher.hr6a',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      fullName: 'Homeroom 6A',
      linkedTeacherId: 'TCH-8809',
    );

    final pending = EnrollmentService.instance.pendingApprovalsForCurrentUser();
    expect(pending.map((l) => l.id), ['PL-6A']);
    expect(
      EnrollmentService.instance.canCurrentUserManageParentLink(pending.single),
      isTrue,
    );
    expect(
      EnrollmentService.instance.canCurrentUserManageParentLink(
        EnrollmentService.instance.findLink('PL-5B')!,
      ),
      isFalse,
    );
  });

  test('homeroom teacher of another class does not see the request', () {
    seedHomeroomApprovalFixture();

    AuthService.currentUser = RegisteredUser(
      username: 'teacher.hr7a',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      fullName: 'Homeroom 7A',
      linkedTeacherId: 'TCH-8810',
    );

    expect(EnrollmentService.instance.pendingCountForCurrentUser(), 0);
  });

  test('school admin sees every pending parent link', () {
    seedHomeroomApprovalFixture();

    AuthService.currentUser = RegisteredUser(
      username: 'admin',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
      fullName: 'School Admin',
    );

    expect(EnrollmentService.instance.pendingCountForCurrentUser(), 2);
    expect(
      EnrollmentService.instance.canCurrentUserManageParentLink(
        EnrollmentService.instance.findLink('PL-6A')!,
      ),
      isTrue,
    );
  });

  test(
    'pending link notifies admin and homeroom teacher, not subject teachers',
    () {
      seedHomeroomApprovalFixture();
      NotificationService.instance.clearForLogout();
      StudentRegistryService.instance.applyPersistedStudents([
        AdminStudentRecord(
          studentId: 'STU-8820',
          fullName: 'Notify Child',
          grade: 'Grade 6',
          className: 'Grade 6A',
          schoolId: 'TB-001',
          dateOfBirth: DateTime(2014, 1, 1),
          homeroomTeacherId: 'TCH-8809',
        ),
      ], replace: true);

      EnrollmentService.instance.replaceLinks([], nextId: 920);
      final err = EnrollmentService.instance.verifyAndCreateParentLink(
        schoolId: 'TB-001',
        studentId: 'STU-8820',
        dateOfBirth: DateTime(2014, 1, 1),
        parentUsername: '0911880020',
        parentFullName: 'Notify Parent',
        relationship: ParentRelationship.mother,
        persist: false,
      );
      expect(err, isNull);

      const title = 'Parent link waiting for approval';

      AuthService.currentUser = RegisteredUser(
        username: 'admin',
        password: 'x',
        roleKey: AuthService.roleAdmin,
        schoolId: 'TB-001',
        fullName: 'School Admin',
      );
      expect(
        NotificationService.instance.notificationsForCurrentUser().where(
          (n) => n.title == title,
        ),
        isNotEmpty,
      );

      AuthService.currentUser = RegisteredUser(
        username: 'teacher.hr6a',
        password: 'x',
        roleKey: AuthService.roleTeacher,
        schoolId: 'TB-001',
        fullName: 'Homeroom 6A',
        linkedTeacherId: 'TCH-8809',
      );
      expect(
        NotificationService.instance.notificationsForCurrentUser().where(
          (n) => n.title == title,
        ),
        isNotEmpty,
      );

      AuthService.currentUser = RegisteredUser(
        username: 'teacher.eng',
        password: 'x',
        roleKey: AuthService.roleTeacher,
        schoolId: 'TB-001',
        fullName: 'Subject Teacher',
        linkedTeacherId: 'TCH-8808',
      );
      expect(
        NotificationService.instance.notificationsForCurrentUser().where(
          (n) => n.title == title,
        ),
        isEmpty,
      );
    },
  );
}
