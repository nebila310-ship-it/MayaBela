import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/school_data_service.dart';

/// Persists messaging conversations locally and syncs to Firestore.
class MessagePersistenceService {
  MessagePersistenceService._();
  static final instance = MessagePersistenceService._();

  static const _conversationsKey = 'persisted_conversations';

  Future<void> loadIntoSchoolDataService() async {
    final rows = await LocalJsonStore.readList(_conversationsKey);
    if (rows.isEmpty) return;

    final parsed = <Conversation>[];
    for (final map in rows) {
      try {
        parsed.add(
          ConversationDocumentLite.fromMap(map).toConversation(),
        );
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      SchoolDataService.instance.applyPersistedConversations(parsed);
    }
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    final conversations = SchoolDataService.instance.getConversations();
    await LocalJsonStore.writeList(
      _conversationsKey,
      conversations
          .map((c) => ConversationDocumentLite.fromConversation(c).toMap())
          .toList(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllConversations();
    }
  }

  Future<void> saveConversation(
    Conversation conversation, {
    bool requireCloud = false,
  }) async {
    await saveFromService(pushCloud: false);
    await CloudAppStore.instance.pushConversation(
      conversation,
      requireCloud: requireCloud,
    );
  }
}

/// Lightweight local JSON serializer (mirrors Firestore conversation document).
class ConversationDocumentLite {
  ConversationDocumentLite({
    required this.id,
    required this.name,
    required this.role,
    required this.messagesJson,
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
  });

  final String id;
  final String name;
  final String role;
  final List<Map<String, dynamic>> messagesJson;
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

  factory ConversationDocumentLite.fromConversation(Conversation c) {
    return ConversationDocumentLite(
      id: c.id,
      name: c.name,
      role: c.role,
      messagesJson: c.messages
          .map(
            (m) => {
              'text': m.text,
              'time': m.time.toIso8601String(),
              'senderRole': m.senderRole,
              if (m.seenAt != null) 'seenAt': m.seenAt!.toIso8601String(),
              if (m.senderStaffId != null) 'senderStaffId': m.senderStaffId,
              if (m.senderDisplayName != null)
                'senderDisplayName': m.senderDisplayName,
              if (m.senderUsername != null) 'senderUsername': m.senderUsername,
            },
          )
          .toList(),
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
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role,
        'messages': messagesJson,
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
      };

  factory ConversationDocumentLite.fromMap(Map<String, dynamic> map) {
    return ConversationDocumentLite(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? '',
      messagesJson: (map['messages'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
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
    );
  }

  Conversation toConversation() {
    return Conversation(
      id: id,
      name: name,
      role: role,
      messages: messagesJson
          .map(
            (m) => ChatMessage(
              text: m['text'] as String? ?? '',
              time: DateTime.tryParse(m['time'] as String? ?? '') ??
                  DateTime.now(),
              senderRole: m['senderRole'] as String? ?? '',
              seenAt: m['seenAt'] != null
                  ? DateTime.tryParse(m['seenAt'] as String)
                  : null,
              senderStaffId: m['senderStaffId'] as String?,
              senderDisplayName: m['senderDisplayName'] as String?,
              senderUsername: m['senderUsername'] as String?,
            ),
          )
          .toList(),
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
}
