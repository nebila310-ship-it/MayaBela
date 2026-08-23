import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/web_erp/pages/web_admin_overview_page.dart';
import 'package:mayabela/web_erp/pages/web_transport_dashboard_page.dart';
import 'package:mayabela/web_erp/widgets/web_stat_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'dash.admin',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'FR-001',
      fullName: 'Dashboard Admin',
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  testWidgets('admin dashboard info tiles open their owning modules',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebAdminOverviewPage(onNavigate: opened.add),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Total Students'));
    await tester.tap(find.text('Present Today'));
    await tester.tap(find.text('Teachers'));
    await tester.tap(find.text('Buses Active'));
    await tester.tap(find.text('Outstanding Fees'));
    await tester.pump();

    expect(opened, containsAll(['students', 'attendance', 'hr', 'transport', 'finance']));
    expect(find.byType(WebStatCard), findsWidgets);
  });

  testWidgets('transport info tiles open buses, driver, and GPS', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebTransportDashboardPage(onNavigate: opened.add),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Active Buses'));
    await tester.tap(find.text('Drivers'));
    await tester.tap(find.text('Onboard Now'));
    await tester.pump();

    expect(opened, containsAll(['transport_buses', 'add_driver', 'transport_live_gps']));
  });
}
