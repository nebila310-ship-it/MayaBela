import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/driver_credentials_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/otp_delivery_service.dart';

enum _DriverCredSendOption { sms, whatsApp, telegram, share }

Future<void> showSendDriverCredentials(
  BuildContext context,
  AdminDriverRecord driver,
) async {
  final creds = DriverCredentialsService.instance;
  final phone = driver.phone?.trim();
  final hasPhone = phone != null && phone.isNotEmpty;

  if (!hasPhone) {
    final share = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocale.instance.strings.sendLoginToDriver),
        content: Text(AppLocale.instance.strings.sendLoginNoPhoneDriver),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocale.instance.strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocale.instance.strings.share),
          ),
        ],
      ),
    );
    if (share != true || !context.mounted) return;
    await creds.share(driver);
    return;
  }

  final s = AppLocale.instance.strings;
  final choice = await showModalBottomSheet<_DriverCredSendOption>(
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
              s.sendLoginToDriver,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              driver.fullName,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.sms_outlined, color: Colors.tealAccent),
              title: Text(s.sendViaSms, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, _DriverCredSendOption.sms),
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.greenAccent),
              title: Text(s.sendViaWhatsApp, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, _DriverCredSendOption.whatsApp),
            ),
            ListTile(
              leading: const Icon(Icons.send, color: Colors.lightBlueAccent),
              title: Text(s.sendViaTelegram, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, _DriverCredSendOption.telegram),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.white70),
              title: Text(s.share, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, _DriverCredSendOption.share),
            ),
          ],
        ),
      ),
    ),
  );

  if (!context.mounted || choice == null) return;

  if (choice == _DriverCredSendOption.share) {
    await creds.share(driver);
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
    _DriverCredSendOption.sms => OtpDeliveryChannel.sms,
    _DriverCredSendOption.whatsApp => OtpDeliveryChannel.whatsApp,
    _DriverCredSendOption.telegram => OtpDeliveryChannel.telegram,
    _DriverCredSendOption.share => OtpDeliveryChannel.sms,
  };

  final ok = await creds.sendViaChannel(driver: driver, channel: channel);
  if (!context.mounted) return;

  final channelLabel = switch (choice) {
    _DriverCredSendOption.sms => s.sendViaSms,
    _DriverCredSendOption.whatsApp => s.sendViaWhatsApp,
    _DriverCredSendOption.telegram => s.sendViaTelegram,
    _DriverCredSendOption.share => s.share,
  };

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok ? s.driverLoginSent(channelLabel) : s.otpDeliveryFailed,
      ),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
    ),
  );
}
