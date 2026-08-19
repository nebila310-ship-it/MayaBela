import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mayabela/constants/app_info.dart';
import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';

/// Best-effort crash reports to the `client-crash-report` edge function.
///
/// Never send passwords, tokens, or other secrets. Failures here must not
/// crash the app a second time.
abstract final class CrashReporting {
  static bool _installed = false;
  static bool _sending = false;
  static DateTime? _lastSentAt;

  static void install() {
    if (_installed) return;
    _installed = true;

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(report(details.exception, details.stack, fatal: false));
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(report(error, stack, fatal: true));
      return true;
    };
  }

  static Map<String, String> sanitizeContext(Map<String, Object?> raw) {
    final out = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key.toLowerCase();
      if (_secretKey.hasMatch(key)) continue;
      out[entry.key] = entry.value?.toString() ?? '';
    }
    return out;
  }

  static Future<void> report(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    if (kDebugMode) {
      debugPrint('[CrashReporting] $error');
      return;
    }
    if (_sending) return;
    final now = DateTime.now();
    if (_lastSentAt != null &&
        now.difference(_lastSentAt!) < const Duration(seconds: 8)) {
      return;
    }
    if (!SupabaseBootstrap.isInitialized) return;

    _sending = true;
    _lastSentAt = now;
    try {
      final user = AuthService.currentUser;
      await SupabaseBootstrap.client.functions
          .invoke(
            'client-crash-report',
            body: {
              'message': error.toString(),
              'stack': stack?.toString() ?? '',
              'release': AppInfo.version,
              'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
              'role': user?.roleKey ?? '',
              'schoolId': AuthService.activeSchoolId ?? user?.schoolId ?? '',
              'fatal': fatal,
            },
          )
          .timeout(const Duration(seconds: 4));
    } on FunctionException catch (e) {
      debugPrint('[CrashReporting] invoke failed: ${e.status}');
    } catch (_) {
      // Swallow — reporting must never take down the UI.
    } finally {
      _sending = false;
    }
  }
}

final _secretKey = RegExp(
  r'password|passwd|secret|token|authorization|apikey|session',
  caseSensitive: false,
);
