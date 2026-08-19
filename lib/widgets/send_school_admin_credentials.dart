import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/school_admin_credentials_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

enum _AdminCredSendOption { sms, whatsApp, telegram, share }

/// Send onboarding login details to the school admin (SMS / WhatsApp / Telegram / Share).
Future<void> showSendSchoolAdminCredentials(
  BuildContext context,
  SchoolRecord school,
) async {
  final creds = SchoolAdminCredentialsService.instance;
  final password = creds.passwordForSchool(school);
  if (password == null || password.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No temp password saved for this school'),
        ),
      );
    }
    return;
  }

  final phone = creds.adminPhoneForSchool(school);
  final hasPhone = phone != null && phone.trim().isNotEmpty;

  if (!hasPhone) {
    final share = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send admin login'),
        content: const Text(
          'No admin phone on file. Use Share to send the login details manually.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Share')),
        ],
      ),
    );
    if (share != true || !context.mounted) return;
    await creds.share(school);
    return;
  }

  final s = AppLocale.instance.strings;
  final choice = await showModalBottomSheet<_AdminCredSendOption>(
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
            const Text(
              'Send login to admin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              creds.adminLoginForSchool(school),
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.sms_outlined, color: Colors.tealAccent),
              title: Text(s.sendViaSms, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, _AdminCredSendOption.sms),
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.greenAccent),
              title: Text(s.sendViaWhatsApp, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, _AdminCredSendOption.whatsApp),
            ),
            ListTile(
              leading: const Icon(Icons.send, color: Colors.lightBlueAccent),
              title: Text(s.sendViaTelegram, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, _AdminCredSendOption.telegram),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.white70),
              title: Text(s.share, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, _AdminCredSendOption.share),
            ),
          ],
        ),
      ),
    ),
  );

  if (!context.mounted || choice == null) return;

  if (choice == _AdminCredSendOption.share) {
    await creds.share(school);
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
    _AdminCredSendOption.sms => OtpDeliveryChannel.sms,
    _AdminCredSendOption.whatsApp => OtpDeliveryChannel.whatsApp,
    _AdminCredSendOption.telegram => OtpDeliveryChannel.telegram,
    _AdminCredSendOption.share => OtpDeliveryChannel.sms,
  };

  final ok = await creds.sendViaChannel(school: school, channel: channel);
  if (!context.mounted) return;

  final channelLabel = switch (choice) {
    _AdminCredSendOption.sms => s.sendViaSms,
    _AdminCredSendOption.whatsApp => s.sendViaWhatsApp,
    _AdminCredSendOption.telegram => s.sendViaTelegram,
    _AdminCredSendOption.share => s.share,
  };

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok ? 'Opened $channelLabel with admin login message' : s.otpDeliveryFailed,
      ),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
    ),
  );
}
