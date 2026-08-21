import 'package:share_plus/share_plus.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/utils/phone_utils.dart';

class SchoolAdminCredentialsService {
  SchoolAdminCredentialsService._();
  static final instance = SchoolAdminCredentialsService._();

  static const appName = 'Maya School';
  static const appLink = 'https://mayaschool.et/app';

  String? adminNameForSchool(SchoolRecord school) {
    final fromRecord = school.adminFullName?.trim();
    if (fromRecord != null && fromRecord.isNotEmpty) return fromRecord;
    return AuthService.adminUserForSchool(school.id)?.fullName;
  }

  static bool isDisplayablePassword(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return false;
    if (v == AuthService.passwordRedactedMarker) return false;
    if (v.toLowerCase() == 'redacted') return false;
    return true;
  }

  String passwordLabel(SchoolRecord school) {
    final pwd = passwordForSchool(school);
    if (pwd != null) return pwd;
    return 'Hidden after save — set a new temp password to log in';
  }

  bool schoolHasPassword(SchoolRecord school) {
    return isDisplayablePassword(school.adminInitialPassword) ||
        isDisplayablePassword(passwordForSchool(school));
  }

  /// Backfill admin phone/password from in-memory auth into persisted school records.
  Future<int> backfillMissingCredentials() async {
    var updated = 0;
    for (final school in SchoolRegistryService.instance.getAllSchools()) {
      final admin = AuthService.adminUserForSchool(school.id);
      if (admin == null) continue;

      var dirty = false;
      if (school.adminContactPhone == null || school.adminContactPhone!.trim().isEmpty) {
        school.adminContactPhone = admin.phone ?? admin.username;
        dirty = true;
      }
      if (school.adminInitialPassword == null ||
          school.adminInitialPassword!.trim().isEmpty ||
          !SchoolAdminCredentialsService.isDisplayablePassword(
            school.adminInitialPassword,
          )) {
        if (SchoolAdminCredentialsService.isDisplayablePassword(admin.password)) {
          school.adminInitialPassword = admin.password;
          dirty = true;
        }
      }
      if (school.adminFullName == null || school.adminFullName!.trim().isEmpty) {
        if (admin.fullName != null && admin.fullName!.trim().isNotEmpty) {
          school.adminFullName = admin.fullName;
          dirty = true;
        }
      }
      if (dirty) {
        await SchoolRegistryService.instance.updateSchool(school);
        updated++;
      }
    }
    return updated;
  }

  String credentialsClipboardText(SchoolRecord school) {
    final password = passwordForSchool(school);
    final login = adminLoginForSchool(school);
    final expiry = school.subscriptionExpiresAt;
    final expiryLine = expiry == null
        ? 'Open subscription'
        : 'Active until: ${expiry.day}/${expiry.month}/${expiry.year}';

    return '''School: ${school.name}
School ID: ${school.id}
Admin: ${adminNameForSchool(school) ?? '—'}
Login: $login
        Temp password: ${password ?? 'Hidden after save'}
$expiryLine''';
  }

  String? passwordForSchool(SchoolRecord school) {
    final stored = school.adminInitialPassword?.trim();
    if (isDisplayablePassword(stored)) return stored;
    final local = AuthService.adminUserForSchool(school.id)?.password;
    if (isDisplayablePassword(local)) return local;
    return null;
  }

  String? adminPhoneForSchool(SchoolRecord school) {
    final fromRecord = school.adminContactPhone?.trim();
    if (fromRecord != null && fromRecord.isNotEmpty) return fromRecord;
    final admin = AuthService.adminUserForSchool(school.id);
    return admin?.phone ?? admin?.username;
  }

  String adminLoginForSchool(SchoolRecord school) {
    final phone = adminPhoneForSchool(school);
    if (phone == null || phone.isEmpty) return '—';
    return PhoneUtils.loginKey(phone);
  }

  String buildMessage(SchoolRecord school) {
    final password = passwordForSchool(school);
    final login = adminLoginForSchool(school);
    final expiry = school.subscriptionExpiresAt;
    final expiryLine = expiry == null
        ? 'Subscription: open (no end date)'
        : 'Active until: ${expiry.day}/${expiry.month}/${expiry.year}';

    return '''Welcome to $appName!

Your school admin account:

School: ${school.name}
School ID: ${school.id}
Admin login: $login
Temp password: ${password ?? '—'}
$expiryLine

Download the app: $appLink
Sign in as Admin. Please change your password after first login.''';
  }

  Future<bool> sendViaChannel({
    required SchoolRecord school,
    required OtpDeliveryChannel channel,
  }) async {
    final phone = adminPhoneForSchool(school);
    if (phone == null || phone.trim().isEmpty) return false;
    return OtpDeliveryService.instance.deliver(
      phone: phone,
      otp: '',
      channel: channel,
      messageOverride: buildMessage(school),
    );
  }

  Future<void> share(SchoolRecord school) async {
    await Share.share(
      buildMessage(school),
      subject: '$appName — Admin login for ${school.name}',
    );
  }
}
