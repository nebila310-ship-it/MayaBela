import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void signIn(String schoolId) {
    AuthService.currentUser = RegisteredUser(
      username: 'admin.$schoolId',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
      fullName: 'Admin $schoolId',
    );
  }

  AppNotification notice({
    required String id,
    required String title,
    String? schoolId,
    String recipientRole = AuthService.roleAdmin,
  }) {
    return AppNotification(
      id: id,
      title: title,
      body: '$title body',
      type: NotificationType.announcement,
      fromRole: AuthService.roleAdmin,
      fromName: 'Office',
      recipientRole: recipientRole,
      createdAt: DateTime.now(),
      schoolId: schoolId,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.instance.resetForTests();
    AuthService.currentUser = null;
    AuthService.sessionSchoolId = null;
  });

  tearDown(() {
    AuthService.currentUser = null;
    AuthService.sessionSchoolId = null;
    NotificationService.instance.resetForTests();
  });

  test('a live school does not keep another school’s notices', () {
    signIn('SCH-A');
    NotificationService.instance.applyCloudNotifications([
      notice(id: 'n-a', title: 'School A holiday', schoolId: 'SCH-A'),
    ]);
    expect(
      NotificationService.instance.notificationsForCurrentUser().map(
        (n) => n.title,
      ),
      contains('School A holiday'),
    );

    signIn('SCH-B');
    expect(
      NotificationService.instance.notificationsForCurrentUser().any(
        (n) => n.title == 'School A holiday',
      ),
      isFalse,
    );
  });

  test('notices without a school id stay off a live school', () {
    signIn('FN0597');
    NotificationService.instance.applyCloudNotifications([
      notice(id: 'n-empty', title: 'Stray notice'),
    ]);
    expect(
      NotificationService.instance.notificationsForCurrentUser().any(
        (n) => n.title == 'Stray notice',
      ),
      isFalse,
    );
  });

  test('a live school does not list another school’s announcements', () {
    SchoolDataService.instance.applyPersistedAnnouncements([
      Announcement(
        id: 'ann-a',
        title: 'School A sports day',
        body: 'Bring kits',
        author: 'Office A',
        date: DateTime.now(),
        schoolId: 'SCH-A',
      ),
      Announcement(
        id: 'ann-b',
        title: 'School B assembly',
        body: 'Hall',
        author: 'Office B',
        date: DateTime.now(),
        schoolId: 'SCH-B',
      ),
    ]);

    signIn('SCH-B');
    final titles = SchoolDataService.instance.getAnnouncements().map(
      (a) => a.title,
    );
    expect(titles, contains('School B assembly'));
    expect(titles, isNot(contains('School A sports day')));
  });

  test('announcements without a school id stay off a live school', () {
    SchoolDataService.instance.applyPersistedAnnouncements([
      Announcement(
        id: 'ann-stray',
        title: 'Stray assembly',
        body: 'Hall',
        author: 'Office',
        date: DateTime.now(),
      ),
    ]);
    signIn('FN0597');
    expect(
      SchoolDataService.instance.getAnnouncements().map((a) => a.title),
      isNot(contains('Stray assembly')),
    );
  });

  test('Finance Manager does not get another class’s daily activity toast', () {
    AuthService.currentUser = RegisteredUser(
      username: 'yohannes.fm',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'FN0597',
      fullName: 'Yohannes Kifetew Tebabal',
      staffRoles: const [StaffRoles.accountant],
    );
    NotificationService.instance.applyCloudNotifications([
      AppNotification(
        id: 'n-daily-other',
        title: 'Daily activity report',
        body: 'Bety Hagos posted today\'s activities for Kidest Girma.',
        type: NotificationType.dailyActivity,
        fromRole: AuthService.roleTeacher,
        fromName: 'Bety Hagos',
        recipientRole: AuthService.roleTeacher,
        createdAt: DateTime.now(),
        targetClassName: 'Grade 2A',
        schoolId: 'FN0597',
      ),
    ]);
    expect(
      NotificationService.instance.notificationsForCurrentUser().any(
        (n) => n.title == 'Daily activity report',
      ),
      isFalse,
    );
  });

  test('the classroom teacher still gets that class’s daily activity', () {
    TeacherRegistryService.instance.applyPersistedTeachers([
      AdminTeacherRecord(
        teacherId: 'TCH-DAILY-1',
        fullName: 'Bety Hagos',
        assignedClass: 'Grade 2A',
        schoolId: 'FN0597',
        loginUsername: 'bety.hagos',
        classAssignments: const [
          TeacherClassAssignment(
            className: 'Grade 2A',
            role: TeacherStaffRole.homeroomTeacher,
          ),
        ],
      ),
    ]);
    AuthService.currentUser = RegisteredUser(
      username: 'bety.hagos',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'FN0597',
      fullName: 'Bety Hagos',
      linkedTeacherId: 'TCH-DAILY-1',
    );
    NotificationService.instance.applyCloudNotifications([
      AppNotification(
        id: 'n-daily-own',
        title: 'Daily activity report',
        body: 'Bety Hagos posted today\'s activities for Kidest Girma.',
        type: NotificationType.dailyActivity,
        fromRole: AuthService.roleTeacher,
        fromName: 'Bety Hagos',
        recipientRole: AuthService.roleTeacher,
        createdAt: DateTime.now(),
        targetClassName: 'Grade 2A',
        schoolId: 'FN0597',
      ),
    ]);
    expect(
      NotificationService.instance.notificationsForCurrentUser().any(
        (n) => n.title == 'Daily activity report',
      ),
      isTrue,
    );
    TeacherRegistryService.instance.removeTeacher(
      'TCH-DAILY-1',
      schoolId: 'FN0597',
    );
  });
}
