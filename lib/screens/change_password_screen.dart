import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/password_hash_service.dart';
import 'package:mayabela/utils/auth_navigation.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/settings_ui.dart';

/// Direct password change — no OTP. Used from Settings and forced first login.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});

  /// When true (first login with temp password), user cannot leave until changed.
  final bool forced;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _saving = false;
  String? _error;

  AppStrings get s => AppLocale.instance.strings;

  @override
  void dispose() {
    _currentController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _currentMatches(String stored, String entered) {
    if (stored == entered) return true;
    if (PasswordHashService.instance.isHashed(stored)) {
      return PasswordHashService.instance.verifyPassword(entered, stored);
    }
    return false;
  }

  Future<void> _save() async {
    final current = _currentController.text;
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    final user = AuthService.currentUser;
    if (user == null) return;

    if (!widget.forced) {
      if (current.isEmpty) {
        setState(() => _error = s.changePasswordCurrentRequired);
        return;
      }
      if (!_currentMatches(user.password, current)) {
        setState(() => _error = s.changePasswordCurrentWrong);
        return;
      }
    }

    if (password.length < AuthService.minPasswordLength) {
      setState(() => _error = s.changePasswordTooShort);
      return;
    }
    if (password != confirm) {
      setState(() => _error = s.changePasswordMismatch);
      return;
    }
    if (!widget.forced && password == current) {
      setState(() => _error = s.changePasswordSameAsCurrent);
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    AuthService.changePassword(password);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.changePasswordSuccess),
        backgroundColor: Colors.green,
      ),
    );
    if (widget.forced) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AuthNavigation.homeForCurrentUser()),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        backgroundColor: SettingsPalette.surface,
        appBar: AppBar(
          title: Text(s.changePassword),
          backgroundColor: SettingsPalette.deep,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: !widget.forced,
        ),
        body: ListView(
          padding: listPagePadding(context),
          children: [
            if (widget.forced)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'For security, change your temporary password before continuing.',
                  style: TextStyle(color: Colors.grey.shade800),
                ),
              ),
            SettingsSectionCard(
              title: s.changePassword,
              subtitle: s.changePasswordHint,
              icon: Icons.lock_reset_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.forced) ...[
                    TextField(
                      controller: _currentController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: s.changePasswordCurrentLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: s.changePasswordNewLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: s.changePasswordConfirmLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: SettingsPalette.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(s.changePasswordSave),
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
