import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/platform_audit_entry.dart';
import 'package:mayabela/models/school_audit_entry.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/platform_audit_log_service.dart';
import 'package:mayabela/services/school_audit_log_service.dart';
import 'package:mayabela/web_erp/pages/web_audit_log_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'owner.j',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'MAJIC1',
      fullName: 'School Owner',
    );
    SchoolAuditLogService.instance.applyPersistedEntries(
      [
        SchoolAuditEntry(
          id: 'sa-1',
          schoolId: 'MAJIC1',
          at: DateTime(2026, 10, 12, 10),
          action: 'bus_created',
          actorName: 'School Owner',
          entityType: 'bus',
          entityId: 'BUS-1001',
        ),
      ],
      replace: true,
    );
    PlatformAuditLogService.instance.applyPersistedEntries(
      [
        PlatformAuditEntry(
          id: 'audit-1',
          at: DateTime(2026, 10, 5, 22),
          action: 'school_deleted',
          schoolId: 'DIR718',
          schoolName: 'DIR718',
        ),
        PlatformAuditEntry(
          id: 'audit-2',
          at: DateTime(2026, 10, 5, 22, 1),
          action: 'school_deleted',
          schoolId: 'MADO',
          schoolName: 'mado school',
        ),
      ],
      nextId: 3,
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  testWidgets('school Audit Log has no Platform tab and hides other schools',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebAuditLogPage())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Audit Log'), findsOneWidget);
    expect(find.text('Platform'), findsNothing);
    expect(find.text('school_deleted'), findsNothing);
    expect(find.textContaining('mado school'), findsNothing);
    expect(find.textContaining('DIR718'), findsNothing);
    expect(find.text('bus_created'), findsOneWidget);
  });
}
