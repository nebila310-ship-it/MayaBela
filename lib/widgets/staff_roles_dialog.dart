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
  var templates =
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
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    await showRenameStaffRoleTitleDialog(
                      context: context,
                      teacher: teacher,
                    );
                    if (!context.mounted) return;
                    templates = SchoolRoleCatalogService.instance
                        .rolesForAssign(schoolId: teacher.schoolId);
                    setDialogState(() {});
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(s.renameRoleTitle),
                ),
              ),
              const SizedBox(height: 8),
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

/// Rename the school-facing title of a staff member's assigned role
/// (General Manager → CEO). The role key and permissions stay the same.
Future<bool> showRenameStaffRoleTitleDialog({
  required BuildContext context,
  required AdminTeacherRecord teacher,
  VoidCallback? onSaved,
}) async {
  final s = AppLocale.instance.strings;
  await SchoolRoleCatalogService.instance.ensureLoaded(teacher.schoolId);
  if (!context.mounted) return false;

  final roles = [
    for (final key in teacher.staffRoles)
      SchoolRoleCatalogService.instance.lookup(
        key,
        schoolId: teacher.schoolId,
      ),
  ].whereType<StaffRole>().toList();

  if (roles.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.assignRoleFirst)),
      );
    }
    return false;
  }

  StaffRole? role = roles.first;
  if (roles.length > 1) {
    role = await showDialog<StaffRole>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(s.pickRoleToRename),
        children: [
          for (final item in roles)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, item),
              child: Text(staffRoleLabel(item, s)),
            ),
        ],
      ),
    );
    if (role == null || !context.mounted) return false;
  }

  if (!context.mounted) return false;
  final next = await showDialog<String>(
    context: context,
    builder: (ctx) => _RenameRoleTitleDialog(role: role!, strings: s),
  );
  if (next == null || next.trim().isEmpty) return false;

  final err = await SchoolRoleCatalogService.instance.renameRole(
    roleKey: role.key,
    label: next,
    schoolId: teacher.schoolId,
  );
  if (!context.mounted) return err == null;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(err == null ? s.roleTitleSaved : s.staffRolesSaveFailed),
      backgroundColor: err == null ? Colors.green : Colors.red.shade700,
    ),
  );
  if (err == null) onSaved?.call();
  return err == null;
}

class _RenameRoleTitleDialog extends StatefulWidget {
  const _RenameRoleTitleDialog({
    required this.role,
    required this.strings,
  });

  final StaffRole role;
  final AppStrings strings;

  @override
  State<_RenameRoleTitleDialog> createState() => _RenameRoleTitleDialogState();
}

class _RenameRoleTitleDialogState extends State<_RenameRoleTitleDialog> {
  late final TextEditingController _label = TextEditingController(
    text: staffRoleLabel(widget.role, widget.strings),
  );

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return AlertDialog(
      title: Text(s.renameRoleTitle),
      content: TextField(
        controller: _label,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: s.renameRoleTitleHint,
          hintText: s.renameRoleTitleExample,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _label.text),
          child: Text(s.save),
        ),
      ],
    );
  }
}
