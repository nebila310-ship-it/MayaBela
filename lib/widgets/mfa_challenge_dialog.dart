import 'package:flutter/material.dart';

import 'package:mayabela/services/golive_service.dart';

Future<bool> showMfaChallengeDialog(
  BuildContext context, {
  required String username,
}) async {
  final controller = TextEditingController();
  var error = '';
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Authenticator code'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'This account uses a second factor. Enter the 6-digit '
                  'code or a recovery code.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                  ),
                  onSubmitted: (_) {
                    final passed = GoliveService.instance.verifyLogin(
                      username,
                      controller.text,
                    );
                    if (passed) {
                      Navigator.pop(ctx, true);
                    } else {
                      setLocal(() => error = 'That code is not valid.');
                    }
                  },
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(error, style: TextStyle(color: Colors.red.shade700)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final passed = GoliveService.instance.verifyLogin(
                    username,
                    controller.text,
                  );
                  if (passed) {
                    Navigator.pop(ctx, true);
                  } else {
                    setLocal(() => error = 'That code is not valid.');
                  }
                },
                child: const Text('Verify'),
              ),
            ],
          );
        },
      );
    },
  );
  controller.dispose();
  return ok == true;
}
