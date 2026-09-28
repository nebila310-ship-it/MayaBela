import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cctv/cctv_catalog_service.dart';
import 'package:mayabela/web_erp/pages/web_cctv_page.dart';
import 'package:mayabela/web_erp/router/web_erp_router.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CctvCatalogService.instance.resetForTest();
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  testWidgets('admin CCTV page lists campus camera sites', (tester) async {
    AuthService.currentUser = RegisteredUser(
      username: 'cctv.admin',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebCctvPage())),
    );
    await tester.pump();

    expect(find.text('CCTV'), findsOneWidget);
    expect(find.text('Main gate'), findsOneWidget);
    expect(find.text('Playground'), findsOneWidget);
    expect(find.text('Ready to connect'), findsWidgets);
    expect(find.byKey(const Key('cctv-local-only-banner')), findsOneWidget);
    expect(WebErpRouter.pageFor('cctv'), isA<WebCctvPage>());
  });
}
