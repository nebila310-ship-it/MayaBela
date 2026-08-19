import 'package:flutter/material.dart';

import 'package:mayabela/widgets/maya_floating_chat.dart';

/// Hosts the Maya FAB inside the active route.
///
/// Sync runs in the background with no status chip (Ready / Queued removed).
class AppFloatingChrome extends StatelessWidget {
  const AppFloatingChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        child,
        const MayaFloatingChat(),
      ],
    );
  }
}
