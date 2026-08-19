import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/otp_verification_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/ethiopian_phone_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _identifier = TextEditingController();
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _otpService = OtpVerificationService.instance;

  int _step = 0;
  bool _sending = false;
  String message = '';
  OtpDeliveryChannel? _deliveryChannel;
  OtpDeliveryMode? _otpMode;

  AppStrings get s => AppLocale.instance.strings;

  @override
  void dispose() {
    _identifier.dispose();
    _otp.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _pickChannelAndSendOtp() async {
    setState(() => message = '');
    if (_identifier.text.trim().isEmpty) {
      setState(() => message = s.invalidPhone);
      return;
    }

    final channel = await showModalBottomSheet<OtpDeliveryChannel>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.chooseOtpChannel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.sms_outlined, color: Colors.teal),
                title: Text(s.sendViaSms),
                onTap: () => Navigator.pop(context, OtpDeliveryChannel.sms),
              ),
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.green),
                title: Text(s.sendViaWhatsApp),
                onTap: () => Navigator.pop(context, OtpDeliveryChannel.whatsApp),
              ),
              ListTile(
                leading: const Icon(Icons.send, color: Colors.lightBlue),
                title: Text(s.sendViaTelegram),
                onTap: () => Navigator.pop(context, OtpDeliveryChannel.telegram),
              ),
            ],
          ),
        ),
      ),
    );

    if (channel == null || !mounted) return;

    setState(() => _sending = true);
    final result = await _otpService.sendOtp(
      EthiopianPhoneField.localFromInput(_identifier.text).isEmpty
          ? _identifier.text.trim()
          : EthiopianPhoneField.localFromInput(_identifier.text),
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

    _otpMode = result.mode;

    var delivered = false;
    if (result.mode == OtpDeliveryMode.demoInApp && result.demoOtp != null) {
      delivered = await OtpDeliveryService.instance.deliver(
        phone: _identifier.text.trim(),
        otp: result.demoOtp!,
        channel: channel,
      );
    }

    if (!mounted) return;

    final channelLabel = switch (channel) {
      OtpDeliveryChannel.sms => s.sendViaSms,
      OtpDeliveryChannel.whatsApp => s.sendViaWhatsApp,
      OtpDeliveryChannel.telegram => s.sendViaTelegram,
    };

    final setupFallback =
        OtpVerificationService.isFirebaseSetupError(result.error) ||
            OtpVerificationService.isBillingError(result.error);
    final setupNote = setupFallback
        ? (OtpVerificationService.isBillingError(result.error)
            ? '${s.otpBillingNotEnabled}\n\n'
            : '${s.otpFirebaseSha1Setup}\n\n')
        : '';

    setState(() {
      _sending = false;
      _deliveryChannel = channel;
      _step = 1;
      message = result.mode == OtpDeliveryMode.firebaseSms
          ? (result.e164Phone != null
              ? '${s.otpSentViaSms} ${result.e164Phone}'
              : s.otpSentViaSms)
          : delivered
              ? '$setupNote${s.otpDeliveredVia(channelLabel)}\n${s.demoOtpNote}\n${result.demoOtp}'
              : '$setupNote${s.otpDeliveryFailed}\n${s.demoOtpNote}\n${result.demoOtp}';
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
                  EthiopianPhoneField(
                    controller: _identifier,
                    label: s.enterEmailOrPhone,
                    hintText: '911234567',
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _sending ? null : _pickChannelAndSendOtp,
                    child: _sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(s.sendOtp),
                  ),
                ] else ...[
                  if (_deliveryChannel != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Chip(
                        avatar: Icon(
                          switch (_deliveryChannel!) {
                            OtpDeliveryChannel.sms => Icons.sms_outlined,
                            OtpDeliveryChannel.whatsApp => Icons.chat,
                            OtpDeliveryChannel.telegram => Icons.send,
                          },
                          size: 18,
                        ),
                        label: Text(
                          _otpMode == OtpDeliveryMode.firebaseSms
                              ? s.otpSentViaSms
                              : switch (_deliveryChannel!) {
                                  OtpDeliveryChannel.sms => s.sendViaSms,
                                  OtpDeliveryChannel.whatsApp => s.sendViaWhatsApp,
                                  OtpDeliveryChannel.telegram => s.sendViaTelegram,
                                },
                        ),
                      ),
                    ),
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
