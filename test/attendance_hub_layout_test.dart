import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/web_erp/pages/web_attendance_hub_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'admin.attend',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'FR-001',
      fullName: 'School Admin',
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  testWidgets('admin attendance hub keeps take-roll and reports visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WebAttendanceHubPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Attendance'), findsWidgets);
    expect(find.text('Take attendance'), findsOneWidget);
    expect(find.text('Daily reports'), findsOneWidget);
    expect(find.text('Take Attendance'), findsOneWidget);

    await tester.tap(find.text('Daily reports'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Attendance Reports'), findsOneWidget);
  });
}
