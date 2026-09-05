import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mayabela/database/school_database_service.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/utils/auth_navigation.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_photo_service.dart';
import 'package:mayabela/services/student_account_service.dart';
import 'package:mayabela/services/student_credentials_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_photo_service.dart';
import 'package:mayabela/services/persistence/student_persistence_service.dart';
import 'package:mayabela/services/persistence/teacher_persistence_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/utils/phone_utils.dart';
import 'package:mayabela/utils/text_input_formatters.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/student_medical_info_panel.dart';
import 'package:mayabela/widgets/phone_contact_field.dart';
import 'package:mayabela/widgets/school_branding_header.dart';
import 'package:mayabela/widgets/admin_student_qr_actions.dart';
import 'package:mayabela/widgets/send_student_parent_invites.dart';
import 'package:mayabela/widgets/student_qr_card.dart';
import 'package:mayabela/widgets/send_teacher_credentials.dart';
import 'package:mayabela/widgets/staff_role_picker_table.dart';
import 'package:mayabela/widgets/transport_driver_field.dart';
import 'package:mayabela/services/cloud/session_cloud_sync.dart';
import 'package:mayabela/screens/parent_dashboard.dart';
import 'package:mayabela/web_erp/shell/web_erp_navigation_scope.dart';

/// Ensures a live school JWT before staff/teacher create. Recovers quietly
/// via refresh; if that fails, asks for the Admin password once (no sign-out).
Future<bool> ensureCloudSessionForStaffWrite(BuildContext context) async {
  if (await SchoolAuthCloudService.instance.ensureValidSchoolJwt()) {
    return true;
  }
  if (!context.mounted) return false;
  final password = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final controller = TextEditingController();
      return AlertDialog(
        title: const Text('Confirm your password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your cloud session needs a quick refresh. Enter your login '
              'password to continue — you do not need to sign out.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Continue'),
          ),
        ],
      );
    },
  );
  if (password == null || password.trim().isEmpty) return false;
  final ok = await SchoolAuthCloudService.instance
      .reauthenticateWithPassword(password);
  return ok;
}

bool isRetriableOfflineCloudError(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('cloud not available') ||
      s.contains('school cloud sign-in') ||
      s.contains('timeout') ||
      s.contains('socket') ||
      s.contains('failed host lookup') ||
      s.contains('network') ||
      s.contains('connection') ||
      s.contains('offline') ||
      s.contains('row-level security') ||
      s.contains('could not sync') ||
      s.contains('queued');
}

class ParentPendingScreen extends StatefulWidget {
  const ParentPendingScreen({super.key});

  @override
  State<ParentPendingScreen> createState() => _ParentPendingScreenState();
}

class _ParentPendingScreenState extends State<ParentPendingScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshFromCloud();
  }

  Future<void> _refreshFromCloud() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await SessionCloudSync.awaitRoleCloudSync();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _refreshing = false);
    if (AuthService.isParentAccessApproved()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ParentDashboard()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppLocale.instance,
        AuthService.sessionListenable,
      ]),
      builder: (context, _) {
        if (AuthService.isParentAccessApproved()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ParentDashboard()),
            );
          });
        }

        final user = AuthService.currentUser!;
        final links =
            EnrollmentService.instance.sortedLinksForParent(user.username);
        final hasPending =
            links.any((l) => l.status == ParentLinkStatus.pending);
        final s = AppLocale.instance.strings;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.teal,
            title: Text(s.pendingApproval),
            actions: [
              IconButton(
                icon: _refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
                onPressed: _refreshing ? null : _refreshFromCloud,
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => AuthNavigation.performLogout(),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: listPagePadding(context, horizontal: 24, top: 24),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: listPagePadding(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade700, Colors.teal.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SchoolBrandingHeader(
                    schoolId: AuthService.activeSchoolId,
                    compact: true,
                  ),
                ),
                const SizedBox(height: 24),
                Icon(Icons.hourglass_top, size: 72, color: Colors.orange.shade700),
                const SizedBox(height: 16),
                Text(
                  s.pendingApprovalTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  s.pendingApprovalBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 24),
                if (hasPending)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.pendingApprovalBody,
                            style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ...links.map((link) {
                  final student =
                      StudentRegistryService.instance.lookupById(link.studentId);
                  final isApproved = link.status == ParentLinkStatus.approved;
                  final isPending = link.status == ParentLinkStatus.pending;
                  return Card(
                    elevation: isPending ? 3 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isApproved
                            ? Colors.green.shade300
                            : isPending
                                ? Colors.orange.shade200
                                : Colors.red.shade200,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        _statusIcon(link.status),
                        color: _statusColor(link.status),
                        size: 32,
                      ),
                      title: Text(student?.fullName ?? link.studentId),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s.relationshipLabel(link.relationship)} · ${link.studentId}',
                          ),
                          const SizedBox(height: 6),
                          adminStatusChip(
                            label: s.linkStatus(link.status),
                            color: _statusColor(link.status),
                            icon: _statusIcon(link.status),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _statusIcon(ParentLinkStatus status) {
    return switch (status) {
      ParentLinkStatus.approved => Icons.check_circle,
      ParentLinkStatus.rejected => Icons.cancel,
      ParentLinkStatus.pending => Icons.schedule,
    };
  }

  Color _statusColor(ParentLinkStatus status) {
    return switch (status) {
      ParentLinkStatus.approved => Colors.green,
      ParentLinkStatus.rejected => Colors.red,
      ParentLinkStatus.pending => Colors.orange,
    };
  }
}

class ParentApprovalsScreen extends StatefulWidget {
  const ParentApprovalsScreen({super.key});

  @override
  State<ParentApprovalsScreen> createState() => _ParentApprovalsScreenState();
}

class _ParentApprovalsScreenState extends State<ParentApprovalsScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshFromCloud());
    });
  }

  Future<void> _refreshFromCloud() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await SessionCloudSync.awaitRoleCloudSync();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final queue = EnrollmentService.instance.approvalQueueForCurrentUser();
        final pendingCount =
            queue.where((l) => l.status == ParentLinkStatus.pending).length;
        final reviewer = AuthService.displayNameForRole(
          AuthService.currentUser?.roleKey ?? AuthService.roleAdmin,
        );

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.indigo,
            title: Text(s.parentApprovals),
            actions: [
              IconButton(
                tooltip: s.tryAgain,
                onPressed: _busy ? null : _refreshFromCloud,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
              ),
              if (pendingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pendingCount ${s.pendingApproval}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: _busy && queue.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : queue.isEmpty
              ? Center(child: Text(s.noApprovalRequests))
              : ListView.separated(
                  padding: listPagePadding(context),
                  itemCount: queue.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final link = queue[index];
                    final student = StudentRegistryService.instance
                        .lookupById(link.studentId);
                    final isPending = link.status == ParentLinkStatus.pending;
                    final isApproved = link.status == ParentLinkStatus.approved;
                    final borderColor = isPending
                        ? Colors.orange.shade300
                        : isApproved
                            ? Colors.green.shade300
                            : Colors.red.shade300;

                    return Card(
                      elevation: isPending ? 4 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: borderColor, width: isPending ? 2 : 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    link.parentFullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                adminStatusChip(
                                  label: s.linkStatus(link.status),
                                  color: _approvalStatusColor(link.status),
                                  icon: _approvalStatusIcon(link.status),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('${s.studentId}: ${link.studentId}'),
                            if (student != null)
                              Text('${student.fullName} · ${student.className}'),
                            Text(
                              '${s.relationshipLabel(link.relationship)} · ${s.schoolId}: ${link.schoolId}',
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.studentMedicalSection,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            StudentMedicalInfoPanel(
                              hasMedicalCondition: link.hasMedicalCondition,
                              medicalConditionDetails: link.medicalConditionDetails,
                              otherMedicalInfo: link.otherMedicalInfo,
                              compact: true,
                            ),
                            if (link.reviewedBy != null && !isPending) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${s.approvedStatus}: ${link.reviewedBy}',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (isPending &&
                                EnrollmentService.instance
                                    .canCurrentUserManageParentLink(link)) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await EnrollmentService.instance
                                            .rejectLink(link.id, reviewer);
                                        if (!context.mounted) return;
                                        setState(() {});
                                      },
                                      child: Text(s.reject),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        await EnrollmentService.instance
                                            .approveLink(link.id, reviewer);
                                        if (!context.mounted) return;
                                        setState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(s.parentApproved),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: Text(s.approve),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  IconData _approvalStatusIcon(ParentLinkStatus status) {
    return switch (status) {
      ParentLinkStatus.approved => Icons.check_circle,
      ParentLinkStatus.rejected => Icons.cancel,
      ParentLinkStatus.pending => Icons.schedule,
    };
  }

  Color _approvalStatusColor(ParentLinkStatus status) {
    return switch (status) {
      ParentLinkStatus.approved => Colors.green,
      ParentLinkStatus.rejected => Colors.red,
      ParentLinkStatus.pending => Colors.orange,
    };
  }
}

class AdminAddTeacherScreen extends StatefulWidget {
  /// [administrationStaff] requires a staff role; [classroomTeacher] creates a
  /// plain teacher account with no staffRoles (classroom login tile).
  const AdminAddTeacherScreen({
    super.key,
    this.kind = AdminPersonKind.administrationStaff,
  });

  final AdminPersonKind kind;

  @override
  State<AdminAddTeacherScreen> createState() => _AdminAddTeacherScreenState();
}

enum AdminPersonKind {
  administrationStaff,
  classroomTeacher,
}

class _AdminAddTeacherScreenState extends State<AdminAddTeacherScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _employeeId = TextEditingController();
  String? _selectedCampus;
  File? _pickedPhoto;
  bool _saving = false;
  final Set<String> _selectedRoles = {};

  AppStrings get s => AppLocale.instance.strings;
  bool get _isStaff => widget.kind == AdminPersonKind.administrationStaff;

  bool _isRetriableOfflineCloudError(Object e) =>
      isRetriableOfflineCloudError(e);

  @override
  void initState() {
    super.initState();
    unawaited(SchoolRoleCatalogService.instance.ensureLoaded());
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _employeeId.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await TeacherPhotoService.instance.pickFromGallery();
    if (file != null) setState(() => _pickedPhoto = file);
  }

  List<StaffRole> get _assignableRoles {
    final roles =
        SchoolRoleCatalogService.instance.rolesForAssign().where((r) {
      if (r.ownerOnly && !AuthService.canAssignFullAccess) return false;
      return true;
    }).toList();
    return roles;
  }

  Future<void> _save() async {
    if (_saving) return;
    final schoolId = AuthService.activeSchoolId;
    if (schoolId == null) return;

    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.enterName)),
      );
      return;
    }

    if (!PhoneUtils.isValidLoginPhone(_phone.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.invalidPhone)),
      );
      return;
    }

    final loginKey = PhoneUtils.loginKey(_phone.text.trim());
    final phoneStatus = await AuthService.preparePhoneForStaffRegistration(
      loginKey,
      schoolId: schoolId,
    );
    if (phoneStatus == 'exists') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.phoneAlreadyRegistered)),
      );
      return;
    }
    if (phoneStatus == 'invalid_phone') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.invalidPhone)),
      );
      return;
    }

    if (_isStaff && _selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one staff role for this person.'),
        ),
      );
      return;
    }

    // Heal cloud JWT before creating local rows so first-try create succeeds.
    final cloudReady = await ensureCloudSessionForStaffWrite(context);
    if (!cloudReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not refresh cloud session. Check your Admin password and try again.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    // Unique temp per account; first login forces a password change (no OTP).
    final tempPassword = AuthService.generateTempPassword();

    var teacher = TeacherRegistryService.instance.addTeacher(
      schoolId: schoolId,
      fullName: _name.text,
      email: _email.text,
      phone: _phone.text,
      employeeId:
          _employeeId.text.trim().isEmpty ? null : _employeeId.text.trim(),
      subjects: const [],
      assignedClass: '',
      roles: const [],
      loginUsername: loginKey,
      initialPassword: tempPassword,
      classAssignments: const [],
      campus: _selectedCampus,
      // Role initials drive the short 4-digit id (QA-0001, HR-0001, …).
      staffRoles: _isStaff ? _selectedRoles.toList() : const [],
    );
    final createdTeacherId = teacher.teacherId;
    var loginCreated = false;

    try {
      if (_pickedPhoto != null) {
        final path = await TeacherPhotoService.instance.saveForTeacher(
          teacher.teacherId,
          _pickedPhoto!,
        );
        if (path != null) {
          TeacherPhotoService.instance.rememberPath(teacher.teacherId, path);
          TeacherRegistryService.instance.updatePhoto(teacher.teacherId, path);
          teacher =
              TeacherRegistryService.instance.lookupById(teacher.teacherId)!;
        }
      }

      final authError = AuthService.registerTeacherAccount(
        fullName: _name.text,
        schoolId: schoolId,
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        linkedTeacherId: teacher.teacherId,
        password: tempPassword,
      );

      if (authError != null) {
        TeacherRegistryService.instance.removeTeacher(createdTeacherId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authError == 'invalid_phone'
                  ? s.invalidPhone
                  : s.phoneAlreadyRegistered,
            ),
          ),
        );
        return;
      }
      loginCreated = true;

      TeacherRegistryService.instance.saveCredentials(
        teacherId: teacher.teacherId,
        initialPassword: tempPassword,
        loginUsername: loginKey,
      );
      teacher =
          TeacherRegistryService.instance.lookupById(teacher.teacherId)!;

      // Owner enrollment: identity + RBAC only. Class/subject wiring is done
      // later by Section Director (assignTeachers), not here.
      AuthService.syncTeacherAuthProfile(teacher);

      final roleKeys = _isStaff ? _selectedRoles.toList() : <String>[];
      final rolePermissions = roleKeys.isEmpty
          ? <String>[]
          : (SchoolRoleCatalogService.instance
              .permissionsForRoles(roleKeys, schoolId: schoolId)
              .toList()
            ..sort());

      final account = AuthService.findUser(loginKey);
      if (account == null) {
        TeacherRegistryService.instance.removeTeacher(createdTeacherId);
        await AuthService.revokeRegisteredAccount(loginKey);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.registrationFailed),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      account.password = tempPassword;
      account.mustChangePassword = true;
      account.staffRoles = List<String>.from(roleKeys);
      account.staffPermissions = List<String>.from(rolePermissions);

      TeacherRegistryService.instance.updateTeacher(
        teacher.copyWith(staffRoles: roleKeys),
      );
      teacher =
          TeacherRegistryService.instance.lookupById(teacher.teacherId)!;

      // Immediate cloud write so the account works in any browser without
      // waiting for the post-login sync chip. Also writes teacher_registry
      // via service role so staff directory sync cannot fail on client RLS.
      final cloudUser = RegisteredUser(
        username: account.username,
        password: tempPassword,
        roleKey: account.roleKey,
        email: account.email,
        phone: account.phone,
        schoolId: schoolId,
        fullName: account.fullName,
        linkedStudentIds: account.linkedStudentIds,
        linkedTeacherId: account.linkedTeacherId,
        linkedAdminId: account.linkedAdminId,
        linkedDriverId: account.linkedDriverId,
        linkedStudentId: account.linkedStudentId,
        mustChangePassword: account.mustChangePassword,
        staffRoles: roleKeys,
        staffPermissions: rolePermissions,
      );
      var cloud = await SchoolAuthCloudService.instance.upsertAccount(
        user: cloudUser,
        password: tempPassword,
        staffRoles: roleKeys,
        staffPermissions: rolePermissions,
        teacherRecord: teacher.toMap(),
      );
      if (!cloud.ok &&
          (cloud.errorCode == 'denied' ||
              (cloud.errorMessage ?? '').toLowerCase().contains('session') ||
              (cloud.errorMessage ?? '').toLowerCase().contains('jwt') ||
              (cloud.errorMessage ?? '').toLowerCase().contains('sign in'))) {
        if (!mounted) return;
        if (await ensureCloudSessionForStaffWrite(context)) {
          cloud = await SchoolAuthCloudService.instance.upsertAccount(
            user: cloudUser,
            password: tempPassword,
            staffRoles: roleKeys,
            staffPermissions: rolePermissions,
            teacherRecord: teacher.toMap(),
          );
        }
      }
      if (!cloud.ok) {
        TeacherRegistryService.instance.removeTeacher(createdTeacherId);
        await AuthService.revokeRegisteredAccount(loginKey);
        if (!mounted) return;
        final detail = cloud.errorMessage?.trim();
        final code = cloud.errorCode ?? 'error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detail != null && detail.isNotEmpty
                  ? detail
                  : code == 'denied'
                      ? 'Cloud rejected this create. Confirm your Admin password when prompted, then try again.'
                      : 'Cloud account could not be created ($code). Try again.',
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      }

      // Always force a client directory write too. If the edge function already
      // wrote teacher_registry, this is a no-op upsert; if it skipped (or RLS
      // blocked an earlier soft push), this is what other browsers need.
      try {
        await TeacherPersistenceService.instance.saveRegistryFromService(
          syncTeacherId: teacher.teacherId,
          pushCloud: true,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Staff directory save failed: $e')),
        );
      }
    } catch (_) {
      TeacherRegistryService.instance.removeTeacher(createdTeacherId);
      if (loginCreated) {
        await AuthService.revokeRegisteredAccount(loginKey);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.registrationFailed)),
      );
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;

    await showAdminSuccessDialog(
      context: context,
      title: _isStaff ? 'Administration staff created' : 'Teacher created',
      subtitle: teacher.fullName,
      accent: AdminFormTheme.teacher.primary,
      icon: Icons.check_circle_outline,
      items: [
        AdminDialogSummaryItem(
          icon: Icons.badge_outlined,
          label: _isStaff ? 'Staff ID' : 'Teacher ID',
          value: teacher.employeeId ?? teacher.teacherId,
        ),
        AdminDialogSummaryItem(
          icon: Icons.phone_android_outlined,
          label: s.loginUsername,
          value: loginKey,
        ),
        AdminDialogSummaryItem(
          icon: Icons.lock_outline,
          label: s.tempPassword,
          value: tempPassword,
        ),
        if (_isStaff)
          AdminDialogSummaryItem(
            icon: Icons.admin_panel_settings_outlined,
            label: s.staffRolesTitle,
            value: staffRolesSummary(teacher.staffRoles, s).isEmpty
                ? _selectedRoles
                    .map((k) => SchoolRoleCatalogService.instance.lookup(k))
                    .whereType<StaffRole>()
                    .map((r) => staffRoleLabel(r, s))
                    .join(', ')
                : staffRolesSummary(teacher.staffRoles, s),
          ),
      ],
      footnote: _isStaff
          ? 'Login as Administration Staff with this phone and temporary password '
              '(${AuthService.tempPassword}). Change it after first sign-in. '
              'They only see modules for their assigned role.'
          : 'Login as Teacher with this phone and temporary password '
              '(${AuthService.tempPassword}). Change it after first sign-in. '
              'Section Director assigns classes and subjects later.',
      actions: [
        AdminDialogAction(
          label: s.sendLoginToTeacher,
          icon: Icons.send_rounded,
          onPressed: () async {
            Navigator.pop(context);
            await showSendTeacherCredentials(context, teacher);
          },
        ),
        AdminDialogAction(
          label: s.done,
          primary: true,
          icon: Icons.check_rounded,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
    if (!mounted) return;
    webErpHandleBack(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final theme = AdminFormTheme.teacher;
        final schoolCampuses = SchoolRegistryService.instance
            .campusesForSchool(AuthService.activeSchoolId);
        final roles = _assignableRoles;
        return AdminFormScaffold(
          title: _isStaff ? 'Add Administration Staff' : 'Add Teacher',
          subtitle: _isStaff
              ? 'Register staff with ID, phone, and role. They sign in as Administration Staff and only see that role’s modules.'
              : 'Register a classroom teacher (no admin role). They sign in as Teacher. Section Director assigns classes later.',
          theme: theme,
          body: [
            AdminPhotoPicker(
              photo: _pickedPhoto,
              hint: s.teacherPhotoHint,
              accent: theme.primary,
              onTap: _pickPhoto,
            ),
            const SizedBox(height: 20),
            AdminFormSection(
              title: 'Registration',
              icon: Icons.badge_outlined,
              color: theme.primary,
              children: [
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: nameInputFormatters,
                  decoration: adminFieldDecoration(
                    label: s.fullName,
                    icon: Icons.person,
                    accent: theme.primary,
                  ),
                ),
                TextField(
                  controller: _employeeId,
                  decoration: adminFieldDecoration(
                    label: _isStaff
                        ? 'Staff ID (optional — auto ID if empty)'
                        : 'Teacher ID (optional — auto ID if empty)',
                    icon: Icons.numbers,
                    accent: theme.primary,
                  ),
                ),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: adminFieldDecoration(
                    label: s.emailOptional,
                    icon: Icons.email_outlined,
                    accent: theme.primary,
                  ),
                ),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: adminFieldDecoration(
                    label: s.phoneNumber,
                    hint: s.phoneLoginHint,
                    icon: Icons.phone,
                    accent: theme.primary,
                  ),
                ),
                if (schoolCampuses.length > 1)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCampus ?? schoolCampuses.first,
                    decoration: adminFieldDecoration(
                      label: s.campus,
                      icon: Icons.location_city_outlined,
                      accent: theme.primary,
                    ),
                    items: schoolCampuses
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCampus = v),
                  ),
              ],
            ),
            if (_isStaff)
              AdminFormSection(
                title: 'Staff roles',
                icon: Icons.admin_panel_settings_outlined,
                color: theme.secondary,
                children: [
                  StaffRolePickerTable(
                    roles: roles,
                    selected: _selectedRoles,
                    multiSelect: true,
                    accent: theme.primary,
                    isRoleEnabled: (role) =>
                        !(role.ownerOnly && !AuthService.canAssignFullAccess),
                    onChanged: (next) => setState(() {
                      _selectedRoles
                        ..clear()
                        ..addAll(next);
                    }),
                  ),
                ],
              ),
            adminPrimaryButton(
              label:
                  _isStaff ? 'Create staff account' : 'Create teacher account',
              color: theme.primary,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        );
      },
    );
  }
}

class AdminAddStudentScreen extends StatefulWidget {
  const AdminAddStudentScreen({super.key});

  @override
  State<AdminAddStudentScreen> createState() => _AdminAddStudentScreenState();
}

class _AdminAddStudentScreenState extends State<AdminAddStudentScreen> {
  final _name = TextEditingController();
  final _fatherName = TextEditingController();
  final _fatherPhone = TextEditingController();
  final _motherName = TextEditingController();
  final _motherPhone = TextEditingController();
  final _guardianName = TextEditingController();
  final _guardianPhone = TextEditingController();
  final _emergencyName1 = TextEditingController();
  final _emergencyPhone1 = TextEditingController();
  final _emergencyName2 = TextEditingController();
  final _emergencyPhone2 = TextEditingController();
  final _dob = TextEditingController();
  String? _selectedGrade;
  String? _selectedCampus;
  final _section = TextEditingController();
  final _homeroomTeacherId = TextEditingController();
  final _academicYear = TextEditingController(text: '2025/2026');
  final _transportId = TextEditingController();
  bool _transport = false;
  String? _selectedGender;
  Uint8List? _pickedPhotoBytes;
  bool _saving = false;
  AdminTeacherRecord? _homeroomTeacher;
  String? _homeroomLookupMessage;
  bool _homeroomLookupOk = false;

  bool _isRetriableOfflineCloudError(Object e) =>
      isRetriableOfflineCloudError(e);

  static const _genders = ['Male', 'Female'];

  AppStrings get s => AppLocale.instance.strings;

  @override
  void dispose() {
    _name.dispose();
    _fatherName.dispose();
    _fatherPhone.dispose();
    _motherName.dispose();
    _motherPhone.dispose();
    _guardianName.dispose();
    _guardianPhone.dispose();
    _emergencyName1.dispose();
    _emergencyPhone1.dispose();
    _emergencyName2.dispose();
    _emergencyPhone2.dispose();
    _dob.dispose();
    _section.dispose();
    _homeroomTeacherId.dispose();
    _academicYear.dispose();
    _transportId.dispose();
    super.dispose();
  }

  List<PhoneDialOption> _allDialOptions({String? excludeController}) {
    final options = <PhoneDialOption>[];
    void add(String label, TextEditingController c) {
      if (c.text.trim().isEmpty) return;
      if (excludeController != null && c.text == excludeController) return;
      options.add(PhoneDialOption(label: label, phone: c.text.trim()));
    }

    add(s.fatherPhone, _fatherPhone);
    add(s.motherPhone, _motherPhone);
    add(s.guardianPhoneOptional, _guardianPhone);
    add(s.emergencyPhone, _emergencyPhone1);
    add(s.emergencyPhone, _emergencyPhone2);
    return options;
  }

  List<PhoneDialOption> _fallbackFor(TextEditingController self, String label) {
    return _allDialOptions()
        .where((o) => o.phone != self.text.trim())
        .toList();
  }

  Future<void> _pickPhoto() async {
    final bytes = await StudentPhotoService.instance.pickBytes();
    if (bytes != null) setState(() => _pickedPhotoBytes = bytes);
  }

  void _lookupHomeroomTeacher() {
    final schoolId = AuthService.activeSchoolId;
    final id = _homeroomTeacherId.text.trim();
    if (id.isEmpty) {
      setState(() {
        _homeroomTeacher = null;
        _homeroomLookupMessage = null;
        _homeroomLookupOk = false;
      });
      return;
    }

    final teacher = TeacherRegistryService.instance.lookupById(id);
    if (teacher == null ||
        (schoolId != null &&
            teacher.schoolId.toUpperCase() != schoolId.toUpperCase())) {
      setState(() {
        _homeroomTeacher = null;
        _homeroomLookupMessage = s.teacherNotFoundForSchool;
        _homeroomLookupOk = false;
      });
      return;
    }

    setState(() {
      _homeroomTeacher = teacher;
      _homeroomLookupMessage = teacher.fullName;
      _homeroomLookupOk = true;
    });
  }

  void _refreshHomeroomForClass() {
    if (_selectedGrade == null || _section.text.trim().isEmpty) {
      setState(() {
        _homeroomTeacher = null;
        _homeroomTeacherId.clear();
        _homeroomLookupMessage = null;
        _homeroomLookupOk = false;
      });
      return;
    }

    final grade = _selectedGrade!;
    final section = _section.text.trim();
    final className =
        ClassStructureService.instance.classNameFor(grade, section);
    final teachers =
        ClassStructureService.instance.teachersForSection(grade, section);
    ClassTeacherInfo? homeroom;
    for (final entry in teachers) {
      if (entry.isHomeroom) {
        homeroom = entry;
        break;
      }
    }

    if (homeroom != null) {
      final resolved = homeroom;
      setState(() {
        _homeroomTeacher = resolved.teacher;
        _homeroomTeacherId.text = resolved.teacher.teacherId;
        _homeroomLookupMessage = resolved.teacher.fullName;
        _homeroomLookupOk = true;
      });
      return;
    }

    final fallbackId =
        SchoolDataService.instance.homeroomTeacherIdForClass(className);
    if (fallbackId != null) {
      final teacher = TeacherRegistryService.instance.lookupById(fallbackId);
      if (teacher != null) {
        setState(() {
          _homeroomTeacher = teacher;
          _homeroomTeacherId.text = teacher.teacherId;
          _homeroomLookupMessage = teacher.fullName;
          _homeroomLookupOk = true;
        });
        return;
      }
    }

    setState(() {
      _homeroomTeacher = null;
      _homeroomTeacherId.clear();
      _homeroomLookupMessage = s.noHomeroomTeacherForClass;
      _homeroomLookupOk = false;
    });
  }

  DateTime? _parseDob(String raw) {
    final parts = raw.trim().split('/');
    if (parts.length != 3) return null;
    try {
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final schoolId = AuthService.activeSchoolId;
    if (schoolId == null) return;

    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.enterName)),
      );
      return;
    }
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.selectGender)),
      );
      return;
    }
    if (_selectedGrade == null || _selectedGrade!.trim().isEmpty ||
        _section.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.gradeSectionRequired)),
      );
      return;
    }

    final schoolGrades = ClassStructureService.instance.gradesForSchool();
    if (schoolGrades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noGradesConfigured)),
      );
      return;
    }

    if (_homeroomTeacherId.text.trim().isNotEmpty && !_homeroomLookupOk) {
      _lookupHomeroomTeacher();
      if (!_homeroomLookupOk) return;
    }

    final dob = _parseDob(_dob.text);
    if (dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.invalidDateFormat)),
      );
      return;
    }

    setState(() => _saving = true);

    final grade = _selectedGrade!.trim();
    await ClassStructureService.instance.ensureSectionForGrade(
      grade,
      _section.text.trim(),
    );

    final className = StudentRegistryService.buildClassName(
      grade,
      _section.text,
    );

    var homeroomTeacherId = _homeroomTeacher?.teacherId;
    homeroomTeacherId ??=
        SchoolDataService.instance.homeroomTeacherIdForClass(className);

    final transportIdRaw = _transport ? _transportId.text.trim() : '';
    if (_transport && transportIdRaw.isNotEmpty) {
      final transportError = ParentInviteService.instance.validateTransportId(
        transportIdRaw,
        schoolId: schoolId,
      );
      if (transportError != null) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              transportError == 'wrong_school'
                  ? s.transportIdWrongSchool
                  : s.transportBusNotRegisteredWithId(
                      transportIdRaw.toUpperCase(),
                    ),
            ),
          ),
        );
        return;
      }
    }

    var student = StudentRegistryService.instance.addStudent(
      schoolId: schoolId,
      fullName: _name.text,
      grade: grade,
      className: className,
      dateOfBirth: dob,
      gender: _selectedGender,
      fatherName: _fatherName.text,
      fatherPhone: _fatherPhone.text,
      motherName: _motherName.text,
      motherPhone: _motherPhone.text,
      guardianName: _guardianName.text,
      guardianPhone: _guardianPhone.text,
      emergencyPhone1: _emergencyPhone1.text,
      emergencyContact1Name: _emergencyName1.text,
      emergencyPhone2: _emergencyPhone2.text,
      emergencyContact2Name: _emergencyName2.text,
      homeroomTeacherId: homeroomTeacherId,
      academicYear: _academicYear.text.trim(),
      transportEnabled: _transport,
      transportId: transportIdRaw.isEmpty ? null : transportIdRaw,
      campus: _selectedCampus,
    );
    final createdStudentId = student.studentId;

    try {
      if (_pickedPhotoBytes != null) {
        final path = await StudentPhotoService.instance.saveBytesForStudent(
          student.studentId,
          _pickedPhotoBytes!,
        );
        if (path != null) {
          StudentPhotoService.instance.rememberPath(student.studentId, path);
          StudentRegistryService.instance.updatePhoto(
            student.studentId,
            path,
            persist: false,
          );
          student = StudentRegistryService.instance.lookupById(student.studentId)!;
        }
      }

      SchoolDataService.instance.syncChildFromRegistry(student.studentId);
      if (SchoolDatabaseService.instance.isInitialized) {
        await SchoolDatabaseService.instance
            .syncStudentFromRegistry(student.studentId)
            .timeout(const Duration(seconds: 10));
      }
      // Save locally, then upload this student to cloud immediately on Save
      // (do not wait for Ready / login sync / outbox flush).
      await StudentPersistenceService.instance.saveRegistryFromService(
        syncStudentId: createdStudentId,
        pushCloud: true,
        requireCloudSuccess: false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save student: $e')),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;

    var portalStudent = student;
    if (StudentAccountService.instance.isEligibleGrade(
      gradeLabel: grade,
      schoolId: schoolId,
    )) {
      final withPortal = await StudentAccountService.instance.createPortalAccount(
        studentId: createdStudentId,
        createdBy: AuthService.currentUser?.username ?? 'admin',
        schoolId: schoolId,
      );
      if (withPortal != null) portalStudent = withPortal;
    }

    final summaryItems = <AdminDialogSummaryItem>[
      AdminDialogSummaryItem(
        icon: Icons.badge_outlined,
        label: s.studentId,
        value: student.studentId,
      ),
      AdminDialogSummaryItem(
        icon: Icons.person_outline,
        label: s.fullName,
        value: student.fullName,
      ),
      AdminDialogSummaryItem(
        icon: Icons.class_outlined,
        label: s.section,
        value: className,
      ),
    ];
    if (_homeroomTeacher != null) {
      summaryItems.add(
        AdminDialogSummaryItem(
          icon: Icons.school_outlined,
          label: s.homeroomTeacher,
          value: _homeroomTeacher!.fullName,
        ),
      );
    }
    if (student.transportEnabled) {
      summaryItems.add(
        AdminDialogSummaryItem(
          icon: Icons.directions_bus_outlined,
          label: s.busLinkId,
          value: student.transportId?.isNotEmpty == true
              ? student.transportId!
              : s.transportNotWired,
        ),
      );
    }
    if (portalStudent.loginUsername != null) {
      summaryItems.add(
        AdminDialogSummaryItem(
          icon: Icons.account_circle_outlined,
          label: 'Portal username',
          value: portalStudent.loginUsername!,
        ),
      );
      summaryItems.add(
        AdminDialogSummaryItem(
          icon: Icons.lock_outline,
          label: 'Temp password',
          value: StudentAccountService.instance.passwordForShare(portalStudent),
        ),
      );
    }

    if (!mounted) return;
    final qrProfile = qrProfileForStudent(student);
    await showAdminSuccessDialog(
      context: context,
      title: s.studentEnrolled,
      subtitle: portalStudent.fullName,
      accent: AdminFormTheme.student.primary,
      icon: Icons.check_circle_outline,
      items: summaryItems,
      extra: StudentQrCard(profile: qrProfile, size: 160),
      footnote: s.studentQrUsageHint,
      actions: [
        if (portalStudent.loginUsername != null)
          AdminDialogAction(
            label: 'Share portal login',
            icon: Icons.share_outlined,
            onPressed: () async {
              Navigator.pop(context);
              await StudentCredentialsService.instance.share(portalStudent);
            },
          ),
        AdminDialogAction(
          label: s.generateStudentQr,
          icon: Icons.qr_code_2,
          onPressed: () {
            showAdminStudentQrSheet(context, student: student);
          },
        ),
        AdminDialogAction(
          label: s.sendInviteToContacts,
          icon: Icons.mail_outline,
          onPressed: () async {
            Navigator.pop(context);
            await showSendStudentParentInvites(context, student);
          },
        ),
        AdminDialogAction(
          label: s.done,
          primary: true,
          icon: Icons.check_rounded,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
    if (!mounted) return;
    webErpHandleBack(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final theme = AdminFormTheme.student;
        final schoolGrades = ClassStructureService.instance.gradesForSchool();
        final schoolCampuses = SchoolRegistryService.instance
            .campusesForSchool(AuthService.activeSchoolId);
        final existingSections = _selectedGrade == null
            ? <String>[]
            : ClassStructureService.instance
                .sectionsForGrade(_selectedGrade!);
        return AdminFormScaffold(
          title: s.addStudent,
          subtitle: s.enrollStudent,
          theme: theme,
          body: [
            AdminPhotoPicker(
              photoBytes: _pickedPhotoBytes,
              hint: s.studentPhotoHint,
              accent: theme.primary,
              onTap: _pickPhoto,
            ),
            const SizedBox(height: 20),
            AdminFormSection(
              title: s.fullName,
              icon: Icons.person_outline,
              color: theme.primary,
              children: [
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: nameInputFormatters,
                  decoration: adminFieldDecoration(
                    label: s.fullName,
                    icon: Icons.badge_outlined,
                    accent: theme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedGender),
                  initialValue: _selectedGender,
                  decoration: adminFieldDecoration(
                    label: s.gender,
                    icon: Icons.wc_outlined,
                    accent: theme.primary,
                  ),
                  items: _genders
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text(g == 'Male' ? s.genderMale : s.genderFemale),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedGender = v),
                ),
              ],
            ),
            AdminFormSection(
              title: s.fatherDetails,
              icon: Icons.man_outlined,
              color: const Color(0xFF1565C0),
              children: [
                TextField(
                  controller: _fatherName,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: nameInputFormatters,
                  decoration: adminFieldDecoration(
                    label: s.fatherName,
                    icon: Icons.person,
                    accent: const Color(0xFF1565C0),
                  ),
                ),
                PhoneContactField(
                  controller: _fatherPhone,
                  label: s.fatherPhone,
                  hint: s.phoneLoginHint,
                  fallbackNumbers: _fallbackFor(_fatherPhone, s.fatherPhone),
                ),
              ],
            ),
            AdminFormSection(
              title: s.motherDetails,
              icon: Icons.woman_outlined,
              color: const Color(0xFFAD1457),
              children: [
                TextField(
                  controller: _motherName,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: nameInputFormatters,
                  decoration: adminFieldDecoration(
                    label: s.motherName,
                    icon: Icons.person,
                    accent: const Color(0xFFAD1457),
                  ),
                ),
                PhoneContactField(
                  controller: _motherPhone,
                  label: s.motherPhone,
                  hint: s.phoneLoginHint,
                  fallbackNumbers: _fallbackFor(_motherPhone, s.motherPhone),
                ),
              ],
            ),
            AdminFormSection(
              title: s.guardianDetailsOptional,
              icon: Icons.family_restroom_outlined,
              color: const Color(0xFF6A1B9A),
              children: [
                TextField(
                  controller: _guardianName,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: nameInputFormatters,
                  decoration: adminFieldDecoration(
                    label: s.guardianNameOptional,
                    icon: Icons.person_outline,
                    accent: const Color(0xFF6A1B9A),
                  ),
                ),
                PhoneContactField(
                  controller: _guardianPhone,
                  label: s.guardianPhoneOptional,
                  hint: s.phoneLoginHint,
                  fallbackNumbers: _fallbackFor(_guardianPhone, s.guardianPhoneOptional),
                ),
              ],
            ),
            AdminFormSection(
              title: s.emergencyContactsSection,
              icon: Icons.contact_emergency_outlined,
              color: const Color(0xFFE65100),
              children: [
                TextField(
                  controller: _emergencyName1,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: nameInputFormatters,
                  decoration: adminFieldDecoration(
                    label: s.emergencyContactName,
                    accent: const Color(0xFFE65100),
                  ),
                ),
                PhoneContactField(
                  controller: _emergencyPhone1,
                  label: s.emergencyPhone,
                  hint: s.phoneLoginHint,
                  fallbackNumbers: _fallbackFor(_emergencyPhone1, s.emergencyPhone),
                ),
                TextField(
                  controller: _emergencyName2,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: nameInputFormatters,
                  decoration: adminFieldDecoration(
                    label: s.emergencyContactName,
                    accent: const Color(0xFFE65100),
                  ),
                ),
                PhoneContactField(
                  controller: _emergencyPhone2,
                  label: s.emergencyPhone,
                  hint: s.phoneLoginHint,
                  fallbackNumbers: _fallbackFor(_emergencyPhone2, s.emergencyPhone),
                ),
              ],
            ),
            AdminFormSection(
              title: s.schoolEnrollmentDetails,
              icon: Icons.school_outlined,
              color: theme.secondary,
              children: [
                if (schoolCampuses.length > 1)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCampus ?? schoolCampuses.first,
                    decoration: adminFieldDecoration(
                      label: s.campus,
                      icon: Icons.location_city_outlined,
                      accent: theme.secondary,
                    ),
                    items: schoolCampuses
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCampus = v),
                  ),
                TextField(
                  controller: _academicYear,
                  decoration: adminFieldDecoration(
                    label: s.academicYear,
                    hint: '2025/2026',
                    icon: Icons.calendar_today_outlined,
                    accent: theme.secondary,
                  ),
                ),
                TextField(
                  controller: _dob,
                  keyboardType: TextInputType.number,
                  inputFormatters: dateSlashFormatters,
                  decoration: adminFieldDecoration(
                    label: s.studentDateOfBirth,
                    hint: s.dateFormatHint,
                    icon: Icons.cake_outlined,
                    accent: theme.secondary,
                  ),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedGrade),
                  initialValue: _selectedGrade != null &&
                          schoolGrades.contains(_selectedGrade)
                      ? _selectedGrade
                      : null,
                  decoration: adminFieldDecoration(
                    label: s.grade,
                    icon: Icons.stairs_outlined,
                    accent: theme.secondary,
                  ),
                  hint: Text(s.selectGrade),
                  items: schoolGrades
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text(g),
                        ),
                      )
                      .toList(),
                  onChanged: schoolGrades.isEmpty
                      ? null
                      : (v) {
                          setState(() => _selectedGrade = v);
                          _refreshHomeroomForClass();
                        },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _section,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => _refreshHomeroomForClass(),
                  decoration: adminFieldDecoration(
                    label: s.section,
                    hint: s.sectionAutoCreateHint,
                    icon: Icons.grid_view_outlined,
                    accent: theme.secondary,
                  ),
                ),
                if (existingSections.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: existingSections
                        .map(
                          (sec) => ActionChip(
                            label: Text(sec),
                            onPressed: () {
                              setState(() => _section.text = sec);
                              _refreshHomeroomForClass();
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: _homeroomTeacherId,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _lookupHomeroomTeacher(),
                  decoration: adminFieldDecoration(
                    label: s.homeroomTeacherId,
                    hint: 'TCH-1001',
                    icon: Icons.person_search_outlined,
                    accent: theme.secondary,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _lookupHomeroomTeacher,
                    icon: const Icon(Icons.search),
                    label: Text(s.lookupTeacher),
                  ),
                ),
                if (_homeroomLookupMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _homeroomLookupOk
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _homeroomLookupOk
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _homeroomLookupOk ? Icons.check_circle : Icons.error_outline,
                          color: _homeroomLookupOk ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_homeroomLookupMessage!)),
                      ],
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.transportEnabled),
                  value: _transport,
                  activeThumbColor: theme.primary,
                  onChanged: (v) => setState(() {
                    _transport = v;
                    if (!v) _transportId.clear();
                  }),
                ),
                if (_transport) ...[
                  const SizedBox(height: 8),
                  TransportDriverField(
                    controller: _transportId,
                    schoolId: AuthService.activeSchoolId,
                    accent: theme.primary,
                  ),
                ],
              ],
            ),
            adminPrimaryButton(
              label: s.enrollStudent,
              color: theme.primary,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        );
      },
    );
  }
}
