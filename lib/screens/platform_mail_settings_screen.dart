import 'package:flutter/material.dart';
import 'package:mayabela/services/platform_mail_cloud_service.dart';
import 'package:mayabela/utils/email_utils.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

class PlatformMailSettingsScreen extends StatefulWidget {
  const PlatformMailSettingsScreen({super.key});

  @override
  State<PlatformMailSettingsScreen> createState() =>
      _PlatformMailSettingsScreenState();
}

class _PlatformMailSettingsScreenState extends State<PlatformMailSettingsScreen> {
  final _from = TextEditingController(text: 'MayaBela <onboarding@resend.dev>');
  final _resendKey = TextEditingController();
  final _smtpHost = TextEditingController();
  final _smtpPort = TextEditingController(text: '587');
  final _smtpUser = TextEditingController();
  final _smtpPass = TextEditingController();
  final _testTo = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _showSmtp = false;
  PlatformMailStatus? _status;
  String _message = '';
  bool _messageOk = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _from.dispose();
    _resendKey.dispose();
    _smtpHost.dispose();
    _smtpPort.dispose();
    _smtpUser.dispose();
    _smtpPass.dispose();
    _testTo.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    final status = await PlatformMailCloudService.instance.status();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = status;
      if (status.from.trim().isNotEmpty) {
        _from.text = status.from;
      }
      _showSmtp = status.hasSmtp;
      if (!status.ok && status.errorMessage != null) {
        _message = status.errorMessage!;
        _messageOk = false;
      }
    });
  }

  void _toast(String text, {required bool ok}) {
    setState(() {
      _message = text;
      _messageOk = ok;
    });
  }

  Future<void> _save() async {
    if (!EmailUtils.isValidFromHeader(_from.text)) {
      _toast(
        'From must be an email, e.g. MayaBela <onboarding@resend.dev>',
        ok: false,
      );
      return;
    }
    final key = _resendKey.text.trim();
    final host = _smtpHost.text.trim();
    if (key.isEmpty && host.isEmpty && _status?.configured != true) {
      _toast('Paste a Resend API key, or fill SMTP host / user / password.', ok: false);
      return;
    }
    setState(() => _saving = true);
    final status = await PlatformMailCloudService.instance.save(
      from: _from.text.trim(),
      resendApiKey: key.isEmpty ? null : key,
      smtpHost: host.isEmpty ? null : host,
      smtpPort: _smtpPort.text.trim(),
      smtpUser: _smtpUser.text.trim(),
      smtpPass: _smtpPass.text,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _status = status;
    });
    if (!status.ok) {
      _toast(status.errorMessage ?? 'Could not save mail settings.', ok: false);
      return;
    }
    _resendKey.clear();
    _smtpPass.clear();
    _toast('Mail sender saved. Reset codes can be emailed now.', ok: true);
  }

  Future<void> _sendTest() async {
    if (!EmailUtils.isValid(_testTo.text)) {
      _toast('Enter a real inbox to send the test to.', ok: false);
      return;
    }
    setState(() => _testing = true);
    final status = await PlatformMailCloudService.instance.sendTest(_testTo.text);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _status = status.ok ? status : _status;
    });
    if (!status.ok) {
      _toast(status.errorMessage ?? 'Test send failed.', ok: false);
      return;
    }
    _toast('Test email sent to ${_testTo.text.trim()}. Check the inbox.', ok: true);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Password reset email'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: listPagePadding(context),
              children: [
                _statusCard(status),
                const SizedBox(height: 16),
                const Text(
                  'The reset-password page emails a 6-digit code. It needs a sender: a free Resend API key (recommended) or SMTP.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Resend test sender onboarding@resend.dev only delivers to the email you used to sign up at resend.com until you verify a domain.',
                  style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                _field('From address', _from, hint: 'MayaBela <onboarding@resend.dev>'),
                _field(
                  'Resend API key',
                  _resendKey,
                  hint: status?.hasResend == true
                      ? 'Saved — paste a new key only to replace it'
                      : 're_xxxxxxxxxxxx',
                  obscure: true,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Use SMTP instead of Resend',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  value: _showSmtp,
                  activeThumbColor: Colors.tealAccent,
                  onChanged: (v) => setState(() => _showSmtp = v),
                ),
                if (_showSmtp) ...[
                  _field('SMTP host', _smtpHost, hint: 'smtp.gmail.com'),
                  _field('SMTP port', _smtpPort, keyboard: TextInputType.number),
                  _field('SMTP user', _smtpUser),
                  _field('SMTP password', _smtpPass, obscure: true),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Saving…' : 'Save mail sender'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Send a test',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _field('Test inbox', _testTo, keyboard: TextInputType.emailAddress),
                OutlinedButton.icon(
                  onPressed: _testing ? null : _sendTest,
                  icon: _testing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.outgoing_mail),
                  label: Text(_testing ? 'Sending…' : 'Send test email'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                ),
                if (_message.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    _message,
                    style: TextStyle(
                      color: _messageOk ? Colors.lightGreenAccent : Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _statusCard(PlatformMailStatus? status) {
    final ready = status?.configured == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready
              ? Colors.lightGreenAccent.withValues(alpha: 0.45)
              : Colors.orangeAccent.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ready ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
            color: ready ? Colors.lightGreenAccent : Colors.orangeAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ready
                  ? 'Reset email is on'
                  : 'Reset email is not configured yet',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white54),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.lightBlueAccent.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }
}
