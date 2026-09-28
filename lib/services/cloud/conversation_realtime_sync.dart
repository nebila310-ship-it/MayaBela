import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/cloud/conversation_document.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/messaging_access_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/push_notification_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/school_data_service.dart';

/// Live Supabase listener for conversations.
class ConversationRealtimeSync extends ChangeNotifier {
  ConversationRealtimeSync._();
  static final instance = ConversationRealtimeSync._();

  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  bool _primed = false;
  final Map<String, int> _messageCounts = {};
  final _crud = DocumentStore();

  bool get isListening => _subscription != null;

  void start() {
    if (!SupabaseBootstrap.isInitialized) return;
    if (_subscription != null) return;

    _seedCountsFromLocal();
    _primed = false;

    _subscription = _crud.watchAll(AppCollections.conversations).listen(
          _onSnapshot,
          onError: (Object e) {
            if (kDebugMode) {
              debugPrint('ConversationRealtimeSync: listener error — $e');
            }
          },
        );
  }

  void stop() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _primed = false;
    _messageCounts.clear();
  }

  void _seedCountsFromLocal() {
    _messageCounts.clear();
    for (final conversation in SchoolDataService.instance.getConversations()) {
      _messageCounts[conversation.id] = conversation.messages.length;
    }
  }

  void _onSnapshot(List<Map<String, dynamic>> docs) {
    final role = AuthService.currentUser?.roleKey;
    if (role == null) return;

    final viewerStaffId = role == AuthService.roleAdmin
        ? StaffMemberOption.viewerAdminStaffId(role)
        : StaffMemberOption.viewerStaffId(role);
    final viewerUsername = AuthService.currentUser?.username;

    var changed = false;

    for (final data in docs) {
      Conversation cloud;
      try {
        cloud = ConversationDocument.fromMap(data).toConversation();
      } catch (_) {
        continue;
      }

      if (!MessagingAccessService.canView(cloud, role)) continue;

      final previousCount = _messageCounts[cloud.id] ?? 0;
      final shouldNotify = _primed && cloud.messages.length > previousCount;

      if (shouldNotify) {
        final incoming = cloud.messages
            .skip(previousCount)
            .where(
              (message) => !message.isOutgoingFor(
                role,
                viewerStaffId: viewerStaffId,
                viewerUsername: viewerUsername,
              ),
            )
            .toList();

        for (final message in incoming) {
          _alertIncomingMessage(cloud, message);
        }
      }

      SchoolDataService.instance.mergeConversationFromCloud(cloud);
      _messageCounts[cloud.id] = cloud.messages.length;
      changed = true;
    }

    if (!_primed) {
      _primed = true;
    }

    if (changed) {
      notifyListeners();
      SchoolContentSyncService.instance.markDataChanged();
    }
  }

  void _alertIncomingMessage(Conversation conversation, ChatMessage message) {
    final senderName = message.resolveDisplayName();
    final preview = message.previewBody().isNotEmpty
        ? message.previewBody()
        : 'New message';

    final recipientRole = AuthService.currentUser?.roleKey;
    if (recipientRole == null) return;

    unawaited(
      PushNotificationService.instance.showTrayNotification(
        title: conversation.displayTitleForViewer(viewerRole: recipientRole),
        body: '$senderName: $preview',
      ),
    );

    NotificationService.instance.push(
      title: 'New message from $senderName',
      body: preview,
      type: NotificationType.message,
      fromRole: message.senderRole,
      fromName: senderName,
      recipientRole: recipientRole,
      showOnMessagesBadge: true,
    );
  }
}
