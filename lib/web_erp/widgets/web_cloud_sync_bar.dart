import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/persistence/cloud_outbox_service.dart';
import 'package:mayabela/services/persistence/cloud_save_honesty.dart';

/// Compact outbox banner: hidden when idle, "Syncing…" / "N waiting" otherwise.
class WebCloudSyncBar extends StatelessWidget {
  const WebCloudSyncBar({
    super.key,
    this.horizontalPadding = 12,
  });

  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        CloudOutboxService.instance,
        AppLocale.instance,
      ]),
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final label = CloudSaveHonesty.bannerLabel(s);
        if (label == null || label.isEmpty) {
          return const SizedBox.shrink();
        }
        final syncing = CloudOutboxService.instance.isFlushing;
        final tone = syncing ? Colors.blue : Colors.orange;
        return Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 0),
          child: Material(
            color: tone.shade50,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              key: const Key('cloud-sync-status-banner'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tone.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    syncing
                        ? Icons.cloud_sync_outlined
                        : Icons.cloud_queue_outlined,
                    size: 16,
                    color: tone.shade900,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: tone.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
