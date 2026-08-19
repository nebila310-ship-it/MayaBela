import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/message.dart';

/// Firestore-serializable conversation document.
class ConversationDocument {
  ConversationDocument({
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
    this.linkedStudentIds = const [],
    this.parentParticipantUsernames = const [],
    this.schoolId,
  });

  final String id;
  final String name;
  final String role;
  final List<ChatMessage> messages;
  final int unread;
  final bool isBroadcast;
  final List<String> broadcastAudienceKeys;
  final bool isGroup;
  final List<String> groupParentNames;
  final List<String> groupStaffIds;
  final String? photoPath;
  final bool usesCustomGroupName;
  final String? parentParticipantName;
  final String? staffParticipantId;
  final String? counterpartyStaffId;
  final String? staffSubjectName;
  final List<String> linkedStudentIds;
  final List<String> parentParticipantUsernames;
  final String? schoolId;

  factory ConversationDocument.fromConversation(Conversation c, {String? schoolId}) {
    return ConversationDocument(
      id: c.id,
      name: c.name,
      role: c.role,
      messages: List<ChatMessage>.from(c.messages),
      unread: c.unread,
      isBroadcast: c.isBroadcast,
      broadcastAudienceKeys: List<String>.from(c.broadcastAudienceKeys),
      isGroup: c.isGroup,
      groupParentNames: List<String>.from(c.groupParentNames),
      groupStaffIds: List<String>.from(c.groupStaffIds),
      photoPath: c.photoPath,
      usesCustomGroupName: c.usesCustomGroupName,
      parentParticipantName: c.parentParticipantName,
      staffParticipantId: c.staffParticipantId,
      counterpartyStaffId: c.counterpartyStaffId,
      staffSubjectName: c.staffSubjectName,
      linkedStudentIds: List<String>.from(c.linkedStudentIds),
      parentParticipantUsernames: List<String>.from(c.parentParticipantUsernames),
      schoolId: schoolId,
    );
  }

  Conversation toConversation() {
    return Conversation(
      id: id,
      name: name,
      role: role,
      messages: messages,
      unread: unread,
      isBroadcast: isBroadcast,
      broadcastAudienceKeys: broadcastAudienceKeys,
      isGroup: isGroup,
      groupParentNames: groupParentNames,
      groupStaffIds: groupStaffIds,
      photoPath: photoPath,
      usesCustomGroupName: usesCustomGroupName,
      parentParticipantName: parentParticipantName,
      staffParticipantId: staffParticipantId,
      counterpartyStaffId: counterpartyStaffId,
      staffSubjectName: staffSubjectName,
      linkedStudentIds: linkedStudentIds,
      parentParticipantUsernames: parentParticipantUsernames,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role,
        'messages': messages.map(_messageToMap).toList(),
        'unread': unread,
        'isBroadcast': isBroadcast,
        'broadcastAudienceKeys': broadcastAudienceKeys,
        'isGroup': isGroup,
        'groupParentNames': groupParentNames,
        'groupStaffIds': groupStaffIds,
        if (photoPath != null) 'photoPath': photoPath,
        'usesCustomGroupName': usesCustomGroupName,
        if (parentParticipantName != null)
          'parentParticipantName': parentParticipantName,
        if (staffParticipantId != null) 'staffParticipantId': staffParticipantId,
        if (counterpartyStaffId != null)
          'counterpartyStaffId': counterpartyStaffId,
        if (staffSubjectName != null) 'staffSubjectName': staffSubjectName,
        'linkedStudentIds': linkedStudentIds,
        'parentParticipantUsernames': parentParticipantUsernames,
        if (schoolId != null) 'schoolId': schoolId,
      };

  factory ConversationDocument.fromMap(Map<String, dynamic> map) {
    return ConversationDocument(
      id: map['id'] as String? ?? map['_docId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? '',
      messages: (map['messages'] as List<dynamic>? ?? const [])
          .map((e) => _messageFromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      unread: map['unread'] as int? ?? 0,
      isBroadcast: map['isBroadcast'] as bool? ?? false,
      broadcastAudienceKeys: (map['broadcastAudienceKeys'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isGroup: map['isGroup'] as bool? ?? false,
      groupParentNames: (map['groupParentNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      groupStaffIds: (map['groupStaffIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      photoPath: map['photoPath'] as String?,
      usesCustomGroupName: map['usesCustomGroupName'] as bool? ?? false,
      parentParticipantName: map['parentParticipantName'] as String?,
      staffParticipantId: map['staffParticipantId'] as String?,
      counterpartyStaffId: map['counterpartyStaffId'] as String?,
      staffSubjectName: map['staffSubjectName'] as String?,
      linkedStudentIds: (map['linkedStudentIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      parentParticipantUsernames:
          (map['parentParticipantUsernames'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
      schoolId: map['schoolId'] as String?,
    );
  }

  static Map<String, dynamic> _messageToMap(ChatMessage m) => {
        'text': m.text,
        'time': m.time.toIso8601String(),
        'senderRole': m.senderRole,
        if (m.seenAt != null) 'seenAt': m.seenAt!.toIso8601String(),
        if (m.subject != null) 'subject': m.subject,
        if (m.senderStaffId != null) 'senderStaffId': m.senderStaffId,
        if (m.senderDisplayName != null)
          'senderDisplayName': m.senderDisplayName,
        if (m.senderUsername != null) 'senderUsername': m.senderUsername,
        if (m.senderRelationshipLabel != null)
          'senderRelationshipLabel': m.senderRelationshipLabel,
        'attachments': m.attachments
            .map(
              (a) => {
                'id': a.id,
                'fileName': a.fileName,
                'filePath': a.filePath,
                if (a.fileSizeBytes != null) 'fileSizeBytes': a.fileSizeBytes,
              },
            )
            .toList(),
        if (m.replyTo != null)
          'replyTo': {
            'senderDisplayName': m.replyTo!.senderDisplayName,
            'previewText': m.replyTo!.previewText,
          },
      };

  static ChatMessage _messageFromMap(Map<String, dynamic> map) {
    MessageReplyQuote? replyTo;
    final replyMap = map['replyTo'];
    if (replyMap is Map) {
      replyTo = MessageReplyQuote(
        senderDisplayName: replyMap['senderDisplayName'] as String? ?? '',
        previewText: replyMap['previewText'] as String? ?? '',
      );
    }
    return ChatMessage(
      text: map['text'] as String? ?? '',
      time: DateTime.tryParse(map['time'] as String? ?? '') ?? DateTime.now(),
      senderRole: map['senderRole'] as String? ?? '',
      seenAt: map['seenAt'] != null
          ? DateTime.tryParse(map['seenAt'] as String)
          : null,
      subject: map['subject'] as String?,
      senderStaffId: map['senderStaffId'] as String?,
      senderDisplayName: map['senderDisplayName'] as String?,
      senderUsername: map['senderUsername'] as String?,
      senderRelationshipLabel: map['senderRelationshipLabel'] as String?,
      attachments: (map['attachments'] as List<dynamic>? ?? const [])
          .map(
            (e) => AnnouncementAttachment(
              id: (e as Map)['id'] as String? ?? '',
              fileName: e['fileName'] as String? ?? '',
              filePath: e['filePath'] as String? ?? '',
              fileSizeBytes: e['fileSizeBytes'] as int?,
            ),
          )
          .toList(),
      replyTo: replyTo,
    );
  }
}
