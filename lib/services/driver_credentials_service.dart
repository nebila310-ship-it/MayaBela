import 'package:share_plus/share_plus.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/utils/phone_utils.dart';

class DriverCredentialsService {
  DriverCredentialsService._();
  static final instance = DriverCredentialsService._();

  static const appName = 'Maya School';
  static const appLink = 'https://mayaschool.et/app';

  String loginFor(AdminDriverRecord driver) {
    final stored = driver.loginUsername?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    final phone = driver.phone?.trim();
    if (phone != null && phone.isNotEmpty) {
      return PhoneUtils.loginKey(phone);
    }
    return '—';
  }

  String passwordFor(AdminDriverRecord driver) {
    final stored = driver.initialPassword?.trim();
    if (stored != null &&
        stored.isNotEmpty &&
        stored.length >= AuthService.minPasswordLength &&
        stored != AuthService.demoPassword) {
      return stored;
    }
    return AuthService.tempPassword;
  }

  String buildMessage(AdminDriverRecord driver) {
    final schoolName =
        SchoolRegistryService.instance.displayName(driver.schoolId);
    final login = loginFor(driver);
    final password = passwordFor(driver);

    return '''Welcome to $appName!

Your transport staff account is ready:

Name: ${driver.fullName}
School: $schoolName
School Transport ID: ${driver.driverId}
Route: ${driver.routeName}
Plate number: ${driver.plateNumber}
Login: $login
Temp password: $password

Download the app: $appLink
Sign in as Transport. Please change your password after first login.''';
  }

  Future<bool> sendViaChannel({
    required AdminDriverRecord driver,
    required OtpDeliveryChannel channel,
  }) async {
    final phone = driver.phone?.trim();
    if (phone == null || phone.isEmpty) return false;
    return OtpDeliveryService.instance.deliver(
      phone: phone,
      otp: '',
      channel: channel,
      messageOverride: buildMessage(driver),
    );
  }

  Future<void> share(AdminDriverRecord driver) async {
    await Share.share(
      buildMessage(driver),
      subject: '$appName — Transport login for ${driver.fullName}',
    );
  }
}
