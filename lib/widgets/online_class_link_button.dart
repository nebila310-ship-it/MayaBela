import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mayabela/models/lesson_plan_models.dart';

class OnlineClassLinkButton extends StatelessWidget {
  const OnlineClassLinkButton({super.key, required this.plan});

  final LessonPlan plan;

  Future<void> _open(BuildContext context) async {
    final raw = plan.onlineSessionUrl?.trim() ?? '';
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the class link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!plan.hasOnlineSession) return const SizedBox.shrink();
    final live = plan.onlineSessionIsLive;
    final label = (plan.onlineSessionLabel ?? '').trim().isNotEmpty
        ? plan.onlineSessionLabel!.trim()
        : (live ? 'Join live class' : 'Watch recorded class');
    return FilledButton.tonalIcon(
      onPressed: () => _open(context),
      icon: Icon(live ? Icons.videocam_outlined : Icons.play_circle_outline),
      label: Text(label),
    );
  }
}
