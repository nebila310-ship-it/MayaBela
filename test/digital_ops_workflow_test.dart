import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/digital_ops_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/digital_ops_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/markbook_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/web_erp/pages/web_digital_ops_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DigitalOpsService.resetForTests();
    ExamService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'ict.staff',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.staffs],
      fullName: 'IT Officer',
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('device register and Friday ritual do not write markbook or exams',
      () async {
    expect(ModuleAccess.canView('digital_ops'), isTrue);
    expect(ModuleAccess.canManage('digital_ops'), isTrue);
    expect(ModuleAccess.normalize('ict'), 'digital_ops');

    final beforeExams = ExamService.instance.papersForSchool('TB-001').length;
    final beforeCards = MarkbookService.instance.unpublishedCount();

    final device = await DigitalOpsService.instance.upsertDevice(
      kind: IctDeviceKind.labPc,
      label: 'Lab PC 1',
      assignedTo: 'ICT lab',
      location: 'Block B',
    );
    expect(device.id, startsWith('DEV-'));
    expect(device.kind, IctDeviceKind.labPc);
    expect(
      DigitalOpsService.instance.devicesForSchool('TB-001'),
      hasLength(1),
    );

    final phone = await DigitalOpsService.instance.upsertDevice(
      kind: IctDeviceKind.driverPhone,
      label: 'Bus 1 phone',
      assignedTo: 'Driver Abebe',
      gpsEnabled: true,
    );
    expect(phone.gpsEnabled, isTrue);

    final week = await DigitalOpsService.instance.saveWeeklyReview(
      loginIssuesReviewed: true,
      parentLinkPileReviewed: true,
      backupChecked: true,
      hardRefreshReminded: true,
      devicesChecked: true,
      chairName: 'IT Officer',
    );
    expect(week.id, startsWith('WK-'));
    expect(week.complete, isTrue);
    expect(
      DigitalOpsService.instance.reviewThisWeek('TB-001')?.complete,
      isTrue,
    );

    expect(
      ExamService.instance.papersForSchool('TB-001'),
      hasLength(beforeExams),
    );
    expect(MarkbookService.instance.unpublishedCount(), beforeCards);
  });

  test('ict collections stay on the standard sync lane, not realtime', () {
    expect(
      CloudSyncEngine.standardPriority,
      containsAll([
        AppCollections.ictDevices,
        AppCollections.ictWeeklyReviews,
      ]),
    );
    expect(
      CloudSyncEngine.highPriority,
      isNot(contains(AppCollections.ictDevices)),
    );
    expect(
      CloudSyncEngine.liveRealtimeCollections,
      isNot(contains(AppCollections.ictDevices)),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.j',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      isNot(contains(AppCollections.ictDevices)),
    );
  });

  test('Staff nav includes the five-phase desk', () {
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    expect(ids, contains('digital_ops'));
    expect(StaffRoles.lookup(StaffRoles.staffs)!.permissions,
        contains(SchoolPermissions.manageDigitalOps));
    expect(StaffRoles.templates.any((r) => r.key == 'it'), isFalse);
  });

  testWidgets('Digital operations desk shows all five phases', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WebDigitalOpsPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Digital operations'), findsOneWidget);
    expect(find.text('1 · People & devices'), findsOneWidget);
    expect(find.text('2 · Access help'), findsOneWidget);
    expect(find.text('3 · Go-live ops'), findsOneWidget);
    expect(find.text('4 · Campus systems'), findsOneWidget);
    expect(find.text('5 · Weekly ritual'), findsOneWidget);
    expect(find.text('Add device'), findsOneWidget);
  });
}
