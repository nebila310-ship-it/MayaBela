import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';

Future<String?> askUnlockApprovedGradeReason(
  BuildContext context, {
  required String studentName,
  String? subject,
}) async {
  final s = AppLocale.instance.strings;
  final controller = TextEditingController();
  final saved = await showAdminFormDialog(
    context: context,
    title: s.unlockApprovedGradeTitle,
    subtitle: subject == null || subject.trim().isEmpty
        ? studentName
        : '$studentName · $subject',
    accent: const Color(0xFFB45309),
    icon: Icons.lock_open_outlined,
    saveLabel: s.unlockApprovedGradeAction,
    canSave: (_) => controller.text.trim().isNotEmpty,
    builder: (context, setDialogState) => adminDialogField(
      TextField(
        controller: controller,
        onChanged: (_) => setDialogState(() {}),
        maxLines: 4,
        decoration: adminFieldDecoration(
          label: s.unlockApprovedGradeReasonLabel,
          icon: Icons.edit_note_outlined,
          accent: const Color(0xFFB45309),
        ),
      ),
    ),
  );
  final reason = controller.text.trim();
  controller.dispose();
  if (saved != true || reason.isEmpty) return null;
  return reason;
}
