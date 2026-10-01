import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.instance.resetForTests();
    AuthService.currentUser = null;
  });

  tearDown(() {
    AuthService.currentUser = null;
    NotificationService.instance.resetForTests();
  });

  void signIn({
    required String username,
    required String roleKey,
    String? linkedTeacherId,
    String? linkedAdminId,
  }) {
    AuthService.currentUser = RegisteredUser(
      username: username,
      password: 'x',
      roleKey: roleKey,
      schoolId: 'TB-001',
      linkedTeacherId: linkedTeacherId,
      linkedAdminId: linkedAdminId,
    );
  }

  test('teacher does not see another employee\'s admin message', () {
    signIn(
      username: 'admin.maya',
      roleKey: AuthService.roleAdmin,
      linkedAdminId: 'ADM-1',
    );

    NotificationService.instance.push(
      title: 'Meeting invitation: Staff briefing',
      body: 'Please acknowledge that you will attend.',
      type: NotificationType.message,
      fromRole: AuthService.roleAdmin,
      fromName: 'Admin',
      recipientRole: AuthService.roleTeacher,
      recipientStaffId: StaffMemberOption.teacherKey('TCH-SARA'),
    );

    signIn(
      username: 'rami',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: 'TCH-RAMI',
    );
    expect(
      NotificationService.instance.notificationsForCurrentUser().where(
        (n) => n.title.startsWith('Meeting invitation'),
      ),
      isEmpty,
    );

    signIn(
      username: 'sara',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: 'TCH-SARA',
    );
    expect(
      NotificationService.instance.notificationsForCurrentUser().where(
        (n) => n.title.startsWith('Meeting invitation'),
      ),
      hasLength(1),
    );
  });

  test('role-wide notice still reaches every teacher', () {
    signIn(
      username: 'admin.maya',
      roleKey: AuthService.roleAdmin,
      linkedAdminId: 'ADM-1',
    );
    NotificationService.instance.push(
      title: 'School closed Friday',
      body: 'Holiday.',
      type: NotificationType.announcement,
      fromRole: AuthService.roleAdmin,
      fromName: 'Admin',
      recipientRole: AuthService.roleTeacher,
    );

    signIn(
      username: 'rami',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: 'TCH-RAMI',
    );
    expect(
      NotificationService.instance.notificationsForCurrentUser().any(
        (n) => n.title == 'School closed Friday',
      ),
      isTrue,
    );
  });

  test('username-targeted teacher notice stays with that login', () {
    signIn(
      username: 'admin.maya',
      roleKey: AuthService.roleAdmin,
      linkedAdminId: 'ADM-1',
    );
    NotificationService.instance.push(
      title: 'Case update — Liya',
      body: 'Your report was resolved.',
      type: NotificationType.general,
      fromRole: AuthService.roleAdmin,
      fromName: 'Student Affairs',
      recipientRole: AuthService.roleTeacher,
      recipientUsername: 'sara',
    );

    signIn(
      username: 'rami',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: 'TCH-RAMI',
    );
    expect(
      NotificationService.instance.notificationsForCurrentUser().any(
        (n) => n.title.startsWith('Case update'),
      ),
      isFalse,
    );

    signIn(
      username: 'sara',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: 'TCH-SARA',
    );
    expect(
      NotificationService.instance.notificationsForCurrentUser().any(
        (n) => n.title.startsWith('Case update'),
      ),
      isTrue,
    );
  });
}
