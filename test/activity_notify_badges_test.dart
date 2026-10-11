import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/lms_classroom_service.dart';
import 'package:mayabela/services/notification_preference_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.instance.clearForLogout();
    NotificationService.instance.resetForTests();
    NotificationPreferenceService.instance.resetForTests();
    DashboardBadgeService.instance.clearForLogout();
    SchoolDataService.instance.resetActivityNotifyStateForTests();
    AuthService.currentUser = null;
    StudentRegistryService.instance.applyPersistedStudents(
      const [],
      replace: true,
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
    NotificationService.instance.clearForLogout();
    NotificationService.instance.resetForTests();
    NotificationPreferenceService.instance.resetForTests();
    DashboardBadgeService.instance.clearForLogout();
    SchoolDataService.instance.resetActivityNotifyStateForTests();
    StudentRegistryService.instance.applyPersistedStudents(
      const [],
      replace: true,
    );
  });

  void seedStudent({
    String id = 'STU-ACT-1',
    String className = 'Grade 4N-ACT',
  }) {
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: id,
        fullName: 'Activity Kid',
        grade: '4',
        className: className,
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2016, 5, 1),
        fatherName: 'Parent Act',
      ),
    ], replace: true);
  }

  void signIn({
    required String username,
    required String roleKey,
    List<String> linkedStudentIds = const [],
    String? linkedStudentId,
    String? linkedTeacherId,
    String? fullName,
  }) {
    AuthService.currentUser = RegisteredUser(
      username: username,
      password: 'x',
      roleKey: roleKey,
      schoolId: 'TB-001',
      fullName: fullName ?? username,
      linkedStudentIds: linkedStudentIds,
      linkedStudentId: linkedStudentId,
      linkedTeacherId: linkedTeacherId,
    );
  }

  bool hasType(NotificationType type, String role) {
    return NotificationService.instance.itemsForTests().any(
      (n) => n.type == type && n.recipientRole == role,
    );
  }

  test('new homework notifies parent, student, and increments badges', () {
    seedStudent();
    signIn(username: 'teacher.act', roleKey: AuthService.roleTeacher);

    SchoolDataService.instance.addHomework(
      className: 'Grade 4N-ACT',
      subject: 'Math',
      description: 'Page 12 fractions',
      teacherName: 'Miss Belen',
      teacherId: 'TCH-1001',
    );

    expect(hasType(NotificationType.homework, AuthService.roleParent), isTrue);
    expect(hasType(NotificationType.homework, AuthService.roleStudent), isTrue);
    expect(hasType(NotificationType.homework, AuthService.roleTeacher), isTrue);
    expect(hasType(NotificationType.homework, AuthService.roleAdmin), isTrue);

    signIn(
      username: 'parent.act',
      roleKey: AuthService.roleParent,
      linkedStudentIds: const ['STU-ACT-1'],
    );
    expect(DashboardBadgeService.instance.countFor('homework'), greaterThan(0));

    signIn(
      username: 'student.act',
      roleKey: AuthService.roleStudent,
      linkedStudentId: 'STU-ACT-1',
    );
    final studentBadge = DashboardBadgeService.instance.countFor('homework');
    expect(studentBadge, greaterThan(0));

    DashboardBadgeService.instance.markReadForTile('homework');
    expect(DashboardBadgeService.instance.countFor('homework'), 0);
  });

  test('new daily activity notifies parent, student, and increments badges', () {
    seedStudent();
    signIn(username: 'teacher.act', roleKey: AuthService.roleTeacher);

    SchoolDataService.instance.saveDailyActivity(
      studentId: 'STU-ACT-1',
      studentName: 'Activity Kid',
      className: 'Grade 4N-ACT',
      date: DateTime.now(),
      selectedOptionIds: const [],
      teacherComment: 'Great sharing today',
      teacherName: 'Miss Belen',
    );

    expect(
      hasType(NotificationType.dailyActivity, AuthService.roleParent),
      isTrue,
    );
    expect(
      hasType(NotificationType.dailyActivity, AuthService.roleStudent),
      isTrue,
    );

    signIn(
      username: 'parent.act',
      roleKey: AuthService.roleParent,
      linkedStudentIds: const ['STU-ACT-1'],
    );
    expect(
      DashboardBadgeService.instance.countFor('daily_activities'),
      greaterThan(0),
    );

    signIn(
      username: 'student.act',
      roleKey: AuthService.roleStudent,
      linkedStudentId: 'STU-ACT-1',
    );
    expect(
      DashboardBadgeService.instance.countFor('daily_activities'),
      greaterThan(0),
    );
  });

  test('class discussion posts notify parent and student tiles', () {
    seedStudent();
    signIn(
      username: 'teacher.talk',
      roleKey: AuthService.roleTeacher,
      fullName: 'Miss Belen',
      linkedTeacherId: 'TCH-ACT',
    );

    LmsClassroomService.instance.ensureClassDiscussion('Grade 4N-ACT');
    SchoolDataService.instance.applyPersistedConversations([
      Conversation(
        id: 'disc-act-1',
        name: LmsClassroomService.discussionTitle('Grade 4N-ACT'),
        role: 'Group',
        isGroup: true,
        usesCustomGroupName: true,
        groupStaffIds: [StaffMemberOption.teacherKey('TCH-ACT')],
        linkedStudentIds: const ['STU-ACT-1'],
        messages: [],
      ),
    ]);
    SchoolDataService.instance.sendMessage(
      'disc-act-1',
      'Please bring crayons tomorrow',
    );

    expect(
      hasType(NotificationType.classDiscussion, AuthService.roleParent),
      isTrue,
    );
    expect(
      hasType(NotificationType.classDiscussion, AuthService.roleStudent),
      isTrue,
    );

    signIn(
      username: 'parent.talk',
      roleKey: AuthService.roleParent,
      linkedStudentIds: const ['STU-ACT-1'],
    );
    expect(
      DashboardBadgeService.instance.countFor('class_discussion'),
      greaterThan(0),
    );

    signIn(
      username: 'student.talk',
      roleKey: AuthService.roleStudent,
      linkedStudentId: 'STU-ACT-1',
    );
    expect(
      DashboardBadgeService.instance.countFor('class_discussion'),
      greaterThan(0),
    );

    DashboardBadgeService.instance.markReadForTile('class_discussion');
    expect(DashboardBadgeService.instance.countFor('class_discussion'), 0);
  });

  test('incoming person-targeted notice still lands for the current user', () {
    seedStudent();
    signIn(
      username: 'parent.inbox',
      roleKey: AuthService.roleParent,
      linkedStudentIds: const ['STU-ACT-1'],
      fullName: 'Parent Act',
    );

    NotificationService.instance.push(
      title: 'Class discussion — Grade 4N-ACT',
      body: 'Please bring crayons tomorrow',
      type: NotificationType.classDiscussion,
      fromRole: AuthService.roleTeacher,
      fromName: 'Miss Belen',
      recipientRole: AuthService.roleParent,
      recipientUsername: 'parent.inbox',
      targetClassName: 'Grade 4N-ACT',
      showOnMessagesBadge: false,
    );

    expect(
      NotificationService.instance.notificationsForCurrentUser().where(
        (n) => n.type == NotificationType.classDiscussion,
      ),
      isNotEmpty,
    );
    expect(
      DashboardBadgeService.instance.countFor('class_discussion'),
      greaterThan(0),
    );
  });

  test('cloud homework that arrives after hydrate notifies other accounts', () {
    seedStudent();
    signIn(
      username: 'parent.cloud',
      roleKey: AuthService.roleParent,
      linkedStudentIds: const ['STU-ACT-1'],
    );

    SchoolDataService.instance.applyPersistedHomework(const []);
    final before = NotificationService.instance.itemsForTests().where(
      (n) => n.body.contains('Cloud fractions worksheet'),
    );
    expect(before, isEmpty);

    SchoolDataService.instance.applyPersistedHomework([
      HomeworkItem(
        id: 'hw-cloud-act-1',
        className: 'Grade 4N-ACT',
        subject: 'Math',
        description: 'Cloud fractions worksheet',
        teacherName: 'Miss Hana',
        teacherId: 'TCH-1003',
        postedAt: DateTime.now(),
      ),
    ]);

    expect(
      hasType(NotificationType.homework, AuthService.roleParent),
      isTrue,
    );
    expect(
      hasType(NotificationType.homework, AuthService.roleStudent),
      isTrue,
    );
    expect(DashboardBadgeService.instance.countFor('homework'), greaterThan(0));
  });
}
