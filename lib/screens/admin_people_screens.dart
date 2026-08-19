import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/admin_transfer_screen.dart';
import 'package:mayabela/screens/messages_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_credentials_service.dart';
import 'package:mayabela/services/driver_photo_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/services/phone_launch_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_photo_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_photo_service.dart';
import 'package:mayabela/services/persistence/teacher_persistence_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/subject_multi_picker.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/admin_staff_ui.dart';
import 'package:mayabela/widgets/invite_parent_actions.dart';
import 'package:mayabela/widgets/send_driver_credentials.dart';
import 'package:mayabela/widgets/staff_registry_avatar.dart';
import 'package:mayabela/widgets/staff_roles_dialog.dart';
import 'package:mayabela/widgets/teacher_class_assignment_editor.dart';
import 'package:mayabela/widgets/admin_student_edit_dialog.dart';
import 'package:mayabela/widgets/admin_student_qr_actions.dart';
import 'package:mayabela/widgets/student_medical_info_panel.dart';
import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/models/message.dart';

void openAdminChat(
  BuildContext context, {
  required String name,
  required String role,
  String? staffParticipantId,
}) {
  final adminId =
      StaffMemberOption.viewerAdminStaffId(AuthService.roleAdmin);
  final id = SchoolDataService.instance.openOrCreateConversation(
    contactName: name,
    role: role,
    staffParticipantId: staffParticipantId,
    counterpartyStaffId: adminId,
  );
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(conversationId: id, contactName: name),
    ),
  );
}

Future<void> showAdminCallPicker(
  BuildContext context, {
  required List<({String label, String phone})> options,
}) async {
  final s = AppLocale.instance.strings;
  if (options.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.noPhoneOnFile)),
    );
    return;
  }
  if (options.length == 1) {
    await PhoneLaunchService.instance.dial(options.first.phone);
    return;
  }
  final picked = await showModalBottomSheet<({String label, String phone})>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              s.choosePhoneToCall,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ...options.map(
            (o) => ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: Text(o.label),
              subtitle: Text(o.phone),
              onTap: () => Navigator.pop(ctx, o),
            ),
          ),
        ],
      ),
    ),
  );
  if (picked != null) {
    await PhoneLaunchService.instance.dial(picked.phone);
  }
}

/// Scrollable staff teacher picker (same registry as Staff → Teachers).
Future<AdminTeacherRecord?> showReplacementTeacherPicker(
  BuildContext context, {
  required String className,
  required String excludeTeacherId,
  String? schoolId,
}) async {
  final s = AppLocale.instance.strings;
  final sid = schoolId ?? AuthService.activeSchoolId;
  final teachers = TeacherRegistryService.instance
      .staffTeachersForSchool(sid)
      .where((t) => t.teacherId.toUpperCase() != excludeTeacherId.toUpperCase())
      .toList();

  if (teachers.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noTeachersAvailableForReplacement)),
      );
    }
    return null;
  }

  return showModalBottomSheet<AdminTeacherRecord>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E293B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.75;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.replaceHomeroomTeacher,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.replaceHomeroomPrompt(className),
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.selectReplacementFromStaff,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  itemCount: teachers.length,
                  separatorBuilder: (_, _) => const Divider(color: Colors.white12),
                  itemBuilder: (context, index) {
                    final t = teachers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo.shade100,
                        child: Text(
                          t.fullName[0],
                          style: TextStyle(color: Colors.indigo.shade800),
                        ),
                      ),
                      title: Text(
                        t.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${t.teacherId} · ${t.subject} · ${t.assignedClass}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                      onTap: () => Navigator.pop(ctx, t),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class AdminStudentProfileScreen extends StatefulWidget {
  const AdminStudentProfileScreen({super.key, required this.studentId});

  final String studentId;

  @override
  State<AdminStudentProfileScreen> createState() =>
      _AdminStudentProfileScreenState();
}

class _AdminStudentProfileScreenState extends State<AdminStudentProfileScreen> {
  AdminStudentRecord? get _student =>
      StudentRegistryService.instance.lookupById(widget.studentId);

  AppStrings get s => AppLocale.instance.strings;

  Future<void> _changeStudentPhoto(AdminStudentRecord student) async {
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
    setState(() {});
  }

  List<({String label, String phone})> _phoneOptions(AdminStudentRecord student) {
    final options = <({String label, String phone})>[];
    void add(String label, String? phone) {
      if (phone == null || phone.trim().isEmpty) return;
      options.add((label: label, phone: phone.trim()));
    }

    add(s.fatherPhone, student.fatherPhone);
    add(s.motherPhone, student.motherPhone);
    add(s.guardianPhoneOptional, student.guardianPhone);
    add(s.emergencyPhone, student.emergencyPhone1);
    add(s.emergencyPhone, student.emergencyPhone2);
    return options;
  }

  Future<void> _editStudent(AdminStudentRecord student) async {
    final saved = await showAdminStudentEditDialog(context, student: student);
    if (saved != true || !mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.studentUpdated)),
    );
  }

  void _showStudentQr(AdminStudentRecord student) {
    showAdminStudentQrSheet(context, student: student);
  }

  Future<void> _deleteStudent(AdminStudentRecord student) async {
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.studentRemoved)),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = _student;
    if (student == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.studentProfile)),
        body: Center(child: Text(s.inviteParentNoRecord)),
      );
    }

    final messageTarget = student.primaryParentName ?? student.fullName;
    final homeroomTeacher = student.homeroomTeacherId != null
        ? TeacherRegistryService.instance.lookupById(student.homeroomTeacherId!)
        : null;

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: StaffPalette.students.primary.withValues(alpha: 0.04),
          appBar: AppBar(
            backgroundColor: StaffPalette.students.primary,
            foregroundColor: Colors.white,
            title: Text(student.fullName),
          ),
          body: ListView(
            padding: listPagePadding(context),
            children: [
              AdminProfilePhotoHeader(
                palette: StaffPalette.students,
                name: student.fullName,
                staffId: student.studentId,
                subtitleLines: [
                  student.className,
                  if (student.gender != null) student.gender!,
                ],
                onChangePhoto: () => _changeStudentPhoto(student),
                avatar: StaffRegistryAvatar(
                  staffId: student.studentId,
                  name: student.fullName,
                  radius: 44,
                  isStudent: true,
                  fallbackColor: StaffPalette.students.primary,
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
                icon: Icons.cake_outlined,
                label: s.studentDateOfBirth,
                value: ParentInviteService.formatDob(student.dateOfBirth),
                color: StaffPalette.students.secondary,
              ),
              if (student.gender != null)
                StaffInfoTile(
                  icon: Icons.wc_outlined,
                  label: s.gender,
                  value: student.gender!,
                  color: StaffPalette.students.primary,
                ),
              StaffInfoTile(
                icon: Icons.class_rounded,
                label: s.grade,
                value: '${student.grade} · ${student.className}',
                color: StaffPalette.students.secondary,
              ),
              StaffInfoTile(
                icon: Icons.location_city_outlined,
                label: s.campus,
                value: student.campus,
                color: const Color(0xFF455A64),
              ),
              if (student.academicYear?.trim().isNotEmpty == true)
                StaffInfoTile(
                  icon: Icons.calendar_today_outlined,
                  label: s.academicYear,
                  value: student.academicYear!,
                  color: const Color(0xFF5D4037),
                ),
              if (homeroomTeacher != null)
                StaffInfoTile(
                  icon: Icons.school_outlined,
                  label: s.homeroomTeacher,
                  value:
                      '${homeroomTeacher.fullName} (${homeroomTeacher.teacherId})',
                  color: const Color(0xFF283593),
                ),
              StaffInfoTile(
                icon: Icons.family_restroom,
                label: s.fatherName,
                value: '${student.fatherName ?? '—'} (${student.fatherPhone ?? '—'})',
                color: const Color(0xFF1565C0),
              ),
              StaffInfoTile(
                icon: Icons.family_restroom,
                label: s.motherName,
                value: '${student.motherName ?? '—'} (${student.motherPhone ?? '—'})',
                color: const Color(0xFFAD1457),
              ),
              if (student.guardianName?.trim().isNotEmpty == true ||
                  student.guardianPhone?.trim().isNotEmpty == true)
                StaffInfoTile(
                  icon: Icons.family_restroom_outlined,
                  label: s.guardianNameOptional,
                  value:
                      '${student.guardianName ?? '—'} (${student.guardianPhone ?? '—'})',
                  color: const Color(0xFF6A1B9A),
                ),
              if (student.emergencyContact1Name?.trim().isNotEmpty == true ||
                  student.emergencyPhone1?.trim().isNotEmpty == true)
                StaffInfoTile(
                  icon: Icons.contact_emergency_outlined,
                  label: s.emergencyContactName,
                  value:
                      '${student.emergencyContact1Name ?? '—'} (${student.emergencyPhone1 ?? '—'})',
                  color: const Color(0xFFE65100),
                ),
              if (student.emergencyContact2Name?.trim().isNotEmpty == true ||
                  student.emergencyPhone2?.trim().isNotEmpty == true)
                StaffInfoTile(
                  icon: Icons.contact_emergency_outlined,
                  label: s.emergencyContactName,
                  value:
                      '${student.emergencyContact2Name ?? '—'} (${student.emergencyPhone2 ?? '—'})',
                  color: const Color(0xFFBF360C),
                ),
              StaffInfoTile(
                icon: Icons.directions_bus_filled_rounded,
                label: s.transportEnabled,
                value: student.transportEnabled
                    ? (student.transportId?.isNotEmpty == true
                        ? '${student.transportId} · ${s.transportWired}'
                        : s.transportNotWired)
                    : s.transportNotEnabled,
                color: StaffPalette.transport.primary,
              ),
              const SizedBox(height: 8),
              StudentMedicalInfoPanel(
                hasMedicalCondition: student.hasMedicalCondition,
                medicalConditionDetails: student.medicalConditionDetails,
                otherMedicalInfo: student.otherMedicalInfo,
                accent: StaffPalette.students.primary,
              ),
              const SizedBox(height: 8),
              StaffActionGrid(
                actions: [
                  if (ModuleAccess.canManage('parents'))
                    StaffActionItem(
                      icon: Icons.sms_outlined,
                      label: s.inviteParent,
                      color: Colors.indigo,
                      onPressed: () => inviteParentForRecord(context, student),
                    ),
                  StaffActionItem(
                    icon: Icons.message_rounded,
                    label: s.messageInternally,
                    color: Colors.orange,
                    onPressed: () => openAdminChat(
                      context,
                      name: messageTarget,
                      role: s.parentLabel,
                    ),
                  ),
                  StaffActionItem(
                    icon: Icons.phone_rounded,
                    label: s.callContact,
                    color: Colors.green,
                    onPressed: () => showAdminCallPicker(
                      context,
                      options: _phoneOptions(student),
                    ),
                  ),
                  if (ModuleAccess.canManage('students')) ...[
                    StaffActionItem(
                      icon: Icons.camera_alt_rounded,
                      label: s.changeProfilePhoto,
                      color: StaffPalette.students.primary,
                      onPressed: () => _changeStudentPhoto(student),
                    ),
                    StaffActionItem(
                      icon: Icons.qr_code_2_rounded,
                      label: s.generateStudentQr,
                      color: Colors.teal,
                      onPressed: () => _showStudentQr(student),
                    ),
                    StaffActionItem(
                      icon: Icons.edit_rounded,
                      label: s.editStudent,
                      color: Colors.blue,
                      onPressed: () => _editStudent(student),
                    ),
                  ],
                  if (ModuleAccess.canManage('transfers'))
                    StaffActionItem(
                      icon: Icons.swap_horiz_rounded,
                      label: s.transferStudent,
                      color: Colors.indigo,
                      onPressed: () => showStudentTransferKindPicker(
                        context,
                        studentId: student.studentId,
                      ),
                    ),
                  if (ModuleAccess.canManage('students'))
                    StaffActionItem(
                      icon: Icons.person_off_rounded,
                      label: s.deleteStudent,
                      color: Colors.red,
                      onPressed: () => _deleteStudent(student),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminTeacherProfileScreen extends StatefulWidget {
  const AdminTeacherProfileScreen({super.key, required this.teacherId});

  final String teacherId;

  @override
  State<AdminTeacherProfileScreen> createState() =>
      _AdminTeacherProfileScreenState();
}

class _AdminTeacherProfileScreenState extends State<AdminTeacherProfileScreen> {
  AdminTeacherRecord? get _teacher =>
      TeacherRegistryService.instance.lookupById(widget.teacherId);

  AppStrings get s => AppLocale.instance.strings;

  Future<void> _changePhoto(AdminTeacherRecord teacher) async {
    if (!ModuleAccess.canHireStaff) return;
    final file = await TeacherPhotoService.instance.pickFromGallery();
    if (file == null || !mounted) return;
    final path = await TeacherPhotoService.instance.saveForTeacher(
      teacher.teacherId,
      file,
    );
    if (path == null) return;
    TeacherPhotoService.instance.rememberPath(teacher.teacherId, path);
    TeacherRegistryService.instance.updatePhoto(teacher.teacherId, path);
    setState(() {});
  }

  /// HR: profile / contact fields. Class placement is Section Director.
  Future<void> _editTeacher(AdminTeacherRecord teacher) async {
    if (!ModuleAccess.canHireStaff) return;
    final nameCtrl = TextEditingController(text: teacher.fullName);
    var selectedSubjects = List<String>.from(teacher.subjects);
    final phoneCtrl = TextEditingController(text: teacher.phone ?? '');
    final emailCtrl = TextEditingController(text: teacher.email ?? '');
    final theme = AdminFormTheme.teacher;
    final campusOptions = SchoolRegistryService.instance
        .campusesForSchool(teacher.schoolId)
        .toList();
    if (!campusOptions.contains(teacher.campus)) {
      campusOptions.insert(0, teacher.campus);
    }
    var selectedCampus = teacher.campus;

    final saved = await showAdminFormDialog(
      context: context,
      title: s.editTeacher,
      subtitle: teacher.fullName,
      accent: theme.primary,
      icon: Icons.school_outlined,
      saveBlockedReason: (_) {
        if (nameCtrl.text.trim().isEmpty) return s.enterName;
        return null;
      },
      canSave: (_) => nameCtrl.text.trim().isNotEmpty,
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
              adminDialogField(
                SubjectMultiPicker(
                  selected: selectedSubjects,
                  onChanged: (values) =>
                      setDialogState(() => selectedSubjects = values),
                  accent: theme.primary,
                  label: s.subject,
                ),
              ),
              if (campusOptions.length > 1)
                adminDialogField(
                  DropdownButtonFormField<String>(
                    initialValue: selectedCampus,
                    decoration: adminFieldDecoration(
                      label: s.campus,
                      icon: Icons.location_city_outlined,
                      accent: theme.primary,
                    ),
                    items: campusOptions
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) selectedCampus = value;
                    },
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
                    label: s.email,
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

    if (saved != true || !mounted) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      emailCtrl.dispose();
      return;
    }

    final updated = teacher.copyWith(
      fullName: nameCtrl.text.trim(),
      subjects: selectedSubjects,
      phone: phoneCtrl.text.trim(),
      email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
      campus: selectedCampus,
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();

    TeacherRegistryService.instance.updateTeacher(updated);
    AuthService.syncTeacherAuthProfile(updated);
    await TeacherPersistenceService.instance.saveRegistryFromService();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.teacherUpdated),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Section Director: class / subject placement only.
  Future<void> _assignTeacherClasses(AdminTeacherRecord teacher) async {
    if (!ModuleAccess.canAssignTeachers) return;
    final schoolGrades = ClassStructureService.instance.gradesForSchool();
    final originalAssignments = teacherClassAssignmentsFromRecord(teacher);
    final assignmentEntries = teacherAssignmentEntriesFromRecord(
      teacher,
      schoolGrades: schoolGrades,
    );
    final theme = AdminFormTheme.teacher;

    final saved = await showAdminFormDialog(
      context: context,
      title: s.assignTeacherClasses,
      subtitle: teacher.fullName,
      accent: theme.primary,
      icon: Icons.class_outlined,
      saveBlockedReason: (_) {
        final built = buildTeacherClassAssignments(assignmentEntries);
        if (built.isEmpty && originalAssignments.isEmpty) {
          return s.atLeastOneClass;
        }
        return null;
      },
      canSave: (_) {
        final built = buildTeacherClassAssignments(assignmentEntries);
        return built.isNotEmpty || originalAssignments.isNotEmpty;
      },
      builder: (ctx, setDialogState) => TeacherClassAssignmentEditor(
        entries: assignmentEntries,
        schoolGrades: schoolGrades,
        accent: theme.primary,
        secondary: theme.secondary,
        onChanged: () => setDialogState(() {}),
      ),
    );

    if (saved != true || !mounted) {
      disposeTeacherAssignmentEntries(assignmentEntries);
      return;
    }

    final assignments = resolveTeacherClassAssignmentsForSave(
      entries: assignmentEntries,
      fallback: originalAssignments,
    );
    if (assignments.isEmpty) {
      disposeTeacherAssignmentEntries(assignmentEntries);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.atLeastOneClass)),
      );
      return;
    }

    await ensureTeacherAssignmentSections(assignmentEntries);
    final assignedClass =
        assignments.map((a) => a.className).toSet().join(', ');
    final roles = assignments.map((a) => a.role).toSet().toList();
    final derivedSubjects =
        TeacherRegistryService.subjectsFromAssignments(assignments);

    final updated = teacher.copyWith(
      subjects: derivedSubjects.isNotEmpty ? derivedSubjects : teacher.subjects,
      classAssignments: assignments,
      assignedClass: assignedClass,
      roles: roles,
    );
    disposeTeacherAssignmentEntries(assignmentEntries);

    TeacherRegistryService.instance.updateTeacher(updated);
    SchoolDataService.instance.setTeacherAssignmentsFromRegistry(updated);
    await TeacherPersistenceService.instance.saveRegistryFromService();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.teacherUpdated),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deactivateTeacher(AdminTeacherRecord teacher) async {
    if (!ModuleAccess.canHireStaff) return;
    final homeroomClasses =
        TeacherRegistryService.instance.homeroomClassesFor(teacher.teacherId);
    final replacements = <String, String>{};

    for (final className in homeroomClasses) {
      if (!mounted) return;

      final picked = await showReplacementTeacherPicker(
        context,
        className: className,
        excludeTeacherId: teacher.teacherId,
        schoolId: teacher.schoolId,
      );
      if (picked == null) return;
      replacements[className] = picked.teacherId;
    }

    if (!mounted) return;
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

    final ok = homeroomClasses.isEmpty
        ? () {
            SchoolDataService.instance.removeTeacherAssignments(teacher.teacherId);
            return TeacherRegistryService.instance.deactivateTeacher(teacher.teacherId);
          }()
        : SchoolDataService.instance.deactivateTeacherWithReplacement(
            teacherId: teacher.teacherId,
            homeroomReplacementsByClass: replacements,
          );

    if (!mounted) return;
    if (ok) {
      await TeacherPersistenceService.instance.deleteStaffAndFreePhone(teacher);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.teacherDeactivated)),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacher = _teacher;
    if (teacher == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.teacherProfile)),
        body: Center(child: Text(s.teacherNotFoundForSchool)),
      );
    }

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: StaffPalette.teachers.primary.withValues(alpha: 0.04),
          appBar: AppBar(
            backgroundColor: StaffPalette.teachers.primary,
            foregroundColor: Colors.white,
            title: Text(teacher.fullName),
          ),
          body: ListView(
            padding: listPagePadding(context),
            children: [
              AdminProfilePhotoHeader(
                palette: StaffPalette.teachers,
                name: teacher.fullName,
                staffId: teacher.teacherId,
                subtitleLines: [teacher.subject, teacher.assignedClass],
                onChangePhoto: () => _changePhoto(teacher),
                avatar: StaffRegistryAvatar(
                  staffId: teacher.teacherId,
                  name: teacher.fullName,
                  radius: 44,
                  fallbackColor: StaffPalette.teachers.primary,
                ),
              ),
              const SizedBox(height: 16),
              StaffInfoTile(
                icon: Icons.phone_rounded,
                label: s.phoneNumber,
                value: teacher.phone ?? '—',
                color: Colors.green,
              ),
              StaffInfoTile(
                icon: Icons.email_rounded,
                label: s.email,
                value: teacher.email ?? '—',
                color: Colors.blue,
              ),
              StaffInfoTile(
                icon: Icons.class_rounded,
                label: s.assignedClasses,
                value: teacher.classAssignments.isNotEmpty
                    ? teacher.classAssignments
                        .map((a) {
                          final role = s.teacherRoleLabel(a.role);
                          if (a.teachingSlots.isEmpty) {
                            return '${a.className} · $role';
                          }
                          final slots = a.teachingSlots
                              .map(
                                (slot) =>
                                    '${slot.subjectName} (${slot.subjectId}, ${slot.slotId})',
                              )
                              .join('; ');
                          return '${a.className} · $role · $slots';
                        })
                        .join('\n')
                    : teacher.assignedClass,
                color: StaffPalette.teachers.secondary,
              ),
              const SizedBox(height: 8),
              StaffActionGrid(
                actions: [
                  StaffActionItem(
                    icon: Icons.message_rounded,
                    label: s.messageInternally,
                    color: Colors.orange,
                    onPressed: () => openAdminChat(
                      context,
                      name: teacher.fullName,
                      role: s.teacherLabelShort,
                      staffParticipantId:
                          StaffMemberOption.teacherKey(teacher.teacherId),
                    ),
                  ),
                  StaffActionItem(
                    icon: Icons.phone_rounded,
                    label: s.callContact,
                    color: Colors.green,
                    onPressed: () {
                      if (teacher.phone == null ||
                          teacher.phone!.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.noPhoneOnFile)),
                        );
                        return;
                      }
                      PhoneLaunchService.instance.dial(teacher.phone!);
                    },
                  ),
                  if (ModuleAccess.canHireStaff)
                    StaffActionItem(
                      icon: Icons.camera_alt_rounded,
                      label: s.changeProfilePhoto,
                      color: StaffPalette.teachers.primary,
                      onPressed: () => _changePhoto(teacher),
                    ),
                  if (ModuleAccess.canHireStaff)
                    StaffActionItem(
                      icon: Icons.edit_rounded,
                      label: s.editTeacher,
                      color: Colors.blue,
                      onPressed: () => _editTeacher(teacher),
                    ),
                  if (ModuleAccess.canAssignTeachers)
                    StaffActionItem(
                      icon: Icons.class_outlined,
                      label: s.assignTeacherClasses,
                      color: Colors.teal,
                      onPressed: () => _assignTeacherClasses(teacher),
                    ),
                  if (AuthService.canAssignStaffRoles)
                    StaffActionItem(
                      icon: Icons.admin_panel_settings_rounded,
                      label: s.staffRolesTitle,
                      color: Colors.deepPurple,
                      onPressed: () => showStaffRolesDialog(
                        context: context,
                        teacher: teacher,
                        onSaved: () {
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  if (ModuleAccess.canAssignTeachers)
                    StaffActionItem(
                      icon: Icons.swap_horiz_rounded,
                      label: s.transferTeacher,
                      color: Colors.indigo,
                      onPressed: () => showTeacherTransferKindPicker(
                        context,
                        teacherId: teacher.teacherId,
                      ),
                    ),
                  if (ModuleAccess.canHireStaff)
                    StaffActionItem(
                      icon: Icons.person_off_rounded,
                      label: s.deactivateTeacher,
                      color: Colors.red,
                      onPressed: () => _deactivateTeacher(teacher),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminDriverProfileScreen extends StatefulWidget {
  const AdminDriverProfileScreen({super.key, required this.driverId});

  final String driverId;

  @override
  State<AdminDriverProfileScreen> createState() =>
      _AdminDriverProfileScreenState();
}

class _AdminDriverProfileScreenState extends State<AdminDriverProfileScreen> {
  AdminDriverRecord? get _driver =>
      DriverRegistryService.instance.lookupById(widget.driverId);

  AppStrings get s => AppLocale.instance.strings;

  Future<void> _changePhoto(AdminDriverRecord driver) async {
    final file = await DriverPhotoService.instance.pickFromGallery();
    if (file == null || !mounted) return;
    final path = await DriverPhotoService.instance.saveForDriver(
      driver.driverId,
      file,
    );
    if (path == null) return;
    DriverPhotoService.instance.rememberPath(driver.driverId, path);
    DriverRegistryService.instance.updatePhoto(driver.driverId, path);
    setState(() {});
  }

  Future<void> _editDriver(AdminDriverRecord driver) async {
    final nameCtrl = TextEditingController(text: driver.fullName);
    final phoneCtrl = TextEditingController(text: driver.phone ?? '');
    final emailCtrl = TextEditingController(text: driver.email ?? '');
    final busCtrl = TextEditingController(text: driver.busNumber);
    final routeParts = DriverRegistryService.parseRoute(driver.routeName);
    final routeFromCtrl = TextEditingController(text: routeParts.from);
    final routeThroughCtrl = TextEditingController(text: routeParts.through);
    final routeToCtrl = TextEditingController(text: routeParts.to);
    final plateCtrl = TextEditingController(text: driver.plateNumber);

    final saved = await showAdminFormDialog(
      context: context,
      title: s.editDriver,
      subtitle: driver.fullName,
      accent: AdminFormTheme.driver.primary,
      icon: Icons.directions_bus_outlined,
      builder: (ctx, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminFormDialogSection(
            title: s.fullName,
            icon: Icons.badge_outlined,
            color: AdminFormTheme.driver.primary,
            children: [
              adminDialogField(
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: adminFieldDecoration(
                    label: s.fullName,
                    icon: Icons.person_outline,
                    accent: AdminFormTheme.driver.primary,
                  ),
                ),
              ),
              adminDialogField(
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: adminFieldDecoration(
                    label: s.phoneNumber,
                    icon: Icons.phone_outlined,
                    accent: AdminFormTheme.driver.primary,
                  ),
                ),
              ),
              adminDialogField(
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: adminFieldDecoration(
                    label: s.email,
                    icon: Icons.email_outlined,
                    accent: AdminFormTheme.driver.primary,
                  ),
                ),
              ),
            ],
          ),
          AdminFormDialogSection(
            title: s.transportDetails,
            icon: Icons.route_outlined,
            color: AdminFormTheme.driver.secondary,
            children: [
              adminDialogField(
                TextField(
                  controller: busCtrl,
                  decoration: adminFieldDecoration(
                    label: s.busNumber,
                    icon: Icons.directions_bus_outlined,
                    accent: AdminFormTheme.driver.secondary,
                  ),
                ),
              ),
              adminDialogField(
                TextField(
                  controller: routeFromCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: adminFieldDecoration(
                    label: s.routeFrom,
                    hint: s.routeFromHint,
                    icon: Icons.trip_origin,
                    accent: AdminFormTheme.driver.secondary,
                  ),
                ),
              ),
              adminDialogField(
                TextField(
                  controller: routeThroughCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: adminFieldDecoration(
                    label: s.routeThrough,
                    hint: s.routeThroughHint,
                    icon: Icons.place_outlined,
                    accent: AdminFormTheme.driver.secondary,
                  ),
                ),
              ),
              adminDialogField(
                TextField(
                  controller: routeToCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: adminFieldDecoration(
                    label: s.routeTo,
                    hint: s.routeToHint,
                    icon: Icons.flag_outlined,
                    accent: AdminFormTheme.driver.secondary,
                  ),
                ),
              ),
              adminDialogField(
                TextField(
                  controller: plateCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: adminFieldDecoration(
                    label: s.plateNumber,
                    icon: Icons.confirmation_number_outlined,
                    accent: AdminFormTheme.driver.secondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;

    if (routeFromCtrl.text.trim().isEmpty ||
        routeThroughCtrl.text.trim().isEmpty ||
        routeToCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.transportRouteRequired)),
      );
      return;
    }
    if (plateCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.transportPlateRequired)),
      );
      return;
    }
    if (busCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.busNumberRequired)),
      );
      return;
    }

    final updated = driver.copyWith(
      fullName: nameCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
      email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
      busNumber: DriverRegistryService.normalizeBusNumber(busCtrl.text),
      routeName: DriverRegistryService.formatRoute(
        routeFromCtrl.text,
        routeToCtrl.text,
        through: routeThroughCtrl.text,
      ),
      plateNumber: plateCtrl.text.trim().toUpperCase(),
    );
    DriverRegistryService.instance.updateDriver(updated);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.driverUpdated)),
    );
  }

  Future<void> _deactivateDriver(AdminDriverRecord driver) async {
    final confirmed = await showAdminConfirmDialog(
      context: context,
      title: s.deactivateDriver,
      message: s.confirmDeactivateDriver,
      accent: AdminFormTheme.driver.primary,
      icon: Icons.person_off_outlined,
      confirmLabel: s.deactivateDriver,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    if (DriverRegistryService.instance.deactivateDriver(driver.driverId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.driverDeactivated)),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = _driver;
    if (driver == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.driverProfile)),
        body: Center(child: Text(s.driverNotFound)),
      );
    }

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: StaffPalette.transport.primary.withValues(alpha: 0.04),
          appBar: AppBar(
            backgroundColor: StaffPalette.transport.primary,
            foregroundColor: Colors.white,
            title: Text(driver.fullName),
          ),
          body: ListView(
            padding: listPagePadding(context),
            children: [
              AdminProfilePhotoHeader(
                palette: StaffPalette.transport,
                name: driver.fullName,
                staffId: driver.driverId,
                subtitleLines: [driver.busId, driver.busNumber, driver.routeName],
                onChangePhoto: () => _changePhoto(driver),
                avatar: StaffRegistryAvatar(
                  staffId: driver.driverId,
                  name: driver.fullName,
                  radius: 44,
                  isDriver: true,
                  fallbackColor: StaffPalette.transport.primary,
                ),
              ),
              const SizedBox(height: 16),
              StaffInfoTile(
                icon: Icons.badge_rounded,
                label: s.schoolTransportId,
                value: driver.driverId,
                color: StaffPalette.transport.primary,
              ),
              const SizedBox(height: 8),
              StaffInfoTile(
                icon: Icons.qr_code_2_rounded,
                label: s.busLinkId,
                value: driver.busId,
                color: StaffPalette.transport.primary,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  s.savedLoginDetails,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: StaffPalette.transport.primary.withValues(alpha: 0.85),
                  ),
                ),
              ),
              StaffInfoTile(
                icon: Icons.person_rounded,
                label: s.loginUsername,
                value: DriverCredentialsService.instance.loginFor(driver),
                color: StaffPalette.transport.primary,
              ),
              StaffInfoTile(
                icon: Icons.lock_rounded,
                label: s.tempPassword,
                value: DriverCredentialsService.instance.passwordFor(driver),
                color: Colors.amber.shade800,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text(
                  s.driverCredentialsSaved,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.35,
                  ),
                ),
              ),
              StaffInfoTile(
                icon: Icons.confirmation_number_rounded,
                label: s.plateNumber,
                value: driver.plateNumber,
                color: StaffPalette.transport.primary,
              ),
              StaffInfoTile(
                icon: Icons.route_rounded,
                label: s.routeName,
                value: driver.routeName,
                color: StaffPalette.transport.secondary,
              ),
              StaffInfoTile(
                icon: Icons.phone_rounded,
                label: s.phoneNumber,
                value: driver.phone ?? '—',
                color: Colors.green,
              ),
              StaffInfoTile(
                icon: Icons.email_rounded,
                label: s.email,
                value: driver.email ?? '—',
                color: Colors.blue,
              ),
              const SizedBox(height: 8),
              StaffActionGrid(
                actions: [
                  StaffActionItem(
                    icon: Icons.key_rounded,
                    label: s.sendLoginToDriver,
                    color: StaffPalette.transport.primary,
                    onPressed: () => showSendDriverCredentials(context, driver),
                  ),
                  StaffActionItem(
                    icon: Icons.message_rounded,
                    label: s.messageInternally,
                    color: Colors.orange,
                    onPressed: () => openAdminChat(
                      context,
                      name: driver.fullName,
                      role: 'Driver',
                      staffParticipantId:
                          StaffMemberOption.driverKey(driver.driverId),
                    ),
                  ),
                  StaffActionItem(
                    icon: Icons.phone_rounded,
                    label: s.callContact,
                    color: Colors.green,
                    onPressed: () {
                      if (driver.phone == null ||
                          driver.phone!.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.noPhoneOnFile)),
                        );
                        return;
                      }
                      PhoneLaunchService.instance.dial(driver.phone!);
                    },
                  ),
                  StaffActionItem(
                    icon: Icons.camera_alt_rounded,
                    label: s.changeProfilePhoto,
                    color: StaffPalette.transport.primary,
                    onPressed: () => _changePhoto(driver),
                  ),
                  StaffActionItem(
                    icon: Icons.swap_horiz_rounded,
                    label: s.transferBusToBus,
                    color: Colors.indigo,
                    onPressed: () => openDriverBusTransfer(
                      context,
                      fromDriverId: driver.driverId,
                    ),
                  ),
                  StaffActionItem(
                    icon: Icons.edit_rounded,
                    label: s.editDriver,
                    color: Colors.blue,
                    onPressed: () => _editDriver(driver),
                  ),
                  StaffActionItem(
                    icon: Icons.person_off_rounded,
                    label: s.deactivateDriver,
                    color: Colors.red,
                    onPressed: () => _deactivateDriver(driver),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
