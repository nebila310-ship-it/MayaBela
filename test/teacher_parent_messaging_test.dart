import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/messaging_access_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';
  const teacherId = 'TCH-8801';
  const studentId = 'STU-8801';
  const parentName = 'Meskerem Assefa';
  const parentUsername = '0911880001';
  const className = 'Grade 8MSG';
  const body = 'Please bring the homework folder tomorrow.';

  void signIn({
    required String username,
    required String roleKey,
    String? fullName,
    String? linkedTeacherId,
    String? phone,
  }) {
    AuthService.currentUser = RegisteredUser(
      username: username,
      password: 'x',
      roleKey: roleKey,
      schoolId: schoolId,
      fullName: fullName ?? username,
      linkedTeacherId: linkedTeacherId,
      phone: phone,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;

    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: studentId,
        fullName: 'Kidus Assefa',
        grade: 'Grade 8',
        className: className,
        schoolId: schoolId,
        dateOfBirth: DateTime(2014, 4, 4),
        fatherName: parentName,
      ),
    ]);

    TeacherRegistryService.instance.applyPersistedTeachers([
      AdminTeacherRecord(
        teacherId: teacherId,
        fullName: 'Teacher Message',
        assignedClass: className,
        schoolId: schoolId,
        subject: 'Mathematics',
        loginUsername: 'teacher.msg',
        classAssignments: const [
          TeacherClassAssignment(
            className: className,
            role: TeacherStaffRole.homeroomTeacher,
          ),
        ],
      ),
    ]);

    EnrollmentService.instance.ensureSeeded();
    final existing = EnrollmentService.instance.allLinksSnapshot();
    if (!existing.any((link) => link.id == 'PL-MSG-1')) {
      EnrollmentService.instance.replaceLinks([
        ...existing,
        ParentLinkRequest(
          id: 'PL-MSG-1',
          parentUsername: parentUsername,
          parentFullName: parentName,
          studentId: studentId,
          schoolId: schoolId,
          relationship: ParentRelationship.father,
          requestedAt: DateTime(2024, 1, 1),
          status: ParentLinkStatus.approved,
        ),
      ]);
    }
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('teacher send stamps parent username and student id', () {
    signIn(
      username: 'teacher.msg',
      roleKey: AuthService.roleTeacher,
      fullName: 'Teacher Message',
      linkedTeacherId: teacherId,
    );

    final recipient = MessagingAccessService.findParentRecipient(parentName);
    expect(recipient, isNotNull);
    expect(recipient!.studentIds, contains(studentId));
    expect(recipient.participantUsernames, contains(parentUsername));

    final ids = SchoolDataService.instance.sendAdminDirectMessage(
      body: body,
      parentName: parentName,
    );
    expect(ids, isNotEmpty);

    final conversation = SchoolDataService.instance.getConversation(ids.single)!;
    expect(conversation.linkedStudentIds, contains(studentId));
    expect(conversation.parentParticipantUsernames, contains(parentUsername));
    expect(conversation.messages.last.text, body);
    expect(conversation.messages.last.senderUsername, 'teacher.msg');
  });

  test('parent whose login name is a phone still sees the teacher message', () {
    signIn(
      username: 'teacher.msg',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: teacherId,
    );
    final ids = SchoolDataService.instance.sendAdminDirectMessage(
      body: body,
      parentName: parentName,
    );
    expect(ids, isNotEmpty);

    signIn(
      username: parentUsername,
      roleKey: AuthService.roleParent,
      fullName: parentUsername,
    );
    final visible = SchoolDataService.instance
        .getConversationsForRole(AuthService.roleParent);
    expect(visible.any((c) => c.id == ids.single), isTrue);
    expect(
      visible.firstWhere((c) => c.id == ids.single).messages.last.text,
      body,
    );
  });

  test('sending teacher sees the thread; another teacher and parent do not', () {
    signIn(
      username: 'teacher.msg',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: teacherId,
    );
    final ids = SchoolDataService.instance.sendAdminDirectMessage(
      body: body,
      parentName: parentName,
    );
    expect(ids, isNotEmpty);

    expect(
      SchoolDataService.instance
          .getConversationsForRole(AuthService.roleTeacher)
          .any((c) => c.id == ids.single),
      isTrue,
    );

    signIn(
      username: 'other.teacher',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: 'TCH-1002',
    );
    expect(
      SchoolDataService.instance
          .getConversationsForRole(AuthService.roleTeacher)
          .any((c) => c.id == ids.single),
      isFalse,
    );

    signIn(
      username: '0911999999',
      roleKey: AuthService.roleParent,
      fullName: 'Someone Else',
    );
    expect(
      SchoolDataService.instance
          .getConversationsForRole(AuthService.roleParent)
          .any((c) => c.id == ids.single),
      isFalse,
    );
  });

  test('legacy thread without usernames is still visible via enrollment name', () {
    signIn(
      username: parentUsername,
      roleKey: AuthService.roleParent,
      fullName: parentUsername,
    );

    final legacy = Conversation(
      id: 'legacy-msg-thread',
      name: parentName,
      role: 'Parent',
      parentParticipantName: parentName,
      staffParticipantId: StaffMemberOption.teacherKey(teacherId),
      messages: [
        ChatMessage(
          text: 'Older teacher note',
          time: DateTime(2024, 2, 2),
          senderRole: AuthService.roleTeacher,
        ),
      ],
    );

    expect(legacy.isVisibleToRole(AuthService.roleParent), isTrue);
  });

  test('teacher without linkedTeacherId still participates after registry resolve', () {
    signIn(
      username: 'teacher.msg',
      roleKey: AuthService.roleTeacher,
      fullName: 'Teacher Message',
    );

    final ids = SchoolDataService.instance.sendAdminDirectMessage(
      body: body,
      parentName: parentName,
    );
    expect(ids, isNotEmpty);

    final conversation = SchoolDataService.instance.getConversation(ids.single)!;
    expect(
      conversation.staffParticipantId,
      StaffMemberOption.teacherKey(teacherId),
    );
    expect(
      SchoolDataService.instance
          .getConversationsForRole(AuthService.roleTeacher)
          .any((c) => c.id == ids.single),
      isTrue,
    );
  });

  test('teacher cannot send to a parent outside their classes', () {
    signIn(
      username: 'teacher.msg',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: teacherId,
    );
    expect(
      SchoolDataService.instance.sendAdminDirectMessage(
        body: body,
        parentName: 'Not In My Class Parent',
      ),
      isEmpty,
    );
  });
}
