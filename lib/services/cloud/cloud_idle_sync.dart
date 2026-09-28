import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/cloud/cloud_sync_flags.dart';
import 'package:mayabela/services/cloud/realtime_messaging_bootstrap.dart';

/// Stops PostgREST / Realtime work when nobody is using the app.
///
/// Stay-signed-in plus a leftover browser tab (or an always-visible
/// agent Chrome) used to keep the 5s poll and live channels open
/// overnight and melt the free-plan CPU.
abstract final class CloudIdleSync {
  /// No pointer / key activity for this long → pause poll and drop streams.
  @visibleForTesting
  static Duration idleAfter = const Duration(minutes: 2);

  static Timer? _timer;
  static var _idle = false;
  static var _hidden = false;

  static bool get isIdle => _idle;
  static bool get isHidden => _hidden;
  static bool get isLivePaused => _idle || _hidden;

  /// Call when the 5s engine starts so a forgotten visible tab still goes idle.
  static void onEngineStarted() {
    if (!CloudSyncFlags.enabled) return;
    bumpActivity();
  }

  /// Any user input. Restarts the idle timer and wakes live sync if needed.
  static void bumpActivity() {
    if (!CloudSyncFlags.enabled) return;
    _timer?.cancel();
    final wasIdle = _idle;
    _idle = false;
    _timer = Timer(idleAfter, _onIdleTimeout);
    if ((wasIdle || _needsWake) && !_hidden) {
      _needsWake = false;
      _resumeLive();
    }
  }

  static var _needsWake = false;

  static void onAppHidden() {
    if (!CloudSyncFlags.enabled) return;
    _hidden = true;
    _timer?.cancel();
    _pauseLive();
  }

  static void onAppResumed() {
    if (!CloudSyncFlags.enabled) return;
    _hidden = false;
    _idle = false;
    _needsWake = true;
    bumpActivity();
  }

  static void _onIdleTimeout() {
    if (_idle) return;
    if (AuthService.currentUser == null) return;
    _idle = true;
    _pauseLive();
  }

  static void _pauseLive() {
    CloudSyncEngine.pause();
    RealtimeMessagingBootstrap.pauseLive();
    if (kDebugMode) {
      debugPrint(
        '[CloudIdleSync] live sync paused idle=$_idle hidden=$_hidden',
      );
    }
  }

  static void _resumeLive() {
    if (_hidden || _idle) return;
    CloudSyncEngine.resume();
    RealtimeMessagingBootstrap.resumeLive();
  }

  @visibleForTesting
  static void resetForTests() {
    _timer?.cancel();
    _timer = null;
    _idle = false;
    _hidden = false;
    _needsWake = false;
    idleAfter = const Duration(minutes: 2);
  }
}
