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
    expect(copy.isPublished, isTrue);
    expect(copy.covers(week.add(const Duration(days: 3))), isTrue);
    expect(copy.covers(week.add(const Duration(days: 8))), isFalse);
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
}
