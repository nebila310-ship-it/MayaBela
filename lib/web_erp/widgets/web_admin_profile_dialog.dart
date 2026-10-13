import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/screens/admin_people_screens.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/discipline_service.dart';
import 'package:mayabela/services/dosa_service.dart';
import 'package:mayabela/services/library_rental_service.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/widgets/invite_parent_actions.dart';
import 'package:mayabela/services/persistence/transfer_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_photo_service.dart';
import 'package:mayabela/services/teacher_photo_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/student_sis_profile.dart';
import 'package:mayabela/services/student_support_service.dart';
import 'package:mayabela/services/persistence/teacher_persistence_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/admin_staff_ui.dart';
import 'package:mayabela/widgets/profile_photo_align_dialog.dart';
import 'package:mayabela/widgets/admin_student_edit_dialog.dart';
import 'package:mayabela/widgets/admin_student_qr_actions.dart';
import 'package:mayabela/web_erp/widgets/student_sis_record_view.dart';
import 'package:mayabela/widgets/student_medical_info_panel.dart';
import 'package:mayabela/widgets/student_portal_credentials_card.dart';
import 'package:mayabela/widgets/student_qr_card.dart';
import 'package:mayabela/utils/email_utils.dart';
import 'package:mayabela/widgets/send_teacher_credentials.dart';
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
  bool? administrationStaff,
}) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => _WebTeacherProfileDialog(
      teacherId: teacherId,
      onUpdated: onUpdated,
      administrationStaff: administrationStaff,
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

  @override
  void initState() {
    super.initState();
    unawaited(_hydrateSis());
  }

  Future<void> _hydrateSis() async {
    await Future.wait([
      StudentSupportService.instance.ensureLoaded(),
      DisciplineService.instance.ensureLoaded(),
      DosaService.instance.ensureLoaded(),
      LibraryRentalService.instance.ensureLoaded(),
      TransferPersistenceService.instance.loadIntoService(),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _edit(AdminStudentRecord student) async {
    final saved = await showAdminStudentEditDialog(context, student: student);
    if (saved == true) {
      setState(() {});
      widget.onUpdated?.call();
    }
  }

  Future<void> _changePhoto(AdminStudentRecord student) async {
    final bytes = await pickAlignedPhotoOrSnack(
      context,
      pick: StudentPhotoService.instance.pickBytes,
      errorOf: () => StudentPhotoService.instance.lastError,
    );
    if (bytes == null || !mounted) return;
    final path = await StudentPhotoService.instance.saveBytesForStudent(
      student.studentId,
      bytes,
    );
    if (path == null) return;
    StudentPhotoService.instance.rememberPath(student.studentId, path);
    StudentPhotoService.instance.rememberBytes(student.studentId, bytes);
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
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 820),
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
                                photoPath: student.photoPath,
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
                        const SizedBox(height: 4),
                        StudentPortalCredentialsCard(student: student),
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
                        StaffInfoTile(
                          icon: Icons.flag_outlined,
                          label: 'Lifecycle',
                          value: student.lifecycleStatus.label,
                          color: StaffPalette.students.primary,
                        ),
                        StaffInfoTile(
                          icon: Icons.workspace_premium_outlined,
                          label: s.studentFundingType,
                          value: student.fundingType ==
                                  StudentFundingType.scholarship
                              ? s.scholarshipStudent
                              : s.regularStudent,
                          color: student.fundingType.isScholarship
                              ? const Color(0xFF6A1B9A)
                              : StaffPalette.students.secondary,
                        ),
                        StaffInfoTile(
                          icon: Icons.home_outlined,
                          label: 'House / grouping',
                          value: StudentSisProfile.load(student.studentId)
                                  ?.groupingSummary ??
                              student.className,
                          color: StaffPalette.students.secondary,
                        ),
                        const SizedBox(height: 12),
                        StudentMedicalInfoPanel(
                          hasMedicalCondition: student.hasMedicalCondition,
                          medicalConditionDetails:
                              student.medicalConditionDetails,
                          otherMedicalInfo: student.otherMedicalInfo,
                          compact: true,
                        ),
                        const SizedBox(height: 12),
                        StudentSisRecordView(
                          snapshot: StudentSisProfile.load(student.studentId),
                          compact: true,
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
                        const SizedBox(height: 16),
                        ParentInviteResendBar(student: student),
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
    this.administrationStaff,
  });

  final String teacherId;
  final VoidCallback? onUpdated;
  final bool? administrationStaff;

  @override
  State<_WebTeacherProfileDialog> createState() =>
      _WebTeacherProfileDialogState();
}

class _WebTeacherProfileDialogState extends State<_WebTeacherProfileDialog> {
  AdminTeacherRecord? get _teacher =>
      TeacherRegistryService.instance.lookupAnyById(widget.teacherId);

  bool get _canHireStaff => ModuleAccess.canHireStaff;
  bool get _canAssignTeachers => ModuleAccess.canAssignTeachers;

  bool _isStaff(AdminTeacherRecord teacher) =>
      widget.administrationStaff ?? isAdministrationStaffRecord(teacher);

  Color _accent(bool staff) =>
      staff ? AdminFormTheme.staff.primary : AdminFormTheme.teacher.primary;

  Future<void> _changePhoto(AdminTeacherRecord teacher) async {
    if (!_canHireStaff) return;
    final s = AppLocale.instance.strings;
    final staff = _isStaff(teacher);
    final bytes = await pickAlignedPhotoOrSnack(
      context,
      pick: TeacherPhotoService.instance.pickBytes,
      errorOf: () => TeacherPhotoService.instance.lastError,
    );
    if (bytes == null || !mounted) return;
    final path = await TeacherPhotoService.instance.saveBytesForTeacher(
      teacher.teacherId,
      bytes,
    );
    if (path == null) return;
    TeacherPhotoService.instance.rememberPath(teacher.teacherId, path);
    TeacherPhotoService.instance.rememberBytes(teacher.teacherId, bytes);
    TeacherRegistryService.instance.updatePhoto(teacher.teacherId, path);
    if (!mounted) return;
    setState(() {});
    widget.onUpdated?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(staff ? s.staffUpdated : s.teacherUpdated),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _renameRole(AdminTeacherRecord teacher) async {
    final changed = await showRenameStaffRoleTitleDialog(
      context: context,
      teacher: teacher,
      onSaved: widget.onUpdated,
    );
    if (changed && mounted) setState(() {});
  }

  Future<void> _editStaff(AdminTeacherRecord teacher) async {
    final s = AppLocale.instance.strings;
    final nameCtrl = TextEditingController(text: teacher.fullName);
    final phoneCtrl = TextEditingController(text: teacher.phone ?? '');
    final emailCtrl = TextEditingController(text: teacher.email ?? '');
    final roleTitle = staffRolesSummary(
      teacher.staffRoles,
      s,
      schoolId: teacher.schoolId,
    );
    final roleCtrl = TextEditingController(text: roleTitle);
    final theme = AdminFormTheme.staff;

    final saved = await showAdminFormDialog(
      context: context,
      title: s.editStaff,
      subtitle: teacher.fullName,
      accent: theme.primary,
      icon: Icons.badge_outlined,
      saveBlockedReason: (_) {
        if (nameCtrl.text.trim().isEmpty) return s.enterName;
        if (!EmailUtils.isRealMailbox(emailCtrl.text)) return s.emailRequired;
        return null;
      },
      canSave: (_) =>
          nameCtrl.text.trim().isNotEmpty &&
          EmailUtils.isRealMailbox(emailCtrl.text),
      builder: (ctx, setDialogState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminFormDialogSection(
            title: s.fullName,
            icon: Icons.badge_outlined,
            color: theme.primary,
            children: [
              adminDialogField(
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: adminFieldDecoration(
                    label: s.fullName,
                    icon: Icons.person_outline,
                    accent: theme.primary,
                  ),
                ),
              ),
              if (teacher.staffRoles.isNotEmpty)
                adminDialogField(
                  TextField(
                    controller: roleCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: adminFieldDecoration(
                      label: s.staffJobTitle,
                      hint: s.renameRoleTitleExample,
                      icon: Icons.workspace_premium_outlined,
                      accent: theme.primary,
                    ),
                  ),
                ),
            ],
          ),
          AdminFormDialogSection(
            title: s.contactNumbersOnFile,
            icon: Icons.contact_phone_outlined,
            color: theme.secondary,
            children: [
              adminDialogField(
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: adminFieldDecoration(
                    label: s.phoneNumber,
                    icon: Icons.phone_outlined,
                    accent: theme.secondary,
                  ),
                ),
              ),
              adminDialogField(
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: adminFieldDecoration(
                    label: s.emailForPasswordReset,
                    hint: s.emailForPasswordResetHint,
                    icon: Icons.email_outlined,
                    accent: theme.secondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final nextName = nameCtrl.text.trim();
    final nextPhone = phoneCtrl.text.trim();
    final nextEmail = EmailUtils.userFacing(emailCtrl.text);
    final nextRole = roleCtrl.text.trim();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    roleCtrl.dispose();

    if (saved != true || !mounted) return;

    final updated = teacher.copyWith(
      fullName: nextName,
      phone: nextPhone,
      email: nextEmail,
    );
    TeacherRegistryService.instance.updateTeacher(updated);
    AuthService.syncTeacherAuthProfile(updated);
    await TeacherPersistenceService.instance.saveRegistryFromService();

    if (nextRole.isNotEmpty &&
        nextRole != roleTitle &&
        teacher.staffRoles.isNotEmpty) {
      await SchoolRoleCatalogService.instance.renameRole(
        roleKey: teacher.staffRoles.first,
        label: nextRole,
        schoolId: teacher.schoolId,
      );
    }

    if (!mounted) return;
    setState(() {});
    widget.onUpdated?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.staffUpdated),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteStaff(AdminTeacherRecord teacher) async {
    final s = AppLocale.instance.strings;
    final staff = _isStaff(teacher);
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: s.deactivateTeacher,
      message: s.confirmDeactivateTeacher,
      accent: _accent(staff),
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
    final staff = teacher != null && _isStaff(teacher);
    final accent = _accent(staff);
    final roleTitle = teacher == null
        ? ''
        : staffRolesSummary(
            teacher.staffRoles,
            s,
            schoolId: teacher.schoolId,
          );

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
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
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              StaffRegistryAvatar(
                                staffId: teacher.teacherId,
                                name: teacher.fullName,
                                photoPath: teacher.photoPath,
                                radius: 44,
                                fallbackColor: accent,
                              ),
                              if (_canHireStaff)
                                Material(
                                  color: accent,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => _changePhoto(teacher),
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
                          label: 'Staff ID',
                          value: teacher.employeeId ?? teacher.teacherId,
                          color: accent,
                        ),
                        if (staff)
                          StaffInfoTile(
                            icon: Icons.workspace_premium_outlined,
                            label: s.staffJobTitle,
                            value: roleTitle,
                            color: AdminFormTheme.staff.secondary,
                            trailing: AuthService.canAssignStaffRoles
                                ? IconButton(
                                    tooltip: s.renameRoleTitle,
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: AdminFormTheme.staff.secondary,
                                    ),
                                    onPressed: () => _renameRole(teacher),
                                  )
                                : null,
                          )
                        else ...[
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
                        ],
                        if (teacher.phone?.isNotEmpty == true)
                          StaffInfoTile(
                            icon: Icons.phone_outlined,
                            label: s.phone,
                            value: teacher.phone!,
                            color: const Color(0xFF2E7D32),
                          ),
                        const SizedBox(height: 16),
                        StaffLoginResendBar(
                          teacher: teacher,
                          administrationStaff: staff,
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
                                onSaved: () {
                                  widget.onUpdated?.call();
                                  if (mounted) setState(() {});
                                },
                              );
                            },
                            icon: const Icon(
                              Icons.admin_panel_settings_outlined,
                            ),
                            label: Text(s.staffRolesTitle),
                          ),
                        if (staff && AuthService.canAssignStaffRoles)
                          OutlinedButton.icon(
                            onPressed: () => _renameRole(teacher),
                            icon: const Icon(Icons.badge_outlined),
                            label: Text(s.renameRoleTitle),
                          ),
                        if (_canHireStaff || (!staff && _canAssignTeachers))
                          OutlinedButton.icon(
                            onPressed: () {
                              if (staff && _canHireStaff) {
                                unawaited(_editStaff(teacher));
                                return;
                              }
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
                                  ? (staff ? s.editStaff : s.editTeacher)
                                  : s.assignTeacherClasses,
                            ),
                          ),
                        if (_canHireStaff)
                          OutlinedButton.icon(
                            onPressed: () => _changePhoto(teacher),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(s.changeProfilePhoto),
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
