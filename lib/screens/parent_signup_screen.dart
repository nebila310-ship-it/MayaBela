import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/parent_child_registration_card.dart';
import 'package:mayabela/widgets/registration_terms_dialog.dart';

/// Parent-only registration from the login screen — child link, medical info, account.
class ParentSignUpScreen extends StatefulWidget {
  const ParentSignUpScreen({super.key});

  @override
  State<ParentSignUpScreen> createState() => _ParentSignUpScreenState();
}

class _ParentSignUpScreenState extends State<ParentSignUpScreen> {
  static const _accent = Color(0xFF00695C);

  final _fullName = TextEditingController();
  final _schoolId = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final List<ParentChildFormEntry> _children = [ParentChildFormEntry()];

  String _message = '';
  bool _messageIsSuccess = false;
  bool _busy = false;

  AppStrings get s => AppLocale.instance.strings;
  final _studentRegistry = StudentRegistryService.instance;

  @override
  void dispose() {
    _fullName.dispose();
    _schoolId.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    for (final child in _children) {
      child.dispose();
    }
    super.dispose();
  }

  DateTime? _parseDob(String raw) {
    final parts = raw.trim().split('/');
    if (parts.length != 3) return null;
    try {
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (_) {
      return null;
    }
  }

  void _setMessage(String msg, {required bool isSuccess}) {
    setState(() {
      _message = msg;
      _messageIsSuccess = isSuccess;
    });
  }

  void _addChild() {
    setState(() => _children.add(ParentChildFormEntry()));
  }

  void _removeChild(int index) {
    if (_children.length <= 1) return;
    setState(() {
      _children[index].dispose();
      _children.removeAt(index);
    });
  }

  void _lookupStudent(ParentChildFormEntry entry) {
    if (_schoolId.text.trim().isEmpty) {
      _setMessage(s.enterSchoolId, isSuccess: false);
      return;
    }
    final dob = _parseDob(entry.dobController.text);
    if (dob == null) {
      _setMessage(s.invalidDateFormat, isSuccess: false);
      return;
    }
    final ok = _studentRegistry.verifyStudent(
      schoolId: _schoolId.text,
      studentId: entry.studentIdController.text,
      dateOfBirth: dob,
    );
    setState(() {
      entry.record = ok
          ? _studentRegistry.lookupById(entry.studentIdController.text)
          : null;
      if (ok) {
        applyStudentContactSuggestion(
          entry: entry,
          phoneController: _phone,
          nameController: _fullName,
        );
      }
      _message = ok ? s.studentFound : s.studentNotFound;
      _messageIsSuccess = ok;
    });
  }

  void _applyContactFromStudent(ParentChildFormEntry entry) {
    applyStudentContactSuggestion(
      entry: entry,
      phoneController: _phone,
      nameController: _fullName,
    );
  }

  Future<void> _register() async {
    _setMessage('', isSuccess: false);

    if (_fullName.text.trim().isEmpty) {
      _setMessage(s.enterName, isSuccess: false);
      return;
    }
    if (_schoolId.text.trim().isEmpty) {
      _setMessage(s.enterSchoolId, isSuccess: false);
      return;
    }
    if (_phone.text.trim().isEmpty) {
      _setMessage(s.invalidPhone, isSuccess: false);
      return;
    }
    if (_password.text.length < AuthService.minPasswordLength) {
      _setMessage(s.passwordTooShort, isSuccess: false);
      return;
    }
    if (_password.text != _confirmPassword.text) {
      _setMessage(s.passwordsNoMatch, isSuccess: false);
      return;
    }

    for (final child in _children) {
      if (child.record == null) {
        _setMessage(s.verifyChildFirst, isSuccess: false);
        return;
      }
      if (child.hasMedicalCondition == null) {
        _setMessage(s.studentMedicalRequired, isSuccess: false);
        return;
      }
      if (child.hasMedicalCondition == true &&
          child.medicalDetailsController.text.trim().isEmpty) {
        _setMessage(s.studentMedicalSpecifyRequired, isSuccess: false);
        return;
      }
    }

    final agreed = await showParentGuardianTermsDialog(context);
    if (!agreed || !mounted) {
      if (mounted) _setMessage(s.mustAgreeTerms, isSuccess: false);
      return;
    }

    await _completeRegistration();
  }

  Future<void> _completeRegistration() async {
    if (_busy) return;
    final children = <ParentChildRegistration>[];
    for (final child in _children) {
      final dob = _parseDob(child.dobController.text);
      if (dob == null) {
        _setMessage(s.invalidDateFormat, isSuccess: false);
        return;
      }
      children.add(parentRegistrationFromEntry(child, dateOfBirth: dob));
    }

    setState(() => _busy = true);
    final error = await AuthService.registerParentAccount(
      fullName: _fullName.text.trim(),
      schoolId: _schoolId.text.trim(),
      phone: _phone.text.trim(),
      password: _password.text,
      email: _email.text.trim(),
      children: children,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      _setMessage(s.parentRegisterError(error), isSuccess: false);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(s.accountCreated),
        content: Text(
          '${s.parentPendingApprovalMessage}\n\n${s.waitingForSchoolApproval}',
        ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5FAF9),
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(s.registerAsParent),
      ),
      body: ListView(
        padding: listPagePadding(context),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00695C), Color(0xFF26A69A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.family_restroom_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        s.parentRegistrationTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  s.linkAnotherChildHint,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            s.schoolId,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _schoolId,
            decoration: adminFieldDecoration(
              label: s.schoolId,
              hint: 'TB-001',
              icon: Icons.school_outlined,
              accent: _accent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            s.linkToStudent,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            _children.length,
            (index) => ParentChildRegistrationCard(
              index: index,
              entry: _children[index],
              schoolId: _schoolId.text,
              accent: _accent,
              onVerify: () => _lookupStudent(_children[index]),
              onStudentContactChanged: _applyContactFromStudent,
              onRemove: _children.length > 1 ? () => _removeChild(index) : null,
            ),
          ),
          OutlinedButton.icon(
            onPressed: _addChild,
            icon: const Icon(Icons.add_circle_outline),
            label: Text(s.addAnotherChild),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accent,
              side: BorderSide(color: _accent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            s.yourAccount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fullName,
            decoration: adminFieldDecoration(
              label: s.fullName,
              icon: Icons.person_outline,
              accent: _accent,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: adminFieldDecoration(
              label: s.email,
              icon: Icons.email_outlined,
              accent: _accent,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: adminFieldDecoration(
              label: s.phoneNumber,
              hint: s.phoneLoginHint,
              icon: Icons.phone_outlined,
              accent: _accent,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: adminFieldDecoration(
              label: s.password,
              icon: Icons.lock_outline,
              accent: _accent,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPassword,
            obscureText: true,
            decoration: adminFieldDecoration(
              label: s.confirmPassword,
              icon: Icons.lock_outline,
              accent: _accent,
            ),
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_messageIsSuccess ? Colors.green : Colors.red)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_messageIsSuccess ? Colors.green : Colors.red)
                      .withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                _message,
                style: TextStyle(
                  color: _messageIsSuccess
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _register,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.how_to_reg_rounded),
            label: Text(s.createAccount),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
