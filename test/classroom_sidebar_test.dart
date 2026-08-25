import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/screens/student_dashboard.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/widgets/adaptive_dashboard_shell.dart';
import 'package:mayabela/widgets/classroom_sidebar.dart';
import 'package:mayabela/widgets/role_dashboard_shell.dart';
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
    expect(find.text('Home'), findsWidgets);
    expect(
      tester.getSize(find.byKey(const Key('classroom-sidebar'))).width,
      greaterThan(180),
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
      lessThan(110),
    );

    await tester.tap(find.byKey(const Key('classroom-top-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(UserPreferencesService.instance.classroomSidebarCollapsed, isFalse);
    expect(
      tester.getSize(find.byKey(const Key('classroom-sidebar'))).width,
      greaterThan(180),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone classroom menu opens a slide-out sidebar', (tester) async {
    await pumpShell(tester, size: const Size(390, 844));

    expect(find.byKey(const Key('classroom-open-menu')), findsOneWidget);
    expect(find.byKey(const Key('classroom-sidebar')), findsNothing);

    await tester.tap(find.byKey(const Key('classroom-open-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('classroom-sidebar')), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('parent desktop dashboard uses the same collapsible sidebar', (
    tester,
  ) async {
    AuthService.currentUser = RegisteredUser(
      username: 'parent.sara',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      fullName: 'Sara',
    );
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: AdaptiveDashboardShell(
            title: 'malo Parent Portal',
            welcomeMessage: 'Welcome',
            gradientColors: const [
              Color(0xFF00695C),
              Color(0xFF00897B),
              Color(0xFF26A69A),
            ],
            roleKey: AuthService.roleParent,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('classroom-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('classroom-top-menu')), findsOneWidget);
    expect(find.text('Home'), findsWidgets);

    await tester.tap(find.byKey(const Key('classroom-sidebar-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(UserPreferencesService.instance.classroomSidebarCollapsed, isTrue);
    expect(
      tester.getSize(find.byKey(const Key('classroom-sidebar'))).width,
      lessThan(110),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('parent phone dashboard opens the same slide-out menu', (
    tester,
  ) async {
    AuthService.currentUser = RegisteredUser(
      username: 'parent.sara',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      fullName: 'Sara',
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: AdaptiveDashboardShell(
            title: 'malo Parent Portal',
            welcomeMessage: 'Welcome',
            gradientColors: [
              Color(0xFF00695C),
              Color(0xFF00897B),
              Color(0xFF26A69A),
            ],
            roleKey: AuthService.roleParent,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('classroom-open-menu')), findsOneWidget);
    await tester.tap(find.byKey(const Key('classroom-open-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('classroom-sidebar')), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('student desktop dashboard uses the same collapsible sidebar', (
    tester,
  ) async {
    AuthService.currentUser = RegisteredUser(
      username: 'student.maya',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
      fullName: 'Maya',
    );
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: AdaptiveDashboardShell(
            title: 'malo Student Portal',
            welcomeMessage: 'Welcome',
            gradientColors: const [
              Color(0xFF1565C0),
              Color(0xFF1976D2),
              Color(0xFF42A5F5),
            ],
            roleKey: AuthService.roleStudent,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('classroom-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('classroom-top-menu')), findsOneWidget);
    expect(find.text('Home'), findsWidgets);

    await tester.tap(find.byKey(const Key('classroom-sidebar-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(UserPreferencesService.instance.classroomSidebarCollapsed, isTrue);
    expect(
      tester.getSize(find.byKey(const Key('classroom-sidebar'))).width,
      lessThan(110),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('student phone dashboard opens the same slide-out menu', (
    tester,
  ) async {
    AuthService.currentUser = RegisteredUser(
      username: 'student.maya',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
      fullName: 'Maya',
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: AdaptiveDashboardShell(
            title: 'malo Student Portal',
            welcomeMessage: 'Welcome',
            gradientColors: [
              Color(0xFF1565C0),
              Color(0xFF1976D2),
              Color(0xFF42A5F5),
            ],
            roleKey: AuthService.roleStudent,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('classroom-open-menu')), findsOneWidget);
    await tester.tap(find.byKey(const Key('classroom-open-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('classroom-sidebar')), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('StudentDashboard screen uses the collapsible rail', (tester) async {
    AuthService.currentUser = RegisteredUser(
      username: 'student.maya',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
      fullName: 'Maya',
    );
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(1280, 800)),
          child: StudentDashboard(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RoleDashboardShell), findsOneWidget);
    expect(find.byType(AdaptiveDashboardShell), findsOneWidget);
    expect(find.byKey(const Key('classroom-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('classroom-top-menu')), findsOneWidget);
  });
}
