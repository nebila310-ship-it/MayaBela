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
import 'package:mayabela/widgets/inbox_messages_action.dart';

/// Remind the signed-in role about unread messages once until new mail arrives.
class InboxLoginReminder extends StatefulWidget {
  const InboxLoginReminder({
    super.key,
    required this.child,
    this.onOpenMessages,
  });

  final Widget child;
  final VoidCallback? onOpenMessages;

  static const _prefsPrefix = 'inbox_login_notified_v1_';
  static int? shownForGeneration;
  static final Set<String> _rememberedKeys = {};

  @visibleForTesting
  static void reset() {
    shownForGeneration = null;
  }

  @visibleForTesting
  static Future<void> resetForTests() async {
    shownForGeneration = null;
    _rememberedKeys.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefsPrefix))) {
      await prefs.remove(key);
    }
  }

  static String _storageKey() {
    final user = AuthService.currentUser;
    final school = (AuthService.activeSchoolId ?? user?.schoolId ?? '').trim();
    final username = (user?.username ?? '').trim().toLowerCase();
    return '$_prefsPrefix$school|$username';
  }

  static List<String> currentUnseenKeys() {
    final user = AuthService.currentUser;
    if (user == null) return const [];
    final role = user.roleKey;
    final staffId = role == AuthService.roleAdmin
        ? StaffMemberOption.viewerAdminStaffId(role)
        : StaffMemberOption.viewerStaffId(role);
    final keys = <String>{};
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
        keys.add('chat:${conversation.id}:${message.text}');
      }
    }
    for (final item in NotificationService.instance.notificationsForCurrentUser()) {
      if (item.isRead || item.type != NotificationType.message) continue;
      keys.add('n:${item.id}');
    }
    final out = keys.toList()..sort();
    return out;
  }

  @override
  State<InboxLoginReminder> createState() => _InboxLoginReminderState();
}

class _InboxLoginReminderState extends State<InboxLoginReminder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeRemind());
    });
  }

  Future<void> _maybeRemind() async {
    if (!mounted) return;
    final user = AuthService.currentUser;
    if (user == null) return;

    final generation = AuthService.sessionGeneration;
    if (InboxLoginReminder.shownForGeneration == generation) return;

    final unread = DashboardBadgeService.instance.countFor('messages');
    if (unread <= 0) return;

    final unseen = InboxLoginReminder.currentUnseenKeys();
    if (unseen.isEmpty) return;

    final scope = InboxLoginReminder._storageKey();
    final remembered = unseen
        .every((key) => InboxLoginReminder._rememberedKeys.contains('$scope|$key'));
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final stored = prefs.getStringList(scope) ?? const [];
    final storedSet = stored.toSet();
    if (remembered || unseen.every(storedSet.contains)) return;

    InboxLoginReminder.shownForGeneration = generation;
    for (final key in unseen) {
      InboxLoginReminder._rememberedKeys.add('$scope|$key');
    }
    await prefs.setStringList(
      scope,
      {...storedSet, ...unseen}.toList()..sort(),
    );

    final s = AppLocale.instance.strings;
    final alreadyNotified =
        NotificationService.instance.unreadCountForTypes([
          NotificationType.message,
        ]) >
        0;
    if (!alreadyNotified) {
      NotificationService.instance.push(
        title: s.notifyMessages,
        body: s.inboxUnreadOnLogin(unread),
        type: NotificationType.message,
        fromRole: 'school',
        fromName: s.notifyMessages,
        recipientRole: user.roleKey,
      );
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        key: const Key('inbox-login-reminder'),
        content: Text(s.inboxUnreadOnLogin(unread)),
        action: SnackBarAction(
          label: s.inboxOpenMessages,
          onPressed: () {
            if (widget.onOpenMessages != null) {
              widget.onOpenMessages!();
              return;
            }
            InboxMessagesAction.openInbox(context);
          },
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
