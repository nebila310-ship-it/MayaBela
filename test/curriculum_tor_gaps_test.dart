import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/curriculum_models.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/models/qa_monitor_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/qa_monitor_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CurriculumService.resetForTests();
    LessonPlanService.resetForTests();
    QaMonitorService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'vp.curric',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('national and international standard hints stay as free-text codes', () {
    expect(
      CurriculumStandardHints.codesFor(CurriculumFramework.national),
      contains('MoE-PRI'),
    );
    expect(
      CurriculumStandardHints.codesFor(CurriculumFramework.international),
      contains('IB-MYP'),
    );
  });

  test('attach, relink, and alignment counts stay on existing units', () async {
    final unitA = await CurriculumService.instance.createUnit(
      title: 'Living things',
      subject: 'Science',
      schoolId: 'TB-001',
      standardCodes: const ['MoE-PRI'],
    );
    final unitB = await CurriculumService.instance.createUnit(
      title: 'Forces',
      subject: 'Science',
      schoolId: 'TB-001',
    );
    final linked = await LessonPlanService.instance.createPlan(
      title: 'Plants week 1',
      className: 'Grade 4A',
      subject: 'Science',
      schoolId: 'TB-001',
      curriculumUnitId: unitA.id,
    );
    final unlinked = await LessonPlanService.instance.createPlan(
      title: 'Forces week 1',
      className: 'Grade 4A',
      subject: 'Science',
      schoolId: 'TB-001',
    );
    await LessonPlanService.instance.setStatus(
      linked.id,
      LessonPlanStatus.published,
    );
    await LessonPlanService.instance.setStatus(
      unlinked.id,
      LessonPlanStatus.published,
    );

    await CurriculumService.instance.attachLessonPlan(unitA.id, linked.id);
    expect(unitA.lessonPlanIds, contains(linked.id));
    expect(unitA.version, 2);

    var alignment = CurriculumService.instance.alignmentForSchool('TB-001');
    expect(alignment.publishedPlanCount, 2);
    expect(alignment.linkedPublishedPlanCount, 1);
    expect(alignment.unlinkedPublishedPlanCount, 1);
    expect(alignment.unitsWithStandards, 1);

    await LessonPlanService.instance.updatePlan(
      linked.id,
      curriculumUnitId: unitB.id,
    );
    await CurriculumService.instance.syncLessonPlanUnit(
      planId: linked.id,
      previousUnitId: unitA.id,
      nextUnitId: unitB.id,
    );
    expect(unitA.lessonPlanIds, isNot(contains(linked.id)));
    expect(unitB.lessonPlanIds, contains(linked.id));
    expect(
      CurriculumService.instance.plansForUnit(unitB.id).map((p) => p.id),
      contains(linked.id),
    );
  });

  test('restoreUnitVersion brings back the previous title', () async {
    final unit = await CurriculumService.instance.createUnit(
      title: 'Fractions',
      subject: 'Mathematics',
      schoolId: 'TB-001',
    );
    await CurriculumService.instance.updateUnit(
      unit.id,
      title: 'Fractions and ratios',
      note: 'Expanded',
    );
    expect(unit.title, 'Fractions and ratios');
    expect(unit.version, 2);

    await CurriculumService.instance.restoreUnitVersion(unit.id, 1);
    expect(unit.title, 'Fractions');
    expect(unit.versions.last.note, 'Restored from v1');
  });

  test('parent feedback is visible to staff and can be resolved', () async {
    final unit = await CurriculumService.instance.createUnit(
      title: 'Spoken English',
      subject: 'English',
      schoolId: 'TB-001',
    );
    await CurriculumService.instance.setUnitStatus(
      unit.id,
      CurriculumUnitStatus.published,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.lms',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      fullName: 'Mr Bekele',
    );
    final item = await CurriculumService.instance.addFeedback(
      curriculumUnitId: unit.id,
      body: 'Please add more worksheets',
      rating: 4,
      schoolId: 'TB-001',
    );
    expect(item.status, CurriculumFeedbackStatus.open);

    AuthService.currentUser = RegisteredUser(
      username: 'vp.curric',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
    expect(
      CurriculumService.instance.feedbackForSchool('TB-001'),
      hasLength(1),
    );
    await CurriculumService.instance.setFeedbackStatus(
      item.id,
      CurriculumFeedbackStatus.resolved,
    );
    expect(item.status, CurriculumFeedbackStatus.resolved);
  });

  test('curriculum office can read the latest QA audit for a unit', () async {
    final unit = await CurriculumService.instance.createUnit(
      title: 'Living things',
      subject: 'Science',
      schoolId: 'TB-001',
    );
    final now = DateTime.utc(2026, 9, 11);
    QaMonitorService.instance.applyPersistedData(
      audits: [
        AcademicAudit(
          id: 'AUD-CUR-1',
          schoolId: 'TB-001',
          curriculumUnitId: unit.id,
          unitTitle: unit.title,
          verdict: AuditVerdict.gaps,
          notes: 'Need more national codes',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    final audit = QaMonitorService.instance.latestAuditForUnit(
      unit.id,
      schoolId: 'TB-001',
    );
    expect(audit?.verdict, AuditVerdict.gaps);
    expect(audit?.notes, 'Need more national codes');
  });
}
