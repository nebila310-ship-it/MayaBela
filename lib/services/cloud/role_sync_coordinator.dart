import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/cloud/sync_cursor_store.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';

/// Coalesces full role-pack downloads across login, polling, and realtime.
///
/// One in-flight pull per session generation. Extra triggers schedule a single
/// follow-up instead of starting a concurrent pack. Cursor stamps after a
/// successful pull so the 5s engine does not immediately re-download.
abstract final class RoleSyncCoordinator {
  static const bootCursorKey = '_role_boot';

  static Future<void>? _inFlight;
  static int? _inFlightGeneration;
  static var _followUpRequested = false;
  static String? _followUpReason;
  static var _completedPulls = 0;
  static var _skippedBecauseRunning = 0;
  static var _followUpsScheduled = 0;

  static bool get isFullPullRunning => _inFlight != null;

  @visibleForTesting
  static int get debugCompletedPulls => _completedPulls;

  @visibleForTesting
  static int get debugSkippedBecauseRunning => _skippedBecauseRunning;

  @visibleForTesting
  static int get debugFollowUpsScheduled => _followUpsScheduled;

  @visibleForTesting
  static Future<void> Function()? debugPullOverride;

  @visibleForTesting
  static void resetForTests() {
    _inFlight = null;
    _inFlightGeneration = null;
    _followUpRequested = false;
    _followUpReason = null;
    _completedPulls = 0;
    _skippedBecauseRunning = 0;
    _followUpsScheduled = 0;
    debugPullOverride = null;
  }

  static void log(String message) {
    debugPrint('[RoleSync] $message');
  }

  /// Stamp boot + role-collection cursors after the login role pack succeeds.
  static Future<void> markInitialRoleSyncComplete({
    required int generation,
  }) async {
    if (!AuthService.isLiveGeneration(generation)) {
      log('initial role sync cursor skip stale gen=$generation');
      return;
    }
    await _advanceCursors(generation);
    if (AuthService.isLiveGeneration(generation)) {
      log(
        'initial role sync complete gen=$generation '
        'role=${AuthService.currentUser?.roleKey}',
      );
    }
  }

  /// Request a full role download. Same-generation callers share one in-flight
  /// pull and at most one follow-up.
  static Future<bool> requestFullRolePull({
    required String reason,
    required int generation,
  }) async {
    if (!AuthService.isLiveGeneration(generation)) {
      log('full role pull skipped stale gen=$generation reason=$reason');
      return false;
    }

    final inFlight = _inFlight;
    if (inFlight != null) {
      if (_inFlightGeneration == generation) {
        if (!_followUpRequested) {
          _followUpsScheduled++;
        }
        _followUpRequested = true;
        _followUpReason = reason;
        _skippedBecauseRunning++;
        log(
          'full role pull skipped already running gen=$generation '
          'reason=$reason scheduledFollowUp=true',
        );
        try {
          await inFlight;
        } catch (_) {}
        return AuthService.isLiveGeneration(generation);
      }
      log(
        'full role pull other-generation in flight '
        'runningGen=$_inFlightGeneration requestGen=$generation reason=$reason',
      );
    }

    return _runPull(reason: reason, generation: generation);
  }

  static Future<bool> _runPull({
    required String reason,
    required int generation,
  }) async {
    if (!AuthService.isLiveGeneration(generation)) return false;

    late final Future<void> run;
    run = () async {
      log(
        'full role pull requested gen=$generation reason=$reason '
        'role=${AuthService.currentUser?.roleKey}',
      );
      final override = debugPullOverride;
      if (override != null) {
        await override();
      } else {
        await CloudAppStore.instance.pullCurrentRolePack();
      }
    }();

    _inFlight = run;
    _inFlightGeneration = generation;

    try {
      await run;
      if (!AuthService.isLiveGeneration(generation)) {
        log('full role pull aborted stale gen=$generation reason=$reason');
        return false;
      }
      await _advanceCursors(generation);
      if (!AuthService.isLiveGeneration(generation)) return false;
      _completedPulls++;
      log('full role pull finished gen=$generation reason=$reason');
      return true;
    } catch (e) {
      log('full role pull failed gen=$generation reason=$reason');
      rethrow;
    } finally {
      if (identical(_inFlight, run)) {
        _inFlight = null;
        _inFlightGeneration = null;
      }
      final shouldFollowUp = _followUpRequested &&
          AuthService.isLiveGeneration(generation);
      final followReason = _followUpReason ?? 'follow-up';
      _followUpRequested = false;
      _followUpReason = null;
      if (shouldFollowUp) {
        log(
          'full role pull follow-up gen=$generation reason=$followReason',
        );
        unawaited(
          _runPull(reason: followReason, generation: generation),
        );
      }
    }
  }

  static Future<void> _advanceCursors(int generation) async {
    if (!AuthService.isLiveGeneration(generation)) return;
    final cursors = SyncCursorStore.instance;
    await cursors.ensureLoaded();
    if (!AuthService.isLiveGeneration(generation)) return;
    final now = DateTime.now().toUtc();
    final collections = CloudSyncEngine.collectionsForCurrentRole();
    for (final collection in collections) {
      if (!AuthService.isLiveGeneration(generation)) return;
      await cursors.setCursor(collection, now);
    }
    if (!AuthService.isLiveGeneration(generation)) return;
    await cursors.setCursor(bootCursorKey, now);
  }
}
