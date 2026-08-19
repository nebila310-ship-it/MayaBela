import 'package:mayabela/database/models/database_models.dart';
import 'package:mayabela/database/user_roles.dart';

/// Resolves ID-based relationships — users never connect directly.
///
/// Parent → Teacher path:
///   Parent → ParentStudentLink → Student → Class → TeacherAssignment → Teacher
class RelationshipResolver {
  const RelationshipResolver({
    required this.students,
    required this.parentLinks,
    required this.teacherAssignments,
    required this.transportAssignments,
    required this.routes,
  });

  final List<StudentRecord> students;
  final List<ParentStudentLink> parentLinks;
  final List<TeacherAssignment> teacherAssignments;
  final List<TransportAssignment> transportAssignments;
  final List<RouteRecord> routes;

  /// Students linked to a parent (one parent, many children).
  List<StudentRecord> studentsForParent(String parentId) {
    final ids = parentLinks
        .where((l) => l.parentId == parentId)
        .map((l) => l.studentId)
        .toSet();
    return students.where((s) => ids.contains(s.studentId)).toList();
  }

  /// Parent IDs for a student (many parents possible via links).
  List<String> parentIdsForStudent(String studentId) {
    return parentLinks
        .where((l) => l.studentId == studentId)
        .map((l) => l.parentId)
        .toList();
  }

  /// Students in a class.
  List<StudentRecord> studentsInClass(String classId) {
    return students.where((s) => s.classId == classId).toList();
  }

  /// Teachers assigned to a class (via teacher_assignments).
  List<TeacherAssignment> assignmentsForClass(String classId) {
    return teacherAssignments.where((a) => a.classId == classId).toList();
  }

  /// Classes a teacher is assigned to.
  List<String> classIdsForTeacher(String teacherId) {
    return teacherAssignments
        .where((a) => a.teacherId == teacherId)
        .map((a) => a.classId)
        .toSet()
        .toList();
  }

  /// Teachers reachable from a parent (child's class teachers only).
  List<TeacherAssignment> teachersForParent(String parentId) {
    final childClassIds = studentsForParent(parentId)
        .map((s) => s.classId)
        .toSet();
    return teacherAssignments
        .where((a) => childClassIds.contains(a.classId))
        .toList();
  }

  /// Route for a student.
  TransportAssignment? transportForStudent(String studentId) {
    try {
      return transportAssignments.firstWhere((a) => a.studentId == studentId);
    } catch (_) {
      return null;
    }
  }

  /// Students on a route.
  List<StudentRecord> studentsOnRoute(String routeId) {
    final ids = transportAssignments
        .where((a) => a.routeId == routeId)
        .map((a) => a.studentId)
        .toSet();
    return students.where((s) => ids.contains(s.studentId)).toList();
  }

  /// Route assigned to a driver.
  RouteRecord? routeForDriver(String driverId) {
    try {
      return routes.firstWhere((r) => r.driverId == driverId);
    } catch (_) {
      return null;
    }
  }
}

/// Role-based access checks aligned with the schema spec.
abstract final class RoleAccessRules {
  static bool adminCanManageAll(String role) => role == UserRoles.admin;

  static bool teacherCanAccessClass({
    required String teacherId,
    required String classId,
    required RelationshipResolver resolver,
  }) {
    return resolver.classIdsForTeacher(teacherId).contains(classId);
  }

  static bool parentCanAccessStudent({
    required String parentId,
    required String studentId,
    required RelationshipResolver resolver,
  }) {
    return resolver.studentsForParent(parentId).any(
          (s) => s.studentId == studentId,
        );
  }

  static bool driverCanAccessStudent({
    required String driverId,
    required String studentId,
    required RelationshipResolver resolver,
  }) {
    final route = resolver.routeForDriver(driverId);
    if (route == null) return false;
    return resolver.studentsOnRoute(route.routeId).any(
          (s) => s.studentId == studentId,
        );
  }
}
