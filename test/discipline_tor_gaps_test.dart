import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/discipline_case.dart';
import 'package:mayabela/screens/teacher_student_affairs_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/discipline_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/web_erp/pages/web_student_affairs_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DisciplineService.instance.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.disc',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      fullName: 'Ms Hana',
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
    DisciplineService.instance.resetForTests();
  });

  test(
    'filed report tags a conduct code and notifies parent plus desk',
    () async {
      final filed = await DisciplineService.instance.fileReport(
        studentId: 'STU-1001',
        studentName: 'Sara Bekele',
        className: 'Grade 4A',
        kind: DisciplineCaseKind.incident,
        title: 'Classroom disruption',
        description: 'Talking over the lesson',
        conductCode: 'Disruption',
      );

      expect(filed.conductCode, 'Disruption');
      expect(filed.parentNotified, isTrue);
      expect(filed.status, DisciplineCaseStatus.submitted);

      final copy = DisciplineCase.fromMap(filed.toMap());
      expect(copy.conductCode, 'Disruption');

      final notes = NotificationService.instance.itemsForTests();
      expect(
        notes.any(
          (n) =>
              n.recipientRole == AuthService.roleParent &&
              n.targetStudentId == 'STU-1001' &&
              n.body.contains('Classroom disruption') &&
              n.body.contains('Disruption'),
        ),
        isTrue,
      );
      expect(
        notes.any(
          (n) =>
              n.title == 'New discipline report' &&
              n.recipientRole == AuthService.roleAdmin &&
              n.body.contains('Sara Bekele'),
        ),
        isTrue,
      );
    },
  );

  test('escalation reaches section director and notifies parent', () async {
    final filed = await DisciplineService.instance.fileReport(
      studentId: 'STU-1001',
      studentName: 'Sara Bekele',
      className: 'Grade 4A',
      kind: DisciplineCaseKind.behaviour,
      title: 'Repeated disrespect',
      description: 'Ignored two warnings',
      conductCode: 'Disrespect',
      notifyParent: false,
    );

    final updated = await DisciplineService.instance.updateCase(
      filed.id,
      (cur) => cur.copyWith(
        status: DisciplineCaseStatus.escalated,
        escalatedTo: 'section_director',
        parentNotified: true,
      ),
      notifyParent: true,
    );

    expect(updated, isNotNull);
    expect(updated!.escalatedTo, 'section_director');
    expect(
      DisciplineConductCodes.escalationLabel(updated.escalatedTo),
      'Section Director',
    );

    final notes = NotificationService.instance.itemsForTests();
    expect(
      notes.any(
        (n) =>
            n.recipientRole == AuthService.roleParent &&
            n.body.contains('Section Director'),
      ),
      isTrue,
    );
    expect(
      notes.any(
        (n) =>
            n.title == 'Discipline case escalated' &&
            n.recipientRole == AuthService.roleAdmin,
      ),
      isTrue,
    );
  });

  test('resolved reports stay closed for the teacher and the desk', () async {
    final filed = await DisciplineService.instance.fileReport(
      studentId: 'STU-1001',
      studentName: 'Sara Bekele',
      className: 'Grade 4A',
      kind: DisciplineCaseKind.behaviour,
      title: 'Repeated disruption',
      description: 'Talked over the lesson twice',
      notifyParent: false,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'affairs.desk',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
      fullName: 'Student Affairs',
    );
    final closed = await DisciplineService.instance.updateCase(
      filed.id,
      (cur) => cur.copyWith(
        status: DisciplineCaseStatus.resolved,
        outcome: DisciplineOutcome.warning,
        outcomeNotes: 'Spoken to the student',
      ),
    );

    expect(closed, isNotNull);
    expect(closed!.isClosed, isTrue);
    expect(closed.isOpen, isFalse);
    expect(
      DisciplineService.instance.forSchool('TB-001').where((c) => c.isClosed),
      isNotEmpty,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'teacher.disc',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      fullName: 'Ms Hana',
    );
    final mine = DisciplineService.instance.reportsForCurrentTeacher();
    expect(mine, hasLength(1));
    expect(mine.single.id, filed.id);
    expect(mine.single.isClosed, isTrue);
    expect(mine.single.outcome, DisciplineOutcome.warning);
    expect(
      DisciplineCase.fromMap({'status': 'closed'}).status,
      DisciplineCaseStatus.resolved,
    );
    expect(
      DisciplineCase.fromMap({'status': 'hearingScheduled'}).status,
      DisciplineCaseStatus.hearingScheduled,
    );
  });

  testWidgets('teacher student affairs keeps a closed report on the list', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 30);
    DisciplineService.instance.applyPersistedData([
      DisciplineCase(
        id: 'dc-closed-1',
        schoolId: 'TB-001',
        studentId: 'STU-1001',
        studentName: 'Sara Bekele',
        className: 'Grade 4A',
        reporterId: 'teacher.disc',
        reporterName: 'Ms Hana',
        reporterRole: 'teacher',
        kind: DisciplineCaseKind.incident,
        title: 'Phone in class',
        description: 'Used phone during exam review',
        status: DisciplineCaseStatus.resolved,
        outcome: DisciplineOutcome.warning,
        outcomeNotes: 'Warning issued',
        handledByName: 'Student Affairs',
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(home: TeacherStudentAffairsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Closed reports'), findsOneWidget);
    expect(find.text('Sara Bekele — Phone in class'), findsOneWidget);
    expect(find.textContaining('Closed'), findsWidgets);
    expect(find.textContaining('Warning issued'), findsOneWidget);
  });

  testWidgets('student affairs open filter shows a teacher-filed case', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 9, 30);
    AuthService.currentUser = RegisteredUser(
      username: 'affairs.desk',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      fullName: 'Student Affairs',
      staffRoles: const [StaffRoles.studentAffairs],
    );
    DisciplineService.instance.applyPersistedData([
      DisciplineCase(
        id: 'dc-open-other-pc',
        schoolId: 'TB-001',
        studentId: 'STU-1001',
        studentName: 'Sara Bekele',
        className: 'Grade 4A',
        reporterId: 'teacher.disc',
        reporterName: 'Ms Hana',
        reporterRole: 'teacher',
        kind: DisciplineCaseKind.incident,
        title: 'Classroom disruption',
        description: 'Talking over the lesson',
        status: DisciplineCaseStatus.submitted,
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebStudentAffairsPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('No discipline cases in this view.'), findsNothing);
    expect(find.text('Sara Bekele — Grade 4A'), findsOneWidget);
    expect(find.text('Classroom disruption'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.textContaining('Reported by Ms Hana'), findsOneWidget);
  });

  test('detention is a first-class outcome on the same case store', () {
    expect(
      DisciplineConductCodes.outcomeLabel(DisciplineOutcome.detention),
      'Detention',
    );
    final now = DateTime.utc(2026, 9, 11);
    final restored = DisciplineCase.fromMap(
      DisciplineCase(
        id: 'dc-det',
        schoolId: 'TB-001',
        studentId: 'STU-1001',
        studentName: 'Sara Bekele',
        className: 'Grade 4A',
        reporterId: 't1',
        reporterName: 'Ms Hana',
        reporterRole: 'teacher',
        kind: DisciplineCaseKind.incident,
        title: 'Phone in class',
        description: 'Used phone during exam review',
        conductCode: 'Academic integrity',
        status: DisciplineCaseStatus.resolved,
        outcome: DisciplineOutcome.detention,
        createdAt: now,
        updatedAt: now,
      ).toMap(),
    );
    expect(restored.outcome, DisciplineOutcome.detention);
    expect(restored.conductCode, 'Academic integrity');
  });

  test('student affairs on another session still sees a teacher report as open',
      () async {
    final filed = await DisciplineService.instance.fileReport(
      studentId: 'STU-1001',
      studentName: 'Sara Bekele',
      className: 'Grade 4A',
      kind: DisciplineCaseKind.incident,
      title: 'Classroom disruption',
      description: 'Talking over the lesson',
      notifyParent: false,
    );

    expect(filed.schoolId, 'TB-001');
    expect(filed.isOpen, isTrue);
    expect(filed.status, DisciplineCaseStatus.submitted);
    final snapshot = DisciplineService.instance.snapshotMaps().single;
    expect(snapshot['id'], filed.id);
    expect(snapshot['schoolId'], 'TB-001');
    expect(snapshot['status'], 'submitted');

    // Other PC / other login: Student Affairs desk, same in-memory school
    // store after cloud pull. Must not be filtered to the teacher's own
    // reports, and must show as an Open case.
    AuthService.currentUser = RegisteredUser(
      username: 'affairs.desk',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      fullName: 'Student Affairs',
      staffRoles: const [StaffRoles.studentAffairs],
    );
    expect(AuthService.mayReadAllSchoolData, isTrue);
    expect(AuthService.usesScopedCloudReads, isFalse);
    expect(ModuleAccess.canManage('student_affairs'), isTrue);

    final open = DisciplineService.instance
        .forSchool('TB-001')
        .where((c) => c.isOpen)
        .toList();
    expect(open, hasLength(1));
    expect(open.single.id, filed.id);
    expect(open.single.reporterId, 'teacher.disc');
  });

  test('student affairs stays on the existing discipline module', () {
    AuthService.currentUser = RegisteredUser(
      username: 'admin.disc',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    expect(ModuleAccess.canView('student_affairs'), isTrue);
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    expect(ids, contains('student_affairs'));
  });
}
