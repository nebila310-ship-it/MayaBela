import 'package:flutter/material.dart';

import 'package:mayabela/services/platform_mail_cloud_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

/// School-desk check: password-reset email is configured (no owner PIN).
class MailPreflightCard extends StatefulWidget {
  const MailPreflightCard({super.key, this.compact = false});

  final bool compact;

  @override
  State<MailPreflightCard> createState() => MailPreflightCardState();
}

class MailPreflightCardState extends State<MailPreflightCard> {
  bool _loading = true;
  PlatformMailStatus? _status;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => _loading = true);
    final status = await PlatformMailCloudService.instance.publicStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  bool get configured => _status?.configured == true;

  String get _detail {
    final status = _status;
    if (_loading) return 'Checking password-reset email…';
    if (status == null) return 'Could not check password-reset email.';
    if (status.configured) {
      if (status.hasResend) return 'Resend is configured for password reset.';
      if (status.hasSmtp) return 'SMTP is configured for password reset.';
      return 'Password-reset email is configured.';
    }
    return status.errorMessage ??
        'Password-reset email is not configured. Open the platform console.';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return ListTile(
        dense: true,
        leading: Icon(
          _loading
              ? Icons.hourglass_empty
              : configured
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
          color: _loading
              ? Colors.blueGrey
              : configured
                  ? Colors.teal
                  : Colors.orange,
        ),
        title: const Text('Password-reset email configured'),
        subtitle: Text(_detail),
      );
    }

    final color = _loading
        ? Colors.blueGrey
        : configured
            ? Colors.teal
            : Colors.orange;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mark_email_read_outlined, color: color),
          const SizedBox(height: 12),
          Text(
            'Password-reset email',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            _loading
                ? 'Checking…'
                : configured
                    ? 'Configured'
                    : 'Not configured',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color.shade700,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(_detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
