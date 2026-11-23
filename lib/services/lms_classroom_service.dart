import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/enrollment_service.dart';
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

enum LmsFeedKind { lesson, homework, material, exam }

class LmsFeedItem {
  const LmsFeedItem({
    required this.kind,
    required this.title,
    required this.at,
    this.subtitle = '',
  });

  final LmsFeedKind kind;
  final String title;
  final DateTime at;
  final String subtitle;
}

class LmsLateWorkRow {
  const LmsLateWorkRow({
    required this.className,
    required this.subject,
    required this.homeworkTitle,
    required this.studentName,
    required this.dueDate,
    this.studentId,
  });

  final String className;
  final String subject;
  final String homeworkTitle;
  final String studentName;
  final String? studentId;
  final DateTime dueDate;
}

/// Reuses lesson plans, homework, exams, materials, and group chat.
class LmsClassroomService {
  LmsClassroomService._();
  static final instance = LmsClassroomService._();

  static String discussionTitle(String className) =>
      '${className.trim()} class discussion';

  String ensureClassDiscussion(String className) {
    final title = discussionTitle(className);
    final students = StudentRegistryService.instance.studentsForClass(className);
    final parentNames = <String>{};
    final parentUsernames = <String>{};
    final studentIds = students.map((s) => s.studentId.toUpperCase()).toSet();
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
    EnrollmentService.instance.ensureSeeded();
    for (final link in EnrollmentService.instance.allLinksSnapshot()) {
      if (link.status != ParentLinkStatus.approved) continue;
      if (!studentIds.contains(link.studentId.trim().toUpperCase())) continue;
      final username = link.parentUsername.trim();
      if (username.isNotEmpty) parentUsernames.add(username);
      final fullName = link.parentFullName.trim();
      if (fullName.isNotEmpty) parentNames.add(fullName);
    }

    final staffIds = <String>{};
    for (final teacher in TeacherRegistryService.instance.visibleTeachers()) {
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
      parentParticipantUsernames: parentUsernames.toList()..sort(),
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
    for (final item in SchoolDataService.instance.homeworkForSchool(schoolId)) {
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

  List<LmsFeedItem> courseFeed({
    required String className,
    required String subject,
    String? schoolId,
  }) {
    final subjectKey = subject.trim().toLowerCase();
    final items = <LmsFeedItem>[];
    for (final plan in LessonPlanService.instance.forSchool(schoolId)) {
      if (!StudentRegistryService.classNamesMatch(plan.className, className)) {
        continue;
      }
      if (plan.subject.trim().toLowerCase() != subjectKey) continue;
      items.add(
        LmsFeedItem(
          kind: LmsFeedKind.lesson,
          title: plan.title.trim().isEmpty ? 'Lesson plan' : plan.title.trim(),
          subtitle: plan.periodLabel.trim().isEmpty
              ? 'Lesson'
              : plan.periodLabel.trim(),
          at: plan.weekStart,
        ),
      );
    }
    for (final homework
        in SchoolDataService.instance.getHomeworkForClass(className)) {
      if (homework.subject.trim().toLowerCase() != subjectKey) continue;
      items.add(
        LmsFeedItem(
          kind: LmsFeedKind.homework,
          title: homework.displayTitle,
          subtitle: homework.dueDate == null
              ? 'Homework'
              : 'Due ${homework.dueDate!.day}/${homework.dueDate!.month}',
          at: homework.dueDate ?? homework.postedAt,
        ),
      );
    }
    for (final material
        in SchoolDataService.instance.learningMaterialsSnapshot()) {
      if (!StudentRegistryService.classNamesMatch(
        material.className,
        className,
      )) {
        continue;
      }
      if (material.subject.trim().toLowerCase() != subjectKey) continue;
      items.add(
        LmsFeedItem(
          kind: LmsFeedKind.material,
          title: material.materialName.trim().isEmpty
              ? material.bookName
              : material.materialName,
          subtitle: 'Material',
          at: material.postedAt,
        ),
      );
    }
    for (final paper in ExamService.instance.papersForSchool(schoolId)) {
      if (!StudentRegistryService.classNamesMatch(paper.className, className)) {
        continue;
      }
      if (paper.subject.trim().toLowerCase() != subjectKey) continue;
      items.add(
        LmsFeedItem(
          kind: LmsFeedKind.exam,
          title: paper.title,
          subtitle: paper.room.trim().isEmpty
              ? 'Exam paper'
              : 'Room ${paper.room}',
          at: paper.startAt ?? paper.createdAt,
        ),
      );
    }
    items.sort((a, b) => b.at.compareTo(a.at));
    return items;
  }

  List<LmsLateWorkRow> lateWorkInbox({
    String? schoolId,
    String? className,
    String? subject,
  }) {
    final classFilter = className?.trim();
    final subjectKey = subject?.trim().toLowerCase();
    final rows = <LmsLateWorkRow>[];
    for (final homework
        in SchoolDataService.instance.homeworkForSchool(schoolId)) {
      if (!homework.isOverdue) continue;
      if (classFilter != null &&
          classFilter.isNotEmpty &&
          !StudentRegistryService.classNamesMatch(
            homework.className,
            classFilter,
          )) {
        continue;
      }
      if (subjectKey != null &&
          subjectKey.isNotEmpty &&
          homework.subject.trim().toLowerCase() != subjectKey) {
        continue;
      }
      final roster = StudentRegistryService.instance.studentsForClass(
        homework.className,
        schoolId: schoolId,
      );
      for (final student in roster) {
        final worksheets = homework.worksheetsForStudent(student.studentId);
        final scored = homework.studentScores.containsKey(
              student.studentId.trim().toUpperCase(),
            ) ||
            homework.studentScores.containsKey(student.studentId);
        if (worksheets.isNotEmpty || scored) continue;
        rows.add(
          LmsLateWorkRow(
            className: homework.className,
            subject: homework.subject,
            homeworkTitle: homework.displayTitle,
            studentName: student.fullName,
            studentId: student.studentId,
            dueDate: homework.dueDate ?? homework.postedAt,
          ),
        );
      }
    }
    rows.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return rows;
  }
}
