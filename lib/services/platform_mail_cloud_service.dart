import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/platform_owner_service.dart';

class PlatformMailStatus {
  const PlatformMailStatus({
    required this.ok,
    required this.configured,
    this.from = '',
    this.hasResend = false,
    this.hasSmtp = false,
    this.errorCode,
    this.errorMessage,
  });

  final bool ok;
  final bool configured;
  final String from;
  final bool hasResend;
  final bool hasSmtp;
  final String? errorCode;
  final String? errorMessage;

  factory PlatformMailStatus.fromMap(Map<dynamic, dynamic> data) {
    return PlatformMailStatus(
      ok: data['ok'] == true && data['error'] == null,
      configured: data['configured'] == true,
      from: (data['from'] ?? '').toString(),
      hasResend: data['hasResend'] == true,
      hasSmtp: data['hasSmtp'] == true,
      errorCode: data['code']?.toString(),
      errorMessage: data['error']?.toString() ?? data['message']?.toString(),
    );
  }

  static const unauthorized = PlatformMailStatus(
    ok: false,
    configured: false,
    errorCode: 'unauthorized',
    errorMessage: 'Unlock the platform console with your Owner PIN, then retry.',
  );

  static const cloudRequired = PlatformMailStatus(
    ok: false,
    configured: false,
    errorCode: 'cloud_required',
    errorMessage: 'Cloud is not configured on this build.',
  );
}

class PlatformMailCloudService {
  PlatformMailCloudService._();
  static final instance = PlatformMailCloudService._();

  /// Widget tests must not start the 15s functions timeout.
  @visibleForTesting
  static bool disableNetworkForTests = false;

  static const gmailSmtpBlocked =
      'Gmail SMTP cannot be used from MayaBela cloud — that is the Failed to fetch error. Create a free Resend API key at resend.com, paste it in Resend API key, set From to MayaBela <onboarding@resend.dev>, Save, then Send test. It will arrive at the Gmail you used to sign up at Resend.';

  static String _friendlyMailError(String raw, {String? code}) {
    final text = raw.toLowerCase();
    final codeKey = (code ?? '').toLowerCase();
    if (codeKey == 'smtp_blocked' ||
        codeKey == 'smtp_timeout' ||
        text.contains('smtp_blocked') ||
        text.contains('smtp_timeout') ||
        text.contains('failed to fetch') ||
        text.contains('clientexception') ||
        text.contains('timeout')) {
      return gmailSmtpBlocked;
    }
    return raw;
  }

  Future<String?> _ownerPinOrNull() async {
    await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
    if (!SupabaseBootstrap.isInitialized) return null;
    final existing = PlatformOwnerService.instance.sessionOwnerPin?.trim();
    if (existing != null &&
        existing.length >= PlatformOwnerService.minPinLength) {
      return existing;
    }
    await PlatformOwnerService.instance.syncPinWithCloud();
    final pin = PlatformOwnerService.instance.sessionOwnerPin?.trim();
    if (pin == null || pin.length < PlatformOwnerService.minPinLength) {
      return null;
    }
    return pin;
  }

  Future<PlatformMailStatus> _invoke(Map<String, dynamic> body) async {
    try {
      final ownerPin = await _ownerPinOrNull();
      if (!SupabaseBootstrap.isInitialized) {
        return PlatformMailStatus.cloudRequired;
      }
      if (ownerPin == null) return PlatformMailStatus.unauthorized;

      final res = await SupabaseBootstrap.client.functions
          .invoke(
            'platform-mail-config',
            body: {
              'ownerPin': ownerPin,
              ...body,
            },
          )
          .timeout(const Duration(seconds: 20));
      final data = res.data;
      if (data is! Map) {
        return const PlatformMailStatus(
          ok: false,
          configured: false,
          errorCode: 'invalid',
          errorMessage: 'Unexpected cloud response.',
        );
      }
      if (data['error'] != null) {
        final code = (data['code'] as String?) ?? 'invalid';
        return PlatformMailStatus(
          ok: false,
          configured: false,
          errorCode: code,
          errorMessage: _friendlyMailError(
            data['error']?.toString() ?? 'Mail config failed.',
            code: code,
          ),
        );
      }
      return PlatformMailStatus.fromMap(data);
    } on FunctionException catch (e) {
      if (kDebugMode) {
        debugPrint('PlatformMailCloudService: ${e.status} ${e.details}');
      }
      final details = e.details;
      String? code;
      String? message;
      if (details is Map) {
        code = details['code']?.toString();
        message = details['error']?.toString() ?? details['message']?.toString();
      } else if (details is String) {
        message = details;
        final codeMatch = RegExp(r'"code"\s*:\s*"([^"]+)"').firstMatch(details);
        final errMatch = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(details);
        code = codeMatch?.group(1);
        message = errMatch?.group(1) ?? message;
      }
      return PlatformMailStatus(
        ok: false,
        configured: false,
        errorCode: code ?? 'invalid',
        errorMessage: _friendlyMailError(
          message ?? 'Mail config failed (${e.status}).',
          code: code,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PlatformMailCloudService failed: $e');
      }
      return PlatformMailStatus(
        ok: false,
        configured: false,
        errorCode: 'invalid',
        errorMessage: _friendlyMailError(e.toString()),
      );
    }
  }

  Future<PlatformMailStatus> status() => _invoke({'action': 'status'});

  /// School desks: whether password-reset email is configured. No owner PIN.
  Future<PlatformMailStatus> publicStatus() async {
    if (disableNetworkForTests) {
      return PlatformMailStatus.cloudRequired;
    }
    try {
      if (!SupabaseBootstrap.isInitialized) {
        await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
      }
      if (!SupabaseBootstrap.isInitialized) {
        return PlatformMailStatus.cloudRequired;
      }
      final res = await SupabaseBootstrap.client.functions
          .invoke(
            'platform-mail-config',
            body: {'action': 'public-status'},
          )
          .timeout(const Duration(seconds: 15));
      final data = res.data;
      if (data is Map) {
        return PlatformMailStatus.fromMap(data);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PlatformMailCloudService publicStatus: $e');
      }
    }
    return const PlatformMailStatus(
      ok: false,
      configured: false,
      errorCode: 'unavailable',
      errorMessage: 'Could not check password-reset email.',
    );
  }

  Future<PlatformMailStatus> save({
    required String from,
    String? resendApiKey,
    String? smtpHost,
    String? smtpPort,
    String? smtpUser,
    String? smtpPass,
    String? smtpSecure,
  }) {
    return _invoke({
      'action': 'save',
      'from': from.trim(),
      if (resendApiKey != null && resendApiKey.trim().isNotEmpty)
        'resendApiKey': resendApiKey.trim(),
      if (smtpHost != null && smtpHost.trim().isNotEmpty)
        'smtpHost': smtpHost.trim(),
      if (smtpPort != null && smtpPort.trim().isNotEmpty)
        'smtpPort': smtpPort.trim(),
      if (smtpUser != null && smtpUser.trim().isNotEmpty)
        'smtpUser': smtpUser.trim(),
      if (smtpPass != null && smtpPass.trim().isNotEmpty)
        'smtpPass': smtpPass,
      if (smtpSecure != null && smtpSecure.trim().isNotEmpty)
        'smtpSecure': smtpSecure.trim(),
    });
  }

  Future<PlatformMailStatus> sendTest(String to) => _invoke({
        'action': 'test',
        'to': to.trim(),
      });
}
