import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/teacher_credentials_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/widgets/staff_role_labels.dart';

enum _TeacherCredSendOption { sms, whatsApp, telegram, share }

bool _isStaffRecord(AdminTeacherRecord teacher, bool? override) =>
    override ?? isAdministrationStaffRecord(teacher);

/// Send onboarding login details (SMS / WhatsApp / Telegram / Share).
Future<void> showSendTeacherCredentials(
  BuildContext context,
  AdminTeacherRecord teacher, {
  bool? administrationStaff,
}) async {
  final isStaff = _isStaffRecord(teacher, administrationStaff);
  final creds = TeacherCredentialsService.instance;
  final phone = teacher.phone?.trim();
  final hasPhone = phone != null && phone.isNotEmpty;
  final s = AppLocale.instance.strings;

  if (!hasPhone) {
    final share = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isStaff ? s.sendStaffLogin : 'Send teacher login'),
        content: Text(
          isStaff
              ? s.sendLoginNoPhoneStaff
              : 'No phone number on file. Use Share to send the login details manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.share),
          ),
        ],
      ),
    );
    if (share != true || !context.mounted) return;
    await creds.share(teacher);
    return;
  }

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
              isStaff ? s.sendLoginToStaff : s.sendLoginToTeacher,
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
        ok
            ? s.openedLoginChannel(channelLabel, staff: isStaff)
            : s.otpDeliveryFailed,
      ),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
    ),
  );
}

Future<void> sendStaffLoginToRegisteredNumber(
  BuildContext context,
  AdminTeacherRecord teacher,
  OtpDeliveryChannel channel,
) async {
  final s = AppLocale.instance.strings;
  final phone = teacher.phone?.trim();
  if (phone == null || phone.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.sendLoginNoPhoneStaff)),
      );
    }
    return;
  }
  final ok = await TeacherCredentialsService.instance.sendViaChannel(
    teacher: teacher,
    channel: channel,
  );
  if (!context.mounted) return;
  final channelLabel = switch (channel) {
    OtpDeliveryChannel.sms => s.sendViaSms,
    OtpDeliveryChannel.whatsApp => s.sendViaWhatsApp,
    OtpDeliveryChannel.telegram => s.sendViaTelegram,
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? s.openedLoginChannel(channelLabel, staff: true)
            : s.otpDeliveryFailed,
      ),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
    ),
  );
}

Future<void> copyStaffLoginDetails(
  BuildContext context,
  AdminTeacherRecord teacher,
) async {
  final s = AppLocale.instance.strings;
  await Clipboard.setData(
    ClipboardData(
      text: TeacherCredentialsService.instance.buildMessage(teacher),
    ),
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(s.staffLoginCopied)),
  );
}

/// WhatsApp / Telegram / copy — same pattern as [ParentInviteResendBar].
class StaffLoginResendBar extends StatelessWidget {
  const StaffLoginResendBar({
    super.key,
    required this.teacher,
    this.administrationStaff = true,
  });

  final AdminTeacherRecord teacher;
  final bool administrationStaff;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final phone = teacher.phone?.trim();
        final hasPhone = phone != null && phone.isNotEmpty;
        final buttons = <Widget>[
          if (hasPhone) ...[
            FilledButton.icon(
              onPressed: () => sendStaffLoginToRegisteredNumber(
                context,
                teacher,
                OtpDeliveryChannel.whatsApp,
              ),
              icon: const Icon(Icons.chat),
              label: Text(s.sendViaWhatsApp),
            ),
            FilledButton.tonalIcon(
              onPressed: () => sendStaffLoginToRegisteredNumber(
                context,
                teacher,
                OtpDeliveryChannel.telegram,
              ),
              icon: const Icon(Icons.send),
              label: Text(s.sendViaTelegram),
            ),
          ],
          OutlinedButton.icon(
            onPressed: () => copyStaffLoginDetails(context, teacher),
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(s.copyStaffLogin),
          ),
          TextButton.icon(
            onPressed: () => showSendTeacherCredentials(
              context,
              teacher,
              administrationStaff: administrationStaff,
            ),
            icon: const Icon(Icons.sms_outlined),
            label: Text(
              administrationStaff ? s.sendLoginToStaff : s.sendLoginToTeacher,
            ),
          ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.staffLoginResendTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              hasPhone
                  ? s.staffLoginSendsTo(teacher.fullName, phone)
                  : s.sendLoginNoPhoneStaff,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: buttons),
          ],
        );
      },
    );
  }
}
