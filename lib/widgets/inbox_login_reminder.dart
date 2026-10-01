import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/theme/classroom_palette.dart';
import 'package:mayabela/widgets/inbox_messages_action.dart';

/// Remind about unread mail once. Seeing or reading it never repeats that mail.
class InboxLoginReminder extends StatefulWidget {
  const InboxLoginReminder({
    super.key,
    required this.child,
    this.onOpenMessages,
  });

  final Widget child;
  final VoidCallback? onOpenMessages;

  static const _prefsPrefix = 'inbox_ack_v3_';
  static int? shownForGeneration;
  static final Set<String> _rememberedKeys = {};

  @visibleForTesting
  static const displayDuration = Duration(seconds: 5);

  @visibleForTesting
  static void reset() {
    shownForGeneration = null;
  }

  @visibleForTesting
  static Future<void> resetForTests() async {
    shownForGeneration = null;
    _rememberedKeys.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(
      (k) =>
          k.startsWith(_prefsPrefix) ||
          k.startsWith('inbox_login_notified_v1_'),
    )) {
      await prefs.remove(key);
    }
  }

  static String _storageKey() {
    final username = (AuthService.currentUser?.username ?? '')
        .trim()
        .toLowerCase();
    final role = AuthService.currentUser?.roleKey ?? '';
    return '$_prefsPrefix${username.isEmpty ? role : username}';
  }

  static List<Set<String>> currentUnseenGroups({bool messagesOnly = true}) {
    final user = AuthService.currentUser;
    if (user == null) return const [];
    final role = user.roleKey;
    final staffId = role == AuthService.roleAdmin
        ? StaffMemberOption.viewerAdminStaffId(role)
        : StaffMemberOption.viewerStaffId(role);
    final groups = <Set<String>>[];
    for (final conversation
        in SchoolDataService.instance.getConversationsForRole(role)) {
      for (final message in conversation.messages) {
        if (message.isOutgoingFor(
          role,
          viewerStaffId: staffId,
          viewerUsername: user.username,
        )) {
          continue;
        }
        if (message.seenAt != null) continue;
        groups.add({
          'chat:${conversation.id}:${message.text}',
          'msg:${message.senderDisplayName}|${message.text}',
        });
      }
    }
    for (final item
        in NotificationService.instance.notificationsForCurrentUser()) {
      if (item.isRead) continue;
      if (messagesOnly && item.type != NotificationType.message) continue;
      groups.add({
        'n:${item.id}',
        'n:${item.type.name}|${item.title}|${item.body}|${item.recipientRole}',
      });
    }
    return groups;
  }

  static List<String> currentUnseenKeys({bool messagesOnly = true}) {
    final keys = <String>{};
    for (final group in currentUnseenGroups(messagesOnly: messagesOnly)) {
      keys.addAll(group);
    }
    return keys.toList()..sort();
  }

  /// Call when the user opens Messages or the notification tray.
  static Future<void> acknowledgeCurrent() async {
    final unseen = currentUnseenKeys(messagesOnly: false);
    if (unseen.isNotEmpty) {
      await _persistAck(unseen);
    }
    NotificationService.instance.markAllRead();
    NotificationService.instance.markMessagesBadgeRead();
  }

  static Future<void> _persistAck(List<String> unseen) async {
    final scope = _storageKey();
    for (final key in unseen) {
      _rememberedKeys.add('$scope|$key');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(scope) ?? const [];
      await prefs.setStringList(scope, {...stored, ...unseen}.toList()..sort());
    } catch (_) {}
  }

  static Future<bool> _alreadyAcknowledged({bool messagesOnly = true}) async {
    final groups = currentUnseenGroups(messagesOnly: messagesOnly);
    if (groups.isEmpty) return true;
    final scope = _storageKey();
    bool known(String key) => _rememberedKeys.contains('$scope|$key');
    if (groups.every((group) => group.any(known))) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = (prefs.getStringList(scope) ?? const []).toSet();
      for (final key in stored) {
        _rememberedKeys.add('$scope|$key');
      }
      return groups.every((group) => group.any(stored.contains));
    } catch (_) {
      return groups.every((group) => group.any(known));
    }
  }

  @override
  State<InboxLoginReminder> createState() => _InboxLoginReminderState();
}

class _InboxLoginReminderState extends State<InboxLoginReminder> {
  Timer? _hideTimer;
  bool _visible = false;
  int _unread = 0;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeRemind());
    });
  }

  void _hideToast() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (!mounted || !_visible) return;
    setState(() => _visible = false);
  }

  void _openInbox() {
    _hideToast();
    unawaited(InboxLoginReminder.acknowledgeCurrent());
    if (widget.onOpenMessages != null) {
      widget.onOpenMessages!();
      return;
    }
    InboxMessagesAction.openInbox(context);
  }

  Future<void> _maybeRemind() async {
    if (!mounted) return;
    final user = AuthService.currentUser;
    if (user == null) return;

    final generation = AuthService.sessionGeneration;
    if (InboxLoginReminder.shownForGeneration == generation) return;

    await NotificationService.instance.hydratePersistedReads();
    if (!mounted) return;

    final unread = DashboardBadgeService.instance.countFor('messages');
    if (unread <= 0) return;

    final unseen = InboxLoginReminder.currentUnseenKeys();
    if (unseen.isEmpty) return;
    if (await InboxLoginReminder._alreadyAcknowledged()) return;
    if (!mounted) return;

    // Remember before showing so a rebuild or next login cannot repeat it.
    InboxLoginReminder.shownForGeneration = generation;
    await InboxLoginReminder._persistAck(unseen);
    NotificationService.instance.markMessagesBadgeRead();

    if (!mounted) return;
    setState(() {
      _unread = unread;
      _visible = true;
    });
    _hideTimer?.cancel();
    _hideTimer = Timer(InboxLoginReminder.displayDuration, _hideToast);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final maxWidth = (MediaQuery.sizeOf(context).width - 32).clamp(
      180.0,
      340.0,
    );
    return Stack(
      children: [
        widget.child,
        if (_visible)
          Positioned(
            top: padding.top + 16,
            right: 16,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Material(
                key: const Key('inbox-login-reminder'),
                color: Colors.white,
                elevation: 10,
                shadowColor: ClassroomPalette.green.withValues(alpha: 0.32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: ClassroomPalette.green.withValues(alpha: 0.55),
                  ),
                ),
                child: InkWell(
                  onTap: _openInbox,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.mark_email_unread_rounded,
                          color: ClassroomPalette.green,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            AppLocale.instance.strings.inboxUnreadOnLogin(
                              _unread,
                            ),
                            style: const TextStyle(
                              color: ClassroomPalette.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
