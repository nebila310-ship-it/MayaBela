import 'dart:async';

import 'package:flutter/foundation.dart';

enum CloudSyncProgressPhase { idle, loading, ready, failed }

/// Tracks Firestore cloud sync progress for non-blocking UI (web bottom bar).
class CloudSyncProgressService extends ChangeNotifier {
  CloudSyncProgressService._();
  static final instance = CloudSyncProgressService._();

  CloudSyncProgressPhase _phase = CloudSyncProgressPhase.idle;
  int _completedSteps = 0;
  int _totalSteps = 1;
  String _message = 'Loading school data…';
  Timer? _autoHide;

  DateTime? _loadingStartedAt;

  CloudSyncProgressPhase get phase => _phase;
  bool get isVisible => _phase != CloudSyncProgressPhase.idle;
  bool get isLoading => _phase == CloudSyncProgressPhase.loading;
  bool get isReady => _phase == CloudSyncProgressPhase.ready;
  bool get isFailed => _phase == CloudSyncProgressPhase.failed;

  /// True when a progress chip has been "loading" too long and is blocking live ticks.
  bool get isLoadingStale {
    if (!isLoading || _loadingStartedAt == null) return false;
    return DateTime.now().difference(_loadingStartedAt!) >
        const Duration(seconds: 45);
  }

  /// Whether a cloud pull is currently running.
  bool get isActive => isLoading;

  int get percent =>
      (_phase == CloudSyncProgressPhase.loading ||
              _phase == CloudSyncProgressPhase.failed)
          ? ((_completedSteps / _totalSteps) * 100).round().clamp(0, 99)
          : (_phase == CloudSyncProgressPhase.ready ? 100 : 0);
  int get displayPercent => switch (_phase) {
        CloudSyncProgressPhase.loading => percent,
        CloudSyncProgressPhase.ready => 100,
        CloudSyncProgressPhase.failed => percent,
        CloudSyncProgressPhase.idle => 0,
      };
  String get message => _message;

  void begin({
    required int totalSteps,
    String message = 'Loading school data…',
  }) {
    if (isLoading || isReady || isFailed) return;
    _autoHide?.cancel();
    _phase = CloudSyncProgressPhase.loading;
    _loadingStartedAt = DateTime.now();
    _totalSteps = totalSteps.clamp(1, 99);
    _completedSteps = 0;
    _message = message;
    notifyListeners();
  }

  void step(String message) {
    if (!isLoading) return;
    _message = message;
    _completedSteps = (_completedSteps + 1).clamp(0, _totalSteps);
    notifyListeners();
  }

  void complete({String message = 'Ready'}) {
    if (_phase != CloudSyncProgressPhase.loading &&
        _phase != CloudSyncProgressPhase.ready) {
      return;
    }
    _completedSteps = _totalSteps;
    _phase = CloudSyncProgressPhase.ready;
    _message = message;
    notifyListeners();
    _scheduleAutoHide();
  }

  /// Sync timed out but enough data arrived — show green ready, not red error.
  void completePartial({String message = 'Ready'}) {
    if (_phase != CloudSyncProgressPhase.loading) return;
    _completedSteps = _totalSteps;
    _phase = CloudSyncProgressPhase.ready;
    _message = message;
    notifyListeners();
    _scheduleAutoHide();
  }

  void _scheduleAutoHide() {
    _autoHide?.cancel();
    _autoHide = Timer(const Duration(seconds: 4), reset);
  }

  void fail(String message) {
    if (isReady) return;
    if (!isLoading && !isFailed) return;
    _phase = CloudSyncProgressPhase.failed;
    _message = message;
    notifyListeners();
  }

  /// Hide the chip (logout, dismiss, or platform console).
  void reset() {
    _autoHide?.cancel();
    _autoHide = null;
    if (_phase == CloudSyncProgressPhase.idle) return;
    _phase = CloudSyncProgressPhase.idle;
    _loadingStartedAt = null;
    _completedSteps = 0;
    _totalSteps = 1;
    _message = 'Loading school data…';
    notifyListeners();
  }
}
