import 'package:flutter/material.dart';

import 'package:mayabela/web_erp/utils/web_viewport.dart';

class WebHelpFab extends StatelessWidget {
  const WebHelpFab({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = WebViewport.isCompactPhone(context);
    if (compact) {
      return FloatingActionButton(
        onPressed: () => _showHelp(context),
        tooltip: 'Help',
        child: const Icon(Icons.help_outline),
      );
    }
    return FloatingActionButton.extended(
      onPressed: () => _showHelp(context),
      icon: const Icon(Icons.help_outline),
      label: const Text('Help'),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('MaJo Web Admin — Quick Guide'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Keyboard shortcuts'),
              SizedBox(height: 8),
              Text('• Ctrl+K — Global search'),
              Text('• Ctrl+/ — Global search'),
              SizedBox(height: 16),
              Text('Tips'),
              SizedBox(height: 8),
              Text('• Pin pages with the star in breadcrumbs'),
              Text('• Use Quick Add (+) for common tasks'),
              Text('• Session auto-locks after 30 minutes idle'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
