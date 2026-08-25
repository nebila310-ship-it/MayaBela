import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/web_erp/shell/web_erp_shell.dart';
import 'package:mayabela/web_erp/shell/web_erp_top_bar.dart';
import 'package:mayabela/web_erp/utils/ios_web_input.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/web_erp/widgets/web_erp_hscroll.dart';
import 'package:mayabela/widgets/system_nav_safe_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AuthService.currentUser = null;
  });

  void signInAdmin() {
    AuthService.currentUser = RegisteredUser(
      username: '0900112233',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
  }

  Future<void> pumpPhone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: child,
        ),
      ),
    );
  }

  test('iOS web inputs stay at least 16px so Safari does not zoom', () {
    expect(IosWebInput.minFontSize, 16);
    expect(IosWebInput.fontSize(null), 16);
    expect(IosWebInput.fontSize(14), 16);
    expect(IosWebInput.fontSize(16), 16);
    expect(IosWebInput.fontSize(18), 18);
  });

  testWidgets('phone page padding is 12px', (tester) async {
    late EdgeInsets pad;
    await pumpPhone(
      tester,
      Builder(
        builder: (context) {
          pad = WebViewport.pagePadding(context);
          return const SizedBox.shrink();
        },
      ),
    );
    expect(pad, const EdgeInsets.all(12));
  });

  testWidgets('ERP shell fits a 390px phone without overflow', (tester) async {
    signInAdmin();
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details.exceptionAsString());
      old?.call(details);
    };
    addTearDown(() => FlutterError.onError = old);

    await pumpPhone(tester, const WebErpAdminShell());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      errors.where((e) => e.contains('OVERFLOWING') || e.contains('overflowed')),
      isEmpty,
      reason: errors.join('\n'),
    );
    expect(find.byType(WebErpAdminShell), findsOneWidget);
    expect(find.byType(WebErpTopBar), findsOneWidget);
  });

  testWidgets('top bar on 600px hides desktop extras', (tester) async {
    signInAdmin();
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details.exceptionAsString());
      old?.call(details);
    };
    addTearDown(() => FlutterError.onError = old);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(600, 800)),
          child: const WebErpAdminShell(),
        ),
      ),
    );
    await tester.pump();

    expect(
      errors.where((e) => e.contains('OVERFLOWING') || e.contains('overflowed')),
      isEmpty,
      reason: errors.join('\n'),
    );
    expect(find.text('Online'), findsNothing);
    expect(find.byTooltip('Menu'), findsOneWidget);
  });

  testWidgets('system nav scope pads left and right', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SystemNavSafeScope(child: SizedBox.expand()),
      ),
    );
    final safe = tester.widget<SafeArea>(find.byType(SafeArea).first);
    expect(safe.left, isTrue);
    expect(safe.right, isTrue);
  });

  testWidgets('h-scroll table does not force parent overflow', (tester) async {
    await pumpPhone(
      tester,
      Scaffold(
        body: SizedBox(
          width: 390,
          child: WebErpHScroll(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('A')),
                DataColumn(label: Text('B')),
                DataColumn(label: Text('C')),
                DataColumn(label: Text('D')),
                DataColumn(label: Text('E')),
              ],
              rows: const [
                DataRow(
                  cells: [
                    DataCell(Text('one')),
                    DataCell(Text('two')),
                    DataCell(Text('three')),
                    DataCell(Text('four')),
                    DataCell(Text('five')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(WebErpHScroll), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
