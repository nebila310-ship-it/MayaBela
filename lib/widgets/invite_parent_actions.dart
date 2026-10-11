import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/otp_delivery_service.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/widgets/send_student_parent_invites.dart';

Future<void> inviteParentForRecord(
  BuildContext context,
  AdminStudentRecord record,
) async {
  await showSendStudentParentInvites(context, record);
}

Future<void> sendParentInviteToRegisteredNumber(
  BuildContext context,
  AdminStudentRecord student,
  OtpDeliveryChannel channel,
) async {
  final s = AppLocale.instance.strings;
  final phone = student.primaryContactPhone;
  if (phone == null || phone.trim().isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.inviteParentNoPhone)),
      );
    }
    return;
  }
  final ok = await ParentInviteService.instance.invitePrimaryViaChannel(
    student,
    channel,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ok ? s.inviteParentSent : s.otpDeliveryFailed),
      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
    ),
  );
}

Future<void> copyFullParentInvite(
  BuildContext context,
  AdminStudentRecord student,
) async {
  final s = AppLocale.instance.strings;
  await Clipboard.setData(
    ClipboardData(
      text: ParentInviteService.instance.buildMessageForRecord(student),
    ),
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(s.fullParentInviteCopied)),
  );
}

/// WhatsApp / Telegram go to the registered parent number. Copy pastes the
/// full welcome text, not only the URL.
class ParentInviteResendBar extends StatelessWidget {
  const ParentInviteResendBar({
    super.key,
    required this.student,
  });

  final AdminStudentRecord student;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final phone = student.primaryContactPhone;
        final name = student.primaryParentName ?? student.fullName;
        final buttons = <Widget>[
          if (phone != null && phone.trim().isNotEmpty) ...[
            FilledButton.icon(
              onPressed: () => sendParentInviteToRegisteredNumber(
                context,
                student,
                OtpDeliveryChannel.whatsApp,
              ),
              icon: const Icon(Icons.chat),
              label: Text(s.sendViaWhatsApp),
            ),
            FilledButton.tonalIcon(
              onPressed: () => sendParentInviteToRegisteredNumber(
                context,
                student,
                OtpDeliveryChannel.telegram,
              ),
              icon: const Icon(Icons.send),
              label: Text(s.sendViaTelegram),
            ),
          ],
          OutlinedButton.icon(
            onPressed: () => copyFullParentInvite(context, student),
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(s.copyFullParentInvite),
          ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.parentInviteResendTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              phone == null || phone.trim().isEmpty
                  ? s.inviteParentNoPhone
                  : s.parentInviteSendsTo(name, phone),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: buttons),
          ],
        );
      },
    );
  }
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
