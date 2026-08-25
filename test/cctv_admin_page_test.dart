import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/web_erp/pages/web_cctv_page.dart';
import 'package:mayabela/web_erp/router/web_erp_router.dart';

void main() {
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

    expect(find.text('CCTV'), findsOneWidget);
    expect(find.text('Main gate'), findsOneWidget);
    expect(find.text('Playground'), findsOneWidget);
    expect(find.text('Ready to connect'), findsWidgets);
    expect(WebErpRouter.pageFor('cctv'), isA<WebCctvPage>());
  });
}
