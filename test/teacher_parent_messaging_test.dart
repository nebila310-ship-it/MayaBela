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
    List<String> linkedStudentIds = const [],
  }) {
    AuthService.currentUser = RegisteredUser(
      username: username,
      password: 'x',
      roleKey: roleKey,
      schoolId: schoolId,
      fullName: fullName ?? username,
      linkedTeacherId: linkedTeacherId,
      phone: phone,
      linkedStudentIds: linkedStudentIds,
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
    expect(conversation.id.toUpperCase(), contains(teacherId));
    expect(conversation.id.toUpperCase(), contains(studentId));
    expect(conversation.id.toLowerCase(), contains('-stu-'));
    expect(conversation.id.toLowerCase(), isNot(contains('user-0911')));
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

  test('teacher send stamps parent phone from student record without enrollment',
      () {
    EnrollmentService.instance.replaceLinks(const []);
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: studentId,
        fullName: 'Kidus Assefa',
        grade: 'Grade 8',
        className: className,
        schoolId: schoolId,
        dateOfBirth: DateTime(2014, 4, 4),
        fatherName: parentName,
        fatherPhone: parentUsername,
      ),
    ]);

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
          .getConversation(ids.single)!
          .parentParticipantUsernames,
      contains(parentUsername),
    );

    signIn(
      username: parentUsername,
      roleKey: AuthService.roleParent,
      fullName: parentUsername,
    );
    expect(
      SchoolDataService.instance
          .getConversationsForRole(AuthService.roleParent)
          .any((c) => c.id == ids.single),
      isTrue,
    );
  });

  test('teacher reply stamps missing parent username onto the thread', () {
    signIn(
      username: 'teacher.msg',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: teacherId,
    );
    SchoolDataService.instance.applyPersistedConversations([
      Conversation(
        id: 'direct-reply-stamp',
        name: parentName,
        role: 'Parent',
        parentParticipantName: parentName,
        staffParticipantId: StaffMemberOption.teacherKey(teacherId),
        linkedStudentIds: const [studentId],
        messages: [
          ChatMessage(
            text: 'From parent',
            time: DateTime(2024, 3, 3),
            senderRole: AuthService.roleParent,
          ),
        ],
      ),
    ]);

    SchoolDataService.instance.sendMessage(
      'direct-reply-stamp',
      'Teacher reply for the parent',
    );
    final updated =
        SchoolDataService.instance.getConversation('direct-reply-stamp')!;
    expect(updated.parentParticipantUsernames, contains(parentUsername));
    expect(updated.messages.last.text, 'Teacher reply for the parent');
  });

  test('cloud merge keeps local teacher messages the parent has not pulled yet',
      () {
    const id = 'direct-merge-keep-local';
    SchoolDataService.instance.applyPersistedConversations([
      Conversation(
        id: id,
        name: parentName,
        role: 'Parent',
        parentParticipantName: parentName,
        parentParticipantUsernames: const [parentUsername],
        linkedStudentIds: const [studentId],
        messages: [
          ChatMessage(
            text: 'From parent',
            time: DateTime(2024, 4, 1, 8),
            senderRole: AuthService.roleParent,
          ),
          ChatMessage(
            text: 'Teacher reply still local',
            time: DateTime(2024, 4, 1, 9),
            senderRole: AuthService.roleTeacher,
            senderUsername: 'teacher.msg',
          ),
        ],
      ),
    ]);

    SchoolDataService.instance.mergeConversationFromCloud(
      Conversation(
        id: id,
        name: parentName,
        role: 'Parent',
        parentParticipantName: parentName,
        parentParticipantUsernames: const [parentUsername],
        linkedStudentIds: const [studentId],
        messages: [
          ChatMessage(
            text: 'From parent',
            time: DateTime(2024, 4, 1, 8),
            senderRole: AuthService.roleParent,
          ),
        ],
      ),
    );

    final merged = SchoolDataService.instance.getConversation(id)!;
    expect(merged.messages.map((m) => m.text), contains('Teacher reply still local'));
    expect(merged.messages.length, 2);
  });

  test('parent send and teacher reply stay on the same conversation', () {
    signIn(
      username: parentUsername,
      roleKey: AuthService.roleParent,
      fullName: parentUsername,
      linkedStudentIds: const [studentId],
    );
    final parentIds = SchoolDataService.instance.sendParentDirectMessage(
      body: 'Parent asking about homework',
      staffId: StaffMemberOption.teacherKey(teacherId),
      studentId: studentId,
    );
    expect(parentIds, isNotEmpty);

    signIn(
      username: 'teacher.msg',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: teacherId,
    );
    final teacherIds = SchoolDataService.instance.sendAdminDirectMessage(
      body: 'Teacher reply on the same thread',
      parentName: parentName,
    );
    expect(teacherIds.single, parentIds.single);

    final conversation =
        SchoolDataService.instance.getConversation(parentIds.single)!;
    expect(
      conversation.messages.map((m) => m.text),
      containsAll([
        'Parent asking about homework',
        'Teacher reply on the same thread',
      ]),
    );
  });

  test('teacher send first still receives the parent reply on the same thread',
      () {
    signIn(
      username: 'teacher.msg',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: teacherId,
    );
    final teacherIds = SchoolDataService.instance.sendAdminDirectMessage(
      body: 'Please confirm pickup time',
      parentName: parentName,
    );
    expect(teacherIds, isNotEmpty);

    signIn(
      username: parentUsername,
      roleKey: AuthService.roleParent,
      fullName: parentUsername,
      linkedStudentIds: const [studentId],
    );
    final parentIds = SchoolDataService.instance.sendParentDirectMessage(
      body: 'We will be there at 4',
      staffId: StaffMemberOption.teacherKey(teacherId),
      studentId: studentId,
    );
    expect(parentIds.single, teacherIds.single);
    expect(
      SchoolDataService.instance
          .getConversation(teacherIds.single)!
          .messages
          .map((m) => m.text),
      containsAll(['Please confirm pickup time', 'We will be there at 4']),
    );
  });

  test('legacy user-phone thread migrates onto the teacher+student id', () {
    const legacyId = 'direct-TEACHER:$teacherId-user-$parentUsername';
    signIn(
      username: parentUsername,
      roleKey: AuthService.roleParent,
      fullName: parentUsername,
      linkedStudentIds: const [studentId],
    );
    SchoolDataService.instance.applyPersistedConversations([
      Conversation(
        id: legacyId,
        name: parentName,
        role: 'Parent',
        parentParticipantName: parentName,
        parentParticipantUsernames: const [parentUsername],
        staffParticipantId: StaffMemberOption.teacherKey(teacherId),
        linkedStudentIds: const [studentId],
        messages: [
          ChatMessage(
            text: 'Old parent note',
            time: DateTime(2024, 6, 1),
            senderRole: AuthService.roleParent,
            senderUsername: parentUsername,
          ),
        ],
      ),
    ]);

    final parentIds = SchoolDataService.instance.sendParentDirectMessage(
      body: 'Follow up on the old thread',
      staffId: StaffMemberOption.teacherKey(teacherId),
      studentId: studentId,
    );
    expect(parentIds.single.toUpperCase(), contains(teacherId));
    expect(parentIds.single.toUpperCase(), contains(studentId));
    expect(parentIds.single, isNot(legacyId));
    expect(
      SchoolDataService.instance
          .getConversation(parentIds.single)!
          .messages
          .map((m) => m.text),
      containsAll(['Old parent note', 'Follow up on the old thread']),
    );

    signIn(
      username: 'teacher.msg',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: teacherId,
    );
    final teacherIds = SchoolDataService.instance.sendAdminDirectMessage(
      body: 'Teacher sees the migrated thread',
      parentName: parentName,
    );
    expect(teacherIds.single, parentIds.single);
  });

  test('two children with the same teacher get two conversation ids', () {
    const siblingId = 'STU-8802';
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
      AdminStudentRecord(
        studentId: siblingId,
        fullName: 'Hana Assefa',
        grade: 'Grade 8',
        className: className,
        schoolId: schoolId,
        dateOfBirth: DateTime(2016, 4, 4),
        fatherName: parentName,
      ),
    ]);

    signIn(
      username: parentUsername,
      roleKey: AuthService.roleParent,
      fullName: parentUsername,
      linkedStudentIds: const [studentId, siblingId],
    );
    final first = SchoolDataService.instance.sendParentDirectMessage(
      body: 'About Kidus',
      staffId: StaffMemberOption.teacherKey(teacherId),
      studentId: studentId,
    );
    final second = SchoolDataService.instance.sendParentDirectMessage(
      body: 'About Hana',
      staffId: StaffMemberOption.teacherKey(teacherId),
      studentId: siblingId,
    );
    expect(first.single, isNot(second.single));
    expect(first.single.toUpperCase(), contains(studentId));
    expect(second.single.toUpperCase(), contains(siblingId));
  });

  test('staff-to-staff conversation ids stay on the staff pair scheme', () {
    final id = SchoolDataService.instance.openOrCreateConversation(
      contactName: 'School Admin',
      role: 'Admin',
      staffParticipantId: StaffMemberOption.teacherKey(teacherId),
      counterpartyStaffId: StaffMemberOption.adminKey('ADM-1001'),
    );
    expect(id.toLowerCase(), startsWith('direct-staff-'));
    expect(id.toLowerCase(), isNot(contains('-stu-')));
  });

  test('teacher reply stays outgoing when staff id casing differs', () {
    signIn(
      username: 'teacher.msg',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: teacherId,
    );
    final message = ChatMessage(
      text: 'Pickup at the gate',
      time: DateTime(2024, 5, 5),
      senderRole: AuthService.roleTeacher,
      senderStaffId: 'teacher:${teacherId.toLowerCase()}',
      senderUsername: 'teacher.msg',
    );
    expect(
      message.isOutgoingFor(
        AuthService.roleTeacher,
        viewerStaffId: StaffMemberOption.teacherKey(teacherId),
        viewerUsername: 'teacher.msg',
      ),
      isTrue,
    );

    final conversation = Conversation(
      id: 'direct-case-thread',
      name: parentName,
      role: 'Parent',
      parentParticipantName: parentName,
      parentParticipantUsernames: const [parentUsername],
      staffParticipantId: 'TEACHER:$teacherId',
      linkedStudentIds: const [studentId],
      messages: [message],
    );
    expect(conversation.isVisibleToRole(AuthService.roleTeacher), isTrue);
  });
}
