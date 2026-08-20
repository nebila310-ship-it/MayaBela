import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/utils/email_utils.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialSchoolId,
    this.initialEmail,
  });

  final String? initialSchoolId;
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _schoolId;
  late final TextEditingController _email;
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  int _step = 0;
  bool _busy = false;
  String message = '';
  bool _messageOk = false;

  AppStrings get s => AppLocale.instance.strings;

  @override
  void initState() {
    super.initState();
    _schoolId = TextEditingController(text: widget.initialSchoolId ?? '');
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _schoolId.dispose();
    _email.dispose();
    _otp.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String _resetError(String? code) {
    return switch (code) {
      'mail_not_configured' => s.mailNotConfigured,
      'cloud_required' => s.resetNeedsCloud,
      'rate_limited' => s.tooManyAttempts,
      'expired' => s.invalidOtp,
      'invalid_code' => s.invalidOtp,
      'password_too_short' => s.passwordTooShort,
      _ => s.registrationFailed,
    };
  }

  Future<void> _sendCode() async {
    setState(() {
      message = '';
      _messageOk = false;
    });
    if (_schoolId.text.trim().isEmpty) {
      setState(() => message = s.enterSchoolId);
      return;
    }
    if (!EmailUtils.isValid(_email.text)) {
      setState(() => message = s.emailRequired);
      return;
    }

    setState(() => _busy = true);
    final result = await SchoolAuthCloudService.instance.requestPasswordReset(
      schoolId: _schoolId.text,
      email: _email.text,
    );
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        message = _resetError(result.errorCode);
      });
      return;
    }
    setState(() {
      _busy = false;
      _step = 1;
      _messageOk = true;
      message = s.resetCodeSent;
    });
  }

  Future<void> _resetPassword() async {
    setState(() {
      message = '';
      _messageOk = false;
    });
    if (_otp.text.trim().isEmpty) {
      setState(() => message = s.invalidOtp);
      return;
    }
    if (_newPassword.text.length < AuthService.minPasswordLength) {
      setState(() => message = s.passwordTooShort);
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      setState(() => message = s.passwordsNoMatch);
      return;
    }

    setState(() => _busy = true);
    final result = await SchoolAuthCloudService.instance.confirmPasswordReset(
      schoolId: _schoolId.text,
      email: _email.text,
      code: _otp.text,
      newPassword: _newPassword.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      setState(() => message = _resetError(result.errorCode));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.passwordResetSuccess),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(s.goToLogin),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(s.forgotPasswordTitle),
            backgroundColor: Colors.indigo,
          ),
          body: SingleChildScrollView(
            padding: listPagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == 0) ...[
                  TextField(
                    controller: _schoolId,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: s.schoolId,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: s.email,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _busy ? null : _sendCode,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(s.sendOtp),
                  ),
                ] else ...[
                  TextField(
                    controller: _otp,
                    decoration: InputDecoration(
                      labelText: s.enterResetCode,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPassword,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: s.newPassword,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPassword,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: s.reEnterPassword,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _busy ? null : _resetPassword,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(s.resetPassword),
                  ),
                ],
                const SizedBox(height: 12),
                if (message.isNotEmpty)
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _messageOk ? Colors.green.shade800 : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
