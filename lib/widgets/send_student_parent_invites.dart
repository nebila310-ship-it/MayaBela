import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

/// Send the parent invite to the number already on the student record.
Future<void> showSendStudentParentInvites(
  BuildContext context,
  AdminStudentRecord student,
) async {
  final invite = ParentInviteService.instance;
  final primary = student.primaryContactPhone;
  final s = AppLocale.instance.strings;
  final schoolName = ParentInviteService.schoolNameFor(student.schoolId);

  Future<void> copyFull() async {
    await Clipboard.setData(
      ClipboardData(text: invite.buildMessageForRecord(student)),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.fullParentInviteCopied)),
    );
  }

  Future<void> send(OtpDeliveryChannel channel) async {
    final ok = await invite.invitePrimaryViaChannel(student, channel);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? s.inviteParentSent : s.otpDeliveryFailed),
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  if (primary == null || primary.trim().isEmpty) {
    final share = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Welcome to $schoolName'),
        content: Text(s.inviteParentNoPhone),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(s.copyFullParentInvite)),
        ],
      ),
    );
    if (share != true || !context.mounted) return;
    await copyFull();
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E293B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final parentLabel = student.primaryParentName ?? student.fullName;
      return SafeArea(
        child: Padding(
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
                s.parentInviteSendsTo(parentLabel, primary),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.greenAccent),
                title: Text(s.sendViaWhatsApp, style: const TextStyle(color: Colors.white)),
                subtitle: Text(primary, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () => send(OtpDeliveryChannel.whatsApp),
              ),
              ListTile(
                leading: const Icon(Icons.send, color: Colors.lightBlueAccent),
                title: Text(s.sendViaTelegram, style: const TextStyle(color: Colors.white)),
                subtitle: Text(primary, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () => send(OtpDeliveryChannel.telegram),
              ),
              ListTile(
                leading: const Icon(Icons.copy_all_outlined, color: Colors.white70),
                title: Text(s.copyFullParentInvite, style: const TextStyle(color: Colors.white)),
                onTap: copyFull,
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Colors.white70),
                title: Text(s.share, style: const TextStyle(color: Colors.white)),
                onTap: () => invite.shareInviteForRecord(student),
              ),
            ],
          ),
        ),
      );
    },
  );
}
