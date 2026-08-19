import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/cloud/cloud_sync_flags.dart';

/// Compatibility façade — EDUABA [CloudSyncEngine] owns the 5s loop.
abstract final class RoleCloudLiveSync {
  static const Duration interval = CloudSyncEngine.interval;

  static bool get isStarted => CloudSyncEngine.isStarted;

  static void start() {
    if (!CloudSyncFlags.enabled) return;
    CloudSyncEngine.start();
  }

  static void stop() => CloudSyncEngine.stop();

  static void pause() => CloudSyncEngine.pause();

  static void resume() => CloudSyncEngine.resume();

  static Future<void> tick({String reason = 'manual'}) =>
      CloudSyncEngine.tick(reason: reason);
}
