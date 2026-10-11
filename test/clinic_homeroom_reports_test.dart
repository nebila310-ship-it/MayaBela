import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/student_support_service.dart';
import 'package:mayabela/widgets/clinic_teacher_report_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void signInCareDesk() {
    AuthService.currentUser = RegisteredUser(
      username: 'vp.care',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSupportService.resetForTests();
    signInCareDesk();
  });

  tearDown(() => AuthService.currentUser = null);

  test('homeroom sees clinic and incident reports for their class only',
      () async {
    await StudentSupportService.instance.addHealthRecord(
      studentId: 'STU-1001',
      type: HealthRecordType.clinicVisit,
      title: 'Fell in the yard',
      details: 'Ice pack and rest',
      staffNotes: 'Clinic only — do not tell the class',
      disposition: 'observeClinic',
      followUpAt: DateTime.utc(2026, 10, 13),
      vitalNotes: 'Alert, small bruise',
      schoolId: 'TB-001',
    );
    await StudentSupportService.instance.addHealthRecord(
      studentId: 'STU-1005',
      type: HealthRecordType.accident,
      title: 'Science-lab splash',
      details: 'Rinsed and observed',
      schoolId: 'TB-001',
    );

    final grade4 = StudentSupportService.instance.clinicReportsForClasses(
      const ['Grade 4A'],
      schoolId: 'TB-001',
    );
    expect(grade4, hasLength(1));
    expect(grade4.single.studentName, 'Sara Bekele');
    expect(grade4.single.staffNotes, isEmpty);
    expect(grade4.single.needsSpecialAttention, isTrue);
    expect(grade4.single.vitalNotes, 'Alert, small bruise');

    expect(
      StudentSupportService.instance.clinicReportsForClasses(
        const ['Grade 5B'],
        schoolId: 'TB-001',
      ).map((row) => row.studentId),
      ['STU-1005'],
    );
    expect(
      StudentSupportService.instance.clinicReportsForClasses(
        const ['Grade 4A'],
        schoolId: 'SCH-B',
      ),
      isEmpty,
    );
    expect(
      StudentSupportService.instance.clinicReportBadgeCount(
        const ['Grade 4A'],
        schoolId: 'TB-001',
      ),
      1,
    );
  });

  test('vaccines stay off the homeroom clinic tile', () async {
    await StudentSupportService.instance.addHealthRecord(
      studentId: 'STU-1001',
      type: HealthRecordType.vaccination,
      title: 'MMR',
      schoolId: 'TB-001',
    );
    expect(
      StudentSupportService.instance.clinicReportsForClasses(
        const ['Grade 4A'],
        schoolId: 'TB-001',
      ),
      isEmpty,
    );
  });

  test('clinic reports alias to the student-support desk', () {
    expect(ModuleAccess.normalize('clinic_reports'), 'student_affairs');
  });

  testWidgets('clinic report tile expands to show follow-up detail',
      (tester) async {
    final now = DateTime.utc(2026, 10, 11);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClinicTeacherReportList(
            reports: [
              HealthRecord(
                id: 'HR-TILE-1',
                schoolId: 'TB-001',
                studentId: 'STU-1001',
                studentName: 'Sara Bekele',
                className: 'Grade 4A',
                type: HealthRecordType.clinicVisit,
                title: 'Headache after incident',
                details: 'Observed in clinic, then returned',
                staffNotes: 'hidden',
                disposition: 'returnToClass',
                followUpAt: DateTime.utc(2026, 10, 12),
                vitalNotes: 'Temp 37.2',
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Sara Bekele'), findsOneWidget);
    expect(find.text('Taken to clinic · Grade 4A · 2026-10-11 · Special attention'), findsOneWidget);
    expect(find.textContaining('Observed in clinic'), findsNothing);

    await tester.tap(find.text('Sara Bekele'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Observed in clinic'), findsOneWidget);
    expect(find.textContaining('Temp 37.2'), findsOneWidget);
    expect(find.textContaining('Follow-up 2026-10-12'), findsWidgets);
    expect(find.textContaining('hidden'), findsNothing);
  });
}
