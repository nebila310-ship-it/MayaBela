import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/widgets/inbox_messages_action.dart';

/// Once per login session, remind the signed-in role about unread messages.
class InboxLoginReminder extends StatefulWidget {
  const InboxLoginReminder({
    super.key,
    required this.child,
    this.onOpenMessages,
  });

  final Widget child;
  final VoidCallback? onOpenMessages;

  static int? shownForGeneration;

  @visibleForTesting
  static void reset() {
    shownForGeneration = null;
  }

  @override
  State<InboxLoginReminder> createState() => _InboxLoginReminderState();
}

class _InboxLoginReminderState extends State<InboxLoginReminder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRemind());
  }

  void _maybeRemind() {
    if (!mounted) return;
    final user = AuthService.currentUser;
    if (user == null) return;

    final generation = AuthService.sessionGeneration;
    if (InboxLoginReminder.shownForGeneration == generation) return;

    final unread = DashboardBadgeService.instance.countFor('messages');
    if (unread <= 0) return;

    InboxLoginReminder.shownForGeneration = generation;

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
