import 'dart:async';

import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/student_persistence_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_portal_audit_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/grade_level_utils.dart';
import 'package:mayabela/utils/student_username_generator.dart';

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

  /// Unique temp per student. Optional school template is used as a prefix only.
  String generateTempPassword(String? schoolId) {
    final unique = AuthService.generateTempPassword(length: 10);
    final template = settingsForSchool(schoolId).tempPasswordTemplate.trim();
    if (template.isEmpty) return unique;
    final year = DateTime.now().year.toString();
    final prefix = template.replaceAll('{year}', year).trim();
    if (prefix.isEmpty) return unique;
    // Keep total length reasonable for sharing; still unique per account.
    final base = prefix.length > 8 ? prefix.substring(0, 8) : prefix;
    return '$base-$unique';
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

    final updated = student.copyWith(
      loginUsername: username,
      initialPassword: tempPassword,
      mustChangePassword: true,
      portalAccountStatus: StudentAccountStatus.active,
      portalAccountCreatedAt: DateTime.now(),
      portalAccountCreatedBy: createdBy,
      firstLoginCompleted: false,
    );
    StudentRegistryService.instance.replaceStudent(updated);
    unawaited(StudentPersistenceService.instance.saveRegistryFromService(
      syncStudentId: student.studentId,
    ));

    unawaited(
      StudentPortalAuditService.instance.log(
        action: StudentPortalAuditAction.accountCreated,
        schoolId: sid,
        studentId: student.studentId,
        username: username,
        actor: createdBy,
        detail: 'Portal account created',
      ),
    );
    return updated;
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

    final updated = student.copyWith(
      initialPassword: tempPassword,
      mustChangePassword: true,
      firstLoginCompleted: false,
    );
    StudentRegistryService.instance.replaceStudent(updated);
    unawaited(StudentPersistenceService.instance.saveRegistryFromService(
      syncStudentId: student.studentId,
    ));

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
    final stored = student.initialPassword?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return generateTempPassword(student.schoolId);
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
