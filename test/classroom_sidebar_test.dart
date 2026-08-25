import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/widgets/adaptive_dashboard_shell.dart';
import 'package:mayabela/widgets/classroom_sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserPreferencesService.instance.classroomSidebarCollapsed = false;
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.eman',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      fullName: 'Eman',
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
    UserPreferencesService.instance.classroomSidebarCollapsed = false;
  });

  Future<void> pumpShell(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: AdaptiveDashboardShell(
            title: 'malo Classroom',
            welcomeMessage: 'Welcome',
            gradientColors: TeacherTheme.gradient,
            roleKey: AuthService.roleTeacher,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('desktop classroom sidebar starts open with Home', (tester) async {
    await pumpShell(tester, size: const Size(1280, 800));

    expect(find.byKey(const Key('classroom-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('classroom-nav-home')), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(
      tester.getSize(find.byKey(const Key('classroom-sidebar'))).width,
      closeTo(ClassroomSidebar.expandedWidth, 24),
    );
  });

  testWidgets('desktop classroom sidebar closes and opens again', (tester) async {
    await pumpShell(tester, size: const Size(1280, 800));

    await tester.tap(find.byKey(const Key('classroom-sidebar-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(UserPreferencesService.instance.classroomSidebarCollapsed, isTrue);
    expect(
      tester.getSize(find.byKey(const Key('classroom-sidebar'))).width,
      closeTo(ClassroomSidebar.collapsedWidth, 24),
    );

    await tester.tap(find.byKey(const Key('classroom-top-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(UserPreferencesService.instance.classroomSidebarCollapsed, isFalse);
    expect(
      tester.getSize(find.byKey(const Key('classroom-sidebar'))).width,
      closeTo(ClassroomSidebar.expandedWidth, 24),
    );
  });

  testWidgets('phone classroom menu opens a slide-out sidebar', (tester) async {
    await pumpShell(tester, size: const Size(390, 844));

    expect(find.byKey(const Key('classroom-open-menu')), findsOneWidget);
    expect(find.byKey(const Key('classroom-sidebar')), findsNothing);

    await tester.tap(find.byKey(const Key('classroom-open-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('classroom-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('classroom-nav-home')), findsOneWidget);
  });
}
