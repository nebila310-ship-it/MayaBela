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

  Future<bool> _sendWhatsApp({
    required String phone,
    required String message,
  }) async {
    final digits = PhoneUtils.whatsAppInternationalDigits(phone);
    if (digits.length < 10) return false;

    final candidates = <Uri>[
      Uri.parse(
        'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
      ),
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

  /// Opens the installed Telegram app — never telegram.org in the browser.
  Future<bool> _sendTelegram({
    required String phone,
    required String message,
  }) async {
    final candidates = <Uri>[];

    final local = PhoneUtils.normalizeLocal(phone);
    if (local != null) {
      // Chat with the account linked to this phone number.
      candidates.add(
        Uri(
          scheme: 'tg',
          host: 'resolve',
          queryParameters: {
            'phone': '251${local.substring(1)}',
            'text': message,
          },
        ),
      );
    }

    candidates.addAll([
      // Pre-filled message compose inside Telegram.
      Uri(scheme: 'tg', host: 'msg', queryParameters: {'text': message}),
      Uri(
        scheme: 'tg',
        host: 'msg_url',
        queryParameters: {'url': '', 'text': message},
      ),
      Uri.parse('telegram://msg?text=${Uri.encodeComponent(message)}'),
    ]);

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
