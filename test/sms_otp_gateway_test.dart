import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/forgot_password_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/otp_verification_service.dart';
import 'package:mayabela/utils/phone_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OtpVerificationService.instance.clear();
  });

  test('release auth seed still disables local demo OTP', () {
    expect(AuthService.sendOtp('0911234567'), anyOf('demo_disabled', 'not_found'));
  });

  test('Ethiopian phones normalize to E.164 for the SMS gateway', () {
    expect(PhoneUtils.toE164Ethiopian('0911234567'), '+251911234567');
    expect(PhoneUtils.isValidE164Ethiopian('+251911234567'), isTrue);
    expect(PhoneUtils.isValidE164Ethiopian('+251111234567'), isFalse);
  });

  test('sendOtp requires school ID and a valid Ethiopian mobile', () async {
    final missingSchool = await OtpVerificationService.instance.sendOtp(
      '0911234567',
    );
    expect(missingSchool.success, isFalse);
    expect(missingSchool.error, 'school_mismatch');

    final badPhone = await OtpVerificationService.instance.sendOtp(
      'not-a-phone',
      schoolId: 'TB-001',
    );
    expect(badPhone.success, isFalse);
    expect(badPhone.error, 'invalid_phone');
  });

  test('error copy points at the paid SMS gateway, not Firebase', () {
    final s = AppStrings('en');
    expect(s.otpSmsGatewayRequired.toLowerCase(), contains("africa's talking"));
    expect(s.otpSmsGatewayRequired.toLowerCase(), contains('twilio'));
    expect(s.otpSmsGatewayRequired.toLowerCase(), isNot(contains('firebase')));
    expect(s.otpSmsFailed.toLowerCase(), isNot(contains('firebase')));
    expect(s.otpSmsGatewayHint.toLowerCase(), contains('never shown'));

    final mapped = OtpVerificationService.messageForError(
      strings: s,
      result: const OtpSendResult(
        success: false,
        mode: OtpDeliveryMode.gatewaySms,
        error: 'sms_gateway_required',
      ),
    );
    expect(mapped, s.otpSmsGatewayRequired);
    expect(
      OtpVerificationService.messageForError(
        strings: s,
        result: const OtpSendResult(
          success: false,
          mode: OtpDeliveryMode.gatewaySms,
          error: 'expired',
        ),
      ),
      s.otpExpired,
    );
  });

  testWidgets('forgot password asks for school ID and sends SMS, not a channel picker',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ForgotPasswordScreen(initialSchoolId: 'TB-001'),
      ),
    );
    expect(find.text('TB-001'), findsWidgets);
    expect(
      find.textContaining('We will text a 6-digit code'),
      findsOneWidget,
    );
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('Telegram'), findsNothing);
    expect(find.text('Send OTP'), findsOneWidget);
  });
}
