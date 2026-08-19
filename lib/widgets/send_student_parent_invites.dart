import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

enum _ParentInviteSendOption { sms, whatsApp, telegram, share, allSms }

/// Send parent registration invite to one or all contact numbers on the student.
Future<void> showSendStudentParentInvites(
  BuildContext context,
  AdminStudentRecord student,
) async {
  final invite = ParentInviteService.instance;
  final contacts = invite.contactLinesForRecord(student);
  final s = AppLocale.instance.strings;

  if (contacts.isEmpty) {
    final share = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.inviteParent),
        content: Text(s.inviteParentNoPhone),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(s.share)),
        ],
      ),
    );
    if (share != true || !context.mounted) return;
    await invite.shareMessage(invite.buildMessageForRecord(student));
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
                  s.sendInviteToContacts,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${contacts.length} ${s.contactNumbersOnFile}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...contacts.map(
                  (c) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.contact_phone, color: Colors.white54, size: 20),
                    title: Text(c.label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    subtitle: Text(c.phone, style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.sms_outlined, color: Colors.tealAccent),
                  title: Text(s.sendAllViaSms, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(s.sendAllViaSmsHint, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () => Navigator.pop(context, _ParentInviteSendOption.allSms),
                ),
                ListTile(
                  leading: const Icon(Icons.chat, color: Colors.greenAccent),
                  title: Text(s.sendViaWhatsApp, style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, _ParentInviteSendOption.whatsApp),
                ),
                ListTile(
                  leading: const Icon(Icons.send, color: Colors.lightBlueAccent),
                  title: Text(s.sendViaTelegram, style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, _ParentInviteSendOption.telegram),
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

  Future<bool> confirmBefore(ParentContactLine contact, int index) async {
    if (index == 0) return true;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.sendInviteNextContactTitle),
        content: Text(s.sendInviteNextContactBody(contact.label, contact.phone)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.sendInviteSkipRemaining),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.sendInviteContinue),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  if (choice == _ParentInviteSendOption.share) {
    await invite.shareMessage(invite.buildMessageForRecord(student));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.inviteParentSent), backgroundColor: Colors.green.shade700),
      );
    }
    return;
  }

  if (choice == _ParentInviteSendOption.allSms) {
    final result = await invite.inviteAllContactsViaSms(
      student,
      confirmBefore: confirmBefore,
    );
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

  final result = await invite.inviteAllContactsViaChannel(
    student,
    channel,
    confirmBefore: confirmBefore,
  );
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        result.sent > 0
            ? s.inviteBulkContactsDone(result.sent, result.skipped)
            : s.otpDeliveryFailed,
      ),
      backgroundColor: result.sent > 0 ? Colors.green.shade700 : Colors.red.shade700,
    ),
  );
}
