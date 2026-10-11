import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

String staffRoleLabel(StaffRole role, AppStrings s) {
  if (s.isAmharic) return role.labelAm;
  if (s.isOromo) return role.labelOm;
  return role.labelEn;
}

/// Compact role chips for staff lists ("Procurement Manager +1").
String staffRolesSummary(
  List<String> roleKeys,
  AppStrings s, {
  String? schoolId,
}) {
  final labels = [
    for (final key in roleKeys)
      if (SchoolRoleCatalogService.instance
              .lookup(key, schoolId: schoolId) !=
          null)
        staffRoleLabel(
          SchoolRoleCatalogService.instance.lookup(key, schoolId: schoolId)!,
          s,
        )
      else if (StaffRoles.lookup(key) != null)
        staffRoleLabel(StaffRoles.lookup(key)!, s),
  ];
  if (labels.isEmpty) return '';
  if (labels.length == 1) return labels.first;
  return '${labels.first} +${labels.length - 1}';
}

/// Title the signed-in person should see (CEO, General Manager, Teacher…).
String signedInJobTitle(AppStrings s) {
  final user = AuthService.currentUser;
  if (user == null) return s.roleLabel(AuthService.roleTeacher);
  if (user.roleKey == AuthService.roleAdmin) {
    return s.roleLabel(AuthService.roleAdmin);
  }
  if (user.roleKey != AuthService.roleTeacher &&
      user.roleKey != AuthService.roleStaff) {
    return s.roleLabel(user.roleKey);
  }
  final schoolId = AuthService.activeSchoolId ?? user.schoolId;
  final record = TeacherRegistryService.instance.resolveForAuthUser(
    linkedTeacherId: user.linkedTeacherId,
    username: user.username,
    phone: user.phone,
    schoolId: schoolId,
  );
  final keys = record?.staffRoles.isNotEmpty == true
      ? record!.staffRoles
      : user.staffRoles;
  if (keys.isNotEmpty) {
    final title = staffRolesSummary(keys, s, schoolId: schoolId);
    if (title.isNotEmpty) return title;
    return 'Administration Staff';
  }
  if (AuthService.isClassroomTeacher) return s.teacherLabelShort;
  return s.roleLabel(user.roleKey);
}

/// Classroom placement summary, e.g. "Grade 2C HR (Homeroom Teacher) · Math".
String classroomAssignmentSummary(AdminTeacherRecord teacher, AppStrings s) {
  final assignments = teacher.classAssignments;
  if (assignments.isEmpty) {
    final classes = teacher.assignedClass.trim();
    if (classes.isEmpty) return '';
    final roleBits = <String>[];
    if (teacher.roles.contains(TeacherStaffRole.homeroomTeacher)) {
      roleBits.add(
        'HR (${s.teacherRoleLabel(TeacherStaffRole.homeroomTeacher)})',
      );
    }
    if (teacher.roles.contains(TeacherStaffRole.subjectTeacher)) {
      roleBits.add(
        'ST (${s.teacherRoleLabel(TeacherStaffRole.subjectTeacher)})',
      );
    }
    final subjects =
        teacher.subjects.where((x) => x.trim().isNotEmpty).join(', ');
    final roleText = roleBits.isEmpty ? '' : ' ${roleBits.join(' · ')}';
    final subjectText = subjects.isEmpty ? '' : ' · $subjects';
    return '$classes$roleText$subjectText'.trim();
  }

  return assignments.map((a) {
    final abbr = a.role == TeacherStaffRole.homeroomTeacher ? 'HR' : 'ST';
    final role = s.teacherRoleLabel(a.role);
    final subjects = a.subjectNames.join(', ');
    if (subjects.isEmpty) {
      return '${a.className} $abbr ($role)';
    }
    return '${a.className} $abbr ($role) · $subjects';
  }).join('; ');
}
