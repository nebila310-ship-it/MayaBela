import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/parent_child_registration_card.dart';

/// Logged-in parent links another child using the same registry form.
class ParentLinkChildScreen extends StatefulWidget {
  const ParentLinkChildScreen({super.key});

  @override
  State<ParentLinkChildScreen> createState() => _ParentLinkChildScreenState();
}

class _ParentLinkChildScreenState extends State<ParentLinkChildScreen> {
  final _entry = ParentChildFormEntry();
  String _message = '';
  bool _success = false;

  AppStrings get s => AppLocale.instance.strings;

  @override
  void dispose() {
    _entry.dispose();
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

  void _verify() {
    final schoolId = AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      setState(() {
        _message = s.enterSchoolId;
        _success = false;
      });
      return;
    }
    final dob = _parseDob(_entry.dobController.text);
    if (dob == null) {
      setState(() {
        _message = s.invalidDateFormat;
        _success = false;
      });
      return;
    }
    final ok = StudentRegistryService.instance.verifyStudent(
      schoolId: schoolId,
      studentId: _entry.studentIdController.text,
      dateOfBirth: dob,
    );
    setState(() {
      _entry.record = ok
          ? StudentRegistryService.instance.lookupById(
              _entry.studentIdController.text,
            )
          : null;
      _message = ok ? s.studentFound : s.studentNotFound;
      _success = ok;
    });
  }

  void _submit() {
    if (_entry.record == null) {
      setState(() {
        _message = s.verifyChildFirst;
        _success = false;
      });
      return;
    }
    if (_entry.hasMedicalCondition == null) {
      setState(() {
        _message = s.studentMedicalRequired;
        _success = false;
      });
      return;
    }
    if (_entry.hasMedicalCondition == true &&
        _entry.medicalDetailsController.text.trim().isEmpty) {
      setState(() {
        _message = s.studentMedicalSpecifyRequired;
        _success = false;
      });
      return;
    }

    final dob = _parseDob(_entry.dobController.text);
    if (dob == null) {
      setState(() {
        _message = s.invalidDateFormat;
        _success = false;
      });
      return;
    }

    final error = EnrollmentService.instance.linkChildForCurrentParent(
      parentRegistrationFromEntry(_entry, dateOfBirth: dob),
    );

    if (error != null) {
      setState(() {
        _message = switch (error) {
          'already_linked' => s.alreadyLinkedStudent,
          'student_mismatch' => s.studentVerifyFailed,
          'not_parent' => s.registrationFailed,
          _ => s.registrationFailed,
        };
        _success = false;
      });
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.parentPendingApprovalMessage),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00695C);

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFA),
      appBar: AppBar(
        title: Text(s.linkAnotherChild),
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: listPagePadding(context),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.75)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.family_restroom, color: Colors.white, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    s.linkAnotherChildHint,
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ParentChildRegistrationCard(
            index: 0,
            entry: _entry,
            schoolId: AuthService.activeSchoolId ?? '',
            accent: accent,
            onVerify: _verify,
          ),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _message,
                style: TextStyle(
                  color: _success ? Colors.green.shade800 : Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.send_rounded),
            label: Text(s.submitLinkRequest),
          ),
        ],
      ),
    );
  }
}
