import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/calendar_screen.dart';
import 'package:mayabela/screens/teacher_dashboard.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/setup/dashboard_setup.dart';
import 'package:mayabela/widgets/classroom_sidebar.dart';
import 'package:mayabela/widgets/dashboard_module_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserPreferencesService.instance.classroomSidebarCollapsed = false;
    registerAllDashboards();
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

  testWidgets('teacher sidebar groups modules by category and scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(1280, 800)),
          child: TeacherDashboard(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('classroom-sidebar')), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);
    expect(find.text('MY CLASSROOM'), findsWidgets);
    expect(find.text('TEACHING TOOLS'), findsWidgets);
    expect(find.text('COMMUNICATION'), findsWidgets);
    expect(find.byType(DashboardModuleSection), findsWidgets);
  });

  testWidgets('teacher calendar uses the ERP month-and-events layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(1280, 800)),
          child: CalendarScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.textContaining('Events'), findsWidgets);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('classroom destinations keep Home first then section order', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SizedBox.shrink()),
    );
    final dests = classroomNavDestinations(
      roleKey: AuthService.roleTeacher,
      s: AppLocale.instance.strings,
    );
    expect(dests.first.id, 'home');
    expect(dests.any((d) => d.section == 'My classroom'), isTrue);
    expect(dests.any((d) => d.section == 'Teaching tools'), isTrue);
  });
}
