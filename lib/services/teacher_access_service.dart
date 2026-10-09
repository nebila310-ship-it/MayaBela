import 'package:mayabela/database/school_database_service.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/school_module_catalog.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// Resolves what the logged-in teacher can do per class and feature.
class TeacherAccessService {
  TeacherAccessService._();

  static final instance = TeacherAccessService._();

  static const _subjectTeacherDashboardTiles = {
    'classes',
    'attendance',
    'at_risk',
    'messages',
    'homework',
    'exams',
    'lesson_plans',
    'curriculum',
    'qa_surveys',
    'learning_materials',
    'grades',
    'qr',
    'calendar',
    'timetable',
    'maya_assistant',
    'settings',
  };

  AdminTeacherRecord? get _record =>
      TeacherRegistryService.instance.resolveForAuthUser(
        linkedTeacherId: AuthService.currentUser?.linkedTeacherId,
        username: AuthService.currentUser?.username,
        phone: AuthService.currentUser?.phone,
        schoolId:
            AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId,
      );

  String get teacherId =>
      _record?.teacherId ?? AuthService.currentUser?.linkedTeacherId ?? '';

  String get teacherName {
    final record = _record;
    if (record != null && record.fullName.isNotEmpty) return record.fullName;
    return AuthService.currentUser?.fullName ?? 'Teacher';
  }

  String get teacherSubject => _record?.subject ?? '';

  List<ClassAssignment> get myClasses {
    final id = teacherId;
    if (id.isEmpty) return const [];
    _ensureAssignmentsSynced();
    return SchoolDataService.instance.getClassAssignmentsForTeacher(id);
  }

  void _ensureAssignmentsSynced() {
    final record = _record;
    if (record == null || record.classAssignments.isEmpty) return;
    SchoolDataService.instance.setTeacherAssignmentsFromRegistry(record);
  }

  ClassAssignment? assignmentFor(String className) {
    try {
      return myClasses.firstWhere(
        (a) => StudentRegistryService.classNamesMatch(a.className, className),
      );
    } catch (_) {
      return null;
    }
  }

  TeacherClassAssignment? _registryAssignmentFor(String className) {
    final record = _record;
    if (record == null) return null;
    try {
      return record.classAssignments.firstWhere(
        (assignment) => StudentRegistryService.classNamesMatch(
          assignment.className,
          className,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  List<SubjectTeachingSlot> teachingSlotsFor(String className) {
    final assignment = _registryAssignmentFor(className);
    if (assignment == null) return const [];

    if (assignment.teachingSlots.isNotEmpty) {
      return List<SubjectTeachingSlot>.from(assignment.teachingSlots);
    }

    if (assignment.role == TeacherStaffRole.homeroomTeacher) {
      return SchoolDataService.instance
          .getSubjectsForClass(className)
          .where(
            (subject) =>
                subject.teacherId == teacherId ||
                subject.teacherName == teacherName,
          )
          .map(
            (subject) => SubjectTeachingSlot(
              slotId: 'STA-HR-${subject.subject}',
              subjectId: subject.subject,
              subjectName: subject.subject,
            ),
          )
          .toList();
    }

    final record = _record;
    if (record != null && record.subjects.isNotEmpty) {
      return record.subjects
          .map(
            (name) => SubjectTeachingSlot(
              slotId: 'STA-LEG-$name',
              subjectId: name,
              subjectName: name,
            ),
          )
          .toList();
    }
    return const [];
  }

  SubjectTeachingSlot? teachingSlotFor(String className, String subjectName) {
    final normalized = subjectName.trim().toLowerCase();
    try {
      return teachingSlotsFor(className).firstWhere(
        (slot) => slot.subjectName.trim().toLowerCase() == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  bool _hasClassAccess(String className) {
    final id = teacherId;
    if (id.isEmpty) return false;

    final db = SchoolDatabaseService.instance;
    if (db.isInitialized) {
      return db.canTeacherAccessClassName(teacherId: id, className: className);
    }
    return assignmentFor(className) != null;
  }

  bool isHomeroomFor(String className) {
    if (assignmentFor(className)?.isHomeroom == true) return true;
    return _registryAssignmentFor(className)?.role ==
        TeacherStaffRole.homeroomTeacher;
  }

  bool get hasAnyHomeroomClass {
    if (myClasses.any((assignment) => assignment.isHomeroom)) return true;
    final record = _record;
    if (record == null) return false;
    return record.classAssignments.any(
      (assignment) => assignment.role == TeacherStaffRole.homeroomTeacher,
    );
  }

  bool get hasFullDashboardAccess => hasAnyHomeroomClass;

  bool canAccessTeacherDashboardTile(String tileId) {
    if (!SchoolModuleCatalog.isEnabled(tileId)) return false;
    if (hasFullDashboardAccess) return true;
    return _subjectTeacherDashboardTiles.contains(tileId);
  }

  bool get canCreateAnnouncements => hasAnyHomeroomClass;

  bool get canCreateCalendarEvents => hasAnyHomeroomClass;

  bool canAccessFullClass(String className) => isHomeroomFor(className);

  bool canMessageInClass(String className) => _hasClassAccess(className);

  bool canAddHomework(String className) => _hasClassAccess(className);

  bool canAddLearningMaterial(String className) => _hasClassAccess(className);

  bool canEditLearningMaterial(LearningMaterialItem item) =>
      item.teacherId == teacherId;

  bool canViewAllHomeworkInClass(String className) => isHomeroomFor(className);

  bool canEditHomework(HomeworkItem item) => item.teacherId == teacherId;

  bool canPostGallery(String className) => isHomeroomFor(className);

  bool canTakeAttendance(String className) => _hasClassAccess(className);

  List<String> teachableSubjects(String className) {
    final fromSlots = teachingSlotsFor(className)
        .map((slot) => slot.subjectName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    if (fromSlots.isNotEmpty) return fromSlots;

    final assignment = assignmentFor(className);
    final subjectField = assignment?.subject;
    if (subjectField != null && subjectField.trim().isNotEmpty) {
      return subjectField
          .split(',')
          .map((subject) => subject.trim())
          .where((subject) => subject.isNotEmpty)
          .toList();
    }

    final record = _record;
    if (record != null && record.subjects.isNotEmpty) {
      return List<String>.from(record.subjects);
    }
    return const [];
  }

  /// All class + subject pairs this teacher may post homework or grades for.
  List<({String className, String subject})> teachingAssignments() {
    final pairs = <({String className, String subject})>[];
    for (final assignment in myClasses) {
      for (final subject in teachableSubjects(assignment.className)) {
        pairs.add((className: assignment.className, subject: subject));
      }
    }
    return pairs;
  }

  String? defaultHomeworkSubject(String className) {
    final subjects = teachableSubjects(className);
    return subjects.isEmpty ? null : subjects.first;
  }

  bool canViewSubjectGrade(String className, String subject) {
    if (isHomeroomFor(className)) return true;
    return teachableSubjects(className).contains(subject);
  }

  static bool subjectsMatch(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  /// Teachers prepare lesson plans only for subjects they teach in that class.
  bool canPrepareLessonPlan({
    required String className,
    required String subject,
  }) {
    if (className.trim().isEmpty || subject.trim().isEmpty) return false;
    return teachableSubjects(className).any(
      (name) => subjectsMatch(name, subject),
    );
  }

  bool canEditSubject(
    String className,
    String subject, {
    String? enteredByTeacherId,
  }) {
    if (enteredByTeacherId != null &&
        enteredByTeacherId.isNotEmpty &&
        enteredByTeacherId == teacherId) {
      return true;
    }
    return teachingSlotFor(className, subject) != null;
  }

  bool canExportGradesForClass(String className) => isHomeroomFor(className);

  List<String> get homeroomClassNames {
    final names = <String>{};
    for (final assignment in myClasses) {
      if (assignment.isHomeroom) names.add(assignment.className);
    }
    final record = _record;
    if (record != null) {
      for (final assignment in record.classAssignments) {
        if (assignment.role == TeacherStaffRole.homeroomTeacher) {
          names.add(assignment.className);
        }
      }
    }
    return names.toList();
  }
}
