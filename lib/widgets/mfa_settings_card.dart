import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/widgets/settings_ui.dart';

class MfaSettingsCard extends StatefulWidget {
  const MfaSettingsCard({super.key});

  @override
  State<MfaSettingsCard> createState() => _MfaSettingsCardState();
}

class _MfaSettingsCardState extends State<MfaSettingsCard> {
  String? _secretOnce;
  List<String> _recoveryOnce = const [];
  String? _error;
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _username => AuthService.currentUser?.username ?? '';

  @override
  Widget build(BuildContext context) {
    final svc = GoliveService.instance;
    final enrolled = svc.isEnabledFor(_username);
    return SettingsSectionCard(
      title: 'Authenticator (optional)',
      subtitle:
          'A second factor after your password. Admin and demo accounts stay '
          'password-only until you enroll.',
      icon: Icons.phonelink_lock_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(enrolled
              ? 'Authenticator is on for $_username.'
              : 'Authenticator is off. This is opt-in.'),
          if (_secretOnce != null) ...[
            const SizedBox(height: 8),
            const Text('Save this secret now. It is not shown again.'),
            SelectableText(_secretOnce!),
            const SizedBox(height: 8),
            const Text('Recovery codes (one-time):'),
            SelectableText(_recoveryOnce.join('  ')),
            TextField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Enter a 6-digit code to finish',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                try {
                  await svc.confirmEnrollment(_username, _code.text);
                  if (!mounted) return;
                  setState(() {
                    _secretOnce = null;
                    _recoveryOnce = const [];
                    _error = null;
                  });
                } catch (e) {
                  setState(() => _error = e.toString());
                }
              },
              child: const Text('Confirm enrollment'),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ),
          const SizedBox(height: 8),
          if (!enrolled && _secretOnce == null)
            SettingsActionTile(
              icon: Icons.add_moderator_outlined,
              title: 'Enroll authenticator',
              subtitle: 'Show a secret and recovery codes once',
              onTap: () async {
                try {
                  final started = await svc.startEnrollment();
                  if (!mounted) return;
                  setState(() {
                    _secretOnce = started.enrollment.secret;
                    _recoveryOnce = started.recoveryCodes;
                    _error = null;
                  });
                } catch (e) {
                  setState(() => _error = e.toString());
                }
              },
            ),
          if (enrolled)
            SettingsActionTile(
              icon: Icons.remove_moderator_outlined,
              title: 'Turn off authenticator',
              subtitle: 'Requires a current code or recovery code',
              onTap: () => _disable(context),
            ),
        ],
      ),
    );
  }

  Future<void> _disable(BuildContext context) async {
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn off authenticator'),
        content: TextField(
          controller: code,
          decoration: const InputDecoration(
            labelText: 'Authenticator or recovery code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      try {
        await GoliveService.instance.disableEnrollment(
          _username,
          code: code.text,
          recoveryCode: code.text,
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      }
    }
    code.dispose();
  }
}
