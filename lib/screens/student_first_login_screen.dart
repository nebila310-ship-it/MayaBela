import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/student_account_service.dart';
import 'package:mayabela/utils/auth_navigation.dart';
import 'package:mayabela/widgets/app_floating_chrome.dart';

class StudentFirstLoginScreen extends StatefulWidget {
  const StudentFirstLoginScreen({
    super.key,
    this.skippable = false,
  });

  /// When true, student can return to the dashboard without changing password.
  final bool skippable;

  @override
  State<StudentFirstLoginScreen> createState() => _StudentFirstLoginScreenState();
}

class _StudentFirstLoginScreenState extends State<StudentFirstLoginScreen> {
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _showNew = false;
  bool _showConfirm = false;
  String? _error;

  @override
  void dispose() {
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _submit() {
    final next = _newPassword.text.trim();
    final confirm = _confirmPassword.text.trim();
    if (next.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    AuthService.changePassword(next);
    if (!mounted) return;
    if (widget.skippable) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AppFloatingChrome(
          child: AuthNavigation.dashboardForRole(AuthService.roleStudent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = StudentAccountService.instance.recordForCurrentUser();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
        leading: widget.skippable
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome${student != null ? ', ${student.fullName.split(' ').first}' : ''}!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your account uses a temporary password. You can set a new password now, or skip and change it later in Settings.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _newPassword,
              obscureText: !_showNew,
              decoration: InputDecoration(
                labelText: 'New password',
                suffixIcon: IconButton(
                  icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showNew = !_showNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPassword,
              obscureText: !_showConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                suffixIcon: IconButton(
                  icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const Spacer(),
            if (widget.skippable)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Skip for now'),
              ),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.skippable ? 'Save password' : 'Save and continue'),
            ),
          ],
        ),
      ),
    );
  }
}
