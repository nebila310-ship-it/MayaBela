import 'dart:async';

import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/student_persistence_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_portal_audit_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/grade_level_utils.dart';
import 'package:mayabela/utils/student_username_generator.dart';

enum PortalAccessChange { none, granted, restored, revoked }

class PreparedPortalAccess {
  const PreparedPortalAccess(this.student, this.change);

  final AdminStudentRecord student;
  final PortalAccessChange change;
}

class PortalAccessSyncResult {
  const PortalAccessSyncResult({
    this.granted = 0,
    this.restored = 0,
    this.revoked = 0,
  });

  final int granted;
  final int restored;
  final int revoked;

  int get changed => granted + restored + revoked;

  String savedMessage() {
    if (changed == 0) {
      return 'Student portal settings saved. Enrolled students already match this grade.';
    }
    final parts = <String>['Student portal settings saved.'];
    if (granted > 0) {
      parts.add(
        granted == 1
            ? '1 enrolled student received a login.'
            : '$granted enrolled students received a login.',
      );
    }
    if (restored > 0) {
      parts.add(
        restored == 1
            ? '1 student login was turned back on.'
            : '$restored student logins were turned back on.',
      );
    }
    if (revoked > 0) {
      parts.add(
        revoked == 1
            ? '1 student below this grade lost login.'
            : '$revoked students below this grade lost login.',
      );
    }
    return parts.join(' ');
  }
}

class StudentAccountService {
  StudentAccountService._();
  static final instance = StudentAccountService._();

  StudentPortalSettings settingsForSchool(String? schoolId) {
    if (schoolId == null || schoolId.trim().isEmpty) {
      return const StudentPortalSettings();
    }
    final school = SchoolRegistryService.instance.lookup(schoolId);
    return school?.studentPortal ?? const StudentPortalSettings();
  }

  bool isPortalEnabled(String? schoolId) {
    return settingsForSchool(schoolId).enabled;
  }

  bool isEligibleGrade({
    required String? gradeLabel,
    required String? schoolId,
  }) {
    final settings = settingsForSchool(schoolId);
    if (!settings.enabled) return false;
    return isGradeEligibleForStudentPortal(
      gradeLabel: gradeLabel,
      minimumGrade: settings.minimumGrade,
    );
  }

  bool hasPortalAccount(AdminStudentRecord student) {
    return student.portalAccountStatus != StudentAccountStatus.inactive &&
        (student.loginUsername?.trim().isNotEmpty ?? false);
  }

  bool canLogin(AdminStudentRecord student) {
    if (!student.isActive) return false;
    if (!hasPortalAccount(student)) return false;
    return student.portalAccountStatus.canLogin;
  }

  /// School-set first-login password. Students share one template until they
  /// change it — never a unique generated suffix.
  String resolvedTempPassword(String? schoolId) {
    final resolved = settingsForSchool(schoolId).resolvedTempPassword();
    if (resolved.length >= AuthService.minPasswordLength) return resolved;
    return AuthService.generateTempPassword();
  }

  bool matchesSchoolTempPassword({
    required String password,
    String? schoolId,
  }) {
    if (password.isEmpty) return false;
    return password == resolvedTempPassword(schoolId);
  }

  String generateTempPassword(String? schoolId) =>
      resolvedTempPassword(schoolId);

  Future<void> _syncPlainPasswordToCloud({
    required String username,
    required String plainPassword,
  }) async {
    final user = AuthService.findUser(username);
    if (user == null) return;
    try {
      await SchoolAuthCloudService.instance.upsertAccount(
        user: user,
        password: plainPassword,
      );
    } catch (_) {
      // Local account is still usable; school-login also accepts the template.
    }
  }

  /// Creates portal auth + updates student registry record.
  Future<AdminStudentRecord?> createPortalAccount({
    required String studentId,
    required String createdBy,
    String? schoolId,
  }) async {
    final student = StudentRegistryService.instance.lookupById(studentId);
    if (student == null) return null;
    final sid = (schoolId ?? student.schoolId).trim().toUpperCase();

    if (!isEligibleGrade(gradeLabel: student.grade, schoolId: sid)) {
      return null;
    }
    if (hasPortalAccount(student)) return student;

    final prepared = await preparePortalAccess(student, actor: createdBy);
    if (prepared.change == PortalAccessChange.none) return null;
    await _storePortalAccess(prepared.student);
    return prepared.student;
  }

  /// Gives or removes a login so this student matches the school's portal grade.
  /// Does not write the registry. Suspended, graduated, and transferred
  /// students are left unchanged.
  Future<PreparedPortalAccess> preparePortalAccess(
    AdminStudentRecord student, {
    required String actor,
  }) async {
    if (!student.isActive) {
      return PreparedPortalAccess(student, PortalAccessChange.none);
    }
    final status = student.portalAccountStatus;
    if (status == StudentAccountStatus.suspended ||
        status == StudentAccountStatus.graduated ||
        status == StudentAccountStatus.transferred) {
      return PreparedPortalAccess(student, PortalAccessChange.none);
    }

    final eligible = isEligibleGrade(
      gradeLabel: student.grade,
      schoolId: student.schoolId,
    );
    final username = student.loginUsername?.trim() ?? '';

    if (eligible) {
      if (username.isEmpty) {
        final opened = await _openPortalAccount(student, actor);
        if (opened == null) {
          return PreparedPortalAccess(student, PortalAccessChange.none);
        }
        return PreparedPortalAccess(opened, PortalAccessChange.granted);
      }
      if (status == StudentAccountStatus.inactive) {
        _logStatus(
          student: student,
          actor: actor,
          detail: 'Login turned on because the student meets the portal grade',
        );
        return PreparedPortalAccess(
          student.copyWith(portalAccountStatus: StudentAccountStatus.active),
          PortalAccessChange.restored,
        );
      }
      return PreparedPortalAccess(student, PortalAccessChange.none);
    }

    if (status == StudentAccountStatus.active && username.isNotEmpty) {
      _logStatus(
        student: student,
        actor: actor,
        detail: 'Login turned off because the student is below the portal grade',
      );
      return PreparedPortalAccess(
        student.copyWith(portalAccountStatus: StudentAccountStatus.inactive),
        PortalAccessChange.revoked,
      );
    }
    return PreparedPortalAccess(student, PortalAccessChange.none);
  }

  /// Applies the saved portal grade to every active student already enrolled.
  Future<PortalAccessSyncResult> syncEnrolledPortalAccess({
    required String schoolId,
    required String actor,
  }) async {
    final students = List<AdminStudentRecord>.from(
      StudentRegistryService.instance.studentsForSchool(schoolId),
    );
    var granted = 0;
    var restored = 0;
    var revoked = 0;
    for (final student in students) {
      final prepared = await preparePortalAccess(student, actor: actor);
      switch (prepared.change) {
        case PortalAccessChange.granted:
          granted++;
          await _storePortalAccess(prepared.student);
        case PortalAccessChange.restored:
          restored++;
          await _storePortalAccess(prepared.student);
        case PortalAccessChange.revoked:
          revoked++;
          await _storePortalAccess(prepared.student);
        case PortalAccessChange.none:
          break;
      }
    }
    return PortalAccessSyncResult(
      granted: granted,
      restored: restored,
      revoked: revoked,
    );
  }

  /// After a grade or section change, match this student's login to the rule.
  Future<PortalAccessChange> syncStudentAfterGradeChange({
    required String studentId,
    required String actor,
  }) async {
    final student = StudentRegistryService.instance.lookupById(studentId);
    if (student == null) return PortalAccessChange.none;
    final prepared = await preparePortalAccess(student, actor: actor);
    await _storePortalAccess(prepared.student);
    return prepared.change;
  }

  Future<AdminStudentRecord?> _openPortalAccount(
    AdminStudentRecord student,
    String actor,
  ) async {
    final sid = student.schoolId.trim().toUpperCase();
    final settings = settingsForSchool(sid);
    final username = generateUniqueStudentUsername(
      fullName: student.fullName,
      studentId: student.studentId,
      format: settings.usernameFormat,
      isTaken: AuthService.isUsernameTaken,
    );
    final tempPassword = generateTempPassword(sid);
    final authError = AuthService.registerStudentAccount(
      fullName: student.fullName,
      schoolId: sid,
      username: username,
      linkedStudentId: student.studentId,
      password: tempPassword,
      mustChangePassword: true,
    );
    if (authError != null) return null;
    await _syncPlainPasswordToCloud(
      username: username,
      plainPassword: tempPassword,
    );
    unawaited(
      StudentPortalAuditService.instance.log(
        action: StudentPortalAuditAction.accountCreated,
        schoolId: sid,
        studentId: student.studentId,
        username: username,
        actor: actor,
        detail: 'Portal account created',
      ),
    );
    return student.copyWith(
      loginUsername: username,
      initialPassword: tempPassword,
      mustChangePassword: true,
      portalAccountStatus: StudentAccountStatus.active,
      portalAccountCreatedAt: DateTime.now(),
      portalAccountCreatedBy: actor,
      firstLoginCompleted: false,
    );
  }

  Future<void> _storePortalAccess(AdminStudentRecord student) async {
    StudentRegistryService.instance.replaceStudent(student);
    await StudentPersistenceService.instance.saveRegistryFromService(
      syncStudentId: student.studentId,
      pushCloud: true,
      immediateUpload: true,
    );
  }

  void _logStatus({
    required AdminStudentRecord student,
    required String actor,
    required String detail,
  }) {
    unawaited(
      StudentPortalAuditService.instance.log(
        action: StudentPortalAuditAction.accountStatusChanged,
        schoolId: student.schoolId,
        studentId: student.studentId,
        username: student.loginUsername,
        actor: actor,
        detail: detail,
      ),
    );
  }

  Future<AdminStudentRecord?> regeneratePassword({
    required String studentId,
    required String actor,
  }) async {
    final student = StudentRegistryService.instance.lookupById(studentId);
    if (student == null || !hasPortalAccount(student)) return null;

    final tempPassword = generateTempPassword(student.schoolId);
    final username = student.loginUsername?.trim();
    if (username == null || username.isEmpty) return null;

    AuthService.updateStudentPassword(
      username: username,
      plainPassword: tempPassword,
      mustChangePassword: true,
    );
    await _syncPlainPasswordToCloud(
      username: username,
      plainPassword: tempPassword,
    );

    final updated = student.copyWith(
      initialPassword: tempPassword,
      mustChangePassword: true,
      firstLoginCompleted: false,
    );
    StudentRegistryService.instance.replaceStudent(updated);
    await StudentPersistenceService.instance.saveRegistryFromService(
      syncStudentId: student.studentId,
      pushCloud: true,
      immediateUpload: true,
    );

    unawaited(
      StudentPortalAuditService.instance.log(
        action: StudentPortalAuditAction.passwordReset,
        schoolId: student.schoolId,
        studentId: student.studentId,
        username: username,
        actor: actor,
        detail: 'Temporary password regenerated',
      ),
    );
    return updated;
  }

  Future<void> updateAccountStatus({
    required String studentId,
    required StudentAccountStatus status,
    required String actor,
  }) async {
    final student = StudentRegistryService.instance.lookupById(studentId);
    if (student == null) return;

    final updated = student.copyWith(portalAccountStatus: status);
    StudentRegistryService.instance.replaceStudent(updated);
    unawaited(StudentPersistenceService.instance.saveRegistryFromService(
      syncStudentId: student.studentId,
    ));

    unawaited(
      StudentPortalAuditService.instance.log(
        action: StudentPortalAuditAction.accountStatusChanged,
        schoolId: student.schoolId,
        studentId: student.studentId,
        username: student.loginUsername,
        actor: actor,
        detail: 'Status → ${status.name}',
      ),
    );
  }

  AdminStudentRecord? recordForCurrentUser() {
    final user = AuthService.currentUser;
    if (user == null || user.roleKey != AuthService.roleStudent) return null;
    final linked = user.linkedStudentId?.trim().toUpperCase();
    if (linked != null && linked.isNotEmpty) {
      return StudentRegistryService.instance.lookupById(linked);
    }
    return StudentRegistryService.instance.lookupByLoginUsername(user.username);
  }

  String loginIdentifierFor(AdminStudentRecord student) {
    return student.loginUsername ?? student.studentId;
  }

  String passwordForShare(AdminStudentRecord student) {
    return resolvedTempPassword(student.schoolId);
  }

  String buildCredentialsMessage(AdminStudentRecord student) {
    final schoolName =
        SchoolRegistryService.instance.displayName(student.schoolId);
    final login = loginIdentifierFor(student);
    final password = passwordForShare(student);
    return '''Welcome to MaJo e-School Bridge!

Your student portal account is ready:

Name: ${student.fullName}
School: $schoolName
School ID: ${student.schoolId}
Student ID: ${student.studentId}
Username: $login
Temp password: $password

Sign in as Student. You can also use your Student ID to log in.
Please change your password after first login.''';
  }

  Future<void> markFirstLoginComplete(String studentId) async {
    final student = StudentRegistryService.instance.lookupById(studentId);
    if (student == null) return;
    final updated = student.copyWith(
      mustChangePassword: false,
      firstLoginCompleted: true,
    );
    StudentRegistryService.instance.replaceStudent(updated);
    unawaited(StudentPersistenceService.instance.saveRegistryFromService(
      syncStudentId: student.studentId,
    ));
  }
}
