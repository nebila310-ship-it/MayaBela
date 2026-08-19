import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

class ClassTeacherInfo {
  const ClassTeacherInfo({
    required this.teacher,
    required this.isHomeroom,
  });

  final AdminTeacherRecord teacher;
  final bool isHomeroom;
}

class ClassStructureService {
  ClassStructureService._();
  static final instance = ClassStructureService._();

  String? get _schoolId => AuthService.activeSchoolId;

  List<String> gradesForSchool() {
    final school = SchoolRegistryService.instance.lookup(_schoolId);
    if (school != null && school.gradeLevels.isNotEmpty) {
      return List.from(school.gradeLevels);
    }
    final students = _students();
    final grades = students.map((s) => s.grade.trim()).where((g) => g.isNotEmpty).toSet().toList();
    grades.sort();
    return grades;
  }

  List<String> sectionsForGrade(String grade) {
    final sections = <String>{};
    final schoolId = _schoolId;
    if (schoolId != null) {
      sections.addAll(
        SchoolRegistryService.instance.sectionLabelsForGrade(schoolId, grade),
      );
    }
    for (final student in _students().where((s) => s.grade == grade)) {
      sections.add(_sectionLabel(student.className, grade));
    }
    for (final className in SchoolDataService.instance.getAllClassNames()) {
      if (className.startsWith(grade)) {
        sections.add(_sectionLabel(className, grade));
      }
    }
    final list = sections.toList()..sort();
    return list;
  }

  Future<bool> addSectionForGrade(String grade, String section) async {
    final schoolId = _schoolId;
    if (schoolId == null) return false;
    final ok = await SchoolRegistryService.instance.addSectionForGrade(
      schoolId: schoolId,
      grade: grade,
      section: section,
    );
    if (ok) {
      SchoolDataService.instance.ensureClassExists(
        classNameFor(grade, section),
      );
    }
    return ok;
  }

  /// Creates the section under [grade] when it is not registered yet.
  Future<void> ensureSectionForGrade(String grade, String section) async {
    final label = section.trim();
    if (grade.trim().isEmpty || label.isEmpty) return;
    final existing = sectionsForGrade(grade);
    if (existing.any((s) => s.toLowerCase() == label.toLowerCase())) return;
    await addSectionForGrade(grade, label);
  }

  String classNameFor(String grade, String section) =>
      StudentRegistryService.buildClassName(grade, section);

  List<AdminStudentRecord> studentsInSection(String grade, String section) {
    final className = classNameFor(grade, section);
    return StudentRegistryService.instance.studentsForClass(
      className,
      schoolId: _schoolId,
    );
  }

  List<ClassTeacherInfo> teachersForSection(String grade, String section) {
    final className = classNameFor(grade, section);
    final homeroomId =
        SchoolDataService.instance.homeroomTeacherIdForClass(className);
    final teachers = <ClassTeacherInfo>[];
    final seen = <String>{};

    for (final teacher in TeacherRegistryService.instance.teachersForSchool(
      _schoolId ?? '',
    )) {
      for (final assignment in teacher.classAssignments) {
        if (assignment.className != className) continue;
        if (seen.add(teacher.teacherId)) {
          teachers.add(
            ClassTeacherInfo(
              teacher: teacher,
              isHomeroom: assignment.role == TeacherStaffRole.homeroomTeacher ||
                  teacher.teacherId == homeroomId,
            ),
          );
        }
      }
      if (teacher.classAssignments.isEmpty &&
          teacher.assignedClass.split(',').map((e) => e.trim()).contains(className) &&
          seen.add(teacher.teacherId)) {
        teachers.add(
          ClassTeacherInfo(
            teacher: teacher,
            isHomeroom: teacher.teacherId == homeroomId,
          ),
        );
      }
    }

    teachers.sort((a, b) {
      if (a.isHomeroom && !b.isHomeroom) return -1;
      if (b.isHomeroom && !a.isHomeroom) return 1;
      return a.teacher.fullName.compareTo(b.teacher.fullName);
    });
    return teachers;
  }

  List<AdminStudentRecord> _students() {
    if (_schoolId == null) {
      return StudentRegistryService.instance.getAllStudents();
    }
    return StudentRegistryService.instance.studentsForSchool(_schoolId!);
  }

  String _sectionLabel(String className, String grade) {
    if (className.length > grade.length) {
      return className.substring(grade.length).trim();
    }
    return className;
  }
}
