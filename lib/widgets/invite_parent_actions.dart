import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/widgets/send_student_parent_invites.dart';

Future<void> inviteParentForRecord(
  BuildContext context,
  AdminStudentRecord record,
) async {
  await showSendStudentParentInvites(context, record);
}

class InviteParentButton extends StatelessWidget {
  const InviteParentButton({
    super.key,
    this.student,
    this.studentRef,
    this.compact = false,
  }) : assert(student != null || studentRef != null);

  final AdminStudentRecord? student;
  final StudentRef? studentRef;
  final bool compact;

  AdminStudentRecord? _resolveRecord() {
    if (student != null) return student;
    final ref = studentRef!;
    return ParentInviteService.instance.recordForStudentRef(
      name: ref.name,
      registryStudentId: ref.registryStudentId,
    );
  }

  Future<void> _invite(BuildContext context) async {
    final record = _resolveRecord();
    if (record == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocale.instance.strings.inviteParentNoRecord)),
        );
      }
      return;
    }
    await inviteParentForRecord(context, record);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        if (compact) {
          return IconButton(
            icon: const Icon(Icons.sms_outlined, color: Colors.indigo),
            tooltip: s.inviteParent,
            onPressed: () => _invite(context),
          );
        }
        return TextButton.icon(
          onPressed: () => _invite(context),
          icon: const Icon(Icons.sms_outlined, size: 18),
          label: Text(s.inviteParent),
        );
      },
    );
  }
}

Future<void> showBulkParentInviteDialog(
  BuildContext context, {
  required List<AdminStudentRecord> students,
  String? classLabel,
}) async {
  final s = AppLocale.instance.strings;
  if (students.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.inviteBulkEmpty)),
    );
    return;
  }

  final withPhone = students.where((st) => st.allContactPhones.isNotEmpty);
  final withoutPhone = students.length - withPhone.length;

  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(s.inviteBulkTitle),
      content: Text(
        classLabel != null
            ? s.inviteBulkBodyClass(classLabel, students.length, withPhone.length, withoutPhone)
            : s.inviteBulkBody(students.length, withPhone.length, withoutPhone),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(s.inviteBulkStart),
        ),
      ],
    ),
  );

  if (proceed != true || !context.mounted) return;

  final result = await ParentInviteService.instance.inviteBulkViaSms(
    students.toList(),
  );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.inviteBulkDone(result.sent, result.skipped))),
    );
  }
}

List<AdminStudentRecord> studentsForActiveSchoolClass(String className) {
  final schoolId = AuthService.activeSchoolId;
  return StudentRegistryService.instance.studentsForClass(
    className,
    schoolId: schoolId,
  );
}
