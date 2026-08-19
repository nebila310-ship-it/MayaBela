import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/session_cloud_sync.dart';
import 'package:mayabela/services/student_portal_sync_service.dart';
import 'package:mayabela/widgets/role_dashboard_shell.dart';
import 'package:mayabela/widgets/student_dashboard_summary.dart';
import 'package:mayabela/widgets/student_password_change_banner.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  bool _passwordPromptDismissed = false;

  @override
  Widget build(BuildContext context) {
    final showPasswordPrompt =
        AuthService.requiresPasswordChange() && !_passwordPromptDismissed;

    return ListenableBuilder(
      listenable: StudentPortalSyncService.instance,
      builder: (context, _) {
        final sync = StudentPortalSyncService.instance;

        return Stack(
          children: [
            RoleDashboardShell(
              roleKey: AuthService.roleStudent,
              portalKind: 'student',
              welcomeEmoji: '🎓',
              groupedLayout: true,
              gradientColors: const [
                Color(0xFF1565C0),
                Color(0xFF1976D2),
                Color(0xFF42A5F5),
              ],
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showPasswordPrompt)
                    StudentPasswordChangeBanner(
                      onDismiss: () =>
                          setState(() => _passwordPromptDismissed = true),
                    ),
                  if (sync.error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Material(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.cloud_off, color: Colors.red.shade700),
                          title: Text(
                            sync.error!,
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 13,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () {
                              StudentPortalSyncService.instance.clearError();
                              unawaited(SessionCloudSync.onStudentSessionStarted());
                            },
                          ),
                        ),
                      ),
                    ),
                  const StudentDashboardSummary(),
                ],
              ),
            ),
            if (sync.isSyncing)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 3),
              ),
          ],
        );
      },
    );
  }
}
