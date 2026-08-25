import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/parent_messaging_policy.dart';
import 'package:mayabela/services/rbac/eduaba_chat_matrix.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// Role-scoped conversation visibility — direct threads are participant-only.
abstract final class MessagingAccessService {
  /// School owner, or staff granted messaging / support (e.g. Vice President).
  static bool hasSchoolWideMessaging() {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleAdmin) return true;
    return AuthService.hasPermission(SchoolPermissions.messageParents) ||
        AuthService.hasPermission(SchoolPermissions.accessSupport);
  }

  static bool canView(Conversation conversation, String? roleKey) {
    return conversation.isVisibleToRole(roleKey);
  }

  static String relationshipLabelForCurrentParent() {
    final username = AuthService.currentUser?.username;
    if (username == null) return 'Parent';
    final links = EnrollmentService.instance.linksForParent(username);
    final approved = links.where((l) => l.status == ParentLinkStatus.approved);
    if (approved.isEmpty) return 'Parent';
    return _relationshipDisplay(approved.first.relationship);
  }

  static String relationshipLabelForStudent(String studentId) {
    final username = AuthService.currentUser?.username;
    if (username == null) return 'Parent';
    for (final link in EnrollmentService.instance.linksForParent(username)) {
      if (link.studentId.toUpperCase() == studentId.toUpperCase() &&
          link.status == ParentLinkStatus.approved) {
        return _relationshipDisplay(link.relationship);
      }
    }
    return 'Parent';
  }

  static String _relationshipDisplay(ParentRelationship relationship) {
    return switch (relationship) {
      ParentRelationship.father => 'Father',
      ParentRelationship.mother => 'Mother',
      ParentRelationship.guardian => 'Guardian',
    };
  }

  static List<ParentRecipientOption> parentsForTeacherClasses() {
    final classNames = TeacherAccessService.instance.myClasses
        .map((a) => a.className)
        .toSet();
    return _collectParentRecipients(
      classFilter: classNames,
      schoolId: AuthService.activeSchoolId,
    );
  }

  static List<ParentRecipientOption> parentsForSchool(String? schoolId) {
    return _collectParentRecipients(schoolId: schoolId);
  }

  static ParentRecipientOption? findParentRecipient(
    String parentName, {
    String? schoolId,
  }) {
    final normalized = parentName.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    ParentRecipientOption? merged;
    for (final option in parentsForSchool(schoolId ?? AuthService.activeSchoolId)) {
      if (option.parentName.trim().toLowerCase() != normalized) continue;
      merged = _combineParentRecipients(merged, option);
    }
    if (merged == null) return null;
    return _attachEnrollmentUsernames(merged);
  }

  /// Login usernames to stamp on a thread so the parent can pull it from cloud.
  static List<String> usernamesOf(ParentRecipientOption? recipient) {
    return recipient?.participantUsernames ?? const [];
  }

  static ParentRecipientOption _combineParentRecipients(
    ParentRecipientOption? existing,
    ParentRecipientOption incoming,
  ) {
    if (existing == null) return incoming;
    final studentNames = [...existing.studentNames];
    for (final name in incoming.studentNames) {
      if (!studentNames.contains(name)) studentNames.add(name);
    }
    final studentIds = [...existing.studentIds];
    for (final id in incoming.studentIds) {
      if (!studentIds.contains(id)) studentIds.add(id);
    }
    final usernames = <String>{
      ...existing.participantUsernames,
      ...incoming.participantUsernames,
    };
    return ParentRecipientOption(
      parentName: existing.parentName,
      studentNames: studentNames,
      studentIds: studentIds,
      parentUsername: existing.parentUsername ?? incoming.parentUsername,
      parentUsernames: usernames.toList(),
    );
  }

  static ParentRecipientOption _attachEnrollmentUsernames(
    ParentRecipientOption option,
  ) {
    EnrollmentService.instance.ensureSeeded();
    final usernames = <String>{...option.participantUsernames};
    final studentIds = option.studentIds.map((id) => id.toUpperCase()).toSet();
    final parentName = option.parentName.trim().toLowerCase();
    for (final link in EnrollmentService.instance.allLinksSnapshot()) {
      if (link.status != ParentLinkStatus.approved) continue;
      final matchesStudent = studentIds.contains(link.studentId.toUpperCase());
      final matchesName =
          link.parentFullName.trim().toLowerCase() == parentName;
      if (!matchesStudent && !matchesName) continue;
      final username = link.parentUsername.trim().toLowerCase();
      if (username.isNotEmpty) usernames.add(username);
    }
    return ParentRecipientOption(
      parentName: option.parentName,
      studentNames: option.studentNames,
      studentIds: option.studentIds,
      parentUsername: option.parentUsername ??
          (usernames.isEmpty ? null : usernames.first),
      parentUsernames: usernames.toList(),
    );
  }

  static List<ParentRecipientOption> _collectParentRecipients({
    Set<String>? classFilter,
    String? schoolId,
  }) {
    final normalizedSchoolId = schoolId?.trim().toUpperCase();
    final byKey = <String, ParentRecipientOption>{};

    for (final student in StudentRegistryService.instance.getAllStudents()) {
      if (normalizedSchoolId != null &&
          student.schoolId.trim().toUpperCase() != normalizedSchoolId) {
        continue;
      }
      if (classFilter != null && !classFilter.contains(student.className)) {
        continue;
      }
      if (!student.isActive) continue;

      final parentName = student.primaryParentName;
      if (parentName == null || parentName.trim().isEmpty) continue;
      _mergeParentRecipient(
        byKey,
        parentName: parentName.trim(),
        studentName: student.fullName,
        studentId: student.studentId,
      );
    }

    EnrollmentService.instance.ensureSeeded();
    final links = normalizedSchoolId == null
        ? EnrollmentService.instance.allLinksSnapshot()
        : EnrollmentService.instance.approvedForSchool(normalizedSchoolId);
    for (final link in links) {
      if (link.status != ParentLinkStatus.approved) continue;
      final student =
          StudentRegistryService.instance.lookupById(link.studentId);
      if (student == null || !student.isActive) continue;
      if (normalizedSchoolId != null &&
          student.schoolId.trim().toUpperCase() != normalizedSchoolId) {
        continue;
      }
      if (classFilter != null && !classFilter.contains(student.className)) {
        continue;
      }
      _mergeParentRecipient(
        byKey,
        parentName: link.parentFullName.trim(),
        parentUsername: link.parentUsername,
        studentName: student.fullName,
        studentId: student.studentId,
      );
    }

    return byKey.values.toList()
      ..sort((a, b) => a.parentName.compareTo(b.parentName));
  }

  static void _mergeParentRecipient(
    Map<String, ParentRecipientOption> byKey, {
    required String parentName,
    String? parentUsername,
    required String studentName,
    required String studentId,
  }) {
    if (parentName.isEmpty) return;
    final username = parentUsername?.trim();
    final key = username != null && username.isNotEmpty
        ? 'u:${username.toLowerCase()}'
        : 'n:${parentName.toLowerCase()}';
    final existing = byKey[key];
    if (existing == null) {
      byKey[key] = ParentRecipientOption(
        parentName: parentName,
        studentNames: [studentName],
        studentIds: [studentId],
        parentUsername: username,
      );
      return;
    }

    final studentNames = [...existing.studentNames];
    if (!studentNames.contains(studentName)) {
      studentNames.add(studentName);
    }
    final studentIds = [...existing.studentIds];
    if (!studentIds.contains(studentId)) {
      studentIds.add(studentId);
    }
    final usernames = <String>{
      ...existing.participantUsernames,
      if (username != null && username.isNotEmpty) username,
    };
    byKey[key] = ParentRecipientOption(
      parentName: existing.parentName,
      studentNames: studentNames,
      studentIds: studentIds,
      parentUsername: existing.parentUsername ?? username,
      parentUsernames: usernames.toList(),
    );
  }

  static List<StaffMemberOption> staffContactsForParentChild(String className) {
    return homeroomStaffForParentClass(className) == null
        ? const []
        : [homeroomStaffForParentClass(className)!];
  }

  static StaffMemberOption? homeroomStaffForParentClass(
    String className, {
    String? homeroomTeacherName,
  }) {
    return ParentMessagingPolicy.homeroomStaffForClass(
      className,
      homeroomTeacherName: homeroomTeacherName,
    );
  }

  static List<StaffMemberOption> adminContactsForParent() {
    return ParentMessagingPolicy.adminContactsForSchool(
      AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId,
    );
  }

  static List<StaffMemberOption> adminContactsForTeacher() {
    return adminContactsForParent();
  }

  static bool canTeacherDirectToParent(String parentName) {
    final normalized = parentName.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    if (hasSchoolWideMessaging()) {
      return parentsForSchool(AuthService.activeSchoolId)
          .any((p) => p.parentName.trim().toLowerCase() == normalized);
    }
    return parentsForTeacherClasses()
        .any((p) => p.parentName.trim().toLowerCase() == normalized);
  }

  static bool canTeacherDirectToStaff(String staffId) {
    if (hasSchoolWideMessaging()) {
      final member = StaffMemberOption.resolve(staffId);
      return member != null;
    }
    return ParentMessagingPolicy.isAdminStaff(staffId);
  }

  /// Parents list for compose UI based on the signed-in user's messaging scope.
  static List<ParentRecipientOption> parentsForCurrentCompose() {
    if (hasSchoolWideMessaging()) {
      return parentsForSchool(AuthService.activeSchoolId);
    }
    return parentsForTeacherClasses();
  }

  /// Staff list for compose UI based on the signed-in user's messaging scope.
  ///
  /// Owner sees everyone; administration staff see the EDUABA chat matrix
  /// scope (superior, reports, peers, and operationally linked branches);
  /// classroom teachers see their admin contacts.
  static List<StaffMemberOption> staffForCurrentCompose() {
    final me = AuthService.currentUser;
    if (me?.roleKey == AuthService.roleAdmin) {
      return SchoolDataService.instance.getStaffForActiveSchool();
    }
    if (AuthService.isAdministrationStaff) {
      final myRoles = me?.staffRoles ?? const <String>[];
      if (myRoles.isNotEmpty) {
        return SchoolDataService.instance
            .getStaffForActiveSchool()
            .where((peer) => _staffPeerAllowedByMatrix(myRoles, peer))
            .toList();
      }
    }
    if (hasSchoolWideMessaging()) {
      return SchoolDataService.instance.getStaffForActiveSchool();
    }
    return adminContactsForTeacher();
  }

  /// EDUABA chat matrix filter for one staff-directory entry.
  static bool _staffPeerAllowedByMatrix(
    List<String> myRoles,
    StaffMemberOption peer,
  ) {
    final my = myRoles.map(StaffRoles.canonicalize).toSet();
    switch (peer.kind) {
      case StaffKind.driver:
        return my.any(EduabaChatMatrix.driverContacts.contains);
      case StaffKind.adminStaff:
        // School owner / console accounts are always reachable upward.
        return true;
      case StaffKind.teacher:
        final record = TeacherRegistryService.instance.lookupById(peer.rawId);
        final peerRoles = record?.staffRoles ?? const <String>[];
        if (peerRoles.isEmpty) {
          // Classroom teacher without administration staff roles.
          return my.any(EduabaChatMatrix.classroomTeacherContacts.contains);
        }
        return EduabaChatMatrix.canStaffChat(
          actorRoles: myRoles,
          peerRoles: peerRoles,
        );
    }
  }

  /// Subject shown to parents in direct threads, e.g. Mathematics or Homeroom.
  static String? staffSubjectLabelFor({
    required String staffParticipantId,
    List<String> linkedStudentIds = const [],
  }) {
    final member = StaffMemberOption.resolve(staffParticipantId);
    if (member == null) return null;

    return switch (member.kind) {
      StaffKind.adminStaff => 'Admin',
      StaffKind.driver => 'Transport',
      StaffKind.teacher => _teacherSubjectLabel(
          member.rawId,
          staffParticipantId: staffParticipantId,
          linkedStudentIds: linkedStudentIds,
        ),
    };
  }

  static String? _teacherSubjectLabel(
    String teacherId, {
    required String staffParticipantId,
    required List<String> linkedStudentIds,
  }) {
    final teacher = TeacherRegistryService.instance.lookupById(teacherId);
    if (teacher == null) return null;

    for (final studentId in linkedStudentIds) {
      final student = StudentRegistryService.instance.lookupById(studentId);
      if (student == null) continue;

      if (ParentMessagingPolicy.isHomeroomStaffForStudent(
        staffParticipantId,
        studentId,
      )) {
        return 'Homeroom';
      }

      for (final subjectTeacher
          in SchoolDataService.instance.getSubjectsForClass(student.className)) {
        if (subjectTeacher.teacherId.toUpperCase() == teacherId.toUpperCase()) {
          return subjectTeacher.subject;
        }
      }

      for (final assignment in teacher.classAssignments) {
        if (assignment.className != student.className) continue;
        if (assignment.role == TeacherStaffRole.homeroomTeacher) {
          return 'Homeroom';
        }
        if (assignment.teachingSlots.isNotEmpty) {
          return assignment.teachingSlots.first.subjectName;
        }
      }
    }

    if (teacher.subjects.length == 1) return teacher.subjects.first;
    final primary = teacher.subject.trim();
    if (primary.isNotEmpty) return primary;
    if (teacher.subjects.isNotEmpty) return teacher.subjects.first;
    return null;
  }
}
