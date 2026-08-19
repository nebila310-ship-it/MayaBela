import 'package:flutter/material.dart';

import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/student_account_service.dart';
import 'package:mayabela/services/student_credentials_service.dart';
import 'package:mayabela/services/student_password_reset_store.dart';

class AdminStudentPasswordResetScreen extends StatefulWidget {
  const AdminStudentPasswordResetScreen({super.key});

  @override
  State<AdminStudentPasswordResetScreen> createState() =>
      _AdminStudentPasswordResetScreenState();
}

class _AdminStudentPasswordResetScreenState
    extends State<AdminStudentPasswordResetScreen> {
  bool _loading = true;
  List<StudentPasswordResetRequest> _requests = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await StudentPasswordResetStore.instance.load();
    final schoolId = AuthService.activeSchoolId;
    if (schoolId == null) return;
    if (!mounted) return;
    setState(() {
      _requests = StudentPasswordResetStore.instance.pendingForSchool(schoolId);
      _loading = false;
    });
  }

  Future<void> _reset(String requestId, String studentId) async {
    final actor = AuthService.currentUser?.username ?? 'admin';
    final updated = await StudentAccountService.instance.regeneratePassword(
      studentId: studentId,
      actor: actor,
    );
    if (updated == null) return;
    await StudentPasswordResetStore.instance.resolve(
      requestId,
      resolvedBy: actor,
    );
    if (!mounted) return;
    await StudentCredentialsService.instance.share(updated);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Password Requests'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const Center(child: Text('No pending password reset requests'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    return ListTile(
                      title: Text(request.studentName ?? request.studentId),
                      subtitle: Text(
                        '${request.studentId} · ${request.username ?? '—'}\n'
                        'Requested ${request.requestedAt.toLocal()}',
                      ),
                      isThreeLine: true,
                      trailing: FilledButton(
                        onPressed: () => _reset(request.id, request.studentId),
                        child: const Text('Reset'),
                      ),
                    );
                  },
                ),
    );
  }
}
