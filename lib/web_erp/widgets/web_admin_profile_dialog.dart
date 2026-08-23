import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/admin_people_screens.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_photo_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/persistence/teacher_persistence_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/admin_staff_ui.dart';
import 'package:mayabela/widgets/admin_student_edit_dialog.dart';
import 'package:mayabela/widgets/admin_student_qr_actions.dart';
import 'package:mayabela/widgets/student_qr_card.dart';
import 'package:mayabela/widgets/staff_registry_avatar.dart';
import 'package:mayabela/widgets/staff_roles_dialog.dart';

Future<void> showWebStudentProfileDialog(
  BuildContext context, {
  required String studentId,
  VoidCallback? onUpdated,
}) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => _WebStudentProfileDialog(
      studentId: studentId,
      onUpdated: onUpdated,
    ),
  );
}

Future<void> showWebTeacherProfileDialog(
  BuildContext context, {
  required String teacherId,
  VoidCallback? onUpdated,
}) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => _WebTeacherProfileDialog(
      teacherId: teacherId,
      onUpdated: onUpdated,
    ),
  );
}

class _WebStudentProfileDialog extends StatefulWidget {
  const _WebStudentProfileDialog({
    required this.studentId,
    this.onUpdated,
  });

  final String studentId;
  final VoidCallback? onUpdated;

  @override
  State<_WebStudentProfileDialog> createState() =>
      _WebStudentProfileDialogState();
}

class _WebStudentProfileDialogState extends State<_WebStudentProfileDialog> {
  AdminStudentRecord? get _student =>
      StudentRegistryService.instance.lookupById(widget.studentId);

  bool get _canManage => ModuleAccess.canManage('students');

  Future<void> _edit(AdminStudentRecord student) async {
    final saved = await showAdminStudentEditDialog(context, student: student);
    if (saved == true) {
      setState(() {});
      widget.onUpdated?.call();
    }
  }

  Future<void> _changePhoto(AdminStudentRecord student) async {
    final bytes = await StudentPhotoService.instance.pickBytes();
    if (bytes == null || !mounted) return;
    final path = await StudentPhotoService.instance.saveBytesForStudent(
      student.studentId,
      bytes,
    );
    if (path == null) return;
    StudentPhotoService.instance.rememberPath(student.studentId, path);
    StudentRegistryService.instance.updatePhoto(student.studentId, path);
    SchoolDataService.instance.syncChildFromRegistry(student.studentId);
    if (!mounted) return;
    setState(() {});
    widget.onUpdated?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocale.instance.strings.studentUpdated)),
    );
  }

  Future<void> _delete(AdminStudentRecord student) async {
    final s = AppLocale.instance.strings;
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: s.deleteStudent,
      message: s.confirmDeleteStudent,
      accent: AdminFormTheme.student.primary,
      icon: Icons.delete_outline_rounded,
      confirmLabel: s.deleteStudent,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    StudentRegistryService.instance.deactivateStudent(student.studentId);
    SchoolDataService.instance.removeStudentFromSchool(student.studentId);
    if (!mounted) return;
    widget.onUpdated?.call();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.studentRemoved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final student = _student;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
        child: student == null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(s.inviteParentNoRecord),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              StaffRegistryAvatar(
                                staffId: student.studentId,
                                name: student.fullName,
                                radius: 44,
                                isStudent: true,
                                fallbackColor: StaffPalette.students.primary,
                              ),
                              if (_canManage)
                                Material(
                                  color: StaffPalette.students.primary,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => _changePhoto(student),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.camera_alt_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        StaffInfoTile(
                          icon: Icons.badge_outlined,
                          label: s.studentId,
                          value: student.studentId,
                          color: StaffPalette.students.primary,
                        ),
                        StaffInfoTile(
                          icon: Icons.class_rounded,
                          label: s.grade,
                          value: '${student.grade} · ${student.className}',
                          color: StaffPalette.students.secondary,
                        ),
                        StaffInfoTile(
                          icon: Icons.cake_outlined,
                          label: s.studentDateOfBirth,
                          value: ParentInviteService.formatDob(
                            student.dateOfBirth,
                          ),
                          color: StaffPalette.students.primary,
                        ),
                        StaffInfoTile(
                          icon: Icons.family_restroom,
                          label: s.fatherName,
                          value:
                              '${student.fatherName ?? '—'} (${student.fatherPhone ?? '—'})',
                          color: const Color(0xFF1565C0),
                        ),
                        StaffInfoTile(
                          icon: Icons.directions_bus_filled_rounded,
                          label: s.transportEnabled,
                          value: student.transportEnabled ? 'Yes' : 'No',
                          color: const Color(0xFF455A64),
                        ),
                        const SizedBox(height: 12),
                        StudentQrCard(
                          profile: qrProfileForStudent(student),
                          size: 160,
                        ),
                        Text(
                          s.studentQrUsageHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_canManage)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                showAdminStudentQrSheet(context, student: student),
                            icon: const Icon(Icons.qr_code_2),
                            label: Text(s.generateStudentQr),
                          ),
                          FilledButton.icon(
                            onPressed: () => _edit(student),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(s.editStudent),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _changePhoto(student),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(s.changeProfilePhoto),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _delete(student),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                            ),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: Text(s.deleteStudent),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _WebTeacherProfileDialog extends StatefulWidget {
  const _WebTeacherProfileDialog({
    required this.teacherId,
    this.onUpdated,
  });

  final String teacherId;
  final VoidCallback? onUpdated;

  @override
  State<_WebTeacherProfileDialog> createState() =>
      _WebTeacherProfileDialogState();
}

class _WebTeacherProfileDialogState extends State<_WebTeacherProfileDialog> {
  AdminTeacherRecord? get _teacher =>
      TeacherRegistryService.instance.lookupAnyById(widget.teacherId);

  bool get _canHireStaff => ModuleAccess.canHireStaff;
  bool get _canAssignTeachers => ModuleAccess.canAssignTeachers;

  Future<void> _deleteStaff(AdminTeacherRecord teacher) async {
    final s = AppLocale.instance.strings;
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: s.deactivateTeacher,
      message: s.confirmDeactivateTeacher,
      accent: AdminFormTheme.teacher.primary,
      icon: Icons.person_off_outlined,
      confirmLabel: s.deactivateTeacher,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    SchoolDataService.instance.removeTeacherAssignments(teacher.teacherId);
    await TeacherPersistenceService.instance.deleteStaffAndFreePhone(teacher);

    if (!mounted) return;
    widget.onUpdated?.call();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.teacherDeactivated)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final teacher = _teacher;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: teacher == null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(s.noTeachersAvailableForReplacement),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            teacher.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Center(
                          child: StaffRegistryAvatar(
                            staffId: teacher.teacherId,
                            name: teacher.fullName,
                            radius: 44,
                            fallbackColor: StaffPalette.teachers.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StaffInfoTile(
                          icon: Icons.badge_outlined,
                          label: 'Staff ID',
                          value: teacher.employeeId ?? teacher.teacherId,
                          color: StaffPalette.teachers.primary,
                        ),
                        StaffInfoTile(
                          icon: Icons.menu_book_outlined,
                          label: 'Subjects',
                          value: teacher.subjects.join(', '),
                          color: StaffPalette.teachers.secondary,
                        ),
                        StaffInfoTile(
                          icon: Icons.class_outlined,
                          label: s.assignedClasses,
                          value: teacher.assignedClass,
                          color: StaffPalette.teachers.primary,
                        ),
                        if (teacher.phone?.isNotEmpty == true)
                          StaffInfoTile(
                            icon: Icons.phone_outlined,
                            label: s.phone,
                            value: teacher.phone!,
                            color: const Color(0xFF2E7D32),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (AuthService.canAssignStaffRoles)
                          FilledButton.icon(
                            onPressed: () async {
                              await showStaffRolesDialog(
                                context: context,
                                teacher: teacher,
                                onSaved: widget.onUpdated,
                              );
                            },
                            icon: const Icon(
                              Icons.admin_panel_settings_outlined,
                            ),
                            label: Text(s.staffRolesTitle),
                          ),
                        if (_canHireStaff || _canAssignTeachers)
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminTeacherProfileScreen(
                                    teacherId: teacher.teacherId,
                                  ),
                                ),
                              ).then((_) => widget.onUpdated?.call());
                            },
                            icon: Icon(
                              _canHireStaff
                                  ? Icons.edit_outlined
                                  : Icons.class_outlined,
                            ),
                            label: Text(
                              _canHireStaff
                                  ? s.editTeacher
                                  : s.assignTeacherClasses,
                            ),
                          ),
                        if (_canHireStaff)
                          OutlinedButton.icon(
                            onPressed: () => _deleteStaff(teacher),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                            ),
                            icon: const Icon(Icons.person_off_outlined),
                            label: Text(s.deactivateTeacher),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
