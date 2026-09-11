import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/discipline_case.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/discipline_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';

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

  test('filed report tags a conduct code and notifies parent plus desk', () async {
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
  });

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
