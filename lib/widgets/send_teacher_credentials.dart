import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/teacher_credentials_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

enum _TeacherCredSendOption { sms, whatsApp, telegram, share }

/// Send onboarding login details to a teacher (SMS / WhatsApp / Telegram / Share).
Future<void> showSendTeacherCredentials(
  BuildContext context,
  AdminTeacherRecord teacher,
) async {
  final creds = TeacherCredentialsService.instance;
  final phone = teacher.phone?.trim();
  final hasPhone = phone != null && phone.isNotEmpty;

  if (!hasPhone) {
    final share = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send teacher login'),
        content: const Text(
          'No phone number on file. Use Share to send the login details manually.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Share')),
        ],
      ),
    );
    if (share != true || !context.mounted) return;
    await creds.share(teacher);
    return;
  }

  final s = AppLocale.instance.strings;
  final choice = await showModalBottomSheet<_TeacherCredSendOption>(
    context: context,
    backgroundColor: const Color(0xFF1E293B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
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
              s.sendLoginToTeacher,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              teacher.fullName,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.sms_outlined, color: Colors.tealAccent),
              title: Text(s.sendViaSms, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, _TeacherCredSendOption.sms),
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.greenAccent),
              title: Text(s.sendViaWhatsApp, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, _TeacherCredSendOption.whatsApp),
            ),
            ListTile(
              leading: const Icon(Icons.send, color: Colors.lightBlueAccent),
              title: Text(s.sendViaTelegram, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, _TeacherCredSendOption.telegram),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.white70),
              title: Text(s.share, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, _TeacherCredSendOption.share),
            ),
          ],
        ),
      ),
    ),
  );

  if (!context.mounted || choice == null) return;

  if (choice == _TeacherCredSendOption.share) {
    await creds.share(teacher);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.inviteParentSent),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
    return;
  }

  final channel = switch (choice) {
    _TeacherCredSendOption.sms => OtpDeliveryChannel.sms,
    _TeacherCredSendOption.whatsApp => OtpDeliveryChannel.whatsApp,
    _TeacherCredSendOption.telegram => OtpDeliveryChannel.telegram,
    _TeacherCredSendOption.share => OtpDeliveryChannel.sms,
  };

  final ok = await creds.sendViaChannel(teacher: teacher, channel: channel);
  if (!context.mounted) return;

  final channelLabel = switch (choice) {
    _TeacherCredSendOption.sms => s.sendViaSms,
    _TeacherCredSendOption.whatsApp => s.sendViaWhatsApp,
    _TeacherCredSendOption.telegram => s.sendViaTelegram,
    _TeacherCredSendOption.share => s.share,
  };

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok ? 'Opened $channelLabel with teacher login message' : s.otpDeliveryFailed,
      ),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
    ),
  );
}
