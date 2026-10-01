import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/setup/dashboard_setup.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/web_erp/router/web_erp_router.dart';
import 'package:mayabela/web_erp/shell/web_erp_shell.dart';
import 'package:mayabela/widgets/adaptive_dashboard_shell.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/widgets/inbox_login_reminder.dart';
import 'package:mayabela/widgets/inbox_messages_action.dart';
import 'package:mayabela/screens/messages_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NotificationService.instance.resetForTests();
    await InboxLoginReminder.resetForTests();
    AuthService.currentUser = null;
    registerAllDashboards();
  });

  tearDown(() async {
    AuthService.currentUser = null;
    NotificationService.instance.resetForTests();
    await InboxLoginReminder.resetForTests();
  });

  void signIn(String roleKey, {List<String> staffRoles = const []}) {
    AuthService.currentUser = RegisteredUser(
      username: 'inbox.$roleKey',
      password: 'x',
      roleKey: roleKey,
      schoolId: 'TB-001',
      staffRoles: staffRoles,
    );
  }

  test('every classroom role has a Messages tile', () {
    for (final role in [
      AuthService.roleTeacher,
      AuthService.roleParent,
      AuthService.roleStudent,
      AuthService.roleDriver,
    ]) {
      signIn(role);
      final ids = DashboardRegistry.visibleEntriesFor(
        role,
      ).map((e) => e.id).toSet();
      expect(ids, contains('messages'), reason: role);
    }
  });

  test('admin and staff dashboards expose the Messages (support) tile', () {
    signIn(AuthService.roleAdmin);
    expect(
      DashboardRegistry.visibleEntriesFor(
        AuthService.roleAdmin,
      ).map((e) => e.id),
      contains('support'),
    );

    signIn(AuthService.roleStaff, staffRoles: [StaffRoles.librarian]);
    expect(
      DashboardRegistry.visibleEntriesFor(
        AuthService.roleStaff,
      ).map((e) => e.id),
      contains('support'),
    );
  });

  test('messages route opens the inbox', () {
    signIn(AuthService.roleAdmin);
    expect(WebErpRouter.pageFor('messages'), isA<MessagesScreen>());
    expect(WebErpRouter.pageFor('support'), isA<MessagesScreen>());
  });

  testWidgets('classroom top bar shows the inbox icon', (tester) async {
    signIn(AuthService.roleTeacher);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: AdaptiveDashboardShell(
            title: 'Classroom',
            welcomeMessage: 'Welcome',
            gradientColors: TeacherTheme.gradient,
            roleKey: AuthService.roleTeacher,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(InboxMessagesAction.actionKey), findsOneWidget);
  });

  testWidgets('ERP top bar shows the inbox icon on a phone', (tester) async {
    signIn(AuthService.roleAdmin);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: WebErpAdminShell(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(InboxMessagesAction.actionKey), findsOneWidget);
  });

  testWidgets('login reminder appears when unread messages exist', (
    tester,
  ) async {
    signIn(AuthService.roleTeacher);
    final unread = DashboardBadgeService.instance.countFor('messages');
    expect(unread, greaterThan(0));

    await tester.pumpWidget(
      MaterialApp(
        home: InboxLoginReminder(
          child: Scaffold(
            body: Text(AppLocale.instance.strings.notifyMessages),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(const Key('inbox-login-reminder')), findsOneWidget);
    expect(
      find.text(AppLocale.instance.strings.inboxUnreadOnLogin(unread)),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Material>(find.byKey(const Key('inbox-login-reminder')))
          .color,
      Colors.white,
    );

    final toast = tester.getRect(find.byKey(const Key('inbox-login-reminder')));
    final screen = tester.getRect(find.byType(MaterialApp));
    expect(toast.top, lessThan(80));
    expect(toast.right, closeTo(screen.right - 16, 0.5));
  });

  testWidgets('login reminder does not repeat after it has been shown', (
    tester,
  ) async {
    signIn(AuthService.roleTeacher);

    Widget reminder() => MaterialApp(
      home: InboxLoginReminder(
        child: Scaffold(body: Text(AppLocale.instance.strings.notifyMessages)),
      ),
    );

    await tester.pumpWidget(reminder());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('inbox-login-reminder')), findsOneWidget);

    await tester.pump(InboxLoginReminder.displayDuration);
    await tester.pump();
    expect(find.byKey(const Key('inbox-login-reminder')), findsNothing);

    InboxLoginReminder.reset();
    await tester.pumpWidget(reminder());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('inbox-login-reminder')), findsNothing);
  });

  testWidgets(
    'login reminder stays hidden after a later login for the same user',
    (tester) async {
      signIn(AuthService.roleAdmin);

      Widget reminder() => MaterialApp(
        home: InboxLoginReminder(
          child: Scaffold(
            body: Text(AppLocale.instance.strings.notifyMessages),
          ),
        ),
      );

      await tester.pumpWidget(reminder());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pump(InboxLoginReminder.displayDuration);
      await tester.pump();

      InboxLoginReminder.reset();
      NotificationService.instance.clearForLogout();
      signIn(AuthService.roleAdmin);

      await tester.pumpWidget(reminder());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('inbox-login-reminder')), findsNothing);
    },
  );
}
