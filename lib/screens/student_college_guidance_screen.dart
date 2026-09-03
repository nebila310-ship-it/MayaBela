import 'package:flutter/material.dart';

import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/student_support_service.dart';

/// Student college-guidance view. No clinic notes, counseling notes, or
/// child-protection files.
class StudentCollegeGuidanceScreen extends StatefulWidget {
  const StudentCollegeGuidanceScreen({super.key});

  @override
  State<StudentCollegeGuidanceScreen> createState() =>
      _StudentCollegeGuidanceScreenState();
}

class _StudentCollegeGuidanceScreenState
    extends State<StudentCollegeGuidanceScreen> {
  final _svc = StudentSupportService.instance;

  String get _selfId =>
      (AuthService.currentUser?.linkedStudentId ?? '').trim().toUpperCase();

  @override
  void initState() {
    super.initState();
    _svc.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('College guidance')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _requestAppointment,
        icon: const Icon(Icons.event_available_outlined),
        label: const Text('Request appointment'),
      ),
      body: ListenableBuilder(
        listenable: _svc,
        builder: (context, _) {
          final plan = _svc.collegeForStudent(_selfId);
          final requests = _svc.requestsForStudent(_selfId);
          if (plan == null && requests.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No college-guidance plan yet. Request an appointment '
                  'with the counselor.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (plan != null)
                Card(
                  child: ListTile(
                    title: Text('Stage · ${plan.stage.name}'),
                    subtitle: Text(
                      [
                        if (plan.targets.trim().isNotEmpty) plan.targets,
                        if (plan.portfolio.trim().isNotEmpty)
                          'Portfolio: ${plan.portfolio}',
                        if (plan.nextAppointmentAt != null)
                          'Next appointment: ${plan.nextAppointmentAt}',
                      ].join('\n'),
                    ),
                  ),
                ),
              for (final row in requests)
                Card(
                  child: ListTile(
                    title: Text('${row.kind.name} · ${row.status.name}'),
                    subtitle: Text(row.body),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _requestAppointment() async {
    if (_selfId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your student record is not linked.')),
      );
      return;
    }
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('College appointment'),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'What do you need?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.submitSupportRequest(
      studentId: _selfId,
      kind: SupportRequestKind.collegeAppointment,
      body: note.text,
    );
  }
}
