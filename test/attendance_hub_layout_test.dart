import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/screens/attendance_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/theme/classroom_palette.dart';
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
    StudentRegistryService.instance.applyPersistedStudents(
      const [],
      replace: true,
    );
  });

  testWidgets('admin attendance hub keeps take-roll and reports visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebAttendanceHubPage())),
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

  testWidgets(
    'attendance register pages 10 students with full-row status colors',
    (tester) async {
      const className = 'Grade 8A';
      StudentRegistryService.instance.applyPersistedStudents([
        for (var i = 1; i <= 12; i++)
          AdminStudentRecord(
            studentId: 'STU-ATT-${i.toString().padLeft(2, '0')}',
            fullName: 'Roll Kid ${i.toString().padLeft(2, '0')}',
            grade: '8',
            className: className,
            schoolId: 'FR-001',
            dateOfBirth: DateTime(2012, 1, i.clamp(1, 28)),
          ),
      ], replace: true);

      expect(
        SchoolDataService.instance.saveAttendanceSession(
          className: className,
          date: DateTime.now(),
          conductedBy: 'School Admin',
          notifyParents: false,
          entries: [
            StudentAttendanceEntry(
              studentName: 'Roll Kid 01',
              studentId: 'STU-ATT-01',
              status: AttendanceStatus.present,
            ),
            StudentAttendanceEntry(
              studentName: 'Roll Kid 02',
              studentId: 'STU-ATT-02',
              status: AttendanceStatus.absent,
            ),
            StudentAttendanceEntry(
              studentName: 'Roll Kid 03',
              studentId: 'STU-ATT-03',
              status: AttendanceStatus.late,
            ),
          ],
        ),
        isTrue,
      );

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WebAttendanceHubPage())),
      );
      await tester.pumpAndSettle();

      expect(AttendanceScreen.registerPageSize, 10);
      expect(find.byKey(const ValueKey('attendance-register')), findsOneWidget);
      expect(find.text('Roll Kid 01'), findsOneWidget);
      expect(find.text('Roll Kid 10'), findsOneWidget);
      expect(find.text('Roll Kid 12'), findsNothing);
      expect(find.textContaining('1–10 of 12 students'), findsOneWidget);

      Material barColor(String id) => tester.widget<Material>(
        find.byKey(ValueKey('attendance-student-$id')),
      );

      expect(barColor('STU-ATT-01').color, ClassroomPalette.green);
      expect(barColor('STU-ATT-02').color, ClassroomPalette.red);
      expect(barColor('STU-ATT-03').color, ClassroomPalette.orange);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('attendance-student-STU-ATT-01')),
          matching: find.byTooltip('Absent'),
        ),
      );
      await tester.pump();
      expect(barColor('STU-ATT-01').color, ClassroomPalette.red);

      await tester.ensureVisible(
        find.byKey(const ValueKey('attendance-page-next')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attendance-page-next')));
      await tester.pumpAndSettle();

      expect(find.text('Roll Kid 12'), findsOneWidget);
      expect(find.text('Roll Kid 01'), findsNothing);
      expect(barColor('STU-ATT-11').color, ClassroomPalette.green);
    },
  );
}
