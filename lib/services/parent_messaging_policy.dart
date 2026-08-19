import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/admin_registry_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// Who parents may message / see in direct threads (homeroom + school leadership).
abstract final class ParentMessagingPolicy {
  static List<StaffMemberOption> adminContactsForSchool(String? schoolId) {
    final id = schoolId?.trim().toUpperCase();
    final contacts = <StaffMemberOption>[];
    final seen = <String>{};
    for (final admin in AdminRegistryService.instance.getAllAdmins()) {
      if (id != null && admin.schoolId.trim().toUpperCase() != id) continue;
      final option = StaffMemberOption.fromAdmin(admin);
      if (option == null) continue;
      if (seen.add(option.id)) contacts.add(option);
    }
    // Vice President / messaging staff appear as school contacts for parents.
    for (final teacher in TeacherRegistryService.instance.getAllTeachers()) {
      if (!teacher.isActive) continue;
      if (id != null && teacher.schoolId.trim().toUpperCase() != id) continue;
      final roles = teacher.staffRoles.map(StaffRoles.canonicalize).toSet();
      // EDUABA parent endpoints: Homeroom (separate) + Section Director,
      // Student Affairs, Registrar, Finance, Transport Head, leadership.
      if (!roles.contains(StaffRoles.vicePresident) &&
          !roles.contains(StaffRoles.fullAccess) &&
          !roles.contains(StaffRoles.studentAffairs) &&
          !roles.contains(StaffRoles.humanResource) &&
          !roles.contains(StaffRoles.sectionDirector) &&
          !roles.contains(StaffRoles.registrar) &&
          !roles.contains(StaffRoles.accountant) &&
          !roles.contains(StaffRoles.transportAdmin) &&
          !roles.contains(StaffRoles.principal) &&
          !roles.contains(StaffRoles.generalManager) &&
          !roles.contains(StaffRoles.deputyGeneralManager)) {
        continue;
      }
      final option = StaffMemberOption.fromTeacher(teacher);
      if (option == null) continue;
      if (seen.add(option.id)) contacts.add(option);
    }
    contacts.sort((a, b) => a.displayName.compareTo(b.displayName));
    return contacts;
  }

  static StaffMemberOption? homeroomStaffForStudent(String? studentId) {
    if (studentId == null || studentId.trim().isEmpty) return null;
    final student =
        StudentRegistryService.instance.lookupById(studentId.trim());
    if (student == null) return null;

    final homeroomId = student.homeroomTeacherId?.trim();
    if (homeroomId != null && homeroomId.isNotEmpty) {
      final teacher = TeacherRegistryService.instance.lookupById(homeroomId);
      final option = StaffMemberOption.fromTeacher(teacher);
      if (option != null) return option;
    }

    for (final teacher in TeacherRegistryService.instance.getAllTeachers()) {
      if (!teacher.isActive) continue;
      for (final assignment in teacher.classAssignments) {
        if (assignment.className != student.className ||
            assignment.role != TeacherStaffRole.homeroomTeacher) {
          continue;
        }
        return StaffMemberOption.fromTeacher(teacher);
      }
    }
    return null;
  }

  static StaffMemberOption? homeroomStaffForClass(
    String className, {
    String? homeroomTeacherName,
  }) {
    for (final student
        in StudentRegistryService.instance.studentsForClass(className)) {
      final option = homeroomStaffForStudent(student.studentId);
      if (option != null) return option;
    }

    if (homeroomTeacherName != null && homeroomTeacherName.trim().isNotEmpty) {
      final target = homeroomTeacherName.trim().toLowerCase();
      for (final teacher in TeacherRegistryService.instance.getAllTeachers()) {
        if (teacher.fullName.trim().toLowerCase() == target) {
          return StaffMemberOption.fromTeacher(teacher);
        }
      }
    }
    return null;
  }

  static bool isAdminStaff(String staffId) {
    final member = StaffMemberOption.resolve(staffId);
    if (member == null) return false;
    if (member.conversationRole.toLowerCase() == 'admin') return true;
    // Administration staff (VP / student affairs) treated as school contacts.
    if (member.kind == StaffKind.teacher) {
      final teacher = TeacherRegistryService.instance.lookupById(member.rawId);
      if (teacher == null) return false;
      final roles = teacher.staffRoles.map(StaffRoles.canonicalize).toSet();
      return roles.contains(StaffRoles.vicePresident) ||
          roles.contains(StaffRoles.fullAccess) ||
          roles.contains(StaffRoles.studentAffairs) ||
          roles.contains(StaffRoles.humanResource) ||
          roles.contains(StaffRoles.sectionDirector) ||
          roles.contains(StaffRoles.registrar) ||
          roles.contains(StaffRoles.accountant) ||
          roles.contains(StaffRoles.transportAdmin) ||
          roles.contains(StaffRoles.principal) ||
          roles.contains(StaffRoles.generalManager) ||
          roles.contains(StaffRoles.deputyGeneralManager);
    }
    return false;
  }

  static bool isHomeroomStaffForStudent(String staffId, String studentId) {
    final homeroom = homeroomStaffForStudent(studentId);
    return homeroom != null &&
        homeroom.id.trim().toUpperCase() == staffId.trim().toUpperCase();
  }

  static bool isHomeroomStaffForAnyLinkedChild(String staffId) {
    for (final studentId in AuthService.activeLinkedStudentIds()) {
      if (isHomeroomStaffForStudent(staffId, studentId)) return true;
    }
    return false;
  }

  static bool canMessageStaff({
    required String staffId,
    String? studentId,
  }) {
    if (isAdminStaff(staffId)) return true;
    if (studentId != null && studentId.trim().isNotEmpty) {
      return isHomeroomStaffForStudent(staffId, studentId);
    }
    return isHomeroomStaffForAnyLinkedChild(staffId);
  }

  static bool canViewDirectStaffThread(Conversation conversation) {
    if (conversation.isStaffOnlyDirectThread) return false;

    final staffId = conversation.staffParticipantId;
    if (staffId == null || staffId.trim().isEmpty) return false;

    if (isAdminStaff(staffId)) return true;

    for (final studentId in conversation.linkedStudentIds) {
      if (isHomeroomStaffForStudent(staffId, studentId)) return true;
    }
    for (final studentId in AuthService.activeLinkedStudentIds()) {
      if (isHomeroomStaffForStudent(staffId, studentId)) return true;
    }
    return false;
  }
}
