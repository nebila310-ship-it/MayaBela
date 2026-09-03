import 'package:flutter/material.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/theme/login_role_theme.dart';
import 'package:mayabela/web_erp/login/web_login_shell.dart';
import 'package:mayabela/widgets/login_brand_header.dart';

/// Public (no login) admission application for a school.
class PublicAdmissionApplyScreen extends StatefulWidget {
  const PublicAdmissionApplyScreen({super.key, this.initialSchoolId});

  final String? initialSchoolId;

  @override
  State<PublicAdmissionApplyScreen> createState() =>
      _PublicAdmissionApplyScreenState();
}

class _PublicAdmissionApplyScreenState
    extends State<PublicAdmissionApplyScreen> {
  final _schoolId = TextEditingController();
  final _fullName = TextEditingController();
  final _grade = TextEditingController();
  final _guardian = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _previous = TextEditingController();
  bool _busy = false;
  String? _message;
  String? _reference;

  @override
  void initState() {
    super.initState();
    final fromWidget = widget.initialSchoolId?.trim();
    final fromUri = Uri.base.queryParameters['school']?.trim();
    _schoolId.text = (fromWidget != null && fromWidget.isNotEmpty)
        ? fromWidget
        : (fromUri ?? '');
  }

  @override
  void dispose() {
    _schoolId.dispose();
    _fullName.dispose();
    _grade.dispose();
    _guardian.dispose();
    _phone.dispose();
    _email.dispose();
    _previous.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final schoolId = _schoolId.text.trim().toUpperCase();
    final name = _fullName.text.trim();
    if (schoolId.isEmpty || name.isEmpty || _guardian.text.trim().isEmpty) {
      setState(() {
        _message = 'School ID, student name, and guardian name are required.';
        _reference = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
      final result = await SchoolAuthCloudService.instance.submitApplication(
        schoolId: schoolId,
        fullName: name,
        gradeApplying: _grade.text.trim(),
        guardianName: _guardian.text.trim(),
        guardianPhone: _phone.text.trim(),
        guardianEmail: _email.text.trim(),
        previousSchool: _previous.text.trim(),
      );
      if (!mounted) return;
      if (result.ok) {
        setState(() {
          _reference = result.applicationId;
          _message =
              'Application received. Keep this reference for the registrar.';
        });
      } else {
        setState(() {
          _message = result.errorMessage ??
              'Could not submit. Ask the school registrar to record a walk-in application.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message =
            'Could not reach the school cloud. Try again or visit the registrar.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = LoginRoleTheme.forRole('parent');
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const WebLoginBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LoginBrandHeader(
                          schoolId: _schoolId.text.trim().isEmpty
                              ? ' '
                              : _schoolId.text.trim().toUpperCase(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Apply for admission',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Text(
                          'No login required. The registrar will track your application.',
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _schoolId,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'School ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _fullName,
                          decoration: const InputDecoration(
                            labelText: 'Student full name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _grade,
                          decoration: const InputDecoration(
                            labelText: 'Grade applying for',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _guardian,
                          decoration: const InputDecoration(
                            labelText: 'Guardian full name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Guardian phone',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Guardian email (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _previous,
                          decoration: const InputDecoration(
                            labelText: 'Previous school (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Submit application'),
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          Text(_message!),
                        ],
                        if (_reference != null) ...[
                          const SizedBox(height: 6),
                          SelectableText(
                            _reference!,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                        TextButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Back to sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carries the application reference in [SchoolAuthCloudResult.profile.username]
/// as a lightweight id without creating a login account.
