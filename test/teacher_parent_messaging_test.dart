import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/cloud/conversation_document.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/messaging_access_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
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
    AuthService.sessionSchoolId = null;

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

  test('legacy user-phone thread is reused for the same teacher and student', () {
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
    expect(parentIds, isNotEmpty);
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
      body: 'Teacher sees the existing thread',
      parentName: parentName,
    );
    expect(teacherIds.single, parentIds.single);
  });

  test('two children with the same teacher get two conversation ids', () {
    const siblingId = 'STU-6602';
    const localTeacherId = 'TCH-6601';
    const localStudentId = 'STU-6601';
    const localParent = 'Two Child Parent';
    const localPhone = '0911660001';
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: localStudentId,
        fullName: 'Kidus Two',
        grade: 'Grade 8',
        className: className,
        schoolId: schoolId,
        dateOfBirth: DateTime(2014, 4, 4),
        fatherName: localParent,
        fatherPhone: localPhone,
        homeroomTeacherId: localTeacherId,
      ),
      AdminStudentRecord(
        studentId: siblingId,
        fullName: 'Hana Two',
        grade: 'Grade 8',
        className: className,
        schoolId: schoolId,
        dateOfBirth: DateTime(2016, 4, 4),
        fatherName: localParent,
        fatherPhone: localPhone,
        homeroomTeacherId: localTeacherId,
      ),
    ]);
    TeacherRegistryService.instance.applyPersistedTeachers([
      AdminTeacherRecord(
        teacherId: localTeacherId,
        fullName: 'Teacher Two',
        assignedClass: className,
        schoolId: schoolId,
        subject: 'Mathematics',
        loginUsername: 'teacher.two',
        classAssignments: const [
          TeacherClassAssignment(
            className: className,
            role: TeacherStaffRole.homeroomTeacher,
          ),
        ],
      ),
    ]);

    signIn(
      username: localPhone,
      roleKey: AuthService.roleParent,
      fullName: localPhone,
      linkedStudentIds: const [localStudentId, siblingId],
    );
    final first = SchoolDataService.instance.sendParentDirectMessage(
      body: 'About Kidus',
      staffId: StaffMemberOption.teacherKey(localTeacherId),
      studentId: localStudentId,
    );
    final second = SchoolDataService.instance.sendParentDirectMessage(
      body: 'About Hana',
      staffId: StaffMemberOption.teacherKey(localTeacherId),
      studentId: siblingId,
    );
    expect(first.single, isNot(second.single));
    expect(first.single.toUpperCase(), contains(localStudentId));
    expect(second.single.toUpperCase(), contains(siblingId));
  });

  test('reply in an existing two-child thread keeps that conversation id', () {
    const siblingId = 'STU-9902';
    const localTeacherId = 'TCH-9901';
    const localStudentId = 'STU-9901';
    const localParent = 'Nabil Ahmed';
    const localParentPhone = '0911990001';
    const existingId = 'direct-nabil-family';
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: localStudentId,
        fullName: 'Maya Nabil',
        grade: 'Grade 8',
        className: className,
        schoolId: schoolId,
        dateOfBirth: DateTime(2014, 4, 4),
        fatherName: localParent,
        fatherPhone: localParentPhone,
      ),
      AdminStudentRecord(
        studentId: siblingId,
        fullName: 'Brok Nabil',
        grade: 'Grade 8',
        className: className,
        schoolId: schoolId,
        dateOfBirth: DateTime(2016, 4, 4),
        fatherName: localParent,
        fatherPhone: localParentPhone,
      ),
    ]);
    TeacherRegistryService.instance.applyPersistedTeachers([
      AdminTeacherRecord(
        teacherId: localTeacherId,
        fullName: 'Teacher Nabil',
        assignedClass: className,
        schoolId: schoolId,
        subject: 'Mathematics',
        loginUsername: 'teacher.nabil',
        classAssignments: const [
          TeacherClassAssignment(
            className: className,
            role: TeacherStaffRole.homeroomTeacher,
          ),
        ],
      ),
    ]);

    signIn(
      username: 'teacher.nabil',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: localTeacherId,
    );
    SchoolDataService.instance.applyPersistedConversations([
      Conversation(
        id: existingId,
        name: localParent,
        role: 'Parent',
        parentParticipantName: localParent,
        parentParticipantUsernames: const [localParentPhone],
        staffParticipantId: StaffMemberOption.teacherKey(localTeacherId),
        linkedStudentIds: const [localStudentId, siblingId],
        messages: [
          ChatMessage(
            text: 'what shall we do next',
            time: DateTime(2024, 7, 1),
            senderRole: AuthService.roleParent,
            senderUsername: localParentPhone,
          ),
        ],
      ),
    ]);

    SchoolDataService.instance.sendMessage(existingId, 'just do maya homework');
    final conversation = SchoolDataService.instance.getConversation(existingId)!;
    expect(conversation.id, existingId);
    expect(
      conversation.linkedStudentIds,
      containsAll([localStudentId, siblingId]),
    );
    expect(conversation.messages.last.text, 'just do maya homework');
    expect(
      SchoolDataService.instance.sendAdminDirectMessage(
        body: 'hi',
        parentName: localParent,
      ).single,
      existingId,
    );
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

  test('reply on a split clone is copied onto the existing linked thread', () {
    const localTeacherId = 'TCH-7701';
    const localStudentId = 'STU-7701';
    const localParent = 'Clone Parent';
    const localPhone = '0911770001';
    const originalId = 'direct-original-nabil';
    const cloneId = 'direct-TEACHER:$localTeacherId-stu-$localStudentId';

    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: localStudentId,
        fullName: 'Maya Clone',
        grade: 'Grade 8',
        className: className,
        schoolId: schoolId,
        dateOfBirth: DateTime(2014, 4, 4),
        fatherName: localParent,
        fatherPhone: localPhone,
        homeroomTeacherId: localTeacherId,
      ),
    ]);
    TeacherRegistryService.instance.applyPersistedTeachers([
      AdminTeacherRecord(
        teacherId: localTeacherId,
        fullName: 'Teacher Clone',
        assignedClass: className,
        schoolId: schoolId,
        subject: 'Mathematics',
        loginUsername: 'teacher.clone',
        classAssignments: const [
          TeacherClassAssignment(
            className: className,
            role: TeacherStaffRole.homeroomTeacher,
          ),
        ],
      ),
    ]);

    signIn(
      username: 'teacher.clone',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: localTeacherId,
    );
    SchoolDataService.instance.applyPersistedConversations([
      Conversation(
        id: originalId,
        name: localParent,
        role: 'Parent',
        parentParticipantName: localParent,
        parentParticipantUsernames: const [localPhone],
        staffParticipantId: StaffMemberOption.teacherKey(localTeacherId),
        linkedStudentIds: const [localStudentId],
        messages: [
          ChatMessage(
            text: 'what shall we do next',
            time: DateTime(2024, 7, 1, 17, 39),
            senderRole: AuthService.roleParent,
            senderUsername: localPhone,
          ),
          ChatMessage(
            text: 'nothing',
            time: DateTime(2024, 7, 1, 17, 40),
            senderRole: AuthService.roleTeacher,
            senderUsername: 'teacher.clone',
          ),
        ],
      ),
      Conversation(
        id: cloneId,
        name: localParent,
        role: 'Parent',
        parentParticipantName: localParent,
        parentParticipantUsernames: const [localPhone],
        staffParticipantId: StaffMemberOption.teacherKey(localTeacherId),
        linkedStudentIds: const [localStudentId],
        messages: [
          ChatMessage(
            text: 'just do maya homework',
            time: DateTime(2024, 7, 1, 18, 13),
            senderRole: AuthService.roleTeacher,
            senderUsername: 'teacher.clone',
          ),
        ],
      ),
    ]);

    SchoolDataService.instance.sendMessage(cloneId, 'n');
    expect(
      SchoolDataService.instance.getConversation(originalId)!.messages.last.text,
      'n',
    );
    expect(
      SchoolDataService.instance
          .getConversationsForRole(AuthService.roleTeacher)
          .where((c) => c.linkedStudentIds.contains(localStudentId))
          .map((c) => c.id),
      [originalId],
    );
  });

  test('cloud persist stamps school id and keeps the linked parent thread',
      () async {
    signIn(
      username: 'teacher.msg',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: teacherId,
    );
    final ids = SchoolDataService.instance.sendAdminDirectMessage(
      body: body,
      parentName: parentName,
    );
    final conversation =
        SchoolDataService.instance.getConversation(ids.single)!;
    final doc = ConversationDocument.fromConversation(
      conversation,
      schoolId: SchoolAuthCloudService.resolvedSchoolId(),
    );
    expect(doc.schoolId, schoolId);
    expect(doc.parentParticipantUsernames, contains(parentUsername));
    expect(doc.linkedStudentIds, contains(studentId));
    expect(
      await SchoolDataService.instance.persistConversationToCloud('missing-id'),
      isFalse,
    );
  });
}
