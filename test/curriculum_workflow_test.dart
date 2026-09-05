import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/curriculum_models.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CurriculumService.resetForTests();
    LessonPlanService.resetForTests();
    ExamService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'vp.curric',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('unit serializes with version history and standard codes', () {
    final now = DateTime.utc(2026, 9, 3);
    final original = CurriculumUnit(
      id: 'CU-0001',
      schoolId: 'TB-001',
      title: 'Living things',
      subject: 'Science',
      gradeLevel: 'Grade 4A',
      className: 'Grade 4A',
      strand: 'Biology',
      framework: CurriculumFramework.national,
      standardCodes: const ['NS-4.1', 'NS-4.2'],
      examPaperIds: const ['EX-0001'],
      attachmentPaths: const ['curriculum_attachments/map.pdf'],
      version: 2,
      versions: [
        CurriculumUnitVersion(
          version: 1,
          snapshot: const {'title': 'Life'},
          changedBy: 'vp.curric',
          changedAt: now,
          note: 'Renamed',
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    final copy = CurriculumUnit.fromMap(original.toMap());
    expect(copy.id, 'CU-0001');
    expect(copy.framework, CurriculumFramework.national);
    expect(copy.standardCodes, ['NS-4.1', 'NS-4.2']);
    expect(copy.examPaperIds, ['EX-0001']);
    expect(copy.attachmentPaths, ['curriculum_attachments/map.pdf']);
    expect(copy.versions, hasLength(1));
    expect(copy.versions.first.note, 'Renamed');
  });

  test('updateUnit appends a version snapshot', () async {
    final unit = await CurriculumService.instance.createUnit(
      title: 'Fractions',
      subject: 'Mathematics',
      schoolId: 'TB-001',
      standardCodes: const ['M-5.2'],
    );
    expect(unit.version, 1);
    expect(unit.versions, isEmpty);

    await CurriculumService.instance.updateUnit(
      unit.id,
      title: 'Fractions and ratios',
      note: 'Added ratios',
    );
    expect(unit.version, 2);
    expect(unit.versions, hasLength(1));
    expect(unit.versions.first.snapshot['title'], 'Fractions');
    expect(unit.versions.first.note, 'Added ratios');
    expect(unit.title, 'Fractions and ratios');
  });

  test('students cannot see draft units', () async {
    final unit = await CurriculumService.instance.createUnit(
      title: 'Draft map',
      subject: 'Science',
      className: 'Grade 4A',
      schoolId: 'TB-001',
    );
    expect(unit.status, CurriculumUnitStatus.draft);

    AuthService.currentUser = RegisteredUser(
      username: 'sara',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
      linkedStudentId: 'STU-1001',
    );
    expect(CurriculumService.instance.unitsForSchool('TB-001'), isEmpty);

    AuthService.currentUser = RegisteredUser(
      username: 'vp.curric',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
    await CurriculumService.instance.setUnitStatus(
      unit.id,
      CurriculumUnitStatus.published,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'sara',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
      linkedStudentId: 'STU-1001',
    );
    final visible = CurriculumService.instance.publishedForClass(
      'Grade 4A',
      schoolId: 'TB-001',
    );
    expect(visible, hasLength(1));
    expect(visible.first.title, 'Draft map');
  });

  test('DH review updates reviewStatus without changing LessonPlanStatus', () async {
    final plan = await LessonPlanService.instance.createPlan(
      title: 'Week 1 plants',
      className: 'Grade 4A',
      subject: 'Science',
      schoolId: 'TB-001',
    );
    await LessonPlanService.instance.setStatus(
      plan.id,
      LessonPlanStatus.published,
    );
    expect(plan.status, LessonPlanStatus.published);
    expect(plan.reviewStatus, LessonPlanReviewStatus.none);

    await CurriculumService.instance.reviewLessonPlan(
      lessonPlanId: plan.id,
      decision: LessonPlanReviewDecision.approved,
      notes: 'Clear objectives',
    );
    expect(plan.status, LessonPlanStatus.published);
    expect(plan.reviewStatus, LessonPlanReviewStatus.approved);
    expect(plan.latestReviewId, isNotNull);
    expect(CurriculumService.instance.reviewsForSchool('TB-001'), hasLength(1));
  });

  test('students and parents never see evaluation files or meetings', () async {
    await CurriculumService.instance.recordEvaluation(
      teacherId: 'T-0001',
      teacherName: 'Teacher Sci',
      teacherUsername: 'teacher.sci',
      periodLabel: 'Term 1',
      schoolId: 'TB-001',
    );
    await CurriculumService.instance.recordMeeting(
      title: 'Department briefing',
      startsAt: DateTime.utc(2026, 9, 4, 9),
      schoolId: 'TB-001',
    );
    expect(CurriculumService.instance.evaluationsForSchool('TB-001'), hasLength(1));
    expect(CurriculumService.instance.meetingsForSchool('TB-001'), hasLength(1));

    AuthService.currentUser = RegisteredUser(
      username: 'sara',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
    );
    expect(CurriculumService.instance.evaluationsForSchool('TB-001'), isEmpty);
    expect(CurriculumService.instance.meetingsForSchool('TB-001'), isEmpty);
    expect(CurriculumService.instance.reviewsForSchool('TB-001'), isEmpty);

    AuthService.currentUser = RegisteredUser(
      username: 'parent.sara',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(CurriculumService.instance.evaluationsForSchool('TB-001'), isEmpty);
    expect(CurriculumService.instance.meetingsForSchool('TB-001'), isEmpty);
  });

  test('linking a paper id does not create an exam attempt or score', () async {
    await CurriculumService.instance.createUnit(
      title: 'Aligned science',
      subject: 'Science',
      examPaperIds: const ['EX-0001'],
      schoolId: 'TB-001',
    );
    expect(ExamService.instance.attempts, isEmpty);
    expect(ExamService.instance.papers, isEmpty);
  });

  test('curriculum rides academic and syncs on the standard lane', () {
    expect(ModuleAccess.canView('curriculum'), isTrue);
    expect(ModuleAccess.canManage('curriculum'), isTrue);
    expect(ModuleAccess.normalize('curriculum'), 'academic');
    expect(ModuleAccess.normalize('academic_meetings'), 'academic');
    expect(AppCollections.curriculumUnits, 'curriculum_units');
    expect(AppCollections.curriculumFeedback, 'curriculum_feedback');
    expect(AppCollections.lessonPlanReviews, 'lesson_plan_reviews');
    expect(AppCollections.teacherEvaluations, 'teacher_evaluations');
    expect(AppCollections.academicMeetings, 'academic_meetings');
    expect(
      CloudSyncEngine.standardPriority,
      containsAll([
        'curriculum_units',
        'curriculum_feedback',
        'lesson_plan_reviews',
        'teacher_evaluations',
        'academic_meetings',
      ]),
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      containsAll(['curriculum_units', 'curriculum_feedback']),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'sara',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      containsAll(['curriculum_units', 'curriculum_feedback']),
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      isNot(contains('teacher_evaluations')),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'owner.curric',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    expect(ids, contains('curriculum'));
  });
}
