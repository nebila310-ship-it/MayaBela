import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/platform_owner_service.dart';

/// OTP-verified platform PIN change — primary owner phone, secondary fallback.
Future<void> showPlatformChangePinFlow(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E293B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _PlatformChangePinSheet(),
  );
}

class _PlatformChangePinSheet extends StatefulWidget {
  const _PlatformChangePinSheet();

  @override
  State<_PlatformChangePinSheet> createState() => _PlatformChangePinSheetState();
}

class _PlatformChangePinSheetState extends State<_PlatformChangePinSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _otp = TextEditingController();

  int _step = 0;
  String _message = '';
  bool _busy = false;
  bool _usedSecondary = false;
  String? _demoOtp;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    _otp.dispose();
    PlatformOwnerService.instance.clearPinChangeSession();
    super.dispose();
  }

  Future<void> _goToOtpStep() async {
    setState(() {
      _message = '';
      _busy = true;
    });

    if (!await PlatformOwnerService.instance.verifyPin(_current.text)) {
      setState(() {
        _busy = false;
        _message = 'Current PIN is wrong';
      });
      return;
    }

    final newPin = _next.text.trim();
    if (newPin.length < PlatformOwnerService.minPinLength ||
        newPin != _confirm.text.trim()) {
      setState(() {
        _busy = false;
        _message =
            'New PINs do not match or are too short (min ${PlatformOwnerService.minPinLength} digits)';
      });
      return;
    }

    final otp = PlatformOwnerService.instance.beginPinChangeOtp(newPin: newPin);
    final sent = await _sendOtpToPrimary(otp);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = 1;
      _demoOtp = kDebugMode ? otp : null;
      _usedSecondary = false;
      _message = sent
          ? 'OTP sent to primary owner phone ${PlatformOwnerService.primaryPhone}'
          : 'Could not open SMS to ${PlatformOwnerService.primaryPhone}. '
              'Tap “Send to secondary number”.';
    });
  }

  Future<bool> _sendOtpToPrimary(String otp) =>
      OtpDeliveryService.instance.deliver(
        phone: PlatformOwnerService.primaryPhone,
        otp: otp,
        channel: OtpDeliveryChannel.sms,
        messageOverride: OtpDeliveryService.instance.buildPlatformPinChangeMessage(otp),
      );

  Future<void> _sendToSecondary() async {
    final otp = PlatformOwnerService.instance.pendingPinChangeOtp;
    if (otp == null) return;

    setState(() {
      _busy = true;
      _message = '';
    });

    final sent = await OtpDeliveryService.instance.deliver(
      phone: PlatformOwnerService.secondaryPhone,
      otp: otp,
      channel: OtpDeliveryChannel.sms,
      messageOverride: OtpDeliveryService.instance.buildPlatformPinChangeMessage(otp),
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _usedSecondary = true;
      _message = sent
          ? 'OTP sent to secondary owner phone ${PlatformOwnerService.secondaryPhone}'
          : 'Could not open SMS to secondary number. Use demo OTP below.';
    });
  }

  Future<void> _saveWithOtp() async {
    setState(() {
      _message = '';
      _busy = true;
    });

    final ok = await PlatformOwnerService.instance.completePinChangeWithOtp(_otp.text);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _busy = false;
        _message = 'Invalid OTP. Check the code and try again.';
      });
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Platform PIN updated'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _step == 0 ? 'Change platform PIN' : 'Verify with OTP',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_step == 0) ...[
              _field(_current, 'Current PIN', obscure: true),
              _field(_next, 'New PIN (min 4 digits)', obscure: true),
              _field(_confirm, 'Confirm new PIN', obscure: true),
            ] else ...[
              Text(
                'Owner phones:\n'
                'Primary ${PlatformOwnerService.primaryPhone}\n'
                'Secondary ${PlatformOwnerService.secondaryPhone}',
                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              _field(_otp, 'Enter OTP', keyboard: TextInputType.number),
              if (_demoOtp != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Demo OTP (testing): $_demoOtp',
                  style: const TextStyle(color: Colors.amber, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _sendToSecondary,
                icon: const Icon(Icons.phone_forwarded),
                label: Text(
                  _usedSecondary
                      ? 'Resend to secondary number'
                      : 'Send to secondary number',
                ),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
              ),
            ],
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _message,
                style: TextStyle(
                  color: _message.toLowerCase().contains('wrong') ||
                          _message.toLowerCase().contains('invalid') ||
                          _message.toLowerCase().contains('could not')
                      ? Colors.redAccent
                      : Colors.greenAccent,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy
                  ? null
                  : (_step == 0 ? _goToOtpStep : _saveWithOtp),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_step == 0 ? 'Send OTP to primary phone' : 'Verify & save PIN'),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard ?? (obscure ? TextInputType.number : null),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

Future<bool> showPlatformPinDialog(BuildContext context) async {
  await PlatformOwnerService.instance.load();
  if (!context.mounted) return false;

  if (!PlatformOwnerService.instance.hasCustomPin && !kDebugMode) {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => const _PlatformPinSetupDialog(),
    );
    return created == true;
  }

  final unlocked = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (context) => const _PlatformPinDialog(),
  );
  return unlocked == true;
}

class _PlatformPinSetupDialog extends StatefulWidget {
  const _PlatformPinSetupDialog();

  @override
  State<_PlatformPinSetupDialog> createState() => _PlatformPinSetupDialogState();
}

class _PlatformPinSetupDialogState extends State<_PlatformPinSetupDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _hint;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final a = _pin.text.trim();
    final b = _confirm.text.trim();
    if (a.length < PlatformOwnerService.minPinLength) {
      setState(() => _hint =
          'PIN must be at least ${PlatformOwnerService.minPinLength} digits');
      return;
    }
    if (a != b) {
      setState(() => _hint = 'PINs do not match');
      return;
    }
    setState(() {
      _busy = true;
      _hint = null;
    });
    // Re-check cloud in case another device already created the owner PIN.
    PlatformOwnerService.instance.resetCloudSyncFlag();
    await PlatformOwnerService.instance.syncPinWithCloud();
    if (PlatformOwnerService.instance.hasCustomPin) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _hint =
            'An owner PIN already exists. Close this and enter that PIN instead.';
      });
      return;
    }
    await PlatformOwnerService.instance.setPin(a);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create owner PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Set the EduAba platform-owner PIN (not a school login password). '
            'Minimum ${PlatformOwnerService.minPinLength} digits. '
            'This PIN syncs across phones and browsers — create it only once.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'New PIN'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirm,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Confirm PIN'),
            onSubmitted: (_) => _save(),
          ),
          if (_hint != null) ...[
            const SizedBox(height: 8),
            Text(_hint!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save PIN'),
        ),
      ],
    );
  }
}

class _PlatformPinDialog extends StatefulWidget {
  const _PlatformPinDialog();

  @override
  State<_PlatformPinDialog> createState() => _PlatformPinDialogState();
}

class _PlatformPinDialogState extends State<_PlatformPinDialog> {
  final _pin = TextEditingController();
  String? _hint;
  bool _checking = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    PlatformOwnerService.instance.load();
  }

  Future<void> _tryUnlock() async {
    if (_checking) return;
    final entered = _pin.text.trim();
    if (entered.isEmpty) {
      setState(() => _hint = 'Enter your PIN');
      return;
    }

    setState(() {
      _checking = true;
      _hint = null;
    });

    final lock = await PlatformOwnerService.instance.lockoutRemaining();
    if (!mounted) return;
    if (lock != null) {
      setState(() {
        _checking = false;
        _hint =
            'Too many attempts. Try again in ${lock.inMinutes + 1} minute(s).';
      });
      return;
    }

    final valid = await PlatformOwnerService.instance.verifyPin(entered);
    if (!mounted) return;

    if (valid) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _checking = false;
      _hint = 'Wrong PIN. Try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Platform access'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Enter your owner PIN.'),
          const SizedBox(height: 12),
          TextField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            enabled: !_checking,
            decoration: const InputDecoration(
              labelText: 'PIN',
            ),
            onSubmitted: (_) => _tryUnlock(),
          ),
          if (_hint != null) ...[
            const SizedBox(height: 8),
            Text(
              _hint!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _checking ? null : _tryUnlock,
          child: _checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Unlock'),
        ),
      ],
    );
  }
}

/// Owner PIN confirmation for destructive actions (e.g. delete school).
Future<bool> verifyOwnerPinPrompt(
  BuildContext context, {
  String title = 'Confirm with your PIN',
  String message = 'Enter your platform owner PIN to continue.',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (context) => _OwnerPinConfirmDialog(
      title: title,
      message: message,
    ),
  );
  return ok == true;
}

class _OwnerPinConfirmDialog extends StatefulWidget {
  const _OwnerPinConfirmDialog({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  State<_OwnerPinConfirmDialog> createState() => _OwnerPinConfirmDialogState();
}

class _OwnerPinConfirmDialogState extends State<_OwnerPinConfirmDialog> {
  final _pin = TextEditingController();
  String? _hint;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    PlatformOwnerService.instance.load();
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _cancel() {
    if (_checking) return;
    Navigator.of(context).pop(false);
  }

  Future<void> _submit() async {
    if (_checking) return;
    final entered = _pin.text.trim();
    if (entered.isEmpty) {
      setState(() => _hint = 'Enter your PIN');
      return;
    }

    setState(() {
      _checking = true;
      _hint = null;
    });

    final valid = await PlatformOwnerService.instance.verifyPin(entered);
    if (!mounted) return;

    if (valid) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _checking = false;
      _hint = 'Wrong PIN. Try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          TextField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            enabled: !_checking,
            decoration: const InputDecoration(
              labelText: 'Owner PIN',
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_hint != null) ...[
            const SizedBox(height: 8),
            Text(
              _hint!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : _cancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _checking ? null : _submit,
          child: _checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirm'),
        ),
      ],
    );
  }
}
