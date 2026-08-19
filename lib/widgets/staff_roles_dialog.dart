import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/rbac/staff_role_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/widgets/staff_role_labels.dart';
import 'package:mayabela/widgets/staff_role_picker_table.dart';

export 'package:mayabela/widgets/staff_role_labels.dart';

/// Owner/admin dialog to grant staff roles to a teacher account.
/// Multiple roles combine into one permission set at login.
Future<void> showStaffRolesDialog({
  required BuildContext context,
  required AdminTeacherRecord teacher,
  VoidCallback? onSaved,
  Color accent = const Color(0xFF4527A0),
}) async {
  final s = AppLocale.instance.strings;

  if (!AuthService.canAssignStaffRoles) return;
  if ((teacher.loginUsername ?? '').trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.staffRolesNoAccount)),
    );
    return;
  }

  await SchoolRoleCatalogService.instance.ensureLoaded(teacher.schoolId);
  final templates =
      SchoolRoleCatalogService.instance.rolesForAssign(schoolId: teacher.schoolId);

  final selected = <String>{
    for (final key in teacher.staffRoles)
      if (SchoolRoleCatalogService.instance
              .lookup(key, schoolId: teacher.schoolId) !=
          null)
        StaffRoles.canonicalize(key),
  };
  final canGrantOwnerOnly = AuthService.canAssignFullAccess;
  final isOwnAccount = AuthService.currentUser?.username.toLowerCase() ==
      teacher.loginUsername?.trim().toLowerCase();

  if (isOwnAccount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.staffRolesOwnAccount)),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings_outlined, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.staffRolesTitle, style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                teacher.fullName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                s.staffRolesSubtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: StaffRolePickerTable(
                    roles: templates,
                    selected: selected,
                    multiSelect: true,
                    accent: accent,
                    isRoleEnabled: (role) =>
                        !(role.ownerOnly && !canGrantOwnerOnly),
                    onChanged: (next) => setDialogState(() {
                      selected
                        ..clear()
                        ..addAll(next);
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accent),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.save),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final error = await StaffRoleService.instance.assignRoles(
    teacher: teacher,
    roles: selected.toList(),
  );
  if (!context.mounted) return;

  final message = switch (error) {
    null => s.staffRolesUpdated,
    'owner_only_role' => s.staffRolesOwnerOnly,
    'no_account' => s.staffRolesNoAccount,
    'own_account' => s.staffRolesOwnAccount,
    _ => s.staffRolesSaveFailed,
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error == null ? Colors.green : Colors.red.shade700,
    ),
  );
  onSaved?.call();
}
