import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// Class + subject teaching space assembled from existing LMS modules.
class LmsCourseSnapshot {
  const LmsCourseSnapshot({
    required this.className,
    required this.subject,
    required this.lessonPlans,
    required this.homework,
    required this.materials,
    required this.examPapers,
    required this.submittedWorksheets,
    required this.examAttempts,
    required this.rosterSize,
    this.onlinePlan,
  });

  final String className;
  final String subject;
  final int lessonPlans;
  final int homework;
  final int materials;
  final int examPapers;
  final int submittedWorksheets;
  final int examAttempts;
  final int rosterSize;
  final LessonPlan? onlinePlan;
}

/// Reuses lesson plans, homework, exams, materials, and group chat.
class LmsClassroomService {
  LmsClassroomService._();
  static final instance = LmsClassroomService._();

  static String discussionTitle(String className) =>
      '${className.trim()} class discussion';

  String ensureClassDiscussion(String className) {
    final title = discussionTitle(className);
    final existing = SchoolDataService.instance.getConversations().where(
          (c) =>
              c.isGroup &&
              c.name.trim().toLowerCase() == title.toLowerCase(),
        );
    if (existing.isNotEmpty) return existing.first.id;

    final students = StudentRegistryService.instance.studentsForClass(className);
    final parentNames = <String>{};
    for (final student in students) {
      for (final name in [
        student.fatherName,
        student.motherName,
        student.guardianName,
      ]) {
        if (name != null && name.trim().isNotEmpty) {
          parentNames.add(name.trim());
        }
      }
    }

    final staffIds = <String>{};
    for (final teacher in TeacherRegistryService.instance.getAllTeachers()) {
      final assigned = teacher.classAssignments.any(
            (a) => StudentRegistryService.classNamesMatch(
              a.className,
              className,
            ),
          ) ||
          teacher.assignedClass
              .split(',')
              .map((e) => e.trim())
              .any((name) => StudentRegistryService.classNamesMatch(name, className));
      if (assigned) {
        staffIds.add(StaffMemberOption.teacherKey(teacher.teacherId));
      }
    }

    return SchoolDataService.instance.ensureNamedGroupConversation(
      groupName: title,
      parentNames: parentNames.toList()..sort(),
      staffIds: staffIds.toList()..sort(),
      linkedStudentIds: students.map((s) => s.studentId).toList(),
    );
  }

  List<LmsCourseSnapshot> coursesForSchool([String? schoolId]) {
    final keys = <String, ({String className, String subject})>{};
    void remember(String className, String subject) {
      final c = className.trim();
      final s = subject.trim();
      if (c.isEmpty || s.isEmpty) return;
      keys['${c.toLowerCase()}|${s.toLowerCase()}'] = (className: c, subject: s);
    }

    for (final plan in LessonPlanService.instance.forSchool(schoolId)) {
      remember(plan.className, plan.subject);
    }
    for (final item in SchoolDataService.instance.homeworkSnapshot()) {
      remember(item.className, item.subject);
    }
    for (final item in SchoolDataService.instance.learningMaterialsSnapshot()) {
      remember(item.className, item.subject);
    }
    for (final paper in ExamService.instance.papersForSchool(schoolId)) {
      remember(paper.className, paper.subject);
    }

    final rows = <LmsCourseSnapshot>[];
    for (final pair in keys.values) {
      final plans = LessonPlanService.instance
          .forSchool(schoolId)
          .where(
            (p) =>
                StudentRegistryService.classNamesMatch(p.className, pair.className) &&
                p.subject.trim().toLowerCase() == pair.subject.toLowerCase(),
          )
          .toList();
      final homework = SchoolDataService.instance
          .getHomeworkForClass(pair.className)
          .where(
            (h) => h.subject.trim().toLowerCase() == pair.subject.toLowerCase(),
          )
          .toList();
      final materials = SchoolDataService.instance
          .learningMaterialsSnapshot()
          .where(
            (m) =>
                StudentRegistryService.classNamesMatch(m.className, pair.className) &&
                m.subject.trim().toLowerCase() == pair.subject.toLowerCase(),
          )
          .toList();
      final papers = ExamService.instance
          .papersForSchool(schoolId)
          .where(
            (p) =>
                StudentRegistryService.classNamesMatch(p.className, pair.className) &&
                p.subject.trim().toLowerCase() == pair.subject.toLowerCase(),
          )
          .toList();
      LessonPlan? online;
      for (final plan in plans) {
        if (plan.hasOnlineSession && plan.isPublished) {
          online = plan;
          break;
        }
      }
      rows.add(
        LmsCourseSnapshot(
          className: pair.className,
          subject: pair.subject,
          lessonPlans: plans.length,
          homework: homework.length,
          materials: materials.length,
          examPapers: papers.length,
          submittedWorksheets: homework.fold<int>(
            0,
            (sum, item) => sum + item.submittedStudentCount,
          ),
          examAttempts: papers.fold<int>(
            0,
            (sum, paper) =>
                sum +
                ExamService.instance
                    .attemptsForPaper(paper.id)
                    .where((a) => a.status != ExamAttemptStatus.inProgress)
                    .length,
          ),
          rosterSize: StudentRegistryService.instance
              .studentsForClass(pair.className)
              .length,
          onlinePlan: online,
        ),
      );
    }
    rows.sort((a, b) {
      final byClass = a.className.compareTo(b.className);
      return byClass != 0 ? byClass : a.subject.compareTo(b.subject);
    });
    return rows;
  }
}
