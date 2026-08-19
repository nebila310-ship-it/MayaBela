import 'package:flutter/material.dart';

/// Intentionally empty — cloud sync runs in the background with no chip.
/// Kept so any leftover imports still compile.
class WebCloudSyncBar extends StatelessWidget {
  const WebCloudSyncBar({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
