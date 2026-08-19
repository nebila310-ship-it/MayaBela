import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/persistence/teacher_persistence_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// Section-centric teacher assignment (Academic Management).
/// Does not replace the teacher-profile "Assign classes" editor — it writes
/// the same [TeacherClassAssignment] data from the section side.
class SectionTeacherAssignmentService {
  SectionTeacherAssignmentService._();
  static final instance = SectionTeacherAssignmentService._();

  AdminTeacherRecord? _withDerivedFields(
    AdminTeacherRecord teacher,
    List<TeacherClassAssignment> assignments,
  ) {
    final assignedClass =
        assignments.map((a) => a.className).toSet().join(', ');
    final roles = assignments.map((a) => a.role).toSet().toList();
    final derived =
        TeacherRegistryService.subjectsFromAssignments(assignments);
    return teacher.copyWith(
      classAssignments: assignments,
      assignedClass: assignedClass,
      roles: roles.isEmpty ? teacher.roles : roles,
      subjects: derived.isNotEmpty ? derived : teacher.subjects,
    );
  }

  Future<void> _commit(AdminTeacherRecord updated) async {
    TeacherRegistryService.instance.updateTeacher(updated);
    SchoolDataService.instance.setTeacherAssignmentsFromRegistry(updated);
    await TeacherPersistenceService.instance.saveRegistryFromService();
  }

  /// Sets (or clears) the single homeroom teacher for [className].
  Future<void> setHomeroomTeacher({
    required String className,
    required String? teacherId,
  }) async {
    final targetClass = className.trim();
    if (targetClass.isEmpty) return;

    // Clear existing HR rows for this class on every teacher.
    for (final teacher in TeacherRegistryService.instance.getAllTeachers()) {
      final before = teacher.classAssignments.length;
      final next = teacher.classAssignments
          .where(
            (a) =>
                !(a.className == targetClass &&
                    a.role == TeacherStaffRole.homeroomTeacher),
          )
          .toList();
      if (next.length != before) {
        final updated = _withDerivedFields(teacher, next);
        if (updated != null) await _commit(updated);
      }
    }

    final id = teacherId?.trim().toUpperCase();
    if (id == null || id.isEmpty) {
      SchoolDataService.instance.syncEnrollmentFromRegistry();
      return;
    }

    final teacher = TeacherRegistryService.instance.lookupById(id);
    if (teacher == null) return;

    final assignments = List<TeacherClassAssignment>.from(
      teacher.classAssignments,
    )..removeWhere(
        (a) =>
            a.className == targetClass &&
            a.role == TeacherStaffRole.homeroomTeacher,
      );
    // Keep any existing subject row for this class; add HR row.
    final existingSubjects = assignments
        .where((a) => a.className == targetClass)
        .expand((a) => a.teachingSlots)
        .toList();
    assignments.add(
      TeacherClassAssignment(
        className: targetClass,
        role: TeacherStaffRole.homeroomTeacher,
        teachingSlots: existingSubjects,
      ),
    );
    // If there was a separate ST row, drop duplicate className ST when HR
    // already carries subjects — keep both HR + ST if ST has distinct slots.
    // Prefer one HR row; leave ST rows for other subject teachers only.
    final updated = _withDerivedFields(teacher, assignments);
    if (updated != null) await _commit(updated);

    SchoolDataService.instance.assignHomeroomTeacherForClass(
      className: targetClass,
      teacherId: id,
    );
  }

  /// Adds or updates a subject-teacher assignment for [className].
  Future<void> upsertSubjectTeacher({
    required String className,
    required String teacherId,
    required List<String> subjects,
  }) async {
    final targetClass = className.trim();
    final id = teacherId.trim().toUpperCase();
    if (targetClass.isEmpty || id.isEmpty) return;

    final teacher = TeacherRegistryService.instance.lookupById(id);
    if (teacher == null) return;

    final names = subjects.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (names.isEmpty) {
      await removeTeacherFromClass(className: targetClass, teacherId: id);
      return;
    }

    final existing = teacher.classAssignments
        .where(
          (a) =>
              a.className == targetClass &&
              a.role == TeacherStaffRole.subjectTeacher,
        )
        .expand((a) => a.teachingSlots)
        .toList();

    final assignments = List<TeacherClassAssignment>.from(
      teacher.classAssignments,
    )..removeWhere(
        (a) =>
            a.className == targetClass &&
            a.role == TeacherStaffRole.subjectTeacher,
      );

    assignments.add(
      TeacherClassAssignment(
        className: targetClass,
        role: TeacherStaffRole.subjectTeacher,
        teachingSlots: TeacherRegistryService.instance.buildTeachingSlots(
          names,
          existing: existing,
        ),
      ),
    );

    final updated = _withDerivedFields(teacher, assignments);
    if (updated != null) await _commit(updated);
  }

  /// Removes this teacher's assignment(s) for [className] (HR and/or ST).
  Future<void> removeTeacherFromClass({
    required String className,
    required String teacherId,
  }) async {
    final targetClass = className.trim();
    final id = teacherId.trim().toUpperCase();
    if (targetClass.isEmpty || id.isEmpty) return;

    final teacher = TeacherRegistryService.instance.lookupById(id);
    if (teacher == null) return;

    final wasHomeroom = teacher.classAssignments.any(
      (a) =>
          a.className == targetClass &&
          a.role == TeacherStaffRole.homeroomTeacher,
    );

    final assignments = teacher.classAssignments
        .where((a) => a.className != targetClass)
        .toList();
    final updated = _withDerivedFields(teacher, assignments);
    if (updated != null) await _commit(updated);

    if (wasHomeroom) {
      SchoolDataService.instance.syncEnrollmentFromRegistry();
    }
  }
}
