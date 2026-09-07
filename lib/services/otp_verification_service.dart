import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/utils/phone_utils.dart';
import 'package:mayabela/widgets/ethiopian_phone_field.dart';

enum OtpDeliveryMode { gatewaySms, firebaseSms, demoInApp }

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

/// Phone OTP via a paid SMS gateway (Africa's Talking / Twilio).
/// Debug-only in-app codes are used only when the gateway is not configured.
class OtpVerificationService {
  OtpVerificationService._();
  static final instance = OtpVerificationService._();

  String? _pendingDemoOtp;
  String? _pendingPhone;
  String? _pendingSchoolId;

  bool get usesFirebase => false;

  Future<OtpSendResult> sendOtp(
    String phoneOrUsername, {
    String? schoolId,
  }) async {
    await SupabaseBootstrap.tryInitialize();

    final phone = _resolvePhoneInput(phoneOrUsername);
    if (phone == null) {
      return const OtpSendResult(
        success: false,
        mode: OtpDeliveryMode.gatewaySms,
        error: 'invalid_phone',
      );
    }

    final e164 = PhoneUtils.toE164Ethiopian(phone);
    if (!PhoneUtils.isValidE164Ethiopian(e164)) {
      return OtpSendResult(
        success: false,
        mode: OtpDeliveryMode.gatewaySms,
        error: 'invalid_phone',
        e164Phone: e164,
      );
    }

    final sid = (schoolId ?? AuthService.activeSchoolId ?? '').trim().toUpperCase();
    if (sid.isEmpty) {
      return const OtpSendResult(
        success: false,
        mode: OtpDeliveryMode.gatewaySms,
        error: 'school_mismatch',
      );
    }

    _pendingPhone = phone;
    _pendingSchoolId = sid;

    final localUser = AuthService.findUser(phoneOrUsername.trim()) ??
        AuthService.findUser(phone);
    if (localUser != null) {
      AuthService.preparePasswordReset(localUser.username);
    }

    if (SchoolAuthCloudService.instance.isAvailable) {
      final cloud = await SchoolAuthCloudService.instance.sendPasswordResetOtp(
        phone: phone,
        schoolId: sid,
      );
      if (cloud.ok) {
        _pendingDemoOtp = null;
        return OtpSendResult(
          success: true,
          mode: OtpDeliveryMode.gatewaySms,
          e164Phone: cloud.errorMessage ?? e164,
        );
      }
      if (cloud.errorCode != 'sms_gateway_required' &&
          cloud.errorCode != 'cloud_required') {
        return OtpSendResult(
          success: false,
          mode: OtpDeliveryMode.gatewaySms,
          error: cloud.errorCode ?? 'sms_failed',
          e164Phone: e164,
        );
      }
      if (!kDebugMode) {
        return OtpSendResult(
          success: false,
          mode: OtpDeliveryMode.gatewaySms,
          error: cloud.errorCode ?? 'sms_gateway_required',
          e164Phone: e164,
        );
      }
    } else if (!kDebugMode) {
      return OtpSendResult(
        success: false,
        mode: OtpDeliveryMode.gatewaySms,
        error: 'sms_gateway_required',
        e164Phone: e164,
      );
    }

    final otp = AuthService.sendOtp(phoneOrUsername);
    if (otp == 'not_found' || otp == 'demo_disabled' || otp == null) {
      return OtpSendResult(
        success: false,
        mode: OtpDeliveryMode.demoInApp,
        error: otp == 'demo_disabled' ? 'sms_gateway_required' : 'not_found',
        e164Phone: e164,
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

  String? _resolvePhoneInput(String input) {
    final user = AuthService.findUser(input.trim());
    if (user != null) {
      final stored = user.phone?.trim();
      if (stored != null && stored.isNotEmpty) {
        final local = PhoneUtils.normalizeLocal(stored);
        if (local != null) return local;
      }
      final fromUsername = PhoneUtils.normalizeLocal(user.username);
      if (fromUsername != null) return fromUsername;
    }

    final fromInput = PhoneUtils.normalizeLocal(input);
    if (fromInput != null) return fromInput;

    return PhoneUtils.normalizeLocal(
      EthiopianPhoneField.localFromInput(input),
    );
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
    return lower.contains('billing') || error == 'sms_gateway_required';
  }

  static String messageForError({
    required AppStrings strings,
    required OtpSendResult result,
  }) {
    if (result.success && result.mode == OtpDeliveryMode.demoInApp) {
      if (result.error == 'billing_not_enabled' ||
          result.error == 'sms_gateway_required') {
        return strings.otpSmsGatewayRequired;
      }
    }
    return switch (result.error) {
      'invalid_phone' => strings.invalidPhone,
      'not_found' => strings.userNotFound,
      'school_mismatch' => strings.invalidSchoolId,
      'sms_gateway_required' => strings.otpSmsGatewayRequired,
      'sms_failed' => strings.otpSmsFailed,
      'firebase_sha1_required' => strings.otpSmsGatewayRequired,
      'sms_region_not_enabled' => strings.otpSmsFailed,
      'billing_not_enabled' => strings.otpSmsGatewayRequired,
      'too_many_requests' || 'rate_limited' || 'too_many_attempts' =>
        strings.otpSmsFailedDetail(
          'Too many attempts. Wait a few minutes and try again.',
        ),
      'quota_exceeded' => strings.otpSmsFailedDetail('SMS quota exceeded.'),
      'expired' => strings.otpExpired,
      'invalid_otp' => strings.invalidOtp,
      _ when result.e164Phone != null && result.error != null =>
        strings.otpSmsFailedDetail('${result.e164Phone} — ${result.error}'),
      _ => strings.otpSmsFailed,
    };
  }

  Future<bool> verifyAndResetPassword({
    required String code,
    required String newPassword,
    String? phone,
    String? schoolId,
  }) async {
    if (newPassword.length < AuthService.minPasswordLength) return false;

    final sid = (schoolId ?? _pendingSchoolId ?? AuthService.activeSchoolId ?? '')
        .trim()
        .toUpperCase();
    final phoneKey = phone ?? _pendingPhone;
    if (sid.isNotEmpty &&
        phoneKey != null &&
        phoneKey.isNotEmpty &&
        SchoolAuthCloudService.instance.isAvailable) {
      final cloud = await SchoolAuthCloudService.instance.resetPasswordWithOtp(
        phone: phoneKey,
        schoolId: sid,
        otp: code,
        newPassword: newPassword,
      );
      if (cloud.ok) {
        _pendingDemoOtp = null;
        if (AuthService.findUser(phoneKey) != null) {
          AuthService.preparePasswordReset(
            AuthService.findUser(phoneKey)!.username,
          );
          AuthService.resetPasswordWithoutOtpCheck(
            newPassword,
            syncCloud: false,
          );
        }
        return true;
      }
      if (cloud.errorCode != 'cloud_required' &&
          cloud.errorCode != 'sms_gateway_required') {
        return false;
      }
    }

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
    _pendingPhone = null;
    _pendingSchoolId = null;
  }
}
