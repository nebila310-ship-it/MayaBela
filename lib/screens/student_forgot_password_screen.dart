import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_password_reset_store.dart';
import 'package:mayabela/services/student_portal_audit_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/models/student_portal.dart';

class StudentForgotPasswordScreen extends StatefulWidget {
  const StudentForgotPasswordScreen({super.key});

  @override
  State<StudentForgotPasswordScreen> createState() =>
      _StudentForgotPasswordScreenState();
}

class _StudentForgotPasswordScreenState extends State<StudentForgotPasswordScreen> {
  final _identifier = TextEditingController();
  final _schoolId = TextEditingController();
  bool _submitting = false;
  String? _message;

  @override
  void dispose() {
    _identifier.dispose();
    _schoolId.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _identifier.text.trim();
    final school = _schoolId.text.trim().toUpperCase();
    if (id.isEmpty || school.isEmpty) {
      setState(() => _message = 'Enter your username or Student ID and School ID.');
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });

    RegisteredUser? user = AuthService.findUser(id);
    AdminStudentRecord? student;
    if (user != null && user.roleKey == AuthService.roleStudent) {
      student = StudentRegistryService.instance.lookupAnyById(
        user.linkedStudentId ?? '',
      );
    } else if (id.toUpperCase().startsWith('STU-')) {
      student = StudentRegistryService.instance.lookupAnyById(id);
      if (student != null) {
        user = AuthService.findUser(student.loginUsername ?? '');
      }
    } else {
      student = StudentRegistryService.instance.lookupByLoginUsername(id);
      if (student != null) {
        user = AuthService.findUser(student.loginUsername ?? id);
      }
    }

    if (student == null || (user?.roleKey != AuthService.roleStudent)) {
      setState(() {
        _submitting = false;
        _message = 'No student portal account found. Contact your school admin.';
      });
      return;
    }

    if (student.schoolId.toUpperCase() != school) {
      setState(() {
        _submitting = false;
        _message = 'School ID does not match this student record.';
      });
      return;
    }

    await StudentPasswordResetStore.instance.submit(
      studentId: student.studentId,
      schoolId: student.schoolId,
      username: student.loginUsername,
      studentName: student.fullName,
    );

    await StudentPortalAuditService.instance.log(
      action: StudentPortalAuditAction.passwordResetRequested,
      schoolId: student.schoolId,
      studentId: student.studentId,
      username: student.loginUsername,
    );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _message =
          'Request sent to your school admin. They will verify and reset your password.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your username or Student ID. Your school admin will verify and issue a new temporary password.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _schoolId,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'School ID',
                hintText: SchoolRegistryService.instance.getAllSchools().isNotEmpty
                    ? SchoolRegistryService.instance.getAllSchools().first.id
                    : 'TB-001',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _identifier,
              decoration: const InputDecoration(
                labelText: 'Username or Student ID',
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                style: TextStyle(
                  color: _message!.startsWith('Request sent')
                      ? Colors.green.shade800
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send request to admin'),
            ),
          ],
        ),
      ),
    );
  }
}
