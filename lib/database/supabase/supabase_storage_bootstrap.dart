import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';

/// Probes and tracks whether Supabase Storage bucket `school-files` is ready.
abstract final class SupabaseStorageBootstrap {
  /// Set true to skip cloud uploads until Storage is verified in your project.
  static const bool deferred = false;

  static bool? _ready;
  static String? _lastError;
  static String? _rlsDeniedUserId;

  static bool get isReady => !deferred && _ready == true;

  static bool get isDeferred => deferred;

  static String? get lastError => _lastError;

  static String get setupHint =>
      'Create the school-files bucket (see supabase/migrations) and ensure '
      'SUPABASE_URL / SUPABASE_ANON_KEY are configured.';

  /// Storage insert policy is `to authenticated`. An anon upload of
  /// `_app_setup_probe/` is "new row violates row-level security policy"
  /// on `storage.objects`.
  @visibleForTesting
  static bool shouldUploadStorageProbe({required bool signedIn}) => signedIn;

  @visibleForTesting
  static bool storageErrorIsRowSecurity(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('row-level security') ||
        text.contains('42501') ||
        text.contains('write_denied');
  }

  static Future<bool> ensureReady({bool forceRecheck = false}) async {
    if (deferred) {
      _ready = false;
      _lastError = null;
      return false;
    }

    if (!SupabaseBootstrap.isInitialized) {
      _ready = false;
      _lastError = 'Supabase is not initialized';
      return false;
    }

    final userId = SupabaseBootstrap.client.auth.currentUser?.id;
    if (_rlsDeniedUserId != null && _rlsDeniedUserId == userId) {
      _ready = false;
      return false;
    }

    final signedIn = SupabaseBootstrap.client.auth.currentSession != null;
    if (!shouldUploadStorageProbe(signedIn: signedIn)) {
      _lastError = 'Sign in before checking storage';
      return false;
    }

    if (!forceRecheck && _ready != null) return _ready!;

    try {
      final path =
          '_app_setup_probe/${DateTime.now().millisecondsSinceEpoch}.txt';
      await SupabaseBootstrap.client.storage
          .from('school-files')
          .uploadBinary(
            path,
            Uint8List.fromList(const [1]),
            fileOptions: const FileOptions(
              contentType: 'text/plain',
              upsert: true,
            ),
          )
          .timeout(const Duration(seconds: 8));
      await SupabaseBootstrap.client.storage
          .from('school-files')
          .remove([path]).timeout(const Duration(seconds: 5));
      _ready = true;
      _lastError = null;
      _rlsDeniedUserId = null;
      return true;
    } catch (e) {
      _ready = false;
      _lastError = e.toString();
      if (storageErrorIsRowSecurity(e)) {
        _rlsDeniedUserId = userId ?? '';
      }
      if (kDebugMode) {
        debugPrint('[SupabaseStorage] Not ready: $_lastError');
      }
      return false;
    }
  }

  static void reset() {
    _ready = null;
    _lastError = null;
    _rlsDeniedUserId = null;
  }
}
