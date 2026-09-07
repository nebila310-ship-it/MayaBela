import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/otp_verification_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/ethiopian_phone_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialSchoolId});

  final String? initialSchoolId;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _schoolId;
  final _identifier = TextEditingController();
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _otpService = OtpVerificationService.instance;

  int _step = 0;
  bool _sending = false;
  String message = '';
  OtpDeliveryMode? _otpMode;

  AppStrings get s => AppLocale.instance.strings;

  @override
  void initState() {
    super.initState();
    final seed = (widget.initialSchoolId ?? AuthService.activeSchoolId ?? '')
        .trim()
        .toUpperCase();
    _schoolId = TextEditingController(text: seed);
  }

  @override
  void dispose() {
    _schoolId.dispose();
    _identifier.dispose();
    _otp.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String get _phoneInput {
    final local = EthiopianPhoneField.localFromInput(_identifier.text);
    return local.isEmpty ? _identifier.text.trim() : local;
  }

  Future<void> _sendOtp() async {
    setState(() => message = '');
    if (_schoolId.text.trim().isEmpty) {
      setState(() => message = s.invalidSchoolId);
      return;
    }
    if (_identifier.text.trim().isEmpty) {
      setState(() => message = s.invalidPhone);
      return;
    }

    setState(() => _sending = true);
    final result = await _otpService.sendOtp(
      _phoneInput,
      schoolId: _schoolId.text.trim().toUpperCase(),
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _sending = false;
        message = OtpVerificationService.messageForError(
          strings: s,
          result: result,
        );
      });
      return;
    }

    setState(() {
      _sending = false;
      _otpMode = result.mode;
      _step = 1;
      message = result.mode == OtpDeliveryMode.gatewaySms
          ? (result.e164Phone != null
              ? '${s.otpSentViaSms} ${result.e164Phone}'
              : s.otpSentViaSms)
          : '${s.otpFirebaseFallback}\n${s.demoOtpNote}\n${result.demoOtp}';
    });
  }

  Future<void> _resetPassword() async {
    setState(() => message = '');
    if (_newPassword.text.length < AuthService.minPasswordLength) {
      setState(() => message = s.passwordTooShort);
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      setState(() => message = s.passwordsNoMatch);
      return;
    }

    final ok = await _otpService.verifyAndResetPassword(
      code: _otp.text,
      newPassword: _newPassword.text,
      phone: _phoneInput,
      schoolId: _schoolId.text.trim().toUpperCase(),
    );
    if (!ok) {
      setState(() => message = s.invalidOtp);
      return;
    }

    if (!mounted) return;
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
                      hintText: 'TB-001',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  EthiopianPhoneField(
                    controller: _identifier,
                    label: s.enterEmailOrPhone,
                    hintText: '911234567',
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.otpSmsGatewayHint,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _sending ? null : _sendOtp,
                    child: _sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(s.sendOtp),
                  ),
                ] else ...[
                  Chip(
                    avatar: const Icon(Icons.sms_outlined, size: 18),
                    label: Text(
                      _otpMode == OtpDeliveryMode.gatewaySms
                          ? s.otpSentViaSms
                          : s.otpFirebaseFallback,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otp,
                    decoration: InputDecoration(
                      labelText: s.enterOtp,
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
                    onPressed: _resetPassword,
                    child: Text(s.resetPassword),
                  ),
                ],
                const SizedBox(height: 12),
                if (message.isNotEmpty)
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _step == 1 ? Colors.green.shade800 : Colors.red,
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
