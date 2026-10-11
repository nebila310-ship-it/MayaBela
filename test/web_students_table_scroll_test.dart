import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/pages/web_students_table_page.dart';
import 'package:mayabela/web_erp/widgets/web_erp_hscroll.dart';
import 'package:mayabela/widgets/maya_floating_chat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'admin.students',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
      fullName: 'Students Admin',
    );
    StudentRegistryService.instance.applyPersistedStudents([
      for (var i = 1; i <= 12; i++)
        AdminStudentRecord(
          studentId: 'STU-${1000 + i}',
          fullName: 'Student $i',
          grade: 'Grade 2',
          className: 'Grade 2C',
          schoolId: 'TB-001',
          dateOfBirth: DateTime(2016, 1, i.clamp(1, 28)),
          fatherName: 'Parent $i',
        ),
    ], replace: true);
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  testWidgets(
    'phone student list uses page scroll and tiles, not an inner table scroller',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WebStudentsTablePage())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WebErpHScroll), findsNothing);
      expect(find.byType(DataTable), findsNothing);
      expect(find.byKey(const ValueKey('students-page-scroll')), findsOneWidget);
      expect(find.byType(ListTile), findsWidgets);
      expect(find.text('Student 1'), findsOneWidget);
      expect(find.text('12 students'), findsOneWidget);
      expect(find.text('Page 1 of 2'), findsOneWidget);

      final pager = tester.widget<Padding>(
        find.byKey(const ValueKey('students-pagination')),
      );
      expect(
        (pager.padding as EdgeInsets).right,
        MayaFloatingChat.pageEndClearance,
      );
    },
  );

  testWidgets(
    'desktop student list keeps a table and the pager clear of Maya',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WebStudentsTablePage())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WebErpHScroll), findsNothing);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.byKey(const ValueKey('students-page-scroll')), findsNothing);
      expect(find.text('Student 1'), findsOneWidget);
      expect(find.text('12 students'), findsOneWidget);
      expect(find.text('Page 1 of 2'), findsOneWidget);
    },
  );
}
