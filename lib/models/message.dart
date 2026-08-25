import 'package:mayabela/models/announcement.dart';

import 'package:mayabela/models/enrollment.dart';

import 'package:mayabela/services/admin_registry_service.dart';

import 'package:mayabela/services/auth_service.dart';

import 'package:mayabela/services/driver_registry_service.dart';

import 'package:mayabela/services/enrollment_service.dart';

import 'package:mayabela/services/parent_messaging_policy.dart';
import 'package:mayabela/services/student_registry_service.dart';

import 'package:mayabela/services/teacher_registry_service.dart';



class MessageReplyQuote {
  const MessageReplyQuote({
    required this.senderDisplayName,
    required this.previewText,
  });

  final String senderDisplayName;
  final String previewText;

  factory MessageReplyQuote.fromMessage(ChatMessage message) {
    return MessageReplyQuote(
      senderDisplayName: message.resolveDisplayName(),
      previewText: message.previewBody(),
    );
  }
}

class ChatMessage {

  ChatMessage({

    required this.text,

    required this.time,

    required this.senderRole,

    this.seenAt,

    this.subject,

    this.senderStaffId,

    this.senderDisplayName,

    this.senderUsername,

    this.senderRelationshipLabel,

    this.attachments = const [],

    this.replyTo,

  });



  final String text;

  final DateTime time;

  final String senderRole;

  final String? subject;

  final String? senderStaffId;

  final String? senderDisplayName;

  /// Parent login username when sent by a linked parent account.
  final String? senderUsername;

  /// e.g. Mother, Father, Guardian — shown under parent-sent messages.
  final String? senderRelationshipLabel;

  final List<AnnouncementAttachment> attachments;

  final MessageReplyQuote? replyTo;

  DateTime? seenAt;



  /// Short preview for reply quotes and notifications.
  String previewBody() {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (attachments.isEmpty) return '';
    if (attachments.every(_isVoiceFileName)) return 'Voice message';
    if (attachments.length == 1) return attachments.first.fileName;
    return '${attachments.length} attachments';
  }

  static bool _isVoiceFileName(AnnouncementAttachment attachment) {
    final lower = attachment.fileName.toLowerCase();
    return lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.wav') ||
        lower.startsWith('voice_');
  }



  /// Resolved label for message bubbles (actual person, not generic role).
  String resolveDisplayName() {
    final explicit = senderDisplayName?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    if (senderStaffId != null) {
      final member = StaffMemberOption.resolve(senderStaffId!);
      if (member != null && member.displayName.trim().isNotEmpty) {
        return member.displayName;
      }
    }
    return switch (senderRole) {
      AuthService.roleParent => 'Parent',
      AuthService.roleTeacher => 'Teacher',
      AuthService.roleDriver => 'Driver',
      AuthService.roleAdmin => 'Admin',
      _ => 'User',
    };
  }



  bool isOutgoingFor(String? viewerRole, {String? viewerStaffId, String? viewerUsername}) {

    if (viewerRole == null || viewerRole != senderRole) return false;

    if (senderRole == AuthService.roleParent &&
        senderUsername != null &&
        viewerUsername != null) {
      return senderUsername!.trim().toLowerCase() ==
          viewerUsername.trim().toLowerCase();
    }

    if (senderStaffId != null && viewerStaffId != null) {

      return senderStaffId!.trim() == viewerStaffId.trim();

    }

    return true;

  }

}



class Conversation {

  Conversation({

    required this.id,

    required this.name,

    required this.role,

    required this.messages,

    this.unread = 0,

    this.isBroadcast = false,

    this.broadcastAudienceKeys = const [],

    this.isGroup = false,

    this.groupParentNames = const [],

    this.groupStaffIds = const [],

    this.photoPath,

    this.usesCustomGroupName = false,

    this.parentParticipantName,

    this.staffParticipantId,

    this.counterpartyStaffId,

    this.staffSubjectName,

    List<String>? linkedStudentIds,

    List<String>? parentParticipantUsernames,

  })  : linkedStudentIds = List<String>.from(linkedStudentIds ?? const []),

        parentParticipantUsernames =

            List<String>.from(parentParticipantUsernames ?? const []);



  final String id;

  String name;

  final String role;

  final List<ChatMessage> messages;

  int unread;

  final bool isBroadcast;

  final List<String> broadcastAudienceKeys;

  final bool isGroup;

  List<String> groupParentNames;

  List<String> groupStaffIds;

  String? photoPath;

  bool usesCustomGroupName;

  /// Parent in a direct thread (e.g. Mr. Bekele).
  final String? parentParticipantName;

  /// Staff composite id (e.g. teacher:TCH-1001).
  String? staffParticipantId;

  /// Other staff member in a direct staff-to-staff thread (e.g. teacher ↔ admin).
  String? counterpartyStaffId;

  /// Subject label shown to parents, e.g. Mathematics or Homeroom.
  String? staffSubjectName;

  /// Student IDs this thread is about (parent ↔ staff per child).
  List<String> linkedStudentIds;

  /// Parent login usernames allowed in this thread.
  List<String> parentParticipantUsernames;



  /// Unread incoming messages for the signed-in viewer.
  int unreadForViewer(String? roleKey, {String? viewerStaffId}) {
    if (roleKey == null) return unread;
    var count = 0;
    for (final message in messages) {
      if (message.isOutgoingFor(roleKey, viewerStaffId: viewerStaffId)) {
        continue;
      }
      if (message.seenAt == null) count++;
    }
    return count;
  }



  String get lastMessage {
    if (messages.isEmpty) return 'No messages yet';
    final last = messages.last;
    if (last.text.trim().isNotEmpty) return last.text;
    if (last.attachments.isEmpty) return last.text;
    if (last.attachments.every((a) => _isVoiceAttachment(a))) {
      return 'Voice message';
    }
    if (last.attachments.length == 1) {
      return last.attachments.first.fileName;
    }
    return '${last.attachments.length} attachments';
  }



  bool isVisibleToRole(String? roleKey) {
    if (roleKey == null) return false;

    if (isBroadcast) {
      return broadcastAudienceKeys.any((key) {
        switch (AnnouncementAudiences.normalizeLegacy(key)) {
          case AnnouncementAudiences.parents:
            return roleKey == AuthService.roleParent;
          case AnnouncementAudiences.teachers:
            return roleKey == AuthService.roleTeacher;
          case AnnouncementAudiences.students:
            return roleKey == AuthService.roleStudent;
          case AnnouncementAudiences.transport:
            return roleKey == AuthService.roleDriver;
          default:
            return false;
        }
      });
    }

    if (isGroup) {
      return switch (roleKey) {
        AuthService.roleAdmin => _adminInGroup(),
        AuthService.roleParent => _parentInGroup(),
        AuthService.roleTeacher || AuthService.roleDriver => _staffInGroup(roleKey),
        AuthService.roleStudent => _studentInGroup(),
        _ => false,
      };
    }

    return _isDirectThreadParticipant(roleKey);
  }

  bool _studentInGroup() {
    final studentId = AuthService.currentUser?.linkedStudentId?.trim().toUpperCase();
    if (studentId == null || studentId.isEmpty) return false;
    return linkedStudentIds.any((id) => id.toUpperCase() == studentId);
  }

  bool _studentCanSeeDirectThread() {
    final studentId = AuthService.currentUser?.linkedStudentId?.trim().toUpperCase();
    if (studentId == null || studentId.isEmpty) return false;
    return linkedStudentIds.any((id) => id.toUpperCase() == studentId);
  }

  bool _isDirectThreadParticipant(String roleKey) {
    if (roleKey == AuthService.roleStudent) {
      return _studentCanSeeDirectThread();
    }
    if (roleKey == AuthService.roleParent) {
      return _parentCanSeeDirect(role.trim().toLowerCase());
    }
    return _staffCanSeeDirectThread(roleKey);
  }

  bool _hasParentParticipant() {
    if (parentParticipantName?.trim().isNotEmpty == true) return true;
    if (parentParticipantUsernames.isNotEmpty) return true;
    if (linkedStudentIds.isNotEmpty) return true;
    return role.trim().toLowerCase() == 'parent';
  }

  /// Staff↔staff direct threads (e.g. admin↔teacher) — never shown to parents.
  bool get isStaffOnlyDirectThread {
    if (_hasParentParticipant()) return false;
    final staff = staffParticipantId?.trim();
    final peer = counterpartyStaffId?.trim();
    return staff != null &&
        staff.isNotEmpty &&
        peer != null &&
        peer.isNotEmpty;
  }

  String? _compositeStaffIdForRole(String roleKey) {
    if (roleKey == AuthService.roleAdmin) {
      return StaffMemberOption.viewerAdminStaffId(roleKey);
    }
    return StaffMemberOption.viewerStaffId(roleKey);
  }

  /// Direct threads are visible only to the parent and the staff member involved.
  bool _staffCanSeeDirectThread(String roleKey) {
    final viewerStaffId = _compositeStaffIdForRole(roleKey);
    final username = AuthService.currentUser?.username.trim().toLowerCase();

    bool sentByViewer() {
      if (username == null || username.isEmpty) return false;
      return messages.any(
        (m) => m.senderUsername?.trim().toLowerCase() == username,
      );
    }

    if (_hasParentParticipant()) {
      if (viewerStaffId != null &&
          staffParticipantId != null &&
          staffParticipantId!.trim() == viewerStaffId.trim()) {
        return true;
      }
      final threadStaff = staffParticipantId?.trim();
      if (viewerStaffId != null &&
          (threadStaff == null || threadStaff.isEmpty) &&
          messages.any((m) => m.senderStaffId?.trim() == viewerStaffId.trim())) {
        return true;
      }
      return sentByViewer();
    }

    if (viewerStaffId != null &&
        staffParticipantId != null &&
        staffParticipantId!.trim() == viewerStaffId.trim()) {
      return true;
    }

    if (viewerStaffId != null &&
        counterpartyStaffId != null &&
        counterpartyStaffId!.trim() == viewerStaffId.trim()) {
      return true;
    }

    if (viewerStaffId != null &&
        messages.any((m) => m.senderStaffId?.trim() == viewerStaffId.trim())) {
      return true;
    }

    return sentByViewer();
  }

  bool _adminInGroup() {
    final viewerAdminId =
        StaffMemberOption.viewerAdminStaffId(AuthService.roleAdmin);
    if (viewerAdminId != null &&
        groupStaffIds.any((id) => id.trim() == viewerAdminId)) {
      return true;
    }
    return messages.any((m) => m.senderRole == AuthService.roleAdmin);
  }

  static bool _isVoiceAttachment(AnnouncementAttachment attachment) {
    final lower = attachment.fileName.toLowerCase();
    return lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.wav') ||
        lower.startsWith('voice_');
  }

  bool _parentCanSeeDirect(String contactRole) {
    if (isStaffOnlyDirectThread) return false;

    final username = AuthService.currentUser?.username.trim().toLowerCase();
    if (username != null &&
        username.isNotEmpty &&
        parentParticipantUsernames
            .any((u) => u.trim().toLowerCase() == username)) {
      return true;
    }
    final linked = AuthService.activeLinkedStudentIds()
        .map((id) => id.toUpperCase())
        .toSet();
    if (linkedStudentIds.any(linked.contains)) return true;

    if (contactRole == 'parent' && _parentNameMatchesCurrentUser(name)) {
      return true;
    }
    if (parentParticipantName != null &&
        _parentNameMatchesCurrentUser(parentParticipantName!)) {
      return true;
    }
    if (staffParticipantId != null &&
        (contactRole == 'teacher' ||
            contactRole == 'admin' ||
            contactRole == 'driver')) {
      return ParentMessagingPolicy.canViewDirectStaffThread(this);
    }

    if (username != null &&
        messages.any(
          (m) =>
              m.senderRole == AuthService.roleParent &&
              m.senderUsername?.trim().toLowerCase() == username,
        )) {
      return true;
    }

    return false;
  }

  bool _parentNameMatchesCurrentUser(String candidate) {
    final needle = candidate.trim().toLowerCase();
    if (needle.isEmpty) return false;
    final user = AuthService.currentUser;
    if (user == null) return false;

    final names = <String>{};
    void add(String? value) {
      final trimmed = value?.trim().toLowerCase();
      if (trimmed != null && trimmed.isNotEmpty) names.add(trimmed);
    }

    add(user.fullName);
    add(user.username);
    EnrollmentService.instance.ensureSeeded();
    for (final link in EnrollmentService.instance.linksForParent(user.username)) {
      if (link.status != ParentLinkStatus.approved) continue;
      add(link.parentFullName);
    }
    for (final studentId in AuthService.activeLinkedStudentIds()) {
      final student = StudentRegistryService.instance.lookupById(studentId);
      if (student == null) continue;
      add(student.primaryParentName);
      add(student.fatherName);
      add(student.motherName);
      add(student.guardianName);
    }
    return names.contains(needle);
  }



  bool _parentInGroup() {

    final parentUsername = AuthService.currentUser?.username;
    final normalizedUsername = parentUsername?.trim().toLowerCase();
    if (normalizedUsername != null &&
        normalizedUsername.isNotEmpty &&
        parentParticipantUsernames
            .any((u) => u.trim().toLowerCase() == normalizedUsername)) {
      return true;
    }

    if (groupParentNames.isEmpty) return false;

    final targets = groupParentNames

        .map((n) => n.trim().toLowerCase())

        .where((n) => n.isNotEmpty)

        .toSet();

    for (final studentId in AuthService.activeLinkedStudentIds()) {

      final student = StudentRegistryService.instance.lookupById(studentId);

      final name = student?.primaryParentName?.trim().toLowerCase();

      if (name != null && targets.contains(name)) return true;

    }

    if (parentUsername != null) {

      EnrollmentService.instance.ensureSeeded();

      for (final link in EnrollmentService.instance.linksForParent(parentUsername)) {

        if (link.status != ParentLinkStatus.approved) continue;

        final linkName = link.parentFullName.trim().toLowerCase();

        if (linkName.isNotEmpty && targets.contains(linkName)) return true;

      }

    }

    return false;

  }



  bool _staffInGroup(String roleKey) {

    final viewerStaffId = StaffMemberOption.viewerStaffId(roleKey);

    if (viewerStaffId == null) return false;

    return groupStaffIds.any((id) => id.trim() == viewerStaffId.trim());

  }

  /// Conversation list / chat header title for the signed-in viewer.
  String displayTitleForViewer({String? viewerRole}) {
    viewerRole ??= AuthService.currentUser?.roleKey;
    if (isGroup || isBroadcast) return name;

    final contactRole = role.trim().toLowerCase();

    if (viewerRole == AuthService.roleParent && _isStaffDirectContact(contactRole)) {
      return _staffDisplayNameWithSubject() ?? name;
    }

    if ((viewerRole == AuthService.roleTeacher ||
            viewerRole == AuthService.roleAdmin ||
            viewerRole == AuthService.roleDriver) &&
        _isParentDirectThreadForStaff(viewerRole, contactRole)) {
      return _parentWithStudentLabel();
    }

    if (!isGroup &&
        !isBroadcast &&
        !_hasParentParticipant() &&
        (viewerRole == AuthService.roleAdmin ||
            viewerRole == AuthService.roleTeacher ||
            viewerRole == AuthService.roleDriver)) {
      final peer = _peerStaffDisplayName(viewerRole);
      if (peer != null && peer.trim().isNotEmpty) return peer;
    }

    return name;
  }

  String? _peerStaffDisplayName(String? viewerRole) {
    final roleKey = viewerRole ?? AuthService.currentUser?.roleKey;
    if (roleKey == null) return null;
    final viewerId = _compositeStaffIdForRole(roleKey);
    String? peerId;
    if (viewerId != null) {
      if (staffParticipantId?.trim() == viewerId.trim()) {
        peerId = counterpartyStaffId;
      } else if (counterpartyStaffId?.trim() == viewerId.trim()) {
        peerId = staffParticipantId;
      }
    }

    if (peerId != null) {
      final member = StaffMemberOption.resolve(peerId);
      if (member != null) return member.displayName;
    }

    if (viewerId == null) return null;
    for (var i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.senderRole == AuthService.roleParent) continue;
      final senderStaffId = msg.senderStaffId?.trim();
      if (senderStaffId != null && senderStaffId != viewerId.trim()) {
        return msg.resolveDisplayName();
      }
      if (senderStaffId == null && msg.senderRole != viewerRole) {
        return msg.resolveDisplayName();
      }
    }

    if (peerId != null) {
      return StaffMemberOption.resolve(peerId)?.displayName;
    }
    return null;
  }

  bool _isStaffDirectContact(String contactRole) {
    return contactRole == 'parent' ||
        contactRole == 'teacher' ||
        contactRole == 'admin' ||
        contactRole == 'driver';
  }

  bool _isParentDirectThreadForStaff(String? viewerRole, String contactRole) {
    if (contactRole == 'parent') return true;
    if (parentParticipantName == null ||
        parentParticipantName!.trim().isEmpty ||
        staffParticipantId == null) {
      return false;
    }
    final viewerStaffId = StaffMemberOption.viewerStaffId(viewerRole);
    return viewerStaffId != null &&
        staffParticipantId!.trim() == viewerStaffId.trim();
  }

  /// Label for incoming parent messages when viewed by staff in a direct thread.
  String parentSenderLabelForStaff() => _parentWithStudentLabel();

  String? _staffDisplayNameWithSubject() {
    final staffName = _staffDisplayNameForThread();
    if (staffName == null) return null;
    final subject = staffSubjectName?.trim();
    if (subject != null && subject.isNotEmpty) {
      return '$staffName ($subject)';
    }
    return staffName;
  }

  String? _staffDisplayNameForThread() {
    if (staffParticipantId != null) {
      final member = StaffMemberOption.resolve(staffParticipantId!);
      if (member != null) return member.displayName;
    }
    for (var i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.senderRole == AuthService.roleParent) continue;
      final label = msg.senderDisplayName?.trim();
      if (label != null && label.isNotEmpty) return label;
      return AuthService.displayNameForRole(msg.senderRole);
    }
    return null;
  }

  String _parentWithStudentLabel() {
    var parentName = parentParticipantName?.trim().isNotEmpty == true
        ? parentParticipantName!.trim()
        : name.trim();
    final studentNames = linkedStudentIds
        .map((id) => StudentRegistryService.instance.lookupById(id)?.fullName)
        .whereType<String>()
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (linkedStudentIds.isNotEmpty) {
      final student =
          StudentRegistryService.instance.lookupById(linkedStudentIds.first);
      final registryParent = student?.primaryParentName?.trim();
      if (registryParent != null && registryParent.isNotEmpty) {
        parentName = registryParent;
      }
    }
    if (studentNames.length == 1) {
      return '$parentName (${studentNames.first})';
    }
    if (studentNames.isNotEmpty) {
      return '$parentName (${studentNames.join(', ')})';
    }
    return parentName;
  }

}



enum StaffKind { teacher, driver, adminStaff }



class StaffMemberOption {

  const StaffMemberOption({

    required this.id,

    required this.displayName,

    required this.roleKey,

    required this.subtitle,

    required this.kind,

    required this.rawId,

  });



  final String id;

  final String displayName;

  final String roleKey;

  final String subtitle;

  final StaffKind kind;

  final String rawId;



  static String teacherKey(String teacherId) => 'teacher:${teacherId.trim()}';

  static String driverKey(String driverId) => 'driver:${driverId.trim()}';

  static String adminKey(String adminId) => 'admin:${adminId.trim()}';



  static StaffMemberOption? resolve(String compositeId) {

    final parts = compositeId.split(':');

    if (parts.length != 2) return null;

    return switch (parts[0]) {

      'teacher' => fromTeacher(

          TeacherRegistryService.instance.lookupById(parts[1]),

        ),

      'driver' => fromDriver(

          DriverRegistryService.instance.lookupById(parts[1]),

        ),

      'admin' => fromAdmin(

          AdminRegistryService.instance.lookupById(parts[1]),

        ),

      _ => null,

    };

  }



  static StaffMemberOption? fromTeacher(AdminTeacherRecord? teacher) {

    if (teacher == null || !teacher.isActive) return null;

    return StaffMemberOption(

      id: teacherKey(teacher.teacherId),

      displayName: teacher.fullName,

      roleKey: AuthService.roleTeacher,

      subtitle: '${teacher.teacherId} · ${teacher.subject}',

      kind: StaffKind.teacher,

      rawId: teacher.teacherId,

    );

  }



  static StaffMemberOption? fromDriver(AdminDriverRecord? driver) {

    if (driver == null || !driver.isActive) return null;

    return StaffMemberOption(

      id: driverKey(driver.driverId),

      displayName: driver.fullName,

      roleKey: AuthService.roleDriver,

      subtitle: '${driver.driverId} · ${driver.routeName}',

      kind: StaffKind.driver,

      rawId: driver.driverId,

    );

  }



  static StaffMemberOption? fromAdmin(AdminStaffRecord? admin) {

    if (admin == null) return null;

    return StaffMemberOption(

      id: adminKey(admin.adminId),

      displayName: admin.fullName,

      roleKey: AuthService.roleAdmin,

      subtitle: '${admin.adminId} · ${admin.position}',

      kind: StaffKind.adminStaff,

      rawId: admin.adminId,

    );

  }



  static String? viewerStaffId(String? roleKey) {
    final user = AuthService.currentUser;
    if (user == null || roleKey == null) return null;

    if (roleKey == AuthService.roleTeacher) {
      final linked = user.linkedTeacherId?.trim();
      if (linked != null && linked.isNotEmpty) {
        return teacherKey(linked);
      }
      final record = TeacherRegistryService.instance.resolveForAuthUser(
        linkedTeacherId: user.linkedTeacherId,
        username: user.username,
        phone: user.phone,
        schoolId: AuthService.activeSchoolId ?? user.schoolId,
      );
      final resolved = record?.teacherId.trim();
      if (resolved != null && resolved.isNotEmpty) {
        return teacherKey(resolved);
      }
    }

    if (roleKey == AuthService.roleDriver) {
      final linked = user.linkedDriverId?.trim();
      if (linked != null && linked.isNotEmpty) {
        return driverKey(linked);
      }
      final record = DriverRegistryService.instance.resolveForAuthUser(
        linkedDriverId: user.linkedDriverId,
        username: user.username,
        phone: user.phone,
        schoolId: AuthService.activeSchoolId ?? user.schoolId,
      );
      final resolved = record?.driverId.trim();
      if (resolved != null && resolved.isNotEmpty) {
        return driverKey(resolved);
      }
    }

    return null;
  }

  static String? viewerAdminStaffId(String? roleKey) {
    if (roleKey != AuthService.roleAdmin) return null;
    final user = AuthService.currentUser;
    if (user?.linkedAdminId != null && user!.linkedAdminId!.trim().isNotEmpty) {
      return adminKey(user.linkedAdminId!);
    }
    final schoolId = AuthService.activeSchoolId ?? user?.schoolId;
    for (final admin in AdminRegistryService.instance.getAllAdmins()) {
      if (schoolId != null &&
          admin.schoolId.trim().toUpperCase() != schoolId.trim().toUpperCase()) {
        continue;
      }
      final phone = user?.phone?.trim();
      if (phone != null &&
          phone.isNotEmpty &&
          admin.phone?.trim() == phone) {
        return adminKey(admin.adminId);
      }
    }
    return null;
  }

  /// Staff id for the signed-in viewer (admin, teacher, or driver).
  static String? viewerCompositeStaffId(String? roleKey) {
    if (roleKey == AuthService.roleAdmin) {
      return viewerAdminStaffId(roleKey);
    }
    return viewerStaffId(roleKey);
  }



  String get conversationRole => switch (kind) {

        StaffKind.teacher => 'Teacher',

        StaffKind.driver => 'Driver',

        StaffKind.adminStaff => 'Admin',

      };



  bool matchesQuery(String query) {

    final q = query.trim().toLowerCase();

    if (q.isEmpty) return true;

    final fields = [displayName, id, rawId, subtitle, roleKey];

    return fields.any((value) => value.toLowerCase().contains(q));

  }

}



class ParentRecipientOption {

  const ParentRecipientOption({

    required this.parentName,

    required this.studentNames,

    required this.studentIds,

    this.parentUsername,

    this.parentUsernames = const [],

  });



  final String parentName;

  final List<String> studentNames;

  final List<String> studentIds;

  final String? parentUsername;
  final List<String> parentUsernames;

  /// Login usernames that should be stamped on the conversation document.
  List<String> get participantUsernames {
    final fromList = parentUsernames
        .map((u) => u.trim().toLowerCase())
        .where((u) => u.isNotEmpty)
        .toSet()
        .toList();
    if (fromList.isNotEmpty) return fromList;
    final single = parentUsername?.trim().toLowerCase();
    if (single == null || single.isEmpty) return const [];
    return [single];
  }



  String displayLabel() {

    if (studentNames.length == 1) {

      return '$parentName (${studentNames.first})';

    }

    return '$parentName (${studentNames.join(', ')})';

  }



  String get searchDetail {

    final ids = studentIds.join(', ');

    return '$ids · ${studentNames.join(', ')}';

  }



  bool matchesQuery(String query) {

    final q = query.trim().toLowerCase();

    if (q.isEmpty) return true;

    if (parentName.toLowerCase().contains(q)) return true;

    for (final name in studentNames) {

      if (name.toLowerCase().contains(q)) return true;

    }

    for (final id in studentIds) {

      if (id.toLowerCase().contains(q)) return true;

    }

    final username = parentUsername?.trim().toLowerCase();

    if (username != null && username.isNotEmpty && username.contains(q)) {

      return true;

    }

    return false;

  }

}



class GroupMessageDraft {

  const GroupMessageDraft({

    required this.groupName,

    required this.body,

    required this.parentNames,

    required this.staffIds,

    this.subject,

    this.photoPath,

    this.attachments = const [],

  });



  final String groupName;

  final String body;

  final String? subject;

  final List<String> parentNames;

  final List<String> staffIds;

  final String? photoPath;

  final List<AnnouncementAttachment> attachments;

}



class DirectMessageDraft {

  const DirectMessageDraft({

    required this.body,

    this.subject,

    this.parentName,

    this.staffId,

    this.attachments = const [],

  });



  final String body;

  final String? subject;

  final String? parentName;

  final String? staffId;

  final List<AnnouncementAttachment> attachments;

}



class GroupMemberEntry {

  const GroupMemberEntry({

    required this.key,

    required this.displayName,

    required this.subtitle,

    required this.typeLabel,

    required this.isParent,

  });



  final String key;

  final String displayName;

  final String subtitle;

  final String typeLabel;

  final bool isParent;

}

