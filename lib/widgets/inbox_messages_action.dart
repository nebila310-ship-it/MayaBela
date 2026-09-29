import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/messages_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/student_account_service.dart';

/// Top-bar inbox shortcut so no role misses incoming chat.
class InboxMessagesAction extends StatelessWidget {
  const InboxMessagesAction({
    super.key,
    this.iconColor,
    this.onPressed,
    this.tooltip,
  });

  static const actionKey = Key('inbox-messages-action');

  final Color? iconColor;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// Opens the in-shell Messages route, or pushes [MessagesScreen].
  static void openInbox(
    BuildContext context, {
    ValueChanged<String>? onNavigate,
  }) {
    DashboardBadgeService.instance.markReadForTile('messages');
    if (onNavigate != null) {
      onNavigate('support');
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screenForCurrentUser()));
  }

  static Widget screenForCurrentUser() {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleStudent) {
      final allow = StudentAccountService.instance
          .settingsForSchool(AuthService.activeSchoolId)
          .allowStudentMessaging;
      return MessagesScreen(canCompose: allow);
    }
    if (role == AuthService.roleTeacher) {
      return const MessagesScreen(
        canCompose: true,
        composeScope: MessageComposeScope.teacher,
      );
    }
    return const MessagesScreen();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppLocale.instance,
        DashboardBadgeService.instance,
      ]),
      builder: (context, _) {
        final unread = DashboardBadgeService.instance.countFor('messages');
        final s = AppLocale.instance.strings;
        return IconButton(
          key: actionKey,
          tooltip: tooltip ?? s.notifyMessages,
          onPressed: onPressed ?? () => openInbox(context),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: Icon(Icons.forum_outlined, color: iconColor),
          ),
        );
      },
    );
  }
}
