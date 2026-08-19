import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';

/// Probes and tracks whether Supabase Storage bucket `school-files` is ready.
abstract final class SupabaseStorageBootstrap {
  /// Set true to skip cloud uploads until Storage is verified in your project.
  static const bool deferred = false;

  static bool? _ready;
  static String? _lastError;

  static bool get isReady => !deferred && _ready == true;

  static bool get isDeferred => deferred;

  static String? get lastError => _lastError;

  static String get setupHint =>
      'Create the school-files bucket (see supabase/migrations) and ensure '
      'SUPABASE_URL / SUPABASE_ANON_KEY are configured.';

  static Future<bool> ensureReady({bool forceRecheck = false}) async {
    if (deferred) {
      _ready = false;
      _lastError = null;
      return false;
    }

    if (!forceRecheck && _ready != null) return _ready!;

    if (!SupabaseBootstrap.isInitialized) {
      _ready = false;
      _lastError = 'Supabase is not initialized';
      return false;
    }

    try {
      final path =
          '_app_setup_probe/${DateTime.now().millisecondsSinceEpoch}.txt';
      await SupabaseBootstrap.client.storage.from('school-files').uploadBinary(
            path,
            Uint8List.fromList(const [1]),
            fileOptions: const FileOptions(
              contentType: 'text/plain',
              upsert: true,
            ),
          );
      await SupabaseBootstrap.client.storage.from('school-files').remove([path]);
      _ready = true;
      _lastError = null;
      return true;
    } catch (e) {
      _ready = false;
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint('[SupabaseStorage] Not ready: $_lastError');
      }
      return false;
    }
  }

  static void reset() {
    _ready = null;
    _lastError = null;
  }
}
