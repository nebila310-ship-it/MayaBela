import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/device_cloud_sync_state.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/utils/startup_profiler.dart';

/// Shared, deduped Firestore pull used on fresh installs and before login.
abstract final class CloudBootstrapService {
  static bool _pullCompleted = false;
  static Completer<void>? _pullCompleter;

  static bool get pullCompleted => _pullCompleted;

  /// Allow another full pull when this device still has no local data.
  static void resetIfRegistriesEmpty() {
    if (!DeviceCloudSyncState.registriesLookEmpty) return;
    _pullCompleted = false;
    _pullCompleter = null;
  }

  static Future<void> ensureFullCloudPull({
    Duration? timeout,
    bool trackProgress = false,
  }) async {
    if (_pullCompleted) return;
    if (_pullCompleter != null) return _pullCompleter!.future;

    if (!SupabaseBootstrap.isInitialized) return;
    if (!await SupabaseBootstrap.ensureReadyForFirestore()) return;

    final completer = Completer<void>();
    _pullCompleter = completer;

    try {
      await StartupProfiler.track('cloudBootstrap.fullPull', () async {
        await SupabaseBootstrap.ensureAnonymousAuthReady();
        await CloudAppStore.instance
            .pullIntoLocalServices(trackProgress: trackProgress)
            .timeout(
              timeout ??
                  (kIsWeb
                      ? const Duration(seconds: 25)
                      : const Duration(seconds: 45)),
            );
      });
      _pullCompleted = true;
      completer.complete();
    } catch (e, st) {
      _pullCompleter = null;
      if (kDebugMode) {
        debugPrint('[CloudBootstrap] full pull failed: $e\n$st');
      }
      completer.completeError(e);
      rethrow;
    }
  }

  /// Pre-login credential pull removed — authentication is server-side.
  static Future<void> ensureLoginCredentialsFromCloud() async {
    // schoolLogin Cloud Function verifies credentials; no pre-login password sync.
  }
}
