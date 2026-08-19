import 'package:url_launcher/url_launcher.dart';

import 'package:mayabela/utils/phone_utils.dart';

/// Launch phone dialer or SMS for a normalized Ethiopian number.
class PhoneLaunchService {
  PhoneLaunchService._();
  static final instance = PhoneLaunchService._();

  Future<bool> dial(String phone) async {
    final tel = PhoneUtils.telUriPhone(phone);
    if (tel.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: tel);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
