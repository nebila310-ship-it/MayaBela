import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
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
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  String? _error;

  AppStrings get s => AppLocale.instance.strings;

  @override
  void dispose() {
    _currentController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<bool> _currentPasswordIsCorrect(String current) async {
    if (AuthService.currentPasswordMatches(current)) return true;
    // Cloud logins do not keep the secret on this device.
    final cloud = SchoolAuthCloudService.instance;
    if (!cloud.isAvailable) return false;
    return cloud.reauthenticateWithPassword(current);
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

    if (!widget.forced) {
      final ok = await _currentPasswordIsCorrect(current);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error = s.changePasswordCurrentWrong;
          _saving = false;
        });
        return;
      }
    }

    AuthService.changePassword(
      password,
      currentPassword: widget.forced ? null : current,
    );

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

  Widget _passwordField({
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return TextField(
      key: fieldKey,
      controller: controller,
      obscureText: !visible,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: visible ? 'Hide password' : 'Show password',
          onPressed: onToggle,
          icon: Icon(
            visible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
    );
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
                    _passwordField(
                      fieldKey: const Key('change-password-current'),
                      controller: _currentController,
                      label: s.changePasswordCurrentLabel,
                      visible: _showCurrent,
                      onToggle: () =>
                          setState(() => _showCurrent = !_showCurrent),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _passwordField(
                    fieldKey: const Key('change-password-new'),
                    controller: _passwordController,
                    label: s.changePasswordNewLabel,
                    visible: _showNew,
                    onToggle: () => setState(() => _showNew = !_showNew),
                  ),
                  const SizedBox(height: 12),
                  _passwordField(
                    fieldKey: const Key('change-password-confirm'),
                    controller: _confirmController,
                    label: s.changePasswordConfirmLabel,
                    visible: _showConfirm,
                    onToggle: () =>
                        setState(() => _showConfirm = !_showConfirm),
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
