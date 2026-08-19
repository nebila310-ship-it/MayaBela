import 'package:url_launcher/url_launcher.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/platform_audit_log_service.dart';
import 'package:mayabela/services/platform_owner_service.dart';
import 'package:mayabela/services/school_admin_credentials_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/utils/phone_utils.dart';

enum BulkSmsTemplate {
  expiryReminder,
  renewalNotice,
  welcomeCheckIn,
  custom;

  String get label => switch (this) {
        BulkSmsTemplate.expiryReminder => 'Expiry reminder',
        BulkSmsTemplate.renewalNotice => 'Renewal notice',
        BulkSmsTemplate.welcomeCheckIn => 'Welcome check-in',
        BulkSmsTemplate.custom => 'Custom message',
      };

  String buildMessage({
    required SchoolRecord school,
    String? customBody,
  }) {
    final creds = SchoolAdminCredentialsService.instance;
    final expiry = school.subscriptionExpiresAt;
    final expiryLine = expiry == null
        ? 'your subscription'
        : '${expiry.day}/${expiry.month}/${expiry.year}';

    return switch (this) {
      BulkSmsTemplate.expiryReminder =>
        'Hello ${creds.adminNameForSchool(school) ?? 'Admin'}, '
            'this is Maya School Platform. '
            '${school.name} (${school.id}) subscription ends on $expiryLine. '
            'Please contact us to renew. Support: ${PlatformOwnerService.primaryPhone}',
      BulkSmsTemplate.renewalNotice =>
        'Hello ${creds.adminNameForSchool(school) ?? 'Admin'}, '
            '${school.name} subscription has been renewed until $expiryLine. '
            'Thank you for continuing with Maya School.',
      BulkSmsTemplate.welcomeCheckIn =>
        'Hello ${creds.adminNameForSchool(school) ?? 'Admin'}, '
            'checking in on ${school.name}. '
            'Need help with setup, login, or training? Reply or call Maya support.',
      BulkSmsTemplate.custom => customBody?.trim().isNotEmpty == true
          ? customBody!.trim()
          : 'Message from Maya School Platform regarding ${school.name}.',
    };
  }
}

class BulkSmsRecipient {
  BulkSmsRecipient({
    required this.school,
    required this.phone,
    required this.message,
  });

  final SchoolRecord school;
  final String phone;
  final String message;
}

class PlatformBulkSmsService {
  PlatformBulkSmsService._();
  static final instance = PlatformBulkSmsService._();

  List<BulkSmsRecipient> buildRecipients({
    required List<SchoolRecord> schools,
    required BulkSmsTemplate template,
    String? customBody,
  }) {
    final creds = SchoolAdminCredentialsService.instance;
    final out = <BulkSmsRecipient>[];
    for (final school in schools) {
      final phone = creds.adminPhoneForSchool(school);
      if (phone == null || phone.trim().isEmpty) continue;
      out.add(
        BulkSmsRecipient(
          school: school,
          phone: phone.trim(),
          message: template.buildMessage(school: school, customBody: customBody),
        ),
      );
    }
    return out;
  }

  Future<bool> sendViaSms({
    required List<BulkSmsRecipient> recipients,
    OtpDeliveryChannel channel = OtpDeliveryChannel.sms,
  }) async {
    if (recipients.isEmpty) return false;

    if (recipients.length == 1) {
      final r = recipients.first;
      final ok = await OtpDeliveryService.instance.deliver(
        phone: r.phone,
        otp: '',
        channel: channel,
        messageOverride: r.message,
      );
      if (ok) await _logSent(recipients, channel);
      return ok;
    }

    final phones = recipients
        .map((r) => PhoneUtils.smsUriPhone(r.phone))
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();
    if (phones.isEmpty) return false;

    // Shared body only when every message is identical.
    final firstMsg = recipients.first.message;
    final sameMessage = recipients.every((r) => r.message == firstMsg);
    final message = sameMessage ? firstMsg : _combinedBulkBody(recipients);

    final uri = Uri(
      scheme: 'sms',
      path: phones.join(','),
      queryParameters: message.isNotEmpty ? {'body': message} : null,
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok) await _logSent(recipients, channel);
    return ok;
  }

  String _combinedBulkBody(List<BulkSmsRecipient> recipients) {
    return 'Maya School Platform update for ${recipients.length} schools. '
        'Please open Maya Platform or contact support ${PlatformOwnerService.primaryPhone}.';
  }

  Future<void> _logSent(
    List<BulkSmsRecipient> recipients,
    OtpDeliveryChannel channel,
  ) async {
    final names = recipients.map((r) => r.school.id).take(5).join(', ');
    final suffix = recipients.length > 5 ? '…' : '';
    await PlatformAuditLogService.instance.log(
      action: 'bulk_sms_sent',
      detail: '${channel.name} · ${recipients.length} admins ($names$suffix)',
    );
  }
}
