import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/cloud_idle_sync.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/cloud/cloud_sync_flags.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/cloud_outbox_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';

/// Listens for network restore / app resume and flushes the outbox.
abstract final class CloudConnectivitySync {
  static StreamSubscription<List<ConnectivityResult>>? _sub;
  static var _started = false;
  static var _flushScheduled = false;
  static DateTime? _lastFlushAt;

  static Future<void> start() async {
    if (!CloudSyncFlags.enabled) return;
    if (_started) return;
    _started = true;
    await CloudOutboxService.instance.ensureLoaded();

    _sub?.cancel();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (_hasUsableConnection(results)) {
        unawaited(flushIfNeeded(reason: 'connectivity'));
      }
    });

    unawaited(flushIfNeeded(reason: 'startup'));
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  static Future<void> onAppResumed() => flushIfNeeded(reason: 'resume');

  static bool _hasUsableConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn ||
          r == ConnectivityResult.other,
    );
  }

  static Future<void> flushIfNeeded({String reason = 'manual'}) async {
    if (!CloudSyncFlags.enabled) return;
    if (AuthService.currentUser == null) return;
    if (!SupabaseBootstrap.isInitialized) return;

    final now = DateTime.now();
    if (_lastFlushAt != null &&
        now.difference(_lastFlushAt!) < const Duration(seconds: 8)) {
      return;
    }
    if (_flushScheduled || CloudOutboxService.instance.isFlushing) return;
    _flushScheduled = true;

    try {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (AuthService.currentUser == null) return;

      final online = await Connectivity().checkConnectivity();
      if (!_hasUsableConnection(online)) return;

      if (!await SchoolAuthCloudService.hasSchoolClaims()) {
        if (kDebugMode) {
          debugPrint(
            '[CloudConnectivitySync] skip upload ($reason): no school claims',
          );
        }
        return;
      }

      _lastFlushAt = DateTime.now();
      CloudOutboxService.instance.setFlushing(true);
      if (kDebugMode) {
        debugPrint('[CloudConnectivitySync] uploading local data ($reason)');
      }
      await CloudAppStore.instance.flushOutboxForSyncEngine();
      // Also nudge the 5s engine so pull resumes immediately after reconnect.
      if (CloudSyncEngine.isStarted) {
        unawaited(CloudSyncEngine.tick(reason: 'connectivity'));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudConnectivitySync] upload failed ($reason): $e');
      }
    } finally {
      CloudOutboxService.instance.setFlushing(false);
      _flushScheduled = false;
    }
  }
}

class CloudConnectivityLifecycleObserver with WidgetsBindingObserver {
  CloudConnectivityLifecycleObserver._();
  static final instance = CloudConnectivityLifecycleObserver._();

  var _attached = false;

  void attach() {
    if (!CloudSyncFlags.enabled) return;
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!CloudSyncFlags.enabled) return;
    switch (state) {
      case AppLifecycleState.resumed:
        CloudIdleSync.onAppResumed();
        unawaited(CloudConnectivitySync.onAppResumed());
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        CloudIdleSync.onAppHidden();
      case AppLifecycleState.inactive:
        // Dialogs / focus loss — pause the 5s poll only.
        CloudSyncEngine.pause();
      case AppLifecycleState.detached:
        break;
    }
  }
}
