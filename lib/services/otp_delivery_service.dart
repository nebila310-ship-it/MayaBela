import 'package:url_launcher/url_launcher.dart';

import 'package:mayabela/utils/phone_utils.dart';

enum OtpDeliveryChannel { sms, whatsApp, telegram }

class OtpDeliveryService {
  OtpDeliveryService._();
  static final instance = OtpDeliveryService._();

  String buildResetMessage(String otp) =>
      'Your Maya School password reset code is: $otp';

  String buildPlatformPinChangeMessage(String otp) =>
      'Your Maya Platform owner PIN change code is: $otp';

  Future<bool> deliver({
    required String phone,
    required String otp,
    required OtpDeliveryChannel channel,
    String? messageOverride,
  }) async {
    final message = messageOverride ?? buildResetMessage(otp);
    return switch (channel) {
      OtpDeliveryChannel.sms => _sendSms(phone: phone, message: message),
      OtpDeliveryChannel.whatsApp => _sendWhatsApp(phone: phone, message: message),
      OtpDeliveryChannel.telegram => _sendTelegram(phone: phone, message: message),
    };
  }

  Future<bool> _sendSms({
    required String phone,
    required String message,
  }) async {
    final normalized = PhoneUtils.smsUriPhone(phone);
    if (normalized.isEmpty) return false;
    final uri = Uri(
      scheme: 'sms',
      path: normalized,
      queryParameters: {'body': message},
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens WhatsApp (app or web) already addressed to [phone].
  static Uri whatsAppChatUri({
    required String phone,
    required String message,
  }) {
    final digits = PhoneUtils.whatsAppInternationalDigits(phone);
    return Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
    );
  }

  /// Opens Telegram already addressed to [phone] — never the share picker.
  static Uri? telegramChatUri({
    required String phone,
    required String message,
  }) {
    final digits = PhoneUtils.whatsAppInternationalDigits(phone);
    if (digits.length < 10) return null;
    return Uri(
      scheme: 'tg',
      host: 'resolve',
      queryParameters: {
        'phone': digits,
        'text': message,
      },
    );
  }

  Future<bool> _sendWhatsApp({
    required String phone,
    required String message,
  }) async {
    final digits = PhoneUtils.whatsAppInternationalDigits(phone);
    if (digits.length < 10) return false;

    final candidates = <Uri>[
      whatsAppChatUri(phone: phone, message: message),
      Uri(
        scheme: 'whatsapp',
        path: 'send',
        queryParameters: {
          'phone': digits,
          'text': message,
        },
      ),
      Uri.parse(
        'https://api.whatsapp.com/send?phone=$digits&text=${Uri.encodeComponent(message)}',
      ),
    ];

    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        }
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  /// Opens the Telegram chat for this phone — never a "pick a contact" share sheet.
  Future<bool> _sendTelegram({
    required String phone,
    required String message,
  }) async {
    final targeted = telegramChatUri(phone: phone, message: message);
    if (targeted == null) return false;

    final digits = PhoneUtils.whatsAppInternationalDigits(phone);
    final candidates = <Uri>[
      targeted,
      Uri.parse(
        'tg://resolve?phone=$digits&text=${Uri.encodeComponent(message)}',
      ),
    ];

    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        }
      } catch (_) {
        continue;
      }
    }
    return false;
  }
}
