import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/services/student_account_service.dart';
import 'package:mayabela/services/student_credentials_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/widgets/admin_staff_ui.dart';

/// Username and temporary password for one enrolled student.
class StudentPortalCredentialsCard extends StatelessWidget {
  const StudentPortalCredentialsCard({super.key, required this.student});

  final AdminStudentRecord student;

  @override
  Widget build(BuildContext context) {
    final accounts = StudentAccountService.instance;
    final username = student.loginUsername?.trim() ?? '';
    final hasLogin = username.isNotEmpty;
    final waitingForOwnPassword = hasLogin && !student.firstLoginCompleted;
    final password = waitingForOwnPassword
        ? accounts.passwordForShare(student)
        : null;
    final color = StaffPalette.students.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(
            'Student portal login',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        if (!hasLogin)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'No login yet. Save Student portal settings if this grade should have one.',
              key: const ValueKey('student-portal-no-login'),
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
          )
        else ...[
          StaffInfoTile(
            icon: Icons.person_rounded,
            label: 'Username',
            value: username,
            color: color,
          ),
          if (password != null)
            StaffInfoTile(
              icon: Icons.lock_rounded,
              label: 'Temporary password',
              value: password,
              color: Colors.amber.shade800,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              _note(student, waitingForOwnPassword),
              key: const ValueKey('student-portal-login-note'),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('student-portal-copy'),
                onPressed: () => _copy(context, username, password),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy login'),
              ),
              if (waitingForOwnPassword)
                OutlinedButton.icon(
                  key: const ValueKey('student-portal-share'),
                  onPressed: () => StudentCredentialsService.instance.share(student),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share login'),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String _note(AdminStudentRecord student, bool waitingForOwnPassword) {
    final status = switch (student.portalAccountStatus) {
      StudentAccountStatus.active =>
        'Sign in as Student with the school ID and this username, or the student ID.',
      StudentAccountStatus.inactive =>
        'Login is turned off until this grade is included in Student portal settings.',
      StudentAccountStatus.suspended => 'This login is suspended.',
      StudentAccountStatus.graduated => 'This student has graduated.',
      StudentAccountStatus.transferred => 'This student has transferred.',
    };
    if (!waitingForOwnPassword &&
        student.portalAccountStatus == StudentAccountStatus.active) {
      return '$status This student already chose their own password.';
    }
    if (waitingForOwnPassword) {
      return '$status The temporary password works until they change it.';
    }
    return status;
  }

  Future<void> _copy(
    BuildContext context,
    String username,
    String? password,
  ) async {
    final lines = <String>[
      student.fullName,
      'School ID: ${student.schoolId}',
      'Student ID: ${student.studentId}',
      'Username: $username',
      if (password != null) 'Temporary password: $password',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Student login copied')),
    );
  }
}
