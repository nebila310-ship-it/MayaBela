import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/discipline_case.dart';
import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/discipline_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String read(String path) => File(path).readAsStringSync();

  void signIn({
    required String username,
    required String roleKey,
    List<String> staffRoles = const [],
    String? fullName,
  }) {
    AuthService.currentUser = RegisteredUser(
      username: username,
      password: 'x',
      roleKey: roleKey,
      schoolId: 'TB-001',
      fullName: fullName ?? username,
      staffRoles: staffRoles,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    NotificationService.instance.resetForTests();
    DisciplineService.instance.resetForTests();
    ExamService.resetForTests();
  });

  tearDown(() {
    AuthService.currentUser = null;
    NotificationService.instance.resetForTests();
    DisciplineService.instance.resetForTests();
    ExamService.resetForTests();
  });

  test('VP and Section Director can manage the web homework desk', () {
    signIn(
      username: 'vp.p2',
      roleKey: AuthService.roleTeacher,
      staffRoles: const [StaffRoles.vicePresident],
    );
    expect(ModuleAccess.canView('homework'), isTrue);
    expect(ModuleAccess.canManage('homework'), isTrue);

    signIn(
      username: 'sd.p2',
      roleKey: AuthService.roleTeacher,
      staffRoles: const [StaffRoles.sectionDirector],
    );
    expect(ModuleAccess.canView('homework'), isTrue);
    expect(ModuleAccess.canManage('homework'), isTrue);
  });

  test('homework scores, comments, reminders, and markbook push', () {
    const className = 'Grade 8P2';
    const subject = 'Phase2 Science';
    const studentName = 'Phase Two Kidus';
    const studentId = 'STU-P2HW';

    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: studentId,
        fullName: studentName,
        grade: 'Grade 8',
        className: className,
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2013, 3, 3),
      ),
    ]);

    signIn(username: 'teacher.p2', roleKey: AuthService.roleTeacher);
    SchoolDataService.instance.addHomework(
      className: className,
      subject: subject,
      description: 'Read pages 12–14',
      teacherName: 'Ms Hana',
      teacherId: 'TCH-P2',
      dueDate: DateTime(2026, 10, 4),
    );
    final posted = SchoolDataService.instance
        .getHomeworkForClass(className)
        .firstWhere((h) => h.subject == subject);

    expect(
      SchoolDataService.instance.recordHomeworkScore(
        homeworkId: posted.id,
        studentId: studentId,
        score: 88,
      ),
      isTrue,
    );
    expect(posted.studentScores[studentId], 88);

    NotificationService.instance.resetForTests();
    expect(
      SchoolDataService.instance.commentOnHomework(
        homeworkId: posted.id,
        studentId: studentId,
        comment: 'Show your working.',
      ),
      isTrue,
    );
    expect(posted.teacherComments[studentId], 'Show your working.');
    final notes = NotificationService.instance.itemsForTests();
    expect(
      notes.any(
        (n) =>
            n.title.contains('Homework comment') &&
            n.targetStudentId == studentId &&
            n.body.contains('Show your working.'),
      ),
      isTrue,
    );

    expect(
      SchoolDataService.instance.pushHomeworkScoreToMarkbook(
        homeworkId: posted.id,
        studentId: studentId,
        teacherId: 'TCH-P2',
      ),
      isTrue,
    );
    final grade = SchoolDataService.instance
        .getGradeReportForStudent(studentName)!
        .subjects
        .firstWhere((s) => s.subject == subject);
    expect(
      grade.assessments.any((m) => m.categoryId == 'homework' && m.score == 88),
      isTrue,
    );

    final dueToday = HomeworkItem(
      id: 'HW-P2-DUE',
      className: className,
      subject: 'Phase2 Maths',
      description: 'Worksheet 3',
      teacherName: 'Ms Hana',
      teacherId: 'TCH-P2',
      postedAt: DateTime(2026, 10, 1),
      dueDate: DateTime(2026, 10, 4),
    );
    final overdue = HomeworkItem(
      id: 'HW-P2-LATE',
      className: className,
      subject: 'Phase2 English',
      description: 'Essay draft',
      teacherName: 'Ms Hana',
      teacherId: 'TCH-P2',
      postedAt: DateTime(2026, 9, 20),
      dueDate: DateTime(2026, 10, 1),
    );
    SchoolDataService.instance.applyPersistedHomework([dueToday, overdue]);
    NotificationService.instance.resetForTests();
    final sent = SchoolDataService.instance.publishHomeworkReminders(
      now: DateTime(2026, 10, 4, 9),
    );
    expect(sent, greaterThanOrEqualTo(2));
    expect(
      SchoolDataService.instance.homeworkById('HW-P2-DUE')!.dueReminderSent,
      isTrue,
    );
    expect(
      SchoolDataService.instance.homeworkById('HW-P2-LATE')!.overdueReminderSent,
      isTrue,
    );
    final reminders = NotificationService.instance.itemsForTests();
    expect(
      reminders.any((n) => n.title == 'Homework due today — Phase2 Maths'),
      isTrue,
    );
    expect(
      reminders.any((n) => n.title == 'Homework overdue — Phase2 English'),
      isTrue,
    );
    expect(
      SchoolDataService.instance.publishHomeworkReminders(
        now: DateTime(2026, 10, 4, 10),
      ),
      0,
    );
  });

  test('homework item round-trips scores, comments, and reminder flags', () {
    final item = HomeworkItem(
      id: 'HW-P2-MAP',
      className: 'Grade 8P2',
      subject: 'Art',
      description: 'Sketch',
      teacherName: 'Ms Hana',
      teacherId: 'TCH-P2',
      postedAt: DateTime.utc(2026, 10, 1),
      dueDate: DateTime.utc(2026, 10, 5),
      studentScores: const {'STU-P2HW': 91},
      teacherComments: const {'STU-P2HW': 'Great line work'},
      dueReminderSent: true,
    );
    final restored = HomeworkItemPersistence.fromMap(item.toMap());
    expect(restored.studentScores['STU-P2HW'], 91);
    expect(restored.teacherComments['STU-P2HW'], 'Great line work');
    expect(restored.dueReminderSent, isTrue);
    expect(restored.overdueReminderSent, isFalse);
  });

  test('offline papers reject portal sits and accept a staff percent', () async {
    SchoolRegistryService.instance.applyPersistedSchools([
      SchoolRecord(
        id: 'TB-001',
        name: 'Test School',
        gradeLevels: const ['Grade 8'],
        sections: const ['Grade 8P2'],
      ),
    ]);
    signIn(username: 'teacher.exam', roleKey: AuthService.roleTeacher);

    final paper = await ExamService.instance.createPaper(
      title: 'National mock offline',
      className: 'Grade 8P2',
      subject: 'Phase2 Science',
      questionIds: const [],
      markbookCategoryId: 'final',
      sittingMode: ExamSittingMode.offline,
      schoolId: 'TB-001',
    );
    expect(paper.isOnlineSit, isFalse);

    await expectLater(
      ExamService.instance.startAttempt(
        paperId: paper.id,
        studentName: 'Phase Two Kidus',
        className: 'Grade 8P2',
        schoolId: 'TB-001',
      ),
      throwsA(isA<StateError>()),
    );

    final scored = await ExamService.instance.recordStaffOfflineResult(
      paperId: paper.id,
      studentName: 'Phase Two Kidus',
      percent: 76,
      studentId: 'STU-P2HW',
      className: 'Grade 8P2',
    );
    expect(scored.status, ExamAttemptStatus.scored);
    expect(scored.percent, 76);
    expect(scored.studentId, 'STU-P2HW');

    final online = await ExamService.instance.createPaper(
      title: 'Portal sit',
      className: 'Grade 8P2',
      subject: 'Phase2 Science',
      questionIds: const [],
      sittingMode: ExamSittingMode.online,
      schoolId: 'TB-001',
    );
    await expectLater(
      ExamService.instance.recordStaffOfflineResult(
        paperId: online.id,
        studentName: 'Phase Two Kidus',
        percent: 50,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('discipline hearing lands on the staff calendar', () async {
    signIn(
      username: 'sa.p2',
      roleKey: AuthService.roleTeacher,
      fullName: 'Student Affairs',
      staffRoles: const [StaffRoles.studentAffairs],
    );
    final filed = await DisciplineService.instance.fileReport(
      studentId: 'STU-P2HW',
      studentName: 'Phase Two Kidus',
      className: 'Grade 8P2',
      kind: DisciplineCaseKind.incident,
      title: 'Phase2 hallway push',
      description: 'Pushed a classmate in the corridor',
    );
    final hearingAt = DateTime(2026, 10, 8);
    final scheduled = await DisciplineService.instance.scheduleHearing(
      filed.id,
      hearingAt: hearingAt,
      inviteParent: true,
    );
    expect(scheduled?.status, DisciplineCaseStatus.hearingScheduled);
    expect(scheduled?.hearingAt, hearingAt);
    expect(scheduled?.calendarEventId, isNotEmpty);
    expect(scheduled?.parentInvited, isTrue);

    final event = SchoolDataService.instance.getCalendarEvents().firstWhere(
      (e) => e.id == scheduled!.calendarEventId,
    );
    expect(event.audience, 'staff');
    expect(event.type, CalendarEventType.meeting);
    expect(event.title, contains('Phase Two Kidus'));
    expect(event.date, DateTime(2026, 10, 8));
    expect(
      SchoolDataService.instance.calendarEventVisibleToRole(
        event,
        AuthService.roleTeacher,
      ),
      isTrue,
    );
    expect(
      SchoolDataService.instance.calendarEventVisibleToRole(
        event,
        AuthService.roleParent,
      ),
      isFalse,
    );

    final copy = DisciplineCase.fromMap(scheduled!.toMap());
    expect(copy.calendarEventId, scheduled.calendarEventId);
  });

  test('web desks call the new daily-loop service APIs', () {
    final homework = read('lib/web_erp/pages/web_homework_page.dart');
    expect(homework, contains('recordHomeworkScore'));
    expect(homework, contains('pushHomeworkScoreToMarkbook'));
    expect(homework, contains('publishHomeworkReminders'));
    expect(homework, contains('Post homework'));

    final exam = read('lib/web_erp/pages/web_exam_desk_page.dart');
    expect(exam, contains('recordStaffOfflineResult'));
    expect(exam, contains('_offlineRoster'));
    expect(exam, contains('Enter %'));

    final affairs = read('lib/web_erp/pages/web_student_affairs_page.dart');
    expect(affairs, contains('scheduleHearing'));
    expect(affairs.contains('status: DisciplineCaseStatus.hearingScheduled'), isFalse);

    final teacherHw = read('lib/screens/homework_screen.dart');
    expect(teacherHw, contains('recordHomeworkScore'));
    expect(teacherHw, contains('commentOnHomework'));
    expect(teacherHw, contains('pushHomeworkScoreToMarkbook'));
  });
}
