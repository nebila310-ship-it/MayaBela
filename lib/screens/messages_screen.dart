import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/community_photo_service.dart';
import 'package:mayabela/services/messaging_access_service.dart';
import 'package:mayabela/services/presence_service.dart';
import 'package:mayabela/services/cloud/conversation_realtime_sync.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/voice_playback_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/screens/parent_compose_message_screen.dart';
import 'package:mayabela/widgets/chat_contact_profile.dart';
import 'package:mayabela/widgets/inbox_login_reminder.dart';
import 'package:mayabela/widgets/maya_floating_chat.dart';
import 'package:mayabela/widgets/messages_ui.dart';
import 'package:mayabela/widgets/message_voice_input_bar.dart';
import 'package:mayabela/widgets/attachment_share_actions.dart';
import 'package:mayabela/widgets/voice_message_player.dart';

enum MessageComposeScope { admin, teacher }

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    this.canCompose = false,
    this.composeScope = MessageComposeScope.admin,
  });

  final bool canCompose;
  final MessageComposeScope composeScope;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin {
  final _data = SchoolDataService.instance;
  late final TabController _tabs;

  MessageComposeScope get _composeScope {
    if (AuthService.currentUser?.roleKey == AuthService.roleAdmin ||
        MessagingAccessService.hasSchoolWideMessaging()) {
      return MessageComposeScope.admin;
    }
    if (AuthService.currentUser?.roleKey == AuthService.roleTeacher) {
      return MessageComposeScope.teacher;
    }
    return widget.composeScope;
  }

  bool get _canCompose {
    if (widget.canCompose) return true;
    if (MessagingAccessService.hasSchoolWideMessaging()) return true;
    return AuthService.currentUser?.roleKey == AuthService.roleTeacher;
  }

  List<Conversation> get _conversations {
    final role = AuthService.currentUser?.roleKey;
    return _data.getConversationsForRole(role);
  }

  @override
  void initState() {
    super.initState();
    unawaited(InboxLoginReminder.acknowledgeCurrent());
    ConversationRealtimeSync.instance.addListener(_refresh);
    PresenceService.instance.startForCurrentUser();
    PresenceService.instance.noteFromConversations(_conversations);
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    ConversationRealtimeSync.instance.removeListener(_refresh);
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() {
    PresenceService.instance.noteFromConversations(_conversations);
    setState(() {});
  }

  void _openChat(Conversation conversation) {
    _data.markConversationRead(conversation.id);
    setState(() => conversation.unread = 0);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversation.id,
          contactName: conversation.inboxTitleForViewer(),
          isBroadcast: conversation.isBroadcast,
          isGroup: conversation.isGroup,
        ),
      ),
    ).then((_) => _refresh());
  }

  Future<void> _createCommunity() async {
    final draft = await Navigator.push<GroupMessageDraft>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateCommunityMessageScreen(composeScope: _composeScope),
      ),
    );
    if (draft == null || !mounted) return;

    final sent = _data.sendAdminGroupMessage(
      parentNames: draft.parentNames,
      staffIds: draft.staffIds,
      body: draft.body,
      subject: draft.subject,
      groupName: draft.groupName,
      photoPath: draft.photoPath,
      attachments: draft.attachments,
    );
    _refresh();
    _showSendResult(sent.isNotEmpty);
  }

  Future<void> _directChat() async {
    final draft = await Navigator.push<DirectMessageDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => DirectMessageScreen(composeScope: _composeScope),
      ),
    );
    if (draft == null || !mounted) return;

    final sent = _data.sendAdminDirectMessage(
      parentName: draft.parentName,
      staffId: draft.staffId,
      body: draft.body,
      subject: draft.subject,
      attachments: draft.attachments,
    );
    var ok = sent.isNotEmpty;
    if (ok) {
      ok = await _data.persistConversationToCloud(sent.single);
    }
    _refresh();
    if (!ok && sent.isEmpty && draft.parentName != null) {
      _showSendResult(false, classCheck: true);
      return;
    }
    _showSendResult(ok);
  }

  Future<void> _parentCompose() async {
    final conversationId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ParentComposeMessageScreen()),
    );
    if (!mounted || conversationId == null) return;
    _refresh();
    final conversation = _data.getConversation(conversationId);
    if (conversation != null) {
      _openChat(conversation);
    }
  }

  void _showSendResult(bool sent, {bool classCheck = false}) {
    if (sent) {
      _showSentSnackBar();
      return;
    }
    final s = AppLocale.instance.strings;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          classCheck
              ? s.messageParentNotInClasses
              : (_data.lastConversationPersistError ?? s.messageSendFailed),
        ),
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
  }

  void _showSentSnackBar() {
    final s = AppLocale.instance.strings;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.messageSent),
        backgroundColor: const Color(0xFF15803D),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.day}/${time.month}';
  }

  Widget _inboxList(
    BuildContext context, {
    required List<Conversation> chats,
    required bool empty,
    required AppStrings s,
    required bool showCompose,
  }) {
    final bottomPad =
        MayaFloatingChat.pageEndClearance +
        (showCompose ? MayaFloatingChat.stackedFabLift : 0);
    if (chats.isEmpty) {
      return ListView(
        padding: EdgeInsets.only(bottom: bottomPad),
        children: [
          const SizedBox(height: 48),
          if (empty) _EmptyMessagesHeader(),
          if (!empty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                s.startConversation,
                textAlign: TextAlign.center,
                style: TextStyle(color: MessagesPalette.muted),
              ),
            ),
        ],
      );
    }
    return ListView.separated(
      padding: EdgeInsets.only(bottom: bottomPad),
      itemCount: chats.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 76, color: Color(0xFFE9EDEF)),
      itemBuilder: (context, index) {
        final chat = chats[index];
        return ConversationCard(
          conversation: chat,
          timeLabel: _formatTime(
            chat.messages.isEmpty ? DateTime.now() : chat.messages.last.time,
          ),
          audienceLabelBuilder: s.messageAudienceKey,
          onTap: () => _openChat(chat),
        );
      },
    );
  }

  Future<void> _showComposeSheet(BuildContext context) async {
    final s = AppLocale.instance.strings;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(s.directChat),
              onTap: () => Navigator.pop(context, 'direct'),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(s.createGroup),
              onTap: () => Navigator.pop(context, 'group'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'direct') {
      await _directChat();
    } else if (choice == 'group') {
      await _createCommunity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final chats = _conversations;
        final isParent =
            AuthService.currentUser?.roleKey == AuthService.roleParent;
        final showCompose = _canCompose || isParent;
        final broadcasts = chats.where((c) => c.isBroadcast).toList();
        final groups = chats.where((c) => c.isGroup && !c.isBroadcast).toList();
        final direct = chats
            .where((c) => !c.isBroadcast && !c.isGroup)
            .toList();

        return Scaffold(
          backgroundColor: MessagesPalette.listBg,
          appBar: MessagesAppBar(
            title: s.dashboardTitle('messages'),
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: [
                Tab(text: s.messageChatsTab),
                Tab(text: s.messageGroupChats),
                Tab(text: s.messageBroadcasts),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _inboxList(
                context,
                chats: direct,
                empty: chats.isEmpty,
                s: s,
                showCompose: showCompose,
              ),
              _inboxList(
                context,
                chats: groups,
                empty: false,
                s: s,
                showCompose: showCompose,
              ),
              _inboxList(
                context,
                chats: broadcasts,
                empty: false,
                s: s,
                showCompose: showCompose,
              ),
            ],
          ),
          floatingActionButton: !showCompose
              ? null
              : Padding(
                  padding: const EdgeInsets.only(
                    bottom: MayaFloatingChat.stackedFabLift,
                  ),
                  child: FloatingActionButton(
                    key: const Key('messages-compose-fab'),
                    heroTag: 'messages-compose-fab',
                    backgroundColor: MessagesPalette.fab,
                    foregroundColor: Colors.white,
                    onPressed: isParent
                        ? _parentCompose
                        : () => _showComposeSheet(context),
                    child: Icon(
                      isParent ? Icons.message_rounded : Icons.add_rounded,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _EmptyMessagesHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MessagesPalette.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            size: 48,
            color: MessagesPalette.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          s.noConversations,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
        ),
      ],
    );
  }
}

class CreateCommunityMessageScreen extends StatefulWidget {
  const CreateCommunityMessageScreen({
    super.key,
    this.composeScope = MessageComposeScope.admin,
  });

  final MessageComposeScope composeScope;

  @override
  State<CreateCommunityMessageScreen> createState() =>
      _CreateCommunityMessageScreenState();
}

class _CreateCommunityMessageScreenState
    extends State<CreateCommunityMessageScreen> {
  final _data = SchoolDataService.instance;
  final _groupName = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final Set<String> _selectedParentNames = {};
  final Set<String> _selectedStaffIds = {};
  String? _photoPath;
  bool _pickingPhoto = false;
  String _error = '';
  bool _pickingAttachment = false;
  final List<AnnouncementAttachment> _attachments = [];

  List<ParentRecipientOption> get _parents =>
      MessagingAccessService.parentsForCurrentCompose();

  List<StaffMemberOption> get _staff =>
      MessagingAccessService.staffForCurrentCompose();

  @override
  void dispose() {
    _groupName.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    setState(() => _pickingPhoto = true);
    final path = await CommunityPhotoService.instance.pickAndSave();
    if (!mounted) return;
    setState(() {
      _pickingPhoto = false;
      if (path != null) _photoPath = path;
    });
  }

  Future<void> _pickAttachments() async {
    if (_pickingAttachment) return;
    setState(() => _pickingAttachment = true);
    final picked = await AnnouncementAttachmentService.instance
        .pickAndSaveMessageAttachments();
    if (!mounted) return;
    setState(() {
      _pickingAttachment = false;
      _attachments.addAll(picked);
    });
  }

  void _send() {
    final s = AppLocale.instance.strings;
    if (_groupName.text.trim().isEmpty) {
      setState(() => _error = s.communityNameRequired);
      return;
    }
    if (widget.composeScope == MessageComposeScope.teacher) {
      if (_selectedParentNames.isEmpty && _selectedStaffIds.isEmpty) {
        setState(() => _error = s.messageRecipientsRequired);
        return;
      }
    } else if (_selectedParentNames.isEmpty && _selectedStaffIds.isEmpty) {
      setState(() => _error = s.messageRecipientsRequired);
      return;
    }
    if (_body.text.trim().isEmpty && _attachments.isEmpty) {
      setState(() => _error = s.messageBodyRequired);
      return;
    }

    Navigator.pop(
      context,
      GroupMessageDraft(
        groupName: _groupName.text.trim(),
        subject: _subject.text.trim(),
        body: _body.text.trim(),
        parentNames: _selectedParentNames.toList(),
        staffIds: _selectedStaffIds.toList(),
        photoPath: _photoPath,
        attachments: List.unmodifiable(_attachments),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          backgroundColor: CommunityPalette.surface,
          appBar: MessagesAppBar(
            title: s.createGroup,
            useCommunityTheme: true,
            actions: [
              TextButton(
                onPressed: _send,
                child: Text(
                  s.send,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(gradient: CommunityPalette.pageGradient),
            child: SingleChildScrollView(
              padding: listPagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: CommunityPalette.accent.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: CommunityPalette.primary.withValues(
                            alpha: 0.1,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          s.createGroupHint,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _groupName,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: adminFieldDecoration(
                            label: s.communityNameLabel,
                            icon: Icons.groups_2_outlined,
                            accent: CommunityPalette.primary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        CommunityPhotoPicker(
                          photoPath: _photoPath,
                          picking: _pickingPhoto,
                          onPick: _pickPhoto,
                          onRemove: () => setState(() => _photoPath = null),
                        ),
                        const SizedBox(height: 18),
                        if (_parents.isNotEmpty) ...[
                          Text(
                            s.messageParentsOptional,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.messageSearchParentHint,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          MessageParentPicker(
                            parents: _parents,
                            selectedNames: _selectedParentNames,
                            onChanged: (value) => setState(() {
                              _selectedParentNames
                                ..clear()
                                ..addAll(value);
                              _error = '';
                            }),
                          ),
                        ],
                        if (widget.composeScope ==
                            MessageComposeScope.teacher) ...[
                          const SizedBox(height: 18),
                          Text(
                            s.adminLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.messageSearchStaffHint,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          MessageStaffPicker(
                            staff: _staff,
                            selectedIds: _selectedStaffIds,
                            onChanged: (value) => setState(() {
                              _selectedStaffIds
                                ..clear()
                                ..addAll(value);
                              _error = '';
                            }),
                          ),
                        ] else ...[
                          const SizedBox(height: 18),
                          Text(
                            s.messageStaffOptional,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.messageSearchStaffHint,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          MessageStaffPicker(
                            staff: _staff,
                            selectedIds: _selectedStaffIds,
                            onChanged: (value) => setState(() {
                              _selectedStaffIds
                                ..clear()
                                ..addAll(value);
                              _error = '';
                            }),
                          ),
                        ],
                        const SizedBox(height: 18),
                        TextField(
                          controller: _subject,
                          decoration: adminFieldDecoration(
                            label: s.messageSubjectOptional,
                            icon: Icons.subject_rounded,
                            accent: CommunityPalette.primary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_attachments.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: PendingAttachmentRow(
                              attachments: _attachments,
                              onRemove: (attachment) => setState(() {
                                _attachments.removeWhere(
                                  (a) => a.id == attachment.id,
                                );
                              }),
                            ),
                          ),
                        MessageVoiceInputBar(
                          controller: _body,
                          accent: CommunityPalette.primary,
                          pickingAttachment: _pickingAttachment,
                          onPickAttachment: _pickAttachments,
                          onSend: _send,
                          onSendVoice: (attachment) =>
                              setState(() => _attachments.add(attachment)),
                          hintText: s.messageLabel,
                        ),
                      ],
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_error, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DirectMessageScreen extends StatefulWidget {
  const DirectMessageScreen({
    super.key,
    this.composeScope = MessageComposeScope.admin,
  });

  final MessageComposeScope composeScope;

  @override
  State<DirectMessageScreen> createState() => _DirectMessageScreenState();
}

class _DirectMessageScreenState extends State<DirectMessageScreen> {
  final _data = SchoolDataService.instance;
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final Set<String> _selectedParentNames = {};
  final Set<String> _selectedStaffIds = {};
  String _error = '';
  bool _pickingAttachment = false;
  final List<AnnouncementAttachment> _attachments = [];

  List<ParentRecipientOption> get _parents =>
      MessagingAccessService.parentsForCurrentCompose();

  List<StaffMemberOption> get _staff =>
      MessagingAccessService.staffForCurrentCompose();

  Future<void> _pickAttachments() async {
    if (_pickingAttachment) return;
    setState(() => _pickingAttachment = true);
    final picked = await AnnouncementAttachmentService.instance
        .pickAndSaveMessageAttachments();
    if (!mounted) return;
    setState(() {
      _pickingAttachment = false;
      _attachments.addAll(picked);
    });
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _send() {
    final s = AppLocale.instance.strings;
    final hasParent = _selectedParentNames.isNotEmpty;
    final hasStaff = _selectedStaffIds.isNotEmpty;
    if (widget.composeScope == MessageComposeScope.teacher) {
      if (hasParent == hasStaff) {
        setState(() => _error = s.messageDirectRecipientRequired);
        return;
      }
    } else if (hasParent == hasStaff) {
      setState(() => _error = s.messageDirectRecipientRequired);
      return;
    }
    if (_body.text.trim().isEmpty && _attachments.isEmpty) {
      setState(() => _error = s.messageBodyRequired);
      return;
    }

    Navigator.pop(
      context,
      DirectMessageDraft(
        subject: _subject.text.trim(),
        body: _body.text.trim(),
        parentName: hasParent ? _selectedParentNames.first : null,
        staffId: hasStaff ? _selectedStaffIds.first : null,
        attachments: List.unmodifiable(_attachments),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          backgroundColor: const Color(0xFFEEF2FF),
          appBar: MessagesAppBar(
            title: s.directChat,
            actions: [
              TextButton(
                onPressed: _send,
                child: Text(
                  s.send,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(gradient: MessagesPalette.pageGradient),
            child: SingleChildScrollView(
              padding: listPagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: MessagesPalette.accent.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MessagesPalette.primary.withValues(
                            alpha: 0.08,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          s.directChatHint,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_parents.isNotEmpty) ...[
                          Text(
                            s.messageSelectParent,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          MessageParentPicker(
                            parents: _parents,
                            selectedNames: _selectedParentNames,
                            multiSelect: false,
                            onChanged: (value) => setState(() {
                              _selectedParentNames
                                ..clear()
                                ..addAll(value);
                              if (value.isNotEmpty) _selectedStaffIds.clear();
                              _error = '';
                            }),
                          ),
                          const SizedBox(height: 18),
                        ],
                        Text(
                          s.messageSelectStaff,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        MessageStaffPicker(
                          staff: _staff,
                          selectedIds: _selectedStaffIds,
                          multiSelect: false,
                          onChanged: (value) => setState(() {
                            _selectedStaffIds
                              ..clear()
                              ..addAll(value);
                            if (value.isNotEmpty) _selectedParentNames.clear();
                            _error = '';
                          }),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _subject,
                          decoration: adminFieldDecoration(
                            label: s.messageSubjectOptional,
                            icon: Icons.subject_rounded,
                            accent: MessagesPalette.primary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_attachments.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: PendingAttachmentRow(
                              attachments: _attachments,
                              onRemove: (attachment) => setState(() {
                                _attachments.removeWhere(
                                  (a) => a.id == attachment.id,
                                );
                              }),
                            ),
                          ),
                        MessageVoiceInputBar(
                          controller: _body,
                          accent: MessagesPalette.primary,
                          pickingAttachment: _pickingAttachment,
                          onPickAttachment: _pickAttachments,
                          onSend: _send,
                          onSendVoice: (attachment) =>
                              setState(() => _attachments.add(attachment)),
                          hintText: s.messageLabel,
                        ),
                      ],
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_error, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.contactName,
    this.isBroadcast = false,
    this.isGroup = false,
  });

  final String conversationId;
  final String contactName;
  final bool isBroadcast;
  final bool isGroup;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _data = SchoolDataService.instance;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _pendingAttachments = <AnnouncementAttachment>[];
  bool _pickingAttachment = false;
  ChatMessage? _replyTarget;

  Conversation? get conversation =>
      _data.getConversation(widget.conversationId);

  String? get _viewerRole => AuthService.currentUser?.roleKey;

  String? get _viewerStaffId {
    if (_viewerRole == AuthService.roleAdmin) {
      return StaffMemberOption.viewerAdminStaffId(_viewerRole);
    }
    return StaffMemberOption.viewerStaffId(_viewerRole);
  }

  bool _isOutgoing(ChatMessage msg) => msg.isOutgoingFor(
    _viewerRole,
    viewerStaffId: _viewerStaffId,
    viewerUsername: AuthService.currentUser?.username,
  );

  bool get _canReply {
    if (widget.isBroadcast) {
      return _viewerRole == AuthService.roleAdmin;
    }
    return true;
  }

  String? _directIncomingSenderLabel(ChatMessage msg, Conversation? chat) {
    if (widget.isGroup || widget.isBroadcast || chat == null) return null;
    if (isOutgoingForMessage(msg)) return null;

    if (msg.senderRole == AuthService.roleParent) {
      return chat.parentSenderLabelForStaff();
    }

    if (_viewerRole == AuthService.roleParent) {
      return chat.displayTitleForViewer(viewerRole: _viewerRole);
    }

    return msg.resolveDisplayName();
  }

  bool isOutgoingForMessage(ChatMessage msg) => _isOutgoing(msg);

  @override
  void initState() {
    super.initState();
    ConversationRealtimeSync.instance.addListener(_onLiveUpdate);
    _markSeen();
  }

  @override
  void dispose() {
    ConversationRealtimeSync.instance.removeListener(_onLiveUpdate);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onLiveUpdate() {
    if (!mounted) return;
    setState(() {});
    _markSeen();
  }

  void _markSeen() {
    _data.markMessagesSeenByViewer(widget.conversationId);
    if (mounted) setState(() {});
  }

  void _startReply(ChatMessage msg) {
    if (!_canReply) return;
    setState(() => _replyTarget = msg);
  }

  void _clearReply() => setState(() => _replyTarget = null);

  void _send({List<AnnouncementAttachment>? attachments, String? text}) {
    if (!_canReply) return;
    final messageText = text ?? _controller.text.trim();
    final attachmentList =
        attachments ?? List.unmodifiable(_pendingAttachments);
    if (messageText.isEmpty && attachmentList.isEmpty) return;

    final replyTo = _replyTarget == null
        ? null
        : MessageReplyQuote.fromMessage(_replyTarget!);

    _data.sendMessage(
      widget.conversationId,
      messageText.isEmpty ? 'Voice message' : messageText,
      attachments: attachmentList,
      replyTo: replyTo,
    );
    _controller.clear();
    _pendingAttachments.clear();
    _replyTarget = null;
    setState(() {});
    unawaited(_pushSentMessage());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pushSentMessage() async {
    final ok = await _data.persistConversationToCloud(widget.conversationId);
    if (ok || !mounted) return;
    final s = AppLocale.instance.strings;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _data.lastConversationPersistError ?? s.messageSendFailed,
        ),
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
  }

  Future<void> _confirmDeleteMessage(int index) async {
    final s = AppLocale.instance.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteMessage),
        content: Text(s.deleteMessageConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.deleteMessage),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_data.deleteMessage(widget.conversationId, index)) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.messageDeleted)));
    }
  }

  Future<void> _pickAttachments() async {
    if (!_canReply || _pickingAttachment) return;
    setState(() => _pickingAttachment = true);
    final picked = await AnnouncementAttachmentService.instance
        .pickAndSaveMessageAttachments();
    if (!mounted) return;
    setState(() {
      _pickingAttachment = false;
      _pendingAttachments.addAll(picked);
    });
  }

  Future<void> _openAttachment(AnnouncementAttachment attachment) async {
    if (AnnouncementAttachmentService.instance.isVoiceAttachment(attachment)) {
      final ok = await VoicePlaybackService.instance.play(attachment.filePath);
      if (!mounted || ok) return;
      final s = AppLocale.instance.strings;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.voicePlaybackFailed)));
      return;
    }
    await openAttachmentWithFeedback(context, path: attachment.filePath);
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  bool get _canManageGroup =>
      widget.isGroup && _data.canManageCommunityGroup(widget.conversationId);

  void _showMembers() {
    CommunityMembersSheet.show(
      context,
      conversationId: widget.conversationId,
      canManage: _canManageGroup,
      onMemberTap: (member) {
        ChatContactProfileScreen.open(
          context,
          ChatContactDirectory.fromGroupMember(member),
        );
      },
      onChanged: () {
        if (!mounted) return;
        if (_data.getConversation(widget.conversationId) == null) {
          Navigator.pop(context);
          return;
        }
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = conversation;

    return ListenableBuilder(
      listenable: Listenable.merge([
        AppLocale.instance,
        PresenceService.instance,
      ]),
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final peerOnline = chat == null
            ? null
            : (widget.isGroup || widget.isBroadcast
                  ? null
                  : PresenceService.instance.isConversationPeerOnline(chat));
        return Scaffold(
          backgroundColor: MessagesPalette.chatWallpaper,
          appBar: MessagesAppBar(
            titleKey: const Key('chat-app-bar-title'),
            title: chat?.inboxTitleForViewer() ?? widget.contactName,
            subtitle: chat?.chatBarSubtitleForViewer(),
            peerOnline: peerOnline,
            photoPath: widget.isGroup ? chat?.photoPath : null,
            onTitleTap: chat == null
                ? null
                : () {
                    if (widget.isGroup) {
                      _showMembers();
                      return;
                    }
                    if (widget.isBroadcast) return;
                    ChatContactProfileScreen.openPeer(context, chat);
                  },
            actions: [
              if (widget.isGroup && _canManageGroup)
                IconButton(
                  tooltip: s.viewMembers,
                  onPressed: _showMembers,
                  icon: const Icon(Icons.people_outline, color: Colors.white),
                ),
            ],
          ),
          body: Stack(
            children: [
              const Positioned.fill(child: ChatWallpaper()),
              Column(
                children: [
                  if (widget.isBroadcast)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      color: MessagesPalette.warm.withValues(alpha: 0.12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            color: MessagesPalette.warm,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.messageBroadcastNotice,
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.isGroup)
                    Material(
                      color: CommunityPalette.primary.withValues(alpha: 0.1),
                      child: InkWell(
                        onTap: _canManageGroup ? _showMembers : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.diversity_3_outlined,
                                color: CommunityPalette.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.messageGroupNotice,
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_canManageGroup)
                                Text(
                                  s.viewMembers,
                                  style: const TextStyle(
                                    color: CommunityPalette.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: chat == null || chat.messages.isEmpty
                        ? Center(child: Text(s.startConversation))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                            itemCount: chat.messages.length,
                            itemBuilder: (context, index) {
                              final msg = chat.messages[index];
                              final isOutgoing = _isOutgoing(msg);
                              final bubbleColor = isOutgoing
                                  ? MessagesPalette.outgoingBubble
                                  : MessagesPalette.incomingBubble;
                              final accent = MessagesPalette.primary;
                              final senderLabel = _directIncomingSenderLabel(
                                msg,
                                chat,
                              );
                              return Align(
                                alignment: isOutgoing
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: SwipeToReplyMessage(
                                  isOutgoing: isOutgoing,
                                  enabled: _canReply,
                                  accent: accent,
                                  onReply: () => _startReply(msg),
                                  child: GestureDetector(
                                    onLongPress: isOutgoing
                                        ? () => _confirmDeleteMessage(index)
                                        : null,
                                    child: Container(
                                      margin: EdgeInsets.only(
                                        bottom: 4,
                                        left: isOutgoing ? 48 : 8,
                                        right: isOutgoing ? 8 : 48,
                                      ),
                                      padding: const EdgeInsets.fromLTRB(
                                        10,
                                        6,
                                        10,
                                        6,
                                      ),
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                            0.78,
                                      ),
                                      decoration: BoxDecoration(
                                        color: bubbleColor,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(12),
                                          topRight: const Radius.circular(12),
                                          bottomLeft: Radius.circular(
                                            isOutgoing ? 12 : 2,
                                          ),
                                          bottomRight: Radius.circular(
                                            isOutgoing ? 2 : 12,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.06,
                                            ),
                                            blurRadius: 1.5,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (senderLabel != null) ...[
                                            TappableSenderName(
                                              name: senderLabel,
                                              onTap: () =>
                                                  ChatContactProfileScreen.openFromMessage(
                                                    context,
                                                    msg,
                                                    conversation: chat,
                                                  ),
                                            ),
                                          ] else ...[
                                            if (msg.senderRelationshipLabel !=
                                                    null &&
                                                msg
                                                    .senderRelationshipLabel!
                                                    .isNotEmpty) ...[
                                              Text(
                                                msg.senderRelationshipLabel!,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 11,
                                                  color: MessagesPalette.colorForName(
                                                    msg.senderRelationshipLabel!,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                            ],
                                            if (widget.isGroup &&
                                                !isOutgoing) ...[
                                              TappableSenderName(
                                                name: msg.resolveDisplayName(),
                                                onTap: () =>
                                                    ChatContactProfileScreen.openFromMessage(
                                                      context,
                                                      msg,
                                                      conversation: chat,
                                                    ),
                                              ),
                                            ],
                                          ],
                                          if (msg.replyTo != null) ...[
                                            MessageReplyQuoteBubble(
                                              quote: msg.replyTo!,
                                              isOutgoing: isOutgoing,
                                              accent: accent,
                                            ),
                                          ],
                                          if (msg.subject != null &&
                                              msg.subject!.isNotEmpty) ...[
                                            Text(
                                              msg.subject!,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: MessagesPalette.ink,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                          ],
                                          if (msg.text.trim().isNotEmpty)
                                            Text(
                                              msg.text,
                                              style: const TextStyle(
                                                color: MessagesPalette.ink,
                                                height: 1.35,
                                                fontSize: 15,
                                              ),
                                            ),
                                          if (msg.attachments.isNotEmpty) ...[
                                            if (msg.text.trim().isNotEmpty)
                                              const SizedBox(height: 8),
                                            ...msg.attachments.map((
                                              attachment,
                                            ) {
                                              final attachmentService =
                                                  AnnouncementAttachmentService
                                                      .instance;
                                              if (attachmentService
                                                  .isVoiceAttachment(
                                                    attachment,
                                                  )) {
                                                return VoiceMessagePlayer(
                                                  attachment: attachment,
                                                  isOutgoing: isOutgoing,
                                                  accent:
                                                      MessagesPalette.primary,
                                                );
                                              }
                                              return MessageAttachmentChip(
                                                attachment: attachment,
                                                isOutgoing: isOutgoing,
                                                onTap: () =>
                                                    _openAttachment(attachment),
                                              );
                                            }),
                                          ],
                                          const SizedBox(height: 4),
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _formatTime(msg.time),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        MessagesPalette.muted,
                                                  ),
                                                ),
                                                if (isOutgoing) ...[
                                                  const SizedBox(width: 3),
                                                  Icon(
                                                    msg.seenAt != null
                                                        ? Icons.done_all
                                                        : Icons.check,
                                                    size: 16,
                                                    color: msg.seenAt != null
                                                        ? MessagesPalette
                                                              .checkBlue
                                                        : MessagesPalette.muted,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (_canReply)
                    SafeArea(
                      child: Container(
                        color: MessagesPalette.composerBar,
                        padding: const EdgeInsets.fromLTRB(
                          8,
                          6,
                          8 + MayaFloatingChat.pageEndClearance,
                          8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_replyTarget != null)
                              MessageReplyComposerBar(
                                quote: MessageReplyQuote.fromMessage(
                                  _replyTarget!,
                                ),
                                accent: MessagesPalette.primary,
                                onCancel: _clearReply,
                              ),
                            if (_pendingAttachments.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: PendingAttachmentRow(
                                  attachments: _pendingAttachments,
                                  onRemove: (attachment) => setState(() {
                                    _pendingAttachments.removeWhere(
                                      (a) => a.id == attachment.id,
                                    );
                                  }),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: MessageVoiceInputBar(
                                    controller: _controller,
                                    accent: MessagesPalette.primary,
                                    enabled: _canReply && !_pickingAttachment,
                                    pickingAttachment: _pickingAttachment,
                                    hintText: s.typeMessage,
                                    onPickAttachment: _pickAttachments,
                                    onSend: _send,
                                    onSendVoice: (attachment) => _send(
                                      attachments: [attachment],
                                      text: 'Voice message',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
