import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/password_hash_service.dart';

/// Hidden platform-owner access. Unlock via secret gesture + PIN.
///
/// Cloud stores only a salted hash (server-side). Clients never download the
/// hash. After unlock, the plaintext PIN is kept in memory for this session
/// so platform edge calls can prove PIN knowledge without sending a stolen hash.
class PlatformOwnerService {
  PlatformOwnerService._();
  static final instance = PlatformOwnerService._();

  /// Debug-only bootstrap. Never used in release once a custom PIN exists.
  static const _debugBootstrapPin = '782901';

  static const primaryPhone = '+251911646444';
  static const secondaryPhone = '+251912798279';

  static const minPinLength = 6;
  static const maxFailedAttempts = 5;
  static const lockoutMinutes = 15;

  static const _pinHashKey = 'platform_owner_pin_hash';
  static const _legacyPinKey = 'platform_owner_pin';
  static const _failCountKey = 'platform_owner_pin_fails';
  static const _lockUntilKey = 'platform_owner_pin_lock_until';
  static const _cloudConfiguredKey = 'platform_owner_pin_cloud_configured';

  String? _pinHash;
  /// In-memory only — never persisted. Cleared on failed lockout.
  String? _sessionPin;
  String? _pendingPinChangeOtp;
  String? _pendingNewPin;
  DateTime? _otpExpiresAt;
  bool _cloudSynced = false;
  bool _cloudConfigured = false;

  bool get hasCustomPin => _pinHash != null && _pinHash!.isNotEmpty;

  /// Opaque local hash for unlock UX only (not an edge authorization token).
  String? get pinHash => _pinHash;

  /// Plaintext PIN for the current unlocked session (edge authorization).
  String? get sessionOwnerPin => _sessionPin;

  bool get cloudPinConfigured => _cloudConfigured;

  /// True when release (or debug without bootstrap) must create a PIN first.
  bool get needsPinSetup =>
      !hasCustomPin && !_cloudConfigured && !kDebugMode;

  void resetCloudSyncFlag() {
    _cloudSynced = false;
  }

  void clearSessionPin() {
    _sessionPin = null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _pinHash = prefs.getString(_pinHashKey);
    _cloudConfigured = prefs.getBool(_cloudConfiguredKey) ?? false;

    // Migrate legacy plaintext PIN → hash, then delete plaintext.
    final legacy = prefs.getString(_legacyPinKey);
    if ((_pinHash == null || _pinHash!.isEmpty) &&
        legacy != null &&
        legacy.trim().isNotEmpty) {
      _pinHash = PasswordHashService.instance.hashPassword(legacy.trim());
      await prefs.setString(_pinHashKey, _pinHash!);
      await prefs.remove(_legacyPinKey);
    }

    await syncPinWithCloud();
  }

  /// Discover whether cloud has a PIN; never download the hash.
  Future<void> syncPinWithCloud() async {
    if (_cloudSynced) return;
    try {
      await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
      if (!SupabaseBootstrap.isInitialized) return;

      final configured = await _cloudPinConfigured();
      _cloudConfigured = configured;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cloudConfiguredKey, configured);

      // First device: push local PIN to cloud if cloud empty and we have session
      // plaintext (only available right after setPin / verify).
      if (!configured &&
          _sessionPin != null &&
          _sessionPin!.trim().length >= minPinLength) {
        await _saveCloudPin(newPin: _sessionPin!, currentOwnerPin: null);
        _cloudConfigured = true;
        await prefs.setBool(_cloudConfiguredKey, true);
      }
      _cloudSynced = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PlatformOwnerService.syncPinWithCloud: $e');
      }
    }
  }

  Future<bool> _cloudPinConfigured() async {
    final res = await SupabaseBootstrap.client.functions.invoke(
      'platform-owner-pin',
      body: {'action': 'status'},
    );
    final data = res.data;
    if (data is! Map) return false;
    return data['configured'] == true;
  }

  Future<bool> _verifyCloudPin(String pin) async {
    final res = await SupabaseBootstrap.client.functions.invoke(
      'platform-owner-pin',
      body: {'action': 'verify', 'ownerPin': pin},
    );
    final data = res.data;
    if (data is Map && data['ok'] == true) return true;
    return false;
  }

  Future<bool> _saveCloudPin({
    required String newPin,
    String? currentOwnerPin,
  }) async {
    try {
      final res = await SupabaseBootstrap.client.functions.invoke(
        'platform-owner-pin',
        body: {
          'action': 'save',
          'newPin': newPin,
          if (currentOwnerPin != null && currentOwnerPin.isNotEmpty)
            'currentOwnerPin': currentOwnerPin,
        },
      );
      final data = res.data;
      if (data is Map && data['error'] != null) return false;
      return data is Map && data['ok'] == true;
    } on FunctionException catch (e) {
      if (kDebugMode) {
        debugPrint('PlatformOwnerService._saveCloudPin: ${e.status} ${e.details}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PlatformOwnerService._saveCloudPin: $e');
      }
      return false;
    }
  }

  Future<Duration?> lockoutRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lockUntilKey);
    if (ms == null) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(ms);
    final left = until.difference(DateTime.now());
    if (left.isNegative) {
      await prefs.remove(_lockUntilKey);
      await prefs.setInt(_failCountKey, 0);
      return null;
    }
    return left;
  }

  Future<bool> verifyPin(String entered) async {
    await load();
    final lock = await lockoutRemaining();
    if (lock != null) return false;

    final candidate = entered.trim();
    if (candidate.length < minPinLength) {
      await _registerFailure();
      return false;
    }

    var ok = false;
    if (hasCustomPin) {
      ok = PasswordHashService.instance.verifyPassword(candidate, _pinHash!);
    }

    // Prefer / fall back to cloud verify (cross-device or hash not local yet).
    if (!ok && (_cloudConfigured || !hasCustomPin)) {
      try {
        await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
        if (SupabaseBootstrap.isInitialized) {
          final cloudOk = await _verifyCloudPin(candidate);
          if (cloudOk) {
            ok = true;
            _pinHash = PasswordHashService.instance.hashPassword(candidate);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_pinHashKey, _pinHash!);
            _cloudConfigured = true;
            await prefs.setBool(_cloudConfiguredKey, true);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('PlatformOwnerService.verifyPin cloud: $e');
        }
      }
    }

    if (!ok && !hasCustomPin && kDebugMode) {
      ok = candidate == _debugBootstrapPin;
      if (ok) {
        await setPin(candidate);
        return true;
      }
    }

    if (ok) {
      _sessionPin = candidate;
      await _clearFailures();
      return true;
    }
    _sessionPin = null;
    await _registerFailure();
    return false;
  }

  Future<void> setPin(String newPin, {String? currentOwnerPin}) async {
    final trimmed = newPin.trim();
    if (trimmed.length < minPinLength) return;
    final previousSession = _sessionPin;
    _pinHash = PasswordHashService.instance.hashPassword(trimmed);
    _sessionPin = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinHashKey, _pinHash!);
    await prefs.remove(_legacyPinKey);
    await _clearFailures();
    final saved = await _saveCloudPin(
      newPin: trimmed,
      currentOwnerPin: currentOwnerPin ?? previousSession,
    );
    if (saved) {
      _cloudConfigured = true;
      await prefs.setBool(_cloudConfiguredKey, true);
    }
    _cloudSynced = true;
  }

  String beginPinChangeOtp({required String newPin}) {
    _pendingNewPin = newPin.trim();
    final random = Random.secure();
    _pendingPinChangeOtp = (100000 + random.nextInt(900000)).toString();
    _otpExpiresAt = DateTime.now().add(const Duration(minutes: 10));
    return _pendingPinChangeOtp!;
  }

  String? get pendingPinChangeOtp =>
      kDebugMode ? _pendingPinChangeOtp : null;

  bool verifyPinChangeOtp(String otp) {
    if (_otpExpiresAt != null && DateTime.now().isAfter(_otpExpiresAt!)) {
      clearPinChangeSession();
      return false;
    }
    return otp.trim().isNotEmpty && otp.trim() == _pendingPinChangeOtp;
  }

  Future<bool> completePinChangeWithOtp(String otp) async {
    if (!verifyPinChangeOtp(otp) || _pendingNewPin == null) return false;
    if (_pendingNewPin!.length < minPinLength) return false;
    await setPin(_pendingNewPin!, currentOwnerPin: _sessionPin);
    clearPinChangeSession();
    return true;
  }

  void clearPinChangeSession() {
    _pendingPinChangeOtp = null;
    _pendingNewPin = null;
    _otpExpiresAt = null;
  }

  Future<void> _registerFailure() async {
    final prefs = await SharedPreferences.getInstance();
    final fails = (prefs.getInt(_failCountKey) ?? 0) + 1;
    await prefs.setInt(_failCountKey, fails);
    if (fails >= maxFailedAttempts) {
      final until = DateTime.now().add(const Duration(minutes: lockoutMinutes));
      await prefs.setInt(_lockUntilKey, until.millisecondsSinceEpoch);
      await prefs.setInt(_failCountKey, 0);
      _sessionPin = null;
    }
  }

  Future<void> _clearFailures() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failCountKey);
    await prefs.remove(_lockUntilKey);
  }
}
