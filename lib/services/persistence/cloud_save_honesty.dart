import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/cloud_outbox_service.dart';

/// Whether a user save left the device or is still queued locally.
enum CloudSaveOutcome {
  synced,
  syncing,
  waiting,
}

/// Honest save/sync copy: never claim a cloud write that only hit the outbox.
abstract final class CloudSaveHonesty {
  static CloudOutboxService get _outbox => CloudOutboxService.instance;

  static String? bannerLabel(AppStrings s) {
    if (_outbox.isFlushing) return s.cloudSyncingBanner;
    if (!_outbox.hasPending) return null;
    return s.cloudWaitingChangesBanner(_outbox.pendingCount);
  }

  /// Await the local persist, retry the outbox, then report what actually left.
  static Future<CloudSaveOutcome> settle({Future<void>? persist}) async {
    if (persist != null) {
      try {
        await persist;
      } catch (_) {}
    }
    await _outbox.ensureLoaded();
    try {
      await CloudAppStore.instance.flushOutboxForSyncEngine();
    } catch (_) {}
    if (_outbox.isFlushing) return CloudSaveOutcome.syncing;
    if (_outbox.hasPending) return CloudSaveOutcome.waiting;
    return CloudSaveOutcome.synced;
  }

  static String snackbarMessage({
    required String savedOk,
    required CloudSaveOutcome outcome,
    required AppStrings strings,
  }) {
    return switch (outcome) {
      CloudSaveOutcome.synced => savedOk,
      CloudSaveOutcome.syncing => strings.savedSyncingToCloud,
      CloudSaveOutcome.waiting => strings.savedWaitingToSync,
    };
  }

  static Color snackbarColor(CloudSaveOutcome outcome) {
    return switch (outcome) {
      CloudSaveOutcome.synced => Colors.green,
      CloudSaveOutcome.syncing => Colors.blue.shade700,
      CloudSaveOutcome.waiting => Colors.orange.shade800,
    };
  }

  static SnackBar snackBar({
    required String savedOk,
    required CloudSaveOutcome outcome,
    required AppStrings strings,
  }) {
    return SnackBar(
      content: Text(
        snackbarMessage(
          savedOk: savedOk,
          outcome: outcome,
          strings: strings,
        ),
      ),
      backgroundColor: snackbarColor(outcome),
    );
  }
}
