import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/models/notification_preference.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/notification_preference_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_items.dart';
import 'package:mayabela/widgets/inbox_login_reminder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NotificationService.instance.clearForLogout();
    NotificationService.instance.resetForTests();
    NotificationPreferenceService.instance.resetForTests();
    DashboardBadgeService.instance.clearForLogout();
    LessonPlanService.resetForTests();
    await InboxLoginReminder.resetForTests();
    AuthService.currentUser = null;
    StudentRegistryService.instance.applyPersistedStudents(
      const [],
      replace: true,
    );
  });

  tearDown(() async {
    AuthService.currentUser = null;
    NotificationService.instance.clearForLogout();
    NotificationService.instance.resetForTests();
    NotificationPreferenceService.instance.resetForTests();
    DashboardBadgeService.instance.clearForLogout();
    LessonPlanService.resetForTests();
    await InboxLoginReminder.resetForTests();
    StudentRegistryService.instance.applyPersistedStudents(
      const [],
      replace: true,
    );
  });

  void seedStudent({
    String id = 'STU-NTFY-1',
    String className = 'Grade 4A',
  }) {
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: id,
        fullName: 'Notify Kid',
        grade: '4',
        className: className,
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2016, 5, 1),
      ),
    ], replace: true);
  }

  void signIn({
    required String username,
    required String roleKey,
    List<String> linkedStudentIds = const [],
  }) {
    AuthService.currentUser = RegisteredUser(
      username: username,
      password: 'x',
      roleKey: roleKey,
      schoolId: 'TB-001',
      fullName: username,
      linkedStudentIds: linkedStudentIds,
    );
  }

  test('parent, teacher, and admin settings include the eight login actions', () {
    const needed = {
      NotificationPreferenceKey.messages,
      NotificationPreferenceKey.homework,
      NotificationPreferenceKey.lessonPlans,
      NotificationPreferenceKey.attendance,
      NotificationPreferenceKey.dailyActivity,
      NotificationPreferenceKey.grades,
      NotificationPreferenceKey.announcements,
      NotificationPreferenceKey.calendar,
    };
    for (final role in [
      AuthService.roleParent,
      AuthService.roleTeacher,
      AuthService.roleAdmin,
    ]) {
      expect(
        NotificationPreferenceService.keysForRole(role).toSet(),
        containsAll(needed),
        reason: role,
      );
    }
  });

  test('admin homework and lesson-plan sidebar items carry tile badges', () {
    expect(
      webErpAllNavItems.firstWhere((item) => item.id == 'homework').badgeId,
      'homework',
    );
    expect(
      webErpAllNavItems
          .firstWhere((item) => item.id == 'lesson_plans')
          .badgeId,
      'lesson_plans',
    );
  });

  test('publishing a lesson plan notifies parent, teacher, and admin', () async {
    seedStudent();
    signIn(username: 'admin.plans', roleKey: AuthService.roleAdmin);
    final plan = await LessonPlanService.instance.createPlan(
      title: 'Week 3 science',
      className: 'Grade 4A',
      subject: 'Science',
      schoolId: 'TB-001',
    );
    await LessonPlanService.instance.setStatus(
      plan.id,
      LessonPlanStatus.published,
    );

    final notes = NotificationService.instance.itemsForTests().where(
      (n) =>
          n.type == NotificationType.lessonPlan &&
          n.title.contains('Science'),
    );
    expect(
      notes.map((n) => n.recipientRole).toSet(),
      containsAll({
        AuthService.roleParent,
        AuthService.roleTeacher,
        AuthService.roleAdmin,
      }),
    );

    signIn(
      username: 'parent.plans',
      roleKey: AuthService.roleParent,
      linkedStudentIds: const ['STU-NTFY-1'],
    );
    expect(DashboardBadgeService.instance.countFor('lesson_plans'), 1);

    signIn(username: 'teacher.plans', roleKey: AuthService.roleTeacher);
    expect(DashboardBadgeService.instance.countFor('lesson_plans'), 1);

    signIn(username: 'admin.plans', roleKey: AuthService.roleAdmin);
    expect(DashboardBadgeService.instance.countFor('lesson_plans'), 1);
  });

  test('homework, attendance, daily activity, grades, announcements, and calendar notify PTA',
      () {
    seedStudent();
    signIn(username: 'teacher.act', roleKey: AuthService.roleTeacher);

    SchoolDataService.instance.addHomework(
      className: 'Grade 4A',
      subject: 'Math',
      description: 'Page 12',
      teacherName: 'Miss Belen',
      teacherId: 'TCH-1001',
    );
    SchoolDataService.instance.saveAttendanceSession(
      className: 'Grade 4A',
      date: DateTime.now(),
      conductedBy: 'Miss Belen',
      entries: [
        StudentAttendanceEntry(
          studentName: 'Notify Kid',
          studentId: 'STU-NTFY-1',
          status: AttendanceStatus.present,
        ),
      ],
    );
    SchoolDataService.instance.saveDailyActivity(
      studentId: 'STU-NTFY-1',
      studentName: 'Notify Kid',
      className: 'Grade 4A',
      date: DateTime.now(),
      selectedOptionIds: const [],
      teacherComment: 'Great day',
      teacherName: 'Miss Belen',
    );

    signIn(username: 'admin.act', roleKey: AuthService.roleAdmin);
    SchoolDataService.instance.addAnnouncement(
      title: 'Sports day',
      body: 'Bring kits',
      author: 'Office',
      audience: 'All',
    );
    SchoolDataService.instance.scheduleCalendarEvent(
      title: 'Parent meeting',
      description: 'Hall',
      date: DateTime(2026, 10, 20),
      type: CalendarEventType.meeting,
      audience: 'All',
      autoAnnounce: false,
    );

    NotificationService.instance.push(
      title: 'Math report published',
      body: 'Notify Kid scored 90 in Math.',
      type: NotificationType.grade,
      fromRole: AuthService.roleTeacher,
      fromName: 'Miss Belen',
      recipientRole: AuthService.roleParent,
      targetClassName: 'Grade 4A',
      targetStudentId: 'STU-NTFY-1',
      showOnMessagesBadge: false,
    );
    NotificationService.instance.push(
      title: 'Math report published',
      body: 'Notify Kid scored 90 in Math.',
      type: NotificationType.grade,
      fromRole: AuthService.roleTeacher,
      fromName: 'Miss Belen',
      recipientRole: AuthService.roleAdmin,
      targetClassName: 'Grade 4A',
      showOnMessagesBadge: false,
    );

    bool hasType(NotificationType type, String role) {
      return NotificationService.instance.itemsForTests().any(
        (n) => n.type == type && n.recipientRole == role,
      );
    }

    for (final role in [
      AuthService.roleParent,
      AuthService.roleTeacher,
      AuthService.roleAdmin,
    ]) {
      expect(hasType(NotificationType.homework, role), isTrue, reason: 'hw $role');
      expect(
        hasType(NotificationType.attendance, role),
        isTrue,
        reason: 'att $role',
      );
      expect(
        hasType(NotificationType.dailyActivity, role),
        isTrue,
        reason: 'act $role',
      );
      expect(
        hasType(NotificationType.announcement, role),
        isTrue,
        reason: 'ann $role',
      );
      expect(
        hasType(NotificationType.calendar, role),
        isTrue,
        reason: 'cal $role',
      );
    }
    expect(hasType(NotificationType.grade, AuthService.roleParent), isTrue);
    expect(hasType(NotificationType.grade, AuthService.roleAdmin), isTrue);

    signIn(
      username: 'parent.act',
      roleKey: AuthService.roleParent,
      linkedStudentIds: const ['STU-NTFY-1'],
    );
    expect(DashboardBadgeService.instance.countFor('homework'), greaterThan(0));
    expect(
      DashboardBadgeService.instance.countFor('attendance'),
      greaterThan(0),
    );
    expect(
      DashboardBadgeService.instance.countFor('daily_activities'),
      greaterThan(0),
    );
    expect(DashboardBadgeService.instance.countFor('grades'), greaterThan(0));
    expect(
      DashboardBadgeService.instance.countFor('announcements'),
      greaterThan(0),
    );
    expect(DashboardBadgeService.instance.countFor('calendar'), greaterThan(0));
  });

  test('turning a category off in settings skips the push', () async {
    seedStudent();
    await NotificationPreferenceService.instance.setEnabled(
      AuthService.roleParent,
      NotificationPreferenceKey.homework,
      false,
    );
    signIn(username: 'teacher.off', roleKey: AuthService.roleTeacher);
    SchoolDataService.instance.addHomework(
      className: 'Grade 4A',
      subject: 'Math',
      description: 'Silent work',
      teacherName: 'Miss Belen',
      teacherId: 'TCH-1001',
    );

    expect(
      NotificationService.instance.itemsForTests().where(
        (n) =>
            n.type == NotificationType.homework &&
            n.recipientRole == AuthService.roleParent &&
            n.body.contains('Silent work'),
      ),
      isEmpty,
    );

    signIn(
      username: 'parent.off',
      roleKey: AuthService.roleParent,
      linkedStudentIds: const ['STU-NTFY-1'],
    );
    expect(DashboardBadgeService.instance.countFor('homework'), 0);
  });

  testWidgets('homework login toast does not repeat and leaves the tile badge',
      (tester) async {
    seedStudent();
    signIn(username: 'teacher.toast', roleKey: AuthService.roleTeacher);
    NotificationService.instance.push(
      title: 'New homework — Math',
      body: 'Miss Belen: Page 12',
      type: NotificationType.homework,
      fromRole: AuthService.roleTeacher,
      fromName: 'Miss Belen',
      recipientRole: AuthService.roleParent,
      targetClassName: 'Grade 4A',
      showOnMessagesBadge: false,
    );

    signIn(
      username: 'parent.toast',
      roleKey: AuthService.roleParent,
      linkedStudentIds: const ['STU-NTFY-1'],
    );
    expect(DashboardBadgeService.instance.countFor('homework'), greaterThan(0));
    final unread = DashboardBadgeService.instance.countForLoginActions();
    expect(unread, greaterThan(0));

    Widget reminder() => MaterialApp(
      home: InboxLoginReminder(
        child: Scaffold(
          body: Text(AppLocale.instance.strings.notifyHomework),
        ),
      ),
    );

    await tester.pumpWidget(reminder());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('inbox-login-reminder')), findsOneWidget);
    expect(
      find.text(AppLocale.instance.strings.loginSchoolUpdatesOnLogin(unread)),
      findsOneWidget,
    );
    expect(DashboardBadgeService.instance.countFor('homework'), unread);

    await tester.pump(InboxLoginReminder.displayDuration);
    await tester.pump();
    expect(find.byKey(const Key('inbox-login-reminder')), findsNothing);
    expect(DashboardBadgeService.instance.countFor('homework'), unread);

    InboxLoginReminder.reset();
    await tester.pumpWidget(reminder());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('inbox-login-reminder')), findsNothing);
    expect(DashboardBadgeService.instance.countFor('homework'), unread);

    DashboardBadgeService.instance.markReadForTile('homework');
    expect(DashboardBadgeService.instance.countFor('homework'), 0);
  });
}
