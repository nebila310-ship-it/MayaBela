import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';

abstract final class GradeWorkflowService {
  static GradeWorkflowSettings settingsForSchool(String? schoolId) {
    if (schoolId == null || schoolId.trim().isEmpty) {
      return const GradeWorkflowSettings();
    }
    return SchoolRegistryService.instance
            .lookup(schoolId)
            ?.gradeWorkflow ??
        const GradeWorkflowSettings();
  }

  static bool requireApproval(String? schoolId) =>
      settingsForSchool(schoolId).requireApproval;

  static GradeApprovalRole? pendingApproverRole(
    SubjectGrade grade,
    String? schoolId,
  ) {
    if (grade.status != SubjectGradeStatus.pendingApproval) return null;
    final chain = settingsForSchool(schoolId).approvalChain;
    if (chain.isEmpty) return GradeApprovalRole.academicCoordinator;
    final index = grade.approvalLevelIndex.clamp(0, chain.length - 1);
    return chain[index];
  }

  /// Owner or any staff role with [SchoolPermissions.approveGrades]
  /// (Section Director, academic coordinator, etc.).
  static bool get _hasExamApprovalPermission =>
      AuthService.currentUser?.roleKey == AuthService.roleAdmin ||
      AuthService.hasPermission(SchoolPermissions.approveGrades);

  static bool canUserApprove({
    required SubjectGrade grade,
    required String className,
    String? schoolId,
    String? roleKey,
  }) {
    if (grade.status != SubjectGradeStatus.pendingApproval) return false;
    final role = roleKey ?? AuthService.currentUser?.roleKey;
    if (role == null) return false;

    final pending = pendingApproverRole(grade, schoolId);
    if (pending == null) return false;

    return switch (pending) {
      GradeApprovalRole.admin => _hasExamApprovalPermission,
      GradeApprovalRole.homeroomTeacher =>
        role == AuthService.roleTeacher &&
            TeacherAccessService.instance.isHomeroomFor(className),
      // Section Director (and VP escalate) — not homeroom self-approval.
      GradeApprovalRole.academicCoordinator ||
      GradeApprovalRole.vicePrincipal =>
        _hasExamApprovalPermission,
    };
  }

  static String statusLabel(SubjectGradeStatus status) {
    return switch (status) {
      SubjectGradeStatus.draft => 'Draft',
      SubjectGradeStatus.pendingApproval => 'Pending approval',
      SubjectGradeStatus.changesRequested => 'Adjustment requested',
      SubjectGradeStatus.approved => 'Approved',
      SubjectGradeStatus.rejected => 'Rejected',
    };
  }
}
