import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/utils/phone_utils.dart';
import 'package:mayabela/widgets/ethiopian_phone_field.dart';

enum OtpDeliveryMode { firebaseSms, demoInApp }

class OtpSendResult {
  const OtpSendResult({
    required this.success,
    required this.mode,
    this.error,
    this.demoOtp,
    this.e164Phone,
  });

  final bool success;
  final OtpDeliveryMode mode;
  final String? error;
  final String? demoOtp;
  final String? e164Phone;

  OtpSendResult copyWith({
    bool? success,
    OtpDeliveryMode? mode,
    String? error,
    String? demoOtp,
    String? e164Phone,
  }) {
    return OtpSendResult(
      success: success ?? this.success,
      mode: mode ?? this.mode,
      error: error ?? this.error,
      demoOtp: demoOtp ?? this.demoOtp,
      e164Phone: e164Phone ?? this.e164Phone,
    );
  }
}

/// Phone OTP — demo in-app codes in debug. Wire Supabase Auth phone later.
class OtpVerificationService {
  OtpVerificationService._();
  static final instance = OtpVerificationService._();

  String? _pendingDemoOtp;

  bool get usesFirebase => false;

  Future<OtpSendResult> sendOtp(String phoneOrUsername) async {
    await SupabaseBootstrap.tryInitialize();

    final user = AuthService.findUser(phoneOrUsername.trim());
    if (user == null) {
      return const OtpSendResult(
        success: false,
        mode: OtpDeliveryMode.demoInApp,
        error: 'not_found',
      );
    }

    final phone = _resolvePhone(user, phoneOrUsername);
    if (phone == null) {
      return const OtpSendResult(
        success: false,
        mode: OtpDeliveryMode.demoInApp,
        error: 'invalid_phone',
      );
    }

    final e164 = PhoneUtils.toE164Ethiopian(phone);
    if (!PhoneUtils.isValidE164Ethiopian(e164)) {
      return OtpSendResult(
        success: false,
        mode: OtpDeliveryMode.demoInApp,
        error: 'invalid_phone',
        e164Phone: e164,
      );
    }

    AuthService.preparePasswordReset(user.username);

    if (!kDebugMode) {
      return OtpSendResult(
        success: false,
        mode: OtpDeliveryMode.demoInApp,
        error: 'firebase_required',
        e164Phone: e164,
      );
    }

    final otp = AuthService.sendOtp(phoneOrUsername);
    if (otp == 'not_found' || otp == 'demo_disabled') {
      return OtpSendResult(
        success: false,
        mode: OtpDeliveryMode.demoInApp,
        error: otp == 'demo_disabled' ? 'firebase_required' : 'not_found',
      );
    }
    _pendingDemoOtp = otp;
    return OtpSendResult(
      success: true,
      mode: OtpDeliveryMode.demoInApp,
      demoOtp: otp,
      e164Phone: e164,
    );
  }

  String? _resolvePhone(RegisteredUser user, String input) {
    final stored = user.phone?.trim();
    if (stored != null && stored.isNotEmpty) {
      final local = PhoneUtils.normalizeLocal(stored);
      if (local != null) return local;
    }

    final fromInput = PhoneUtils.normalizeLocal(input);
    if (fromInput != null) return fromInput;

    final fromLocalInput = PhoneUtils.normalizeLocal(
      EthiopianPhoneField.localFromInput(input),
    );
    if (fromLocalInput != null) return fromLocalInput;

    final fromUsername = PhoneUtils.normalizeLocal(user.username);
    if (fromUsername != null) return fromUsername;

    return null;
  }

  static bool isFirebaseSetupError(String? error) {
    if (error == null || error.isEmpty) return false;
    if (error == 'firebase_sha1_required') return true;
    final lower = error.toLowerCase();
    return lower.contains('invalid-app-credential') ||
        lower.contains('missing-client-identifier') ||
        lower.contains('app-not-authorized');
  }

  static bool isBillingError(String? error) {
    if (error == null || error.isEmpty) return false;
    final lower = error.toLowerCase();
    return lower.contains('billing');
  }

  static String messageForError({
    required AppStrings strings,
    required OtpSendResult result,
  }) {
    if (result.success && result.mode == OtpDeliveryMode.demoInApp) {
      if (result.error == 'billing_not_enabled') {
        return strings.otpBillingNotEnabled;
      }
      if (result.error == 'firebase_sha1_required' ||
          isFirebaseSetupError(result.error)) {
        return strings.otpFirebaseSha1Setup;
      }
    }
    return switch (result.error) {
      'invalid_phone' => strings.invalidPhone,
      'not_found' => strings.userNotFound,
      'firebase_sha1_required' => strings.otpFirebaseSha1Setup,
      'sms_region_not_enabled' => strings.otpSmsRegionNotEnabled,
      'billing_not_enabled' => strings.otpBillingNotEnabled,
      'too_many_requests' => strings.otpSmsFailedDetail(
          'Too many attempts. Wait a few minutes and try again.',
        ),
      'quota_exceeded' => strings.otpSmsFailedDetail(
          'SMS quota exceeded.',
        ),
      _ when result.e164Phone != null && result.error != null =>
        strings.otpSmsFailedDetail('${result.e164Phone} — ${result.error}'),
      _ => strings.otpSmsFailed,
    };
  }

  Future<bool> verifyAndResetPassword({
    required String code,
    required String newPassword,
  }) async {
    if (newPassword.length < AuthService.minPasswordLength) return false;

    if (_pendingDemoOtp != null && code.trim() == _pendingDemoOtp) {
      final ok = AuthService.resetPassword(code, newPassword);
      _pendingDemoOtp = null;
      return ok;
    }

    return AuthService.resetPassword(code, newPassword);
  }

  bool verifyOtpCode(String code) {
    return AuthService.verifyOtp(code);
  }

  void clear() {
    _pendingDemoOtp = null;
  }
}
