import 'package:flutter/material.dart';

import 'package:mayabela/screens/student_first_login_screen.dart';

/// Optional reminder after first login with a temporary password.
class StudentPasswordChangeBanner extends StatelessWidget {
  const StudentPasswordChangeBanner({
    super.key,
    required this.onDismiss,
  });

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.amber.shade100,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_reset, color: Colors.amber.shade900),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Temporary password',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You can change your password now, or do it later from Settings.',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: onDismiss,
                        child: const Text('Later'),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StudentFirstLoginScreen(
                                skippable: true,
                              ),
                            ),
                          );
                          if (context.mounted) onDismiss();
                        },
                        child: const Text('Change now'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
