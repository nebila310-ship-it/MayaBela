import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

enum _ParentInviteSendOption { sms, whatsApp, telegram, share, allSms }

/// Send parent registration invite to the number on the student record.
Future<void> showSendStudentParentInvites(
  BuildContext context,
  AdminStudentRecord student,
) async {
  final invite = ParentInviteService.instance;
  final primary = student.primaryContactPhone;
  final contacts = invite.contactLinesForRecord(student);
  final s = AppLocale.instance.strings;
  final schoolName = ParentInviteService.schoolNameFor(student.schoolId);
  final inviteUrl = invite.inviteUrlForRecord(student);

  if (primary == null || primary.trim().isEmpty) {
    final share = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Welcome to $schoolName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.inviteParentNoPhone),
            const SizedBox(height: 12),
            Text(s.parentInviteLink, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SelectableText(inviteUrl),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(s.share)),
        ],
      ),
    );
    if (share != true || !context.mounted) return;
    await invite.shareInviteForRecord(student);
    return;
  }

  final choice = await showModalBottomSheet<_ParentInviteSendOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E293B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
      final parentLabel = student.primaryParentName ?? contacts.first.label;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome to $schoolName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Opens WhatsApp or Telegram to $parentLabel · $primary',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  s.parentInviteLink,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  inviteUrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: inviteUrl));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.parentInviteLinkCopied)),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, color: Colors.white70, size: 16),
                    label: Text(
                      s.copyParentInviteLink,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.chat, color: Colors.greenAccent),
                  title: Text(s.sendViaWhatsApp, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    primary,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(context, _ParentInviteSendOption.whatsApp),
                ),
                ListTile(
                  leading: const Icon(Icons.send, color: Colors.lightBlueAccent),
                  title: Text(s.sendViaTelegram, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    primary,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(context, _ParentInviteSendOption.telegram),
                ),
                ListTile(
                  leading: const Icon(Icons.sms_outlined, color: Colors.tealAccent),
                  title: Text(s.sendViaSms, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    primary,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(context, _ParentInviteSendOption.sms),
                ),
                if (contacts.length > 1)
                  ListTile(
                    leading: const Icon(Icons.sms_outlined, color: Colors.white54),
                    title: Text(s.sendAllViaSms, style: const TextStyle(color: Colors.white70)),
                    subtitle: Text(
                      s.sendAllViaSmsHint,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    onTap: () => Navigator.pop(context, _ParentInviteSendOption.allSms),
                  ),
                ListTile(
                  leading: const Icon(Icons.share_outlined, color: Colors.white70),
                  title: Text(s.share, style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, _ParentInviteSendOption.share),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (!context.mounted || choice == null) return;

  if (choice == _ParentInviteSendOption.share) {
    await invite.shareInviteForRecord(student);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.inviteParentSent), backgroundColor: Colors.green.shade700),
      );
    }
    return;
  }

  if (choice == _ParentInviteSendOption.allSms) {
    final result = await invite.inviteAllContactsViaSms(student);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.inviteBulkContactsDone(result.sent, result.skipped)),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
    return;
  }

  final channel = switch (choice) {
    _ParentInviteSendOption.sms => OtpDeliveryChannel.sms,
    _ParentInviteSendOption.whatsApp => OtpDeliveryChannel.whatsApp,
    _ParentInviteSendOption.telegram => OtpDeliveryChannel.telegram,
    _ParentInviteSendOption.allSms => OtpDeliveryChannel.sms,
    _ParentInviteSendOption.share => OtpDeliveryChannel.sms,
  };

  final ok = await invite.invitePrimaryViaChannel(student, channel);
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ok ? s.inviteParentSent : s.otpDeliveryFailed),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
    ),
  );
}
