import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/messaging_access_service.dart';
import 'package:mayabela/services/parent_messaging_policy.dart';
import 'package:mayabela/services/presence_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';
  const hrId = 'TCH-HR-9911';
  const procurementId = 'TCH-PRC-9912';
  const hrUsername = 'hr.mesh';
  const procurementUsername = 'proc.mesh';

  void signIn({
    required String username,
    required String roleKey,
    String? fullName,
    String? linkedTeacherId,
    List<String> staffRoles = const [],
    List<String> linkedStudentIds = const [],
  }) {
    AuthService.currentUser = RegisteredUser(
      username: username,
      password: 'x',
      roleKey: roleKey,
      schoolId: schoolId,
      fullName: fullName ?? username,
      linkedTeacherId: linkedTeacherId,
      staffRoles: staffRoles,
      linkedStudentIds: linkedStudentIds,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    AuthService.sessionSchoolId = null;
    PresenceService.instance.resetForTests();

    TeacherRegistryService.instance.applyPersistedTeachers([
      AdminTeacherRecord(
        teacherId: hrId,
        fullName: 'Hanna Human',
        assignedClass: '',
        schoolId: schoolId,
        subject: 'HR',
        loginUsername: hrUsername,
        staffRoles: const [StaffRoles.humanResource],
      ),
      AdminTeacherRecord(
        teacherId: procurementId,
        fullName: 'Petros Procure',
        assignedClass: '',
        schoolId: schoolId,
        subject: 'Purchasing',
        loginUsername: procurementUsername,
        staffRoles: const [StaffRoles.procurement],
      ),
    ]);
  });

  tearDown(() {
    PresenceService.instance.resetForTests();
    AuthService.currentUser = null;
  });

  test('every staff role can compose internally; parents cannot', () {
    signIn(username: hrUsername, roleKey: AuthService.roleTeacher);
    expect(MessagingAccessService.hasSchoolWideMessaging(), isTrue);

    signIn(username: 'driver.1', roleKey: AuthService.roleDriver);
    expect(MessagingAccessService.hasSchoolWideMessaging(), isTrue);

    signIn(username: 'parent.1', roleKey: AuthService.roleParent);
    expect(MessagingAccessService.hasSchoolWideMessaging(), isFalse);
    expect(MessagingAccessService.staffForCurrentCompose(), isEmpty);
    expect(MessagingAccessService.parentsForCurrentCompose(), isEmpty);

    signIn(username: 'admin.1', roleKey: AuthService.roleAdmin);
    expect(MessagingAccessService.hasSchoolWideMessaging(), isTrue);

    signIn(username: 'stu.1', roleKey: AuthService.roleStudent);
    expect(MessagingAccessService.hasSchoolWideMessaging(), isFalse);
  });

  test('HR compose directory includes procurement as Name (Role)', () {
    signIn(
      username: hrUsername,
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: hrId,
      staffRoles: const [StaffRoles.humanResource],
    );

    final staff = MessagingAccessService.staffForCurrentCompose();
    final procurement = staff.firstWhere(
      (member) => member.id == StaffMemberOption.teacherKey(procurementId),
    );
    expect(procurement.labeledName, 'Petros Procure (Procurement Manager)');
    expect(
      staff.any((member) => member.id == StaffMemberOption.teacherKey(hrId)),
      isFalse,
    );
    expect(
      MessagingAccessService.canTeacherDirectToStaff(
        StaffMemberOption.teacherKey(procurementId),
      ),
      isTrue,
    );
  });

  test('HR can send an attachment to procurement and both see the thread', () {
    signIn(
      username: hrUsername,
      roleKey: AuthService.roleTeacher,
      fullName: 'Hanna Human',
      linkedTeacherId: hrId,
      staffRoles: const [StaffRoles.humanResource],
    );

    const attachment = AnnouncementAttachment(
      id: 'att-mesh-1',
      fileName: 'quote.pdf',
      filePath: '/tmp/quote.pdf',
    );
    final ids = SchoolDataService.instance.sendAdminDirectMessage(
      body: 'Please review this purchase quote',
      staffId: StaffMemberOption.teacherKey(procurementId),
      attachments: const [attachment],
    );
    expect(ids, isNotEmpty);

    final conversation = SchoolDataService.instance.getConversation(
      ids.single,
    )!;
    expect(conversation.displayTitleForViewer(), contains('Petros Procure'));
    expect(conversation.displayTitleForViewer(), contains('Procurement'));
    expect(conversation.messages.last.attachments.single.fileName, 'quote.pdf');
    expect(conversation.isVisibleToRole(AuthService.roleTeacher), isTrue);

    signIn(
      username: procurementUsername,
      roleKey: AuthService.roleTeacher,
      fullName: 'Petros Procure',
      linkedTeacherId: procurementId,
      staffRoles: const [StaffRoles.procurement],
    );
    expect(conversation.isVisibleToRole(AuthService.roleTeacher), isTrue);
    expect(
      conversation.displayTitleForViewer(),
      'Hanna Human (Human Resource)',
    );
  });

  test('parents may only write the homeroom teacher, not office staff', () {
    const homeroomId = 'TCH-HRM-9913';
    const studentId = 'STU-MESH-1';
    TeacherRegistryService.instance.applyPersistedTeachers([
      AdminTeacherRecord(
        teacherId: homeroomId,
        fullName: 'Helen Homeroom',
        assignedClass: 'Grade 4A',
        schoolId: schoolId,
        subject: 'Homeroom',
        loginUsername: 'helen.home',
        classAssignments: const [
          TeacherClassAssignment(
            className: 'Grade 4A',
            role: TeacherStaffRole.homeroomTeacher,
          ),
        ],
      ),
    ]);
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: studentId,
        fullName: 'Maya Mesh',
        grade: 'Grade 4',
        className: 'Grade 4A',
        schoolId: schoolId,
        dateOfBirth: DateTime(2016, 1, 1),
        fatherName: 'Parent Mesh',
        homeroomTeacherId: homeroomId,
      ),
    ]);

    expect(
      ParentMessagingPolicy.canMessageStaff(
        staffId: StaffMemberOption.teacherKey(procurementId),
      ),
      isFalse,
    );
    expect(
      ParentMessagingPolicy.canMessageStaff(
        staffId: StaffMemberOption.teacherKey(hrId),
      ),
      isFalse,
    );

    signIn(
      username: '0911990011',
      roleKey: AuthService.roleParent,
      fullName: 'Parent Mesh',
      linkedStudentIds: const [studentId],
    );

    expect(
      SchoolDataService.instance.sendParentDirectMessage(
        body: 'Can finance share the fee letter?',
        staffId: StaffMemberOption.teacherKey(hrId),
        studentId: studentId,
      ),
      isEmpty,
    );

    expect(
      ParentMessagingPolicy.canMessageStaff(
        staffId: StaffMemberOption.teacherKey(homeroomId),
        studentId: studentId,
      ),
      isTrue,
    );
    final ids = SchoolDataService.instance.sendParentDirectMessage(
      body: 'Maya will be late tomorrow',
      staffId: StaffMemberOption.teacherKey(homeroomId),
      studentId: studentId,
    );
    expect(ids, isNotEmpty);
    expect(
      SchoolDataService.instance
          .getConversation(ids.single)!
          .displayTitleForViewer(),
      contains('Helen Homeroom'),
    );
  });

  test('HR cannot open a parent thread from office compose', () {
    signIn(
      username: hrUsername,
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: hrId,
      staffRoles: const [StaffRoles.humanResource],
    );
    expect(MessagingAccessService.parentsForCurrentCompose(), isEmpty);
    expect(
      SchoolDataService.instance.sendAdminDirectMessage(
        body: 'Office should not write parents from HR',
        parentName: 'Parent Mesh',
      ),
      isEmpty,
    );
  });

  test(
    'presence marks the signed-in user online and peers from heartbeats',
    () {
      signIn(
        username: hrUsername,
        roleKey: AuthService.roleTeacher,
        linkedTeacherId: hrId,
      );
      PresenceService.instance.startForCurrentUser();

      expect(PresenceService.instance.isOnline(username: hrUsername), isTrue);

      final procurement = StaffMemberOption.fromTeacher(
        TeacherRegistryService.instance.lookupById(procurementId),
      )!;
      expect(PresenceService.instance.isStaffOnline(procurement), isFalse);

      PresenceService.instance.noteIdentity(procurementUsername);
      expect(PresenceService.instance.isStaffOnline(procurement), isTrue);

      PresenceService.instance.noteIdentity(
        procurementUsername,
        at: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
      );
      expect(PresenceService.instance.isStaffOnline(procurement), isFalse);
    },
  );
}
