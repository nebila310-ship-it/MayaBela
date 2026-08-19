import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mayabela/supabase_options.dart';
import 'package:mayabela/utils/startup_profiler.dart';

/// Cloud bootstrap (Supabase). Class name kept for call-site compatibility
/// with the former Firebase layer.
abstract final class SupabaseBootstrap {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static String? lastInitError;
  static String? lastAuthError;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<bool> tryInitialize({bool deferAnonymousAuth = false}) async {
    return StartupProfiler.track('supabase.tryInitialize', () async {
      if (_initialized) return true;
      if (!kSupabaseReady) {
        lastInitError =
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY.';
        if (kDebugMode) {
          debugPrint('SupabaseBootstrap: $lastInitError');
        }
        return false;
      }

      try {
        await Supabase.initialize(
          url: kSupabaseUrl,
          publishableKey: kSupabaseAnonKey,
        ).timeout(const Duration(seconds: 8));
        _initialized = true;
        lastInitError = null;
        return true;
      } catch (e) {
        // initialize may throw if already initialized
        try {
          // ignore: unnecessary_statements
          Supabase.instance.client;
          _initialized = true;
          lastInitError = null;
          return true;
        } catch (_) {
          lastInitError = e.toString();
          if (kDebugMode) {
            debugPrint('SupabaseBootstrap: initialize failed — $e');
          }
          return false;
        }
      }
    });
  }

  static Future<void> ensureAnonymousAuth() => ensureAnonymousAuthReady();

  static Future<bool> ensureAnonymousAuthReady() =>
      StartupProfiler.track('supabase.schoolAuth', ensureReadyForFirestore);

  /// Ensures Supabase session has school role claims in app_metadata.
  static Future<bool> ensureReadyForFirestore() async {
    if (!_initialized) {
      await tryInitialize();
    }
    if (!_initialized) return false;

    lastAuthError = null;
    final user = client.auth.currentUser;
    if (user != null) {
      final meta = user.appMetadata;
      final role = meta['role'];
      final schoolId = meta['schoolId'];
      final ok = role is String &&
          role.isNotEmpty &&
          schoolId is String &&
          schoolId.isNotEmpty;
      if (ok) return true;
      lastAuthError =
          'Cloud session is missing school role claims. Please sign in again.';
      return false;
    }

    lastAuthError =
        'Sign in required for cloud sync. Anonymous cloud access is disabled.';
    if (kDebugMode) {
      debugPrint('SupabaseBootstrap: $lastAuthError');
    }
    return false;
  }

  static Future<void> signOutCloud() async {
    if (!_initialized) return;
    try {
      await client.auth.signOut();
    } catch (_) {}
  }
}
