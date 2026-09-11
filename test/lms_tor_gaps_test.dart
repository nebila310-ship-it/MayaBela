import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/lms_classroom_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LessonPlanService.resetForTests();
    ExamService.resetForTests();
    AuthService.currentUser = null;
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('LessonPlan serializes live and recorded class links', () {
    final week = LessonPlan.mondayOf(DateTime.utc(2026, 9, 7));
    final plan = LessonPlan(
      id: 'LP-LMS-1',
      schoolId: 'TB-001',
      title: 'Spoken English',
      className: 'Grade 4A',
      subject: 'English',
      weekStart: week,
      createdAt: week,
      updatedAt: week,
      status: LessonPlanStatus.published,
      onlineSessionUrl: 'https://meet.example.com/room-4a',
      onlineSessionLabel: 'Live spoken English',
      onlineSessionIsLive: true,
    );

    expect(plan.hasOnlineSession, isTrue);
    final restored = LessonPlan.fromMap(plan.toMap());
    expect(restored.onlineSessionUrl, 'https://meet.example.com/room-4a');
    expect(restored.onlineSessionLabel, 'Live spoken English');
    expect(restored.onlineSessionIsLive, isTrue);
    expect(restored.hasOnlineSession, isTrue);
  });

  test('HomeworkItem serializes due date and submitted worksheet count', () {
    final item = HomeworkItem(
      id: 'hw-lms-1',
      className: 'Grade 4A',
      subject: 'English',
      description: 'Read chapter 2',
      teacherName: 'Ms Hana',
      teacherId: 'TCH-1',
      postedAt: DateTime.utc(2026, 9, 10),
      dueDate: DateTime.utc(2026, 9, 14),
      studentWorksheetPaths: const {
        'STU-1': ['ws/1.pdf'],
        'STU-2': ['ws/2.pdf'],
      },
    );

    expect(item.submittedStudentCount, 2);
    final restored = HomeworkItemPersistence.fromMap(item.toMap());
    expect(restored.dueDate, DateTime.utc(2026, 9, 14));
    expect(restored.submittedStudentCount, 2);
  });

  test('Class discussion reuses the same named group conversation', () {
    SchoolDataService.instance.applyPersistedConversations([
      Conversation(
        id: 'existing-forum',
        name: 'LMS Forum 4A class discussion',
        role: 'Group',
        isGroup: true,
        usesCustomGroupName: true,
        messages: const [],
      ),
    ]);

    final first = LmsClassroomService.instance
        .ensureClassDiscussion('LMS Forum 4A');
    final second = LmsClassroomService.instance
        .ensureClassDiscussion('LMS Forum 4A');

    expect(first, 'existing-forum');
    expect(second, 'existing-forum');
    expect(
      SchoolDataService.instance
          .getConversations()
          .where(
            (c) =>
                c.isGroup &&
                c.name.toLowerCase() == 'lms forum 4a class discussion',
          )
          .length,
      1,
    );
  });

  test('Empty classes still get separate discussion rooms', () {
    final a = LmsClassroomService.instance.ensureClassDiscussion('LMS Empty A');
    final b = LmsClassroomService.instance.ensureClassDiscussion('LMS Empty B');
    expect(a, isNot(b));
    expect(
      SchoolDataService.instance.getConversation(a)?.name,
      'LMS Empty A class discussion',
    );
    expect(
      SchoolDataService.instance.getConversation(b)?.name,
      'LMS Empty B class discussion',
    );
  });

  test('LMS course snapshot aggregates class+subject and engagement counts',
      () async {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.lms',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-LMS',
      fullName: 'Ms Hana',
    );

    final plan = await LessonPlanService.instance.createPlan(
      title: 'Spoken English',
      className: 'LMS Tor 4A',
      subject: 'Spoken English',
      schoolId: 'TB-LMS',
      onlineSessionUrl: 'https://meet.example.com/4a',
      onlineSessionLabel: 'Join live English',
      onlineSessionIsLive: true,
    );
    await LessonPlanService.instance.setStatus(
      plan.id,
      LessonPlanStatus.published,
    );

    SchoolDataService.instance.addHomework(
      className: 'LMS Tor 4A',
      subject: 'Spoken English',
      description: 'Worksheet 3',
      teacherName: 'Ms Hana',
      teacherId: 'TCH-LMS',
      dueDate: DateTime.utc(2026, 9, 14),
    );
    final homework = SchoolDataService.instance
        .getHomeworkForClass('LMS Tor 4A')
        .firstWhere((h) => h.subject == 'Spoken English');
    SchoolDataService.instance.addStudentWorksheets(
      homeworkId: homework.id,
      studentId: 'STU-LMS-1',
      paths: const ['ws/1.pdf'],
    );

    final paper = await ExamService.instance.createPaper(
      title: 'English quiz',
      className: 'LMS Tor 4A',
      subject: 'Spoken English',
      schoolId: 'TB-LMS',
    );
    await ExamService.instance.setPaperStatus(
      paper.id,
      ExamPaperStatus.published,
    );
    final attempt = await ExamService.instance.startAttempt(
      paperId: paper.id,
      studentName: 'Abel',
      studentId: 'STU-LMS-1',
      className: 'LMS Tor 4A',
      schoolId: 'TB-LMS',
    );
    await ExamService.instance.submitAttempt(attempt.id);

    final courses = LmsClassroomService.instance.coursesForSchool('TB-LMS');
    final english = courses.firstWhere(
      (c) => c.className == 'LMS Tor 4A' && c.subject == 'Spoken English',
    );
    expect(english.lessonPlans, 1);
    expect(english.homework, 1);
    expect(english.examPapers, 1);
    expect(english.submittedWorksheets, 1);
    expect(english.examAttempts, 1);
    expect(english.onlinePlan?.onlineSessionUrl, 'https://meet.example.com/4a');
  });

  test('LMS hub rides academic access, not a new Course entity', () {
    AuthService.currentUser = RegisteredUser(
      username: 'admin.lms',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    expect(ModuleAccess.normalize('lms'), 'academic');
    expect(ModuleAccess.canView('lms'), isTrue);
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    expect(ids, contains('lms'));
    expect(ids, contains('lesson_plans'));
  });
}
