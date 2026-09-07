import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LessonPlanService.resetForTests();
  });

  test('lesson plan serializes with linked homework, paper, and material ids', () {
    final week = LessonPlan.mondayOf(DateTime.utc(2026, 9, 7));
    final original = LessonPlan(
      id: 'LP-0001',
      schoolId: 'TB-001',
      title: 'Science week 1',
      className: 'Grade 4A',
      subject: 'Science',
      weekStart: week,
      objectives: 'Identify plant parts',
      activities: 'Label a diagram',
      homeworkIds: const ['HW-1'],
      examPaperIds: const ['EX-0001'],
      learningMaterialIds: const ['LM-1'],
      attachmentPaths: const ['lesson_plan_attachments/notes.pdf'],
      status: LessonPlanStatus.published,
      createdAt: week,
      updatedAt: week,
    );
    final copy = LessonPlan.fromMap(original.toMap());
    expect(copy.id, 'LP-0001');
    expect(copy.weekStart, week);
    expect(copy.homeworkIds, ['HW-1']);
    expect(copy.examPaperIds, ['EX-0001']);
    expect(copy.learningMaterialIds, ['LM-1']);
    expect(copy.attachmentPaths, ['lesson_plan_attachments/notes.pdf']);
    expect(copy.isPublished, isTrue);
    expect(copy.covers(week.add(const Duration(days: 3))), isTrue);
    expect(copy.covers(week.add(const Duration(days: 8))), isFalse);
    expect(copy.reviewStatus, LessonPlanReviewStatus.none);
    expect(copy.curriculumUnitId, isNull);
  });

  test('Phase D maps without review fields still load', () {
    final week = LessonPlan.mondayOf(DateTime.utc(2026, 9, 7));
    final copy = LessonPlan.fromMap({
      'id': 'LP-0002',
      'schoolId': 'TB-001',
      'title': 'Legacy plan',
      'className': 'Grade 4A',
      'subject': 'Science',
      'weekStart': week.toIso8601String(),
      'status': 'published',
      'createdAt': week.toIso8601String(),
      'updatedAt': week.toIso8601String(),
    });
    expect(copy.reviewStatus, LessonPlanReviewStatus.none);
    expect(copy.curriculumUnitId, isNull);
    expect(copy.latestReviewId, isNull);
    expect(copy.attachmentPaths, isEmpty);
    expect(copy.isPublished, isTrue);
  });

  test('draft stays hidden from students until published', () async {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.sci',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      fullName: 'Teacher',
    );
    final plan = await LessonPlanService.instance.createPlan(
      title: 'Plants',
      className: 'Grade 4A',
      subject: 'Science',
      schoolId: 'TB-001',
    );
    expect(plan.status, LessonPlanStatus.draft);
    expect(LessonPlanService.instance.draftCount('TB-001'), 1);

    AuthService.currentUser = RegisteredUser(
      username: 'sara',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
      fullName: 'Sara Bekele',
      linkedStudentId: 'STU-1001',
    );
    expect(
      LessonPlanService.instance.publishedForClass('Grade 4A', schoolId: 'TB-001'),
      isEmpty,
    );
    expect(LessonPlanService.instance.forSchool('TB-001'), isEmpty);

    AuthService.currentUser = RegisteredUser(
      username: 'teacher.sci',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    await LessonPlanService.instance.setStatus(
      plan.id,
      LessonPlanStatus.published,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'sara',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
      linkedStudentId: 'STU-1001',
    );
    final visible = LessonPlanService.instance.publishedForClass(
      'Grade 4A',
      schoolId: 'TB-001',
    );
    expect(visible, hasLength(1));
    expect(visible.first.title, 'Plants');
    AuthService.currentUser = null;
  });

  test('publishedForClass matches compact 5B with Grade 5B', () async {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.sci',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    await LessonPlanService.instance.createPlan(
      title: 'Fractions',
      className: 'Grade 5B',
      subject: 'Mathematics',
      schoolId: 'TB-001',
    );
    final draft = LessonPlanService.instance.forClass('5B', schoolId: 'TB-001');
    expect(draft, hasLength(1));
    await LessonPlanService.instance.setStatus(
      draft.first.id,
      LessonPlanStatus.published,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.5b',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(
      LessonPlanService.instance.publishedForClass('5B', schoolId: 'TB-001'),
      hasLength(1),
    );
    AuthService.currentUser = null;
  });

  test('lesson plans ride academic, not examinations', () {
    AuthService.currentUser = RegisteredUser(
      username: 'vp.lessons',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
    expect(ModuleAccess.canView('lesson_plans'), isTrue);
    expect(ModuleAccess.canManage('lesson_plans'), isTrue);
    expect(ModuleAccess.normalize('lesson_plans'), 'academic');
    expect(ModuleAccess.normalize('lessons'), 'academic');
    expect(AppCollections.lessonPlans, 'lesson_plans');
    expect(CloudSyncEngine.standardPriority, contains('lesson_plans'));

    AuthService.currentUser = RegisteredUser(
      username: 'owner.lessons',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    expect(ids, contains('lesson_plans'));
    AuthService.currentUser = null;
  });

  test('createPlan keeps course file paths', () async {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.sci',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    final plan = await LessonPlanService.instance.createPlan(
      title: 'Plants',
      className: 'Grade 4A',
      subject: 'Science',
      schoolId: 'TB-001',
      attachmentPaths: const ['lesson_plan_attachments/slides.pdf'],
    );
    expect(plan.attachmentPaths, ['lesson_plan_attachments/slides.pdf']);
    expect(
      LessonPlanService.instance.planById(plan.id)?.attachmentPaths,
      ['lesson_plan_attachments/slides.pdf'],
    );
    AuthService.currentUser = null;
  });
}
