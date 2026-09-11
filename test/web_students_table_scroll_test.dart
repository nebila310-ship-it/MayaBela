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
    'students directory scrolls both axes and keeps the pager clear of Maya',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 520));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WebStudentsTablePage())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WebErpHScroll), findsOneWidget);
      final scroller = tester.widget<WebErpHScroll>(find.byType(WebErpHScroll));
      expect(
        scroller.minChildWidth,
        WebStudentsTablePage.directoryMinTableWidth,
      );

      expect(find.text('Student 1'), findsOneWidget);
      expect(find.text('12 students'), findsOneWidget);
      expect(find.text('Page 1 of 2'), findsOneWidget);

      final pager = tester.widget<Padding>(
        find.byKey(const ValueKey('students-pagination')),
      );
      expect(pager.padding.right, MayaFloatingChat.pageEndClearance);
      expect(MayaFloatingChat.pageEndClearance, greaterThanOrEqualTo(72));

      final verticalFinder = find.byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.vertical,
      );
      expect(verticalFinder, findsWidgets);
      final vertical = tester.widget<Scrollable>(verticalFinder.first);
      expect(vertical.controller, isNotNull);
      expect(vertical.controller!.position.maxScrollExtent, greaterThan(0));

      final horizontalFinder = find.byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.horizontal,
      );
      expect(horizontalFinder, findsWidgets);
      final horizontal = tester.widget<Scrollable>(horizontalFinder.first);
      expect(horizontal.controller, isNotNull);
      expect(horizontal.controller!.position.maxScrollExtent, greaterThan(200));
    },
  );
}
