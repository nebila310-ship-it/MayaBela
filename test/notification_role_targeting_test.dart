import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';

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
    List<String> staffRoles = const [],
  }) {
    AuthService.currentUser = RegisteredUser(
      username: username,
      password: 'x',
      roleKey: roleKey,
      schoolId: 'TB-001',
      linkedTeacherId: linkedTeacherId,
      linkedAdminId: linkedAdminId,
      staffRoles: staffRoles,
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

  test('staff-role escalation notice reaches VP and Section Director', () {
    signIn(username: 'affairs.desk', roleKey: AuthService.roleTeacher);
    NotificationService.instance.push(
      title: 'Discipline case escalated to you',
      body: 'Sara Bekele (Grade 4A) escalated to Vice Principal.',
      type: NotificationType.general,
      fromRole: AuthService.roleTeacher,
      fromName: 'Student Affairs',
      recipientRole: AuthService.roleTeacher,
      recipientStaffRole: StaffRoles.vicePresident,
    );
    NotificationService.instance.push(
      title: 'Discipline case escalated to you',
      body: 'Sara Bekele (Grade 4A) escalated to Section Director.',
      type: NotificationType.general,
      fromRole: AuthService.roleTeacher,
      fromName: 'Student Affairs',
      recipientRole: AuthService.roleTeacher,
      recipientStaffRole: StaffRoles.sectionDirector,
    );

    signIn(
      username: 'vp.user',
      roleKey: AuthService.roleTeacher,
      staffRoles: const [StaffRoles.vicePresident],
    );
    final vpNotes = NotificationService.instance.notificationsForCurrentUser();
    expect(vpNotes.any((n) => n.body.contains('Vice Principal')), isTrue);
    expect(vpNotes.any((n) => n.body.contains('Section Director')), isFalse);

    signIn(
      username: 'sd.user',
      roleKey: AuthService.roleTeacher,
      staffRoles: const [StaffRoles.sectionDirector],
    );
    final sdNotes = NotificationService.instance.notificationsForCurrentUser();
    expect(sdNotes.any((n) => n.body.contains('Section Director')), isTrue);
    expect(sdNotes.any((n) => n.body.contains('Vice Principal')), isFalse);

    signIn(username: 'plain.teacher', roleKey: AuthService.roleTeacher);
    expect(
      NotificationService.instance.notificationsForCurrentUser().any(
        (n) => n.title == 'Discipline case escalated to you',
      ),
      isFalse,
    );
  });

  test('untargeted staff messages stay off other teachers\' inboxes', () {
    signIn(username: 'admin.maya', roleKey: AuthService.roleAdmin);
    NotificationService.instance.push(
      title: 'New message from Admin',
      body: 'Please acknowledge the staff briefing.',
      type: NotificationType.message,
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
        (n) => n.title == 'New message from Admin',
      ),
      isFalse,
    );

    signIn(username: 'parent.bek', roleKey: AuthService.roleParent);
    NotificationService.instance.push(
      title: 'New message from Parent',
      body: 'Is homework due tomorrow?',
      type: NotificationType.message,
      fromRole: AuthService.roleParent,
      fromName: 'Parent',
      recipientRole: AuthService.roleTeacher,
      recipientUsername: 'sara',
    );

    signIn(
      username: 'sara',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: 'TCH-SARA',
    );
    expect(
      NotificationService.instance.notificationsForCurrentUser().where(
        (n) => n.title.startsWith('New message from Parent'),
      ),
      hasLength(1),
    );

    signIn(
      username: 'rami',
      roleKey: AuthService.roleTeacher,
      linkedTeacherId: 'TCH-RAMI',
    );
    expect(
      NotificationService.instance.notificationsForCurrentUser().any(
        (n) => n.title.startsWith('New message from Parent'),
      ),
      isFalse,
    );
  });

  test('VP signed in as admin still sees desk escalation', () {
    signIn(username: 'affairs.desk', roleKey: AuthService.roleTeacher);
    NotificationService.instance.push(
      title: 'Discipline case escalated to you',
      body: 'Sara Bekele (Grade 4A) escalated to Vice Principal.',
      type: NotificationType.general,
      fromRole: AuthService.roleTeacher,
      fromName: 'Student Affairs',
      recipientRole: AuthService.roleTeacher,
      recipientStaffRole: StaffRoles.vicePresident,
    );

    signIn(
      username: 'vp.admin',
      roleKey: AuthService.roleAdmin,
      staffRoles: const [StaffRoles.vicePresident],
    );
    expect(
      NotificationService.instance.notificationsForCurrentUser().any(
        (n) => n.title == 'Discipline case escalated to you',
      ),
      isTrue,
    );
  });
}
