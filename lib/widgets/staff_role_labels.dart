import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

String staffRoleLabel(StaffRole role, AppStrings s) {
  if (s.isAmharic) return role.labelAm;
  if (s.isOromo) return role.labelOm;
  return role.labelEn;
}

/// Compact role chips for staff lists ("Procurement Manager +1").
String staffRolesSummary(List<String> roleKeys, AppStrings s) {
  final labels = [
    for (final key in roleKeys)
      if (SchoolRoleCatalogService.instance.lookup(key) != null)
        staffRoleLabel(SchoolRoleCatalogService.instance.lookup(key)!, s)
      else if (StaffRoles.lookup(key) != null)
        staffRoleLabel(StaffRoles.lookup(key)!, s),
  ];
  if (labels.isEmpty) return '';
  if (labels.length == 1) return labels.first;
  return '${labels.first} +${labels.length - 1}';
}

/// Classroom placement summary, e.g. "Grade 2C HR (Homeroom Teacher) · Math".
String classroomAssignmentSummary(AdminTeacherRecord teacher, AppStrings s) {
  final assignments = teacher.classAssignments;
  if (assignments.isEmpty) {
    final classes = teacher.assignedClass.trim();
    if (classes.isEmpty) return '';
    final roleBits = <String>[];
    if (teacher.roles.contains(TeacherStaffRole.homeroomTeacher)) {
      roleBits.add('HR (${s.teacherRoleLabel(TeacherStaffRole.homeroomTeacher)})');
    }
    if (teacher.roles.contains(TeacherStaffRole.subjectTeacher)) {
      roleBits.add('ST (${s.teacherRoleLabel(TeacherStaffRole.subjectTeacher)})');
    }
    final subjects = teacher.subjects.where((x) => x.trim().isNotEmpty).join(', ');
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
