import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/web_erp/pages/web_teachers_table_page.dart';
import 'package:mayabela/web_erp/widgets/web_erp_hscroll.dart';
import 'package:mayabela/widgets/maya_floating_chat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'admin.staff',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
      fullName: 'Staff Admin',
    );
    AuthService.applySchoolContext(schoolId);
    TeacherRegistryService.instance.applyPersistedTeachers([
      for (var i = 1; i <= 12; i++)
        AdminTeacherRecord(
          teacherId: 'GM-${10000 + i}',
          fullName: 'Staff $i',
          assignedClass: '',
          schoolId: schoolId,
          email: 'staff$i@school.test',
          phone: '09110000${i.toString().padLeft(2, '0')}',
          employeeId: 'GM-${10000 + i}',
          roles: const [],
          loginUsername: 'staff$i',
          staffRoles: const [StaffRoles.generalManager],
        ),
    ]);
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  void setView(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'phone staff list uses page scroll and tiles, not an inner table scroller',
    (tester) async {
      setView(tester, const Size(390, 844));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WebTeachersTablePage(
              directoryMode: WebTeachersDirectoryMode.administrationStaff,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WebErpHScroll), findsNothing);
      expect(find.byType(DataTable), findsNothing);
      expect(find.byKey(const ValueKey('staff-page-scroll')), findsOneWidget);
      expect(find.byType(ListTile), findsWidgets);
      expect(find.text('Staff 1'), findsOneWidget);
      expect(find.textContaining('registered'), findsOneWidget);
      expect(find.byKey(const ValueKey('teachers-pagination')), findsOneWidget);
    },
  );

  testWidgets(
    'desktop staff list keeps a table and scrolls with the page',
    (tester) async {
      setView(tester, const Size(1280, 800));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WebTeachersTablePage(
              directoryMode: WebTeachersDirectoryMode.administrationStaff,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('staff-page-scroll')), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Staff 1'), findsOneWidget);
      expect(find.textContaining('registered'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_outlined), findsWidgets);

      final pager = tester.widget<Padding>(
        find.byKey(const ValueKey('teachers-pagination')),
      );
      expect(
        (pager.padding as EdgeInsets).right,
        MayaFloatingChat.pageEndClearance,
      );
    },
  );

  test('staff profile dialog source can attach a photo', () {
    final dialog = File(
      'lib/web_erp/widgets/web_admin_profile_dialog.dart',
    ).readAsStringSync();
    expect(dialog, contains('TeacherPhotoService'));
    expect(dialog, contains('s.changeProfilePhoto'));
    expect(dialog, contains('photoPath: teacher.photoPath'));

    final list = File('lib/web_erp/pages/web_teachers_table_page.dart')
        .readAsStringSync();
    expect(list, contains('staff-page-scroll'));
    expect(list, contains('_attachPhoto'));
    expect(list, contains('SingleChildScrollView'));
    expect(list, contains('AlwaysScrollableScrollPhysics'));
    expect(list, contains('ClampingScrollPhysics'));
  });
}
