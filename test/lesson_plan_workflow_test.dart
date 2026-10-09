import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/setup/dashboard_setup.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/widgets/lesson_plan_view_card.dart';
import 'package:mayabela/widgets/platform_path_image.dart';

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
      successCriteria: 'I can label a diagram',
      keyVocabulary: 'petal, stem',
      priorKnowledge: 'Living things',
      starter: 'Mystery plant photo',
      activities: 'Label a diagram',
      plenary: 'Exit ticket',
      differentiation: 'Word bank for support',
      assessment: 'Exit ticket',
      homeLearning: 'Draw a plant at home',
      inclusionNotes: 'Large-print worksheet',
      durationMinutes: 40,
      periodLabel: 'Period 3–4',
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
    expect(copy.successCriteria, 'I can label a diagram');
    expect(copy.keyVocabulary, 'petal, stem');
    expect(copy.starter, 'Mystery plant photo');
    expect(copy.plenary, 'Exit ticket');
    expect(copy.differentiation, 'Word bank for support');
    expect(copy.homeLearning, 'Draw a plant at home');
    expect(copy.durationMinutes, 40);
    expect(copy.periodLabel, 'Period 3–4');
    expect(copy.hasSequence, isTrue);
    expect(copy.homeworkIds, ['HW-1']);
    expect(copy.examPaperIds, ['EX-0001']);
    expect(copy.learningMaterialIds, ['LM-1']);
    expect(copy.attachmentPaths, ['lesson_plan_attachments/notes.pdf']);
    expect(copy.isPublished, isTrue);
    expect(copy.covers(week.add(const Duration(days: 3))), isTrue);
    expect(copy.covers(week.add(const Duration(days: 8))), isFalse);
    expect(copy.reviewStatus, LessonPlanReviewStatus.none);
    expect(copy.reviewLabel, isEmpty);
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
    expect(copy.successCriteria, isEmpty);
    expect(copy.starter, isEmpty);
    expect(copy.plenary, isEmpty);
    expect(copy.durationMinutes, isNull);
    expect(copy.hasSequence, isFalse);
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

  test('teacher, parent, and student dashboards include lesson plans', () {
    registerAllDashboards();
    expect(
      sectionDefinitionsFor(AuthService.roleTeacher).expand((s) => s.entryIds),
      contains('lesson_plans'),
    );
    expect(
      sectionDefinitionsFor(AuthService.roleParent).expand((s) => s.entryIds),
      contains('lesson_plans'),
    );
    expect(
      sectionDefinitionsFor(AuthService.roleStudent).expand((s) => s.entryIds),
      contains('lesson_plans'),
    );
    expect(
      DashboardRegistry.find(AuthService.roleTeacher, 'lesson_plans'),
      isNotNull,
    );
    expect(
      DashboardRegistry.find(AuthService.roleParent, 'lesson_plans'),
      isNotNull,
    );
    expect(
      DashboardRegistry.find(AuthService.roleStudent, 'lesson_plans'),
      isNotNull,
    );
  });

  test('parent JWT class names see an admin-published lesson plan', () async {
    AuthService.currentUser = RegisteredUser(
      username: 'admin.plans',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    final plan = await LessonPlanService.instance.createPlan(
      title: 'Admin weekly plan',
      className: '4A',
      subject: 'Science',
      schoolId: 'TB-001',
    );
    await LessonPlanService.instance.setStatus(
      plan.id,
      LessonPlanStatus.published,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.plans',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-LP-1'],
    );
    AuthService.applyCloudAccessScope(
      linkedClassNames: const ['Grade 4A'],
      linkedStudentIds: const ['STU-LP-1'],
    );
    expect(
      LessonPlanService.instance
          .publishedForClass('Grade 4A', schoolId: 'TB-001')
          .map((p) => p.title),
      contains('Admin weekly plan'),
    );
    AuthService.clearCloudAccessScope();
    AuthService.currentUser = null;
  });

  test('parent lesson-plan SQL allows published class reads', () {
    final sql = File(
      'supabase/migrations/20261009140000_lesson_plans_parent_reads.sql',
    ).readAsStringSync();
    expect(sql, contains("'lesson_plans'"));
    expect(sql, contains("r = 'parent'"));
    expect(sql, contains("<> 'published'"));
    expect(sql, contains("'daily_activities',\n      'lesson_plans'"));
  });

  test('createPlan stores the international weekly-plan fields', () async {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.sci',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    final plan = await LessonPlanService.instance.createPlan(
      title: 'Plant parts',
      className: 'Grade 4A',
      subject: 'Science',
      schoolId: 'TB-001',
      objectives: 'Name the parts of a flowering plant',
      successCriteria: 'I can label petal, stem, and root',
      keyVocabulary: 'petal, stem, root',
      priorKnowledge: 'Living and non-living',
      starter: 'Show a mystery plant',
      activities: 'Guided labelling then independent diagram',
      plenary: 'Three-question exit ticket',
      differentiation: 'Word bank; challenge: function of each part',
      assessment: 'Exit ticket plus questioning',
      homeLearning: 'Sketch a plant from home',
      inclusionNotes: 'Large-print labels',
      durationMinutes: 40,
      periodLabel: 'Period 3–4',
    );
    expect(plan.successCriteria, contains('petal'));
    expect(plan.hasSequence, isTrue);
    expect(plan.durationMinutes, 40);
    await LessonPlanService.instance.updatePlan(
      plan.id,
      plenary: 'Mini whiteboard recap',
      clearDuration: true,
    );
    expect(
      LessonPlanService.instance.planById(plan.id)?.plenary,
      'Mini whiteboard recap',
    );
    expect(LessonPlanService.instance.planById(plan.id)?.durationMinutes, isNull);
    AuthService.currentUser = null;
  });

  test('snapshotMaps drops laptop-only lesson-plan files', () async {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.sci',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    await LessonPlanService.instance.createPlan(
      title: 'Plant parts',
      className: 'Grade 4A',
      subject: 'Science',
      schoolId: 'TB-001',
      attachmentPaths: const [
        r'C:\Users\nabil\worksheet.pdf',
        'web://blob/local-slides',
        'schools/TB-001/lesson_plan_attachments/slides.pdf',
      ],
    );
    final paths = List<String>.from(
      LessonPlanService.instance.snapshotMaps().single['attachmentPaths'] as List,
    );
    expect(paths, isNot(contains(r'C:\Users\nabil\worksheet.pdf')));
    expect(paths, isNot(contains('web://blob/local-slides')));
    expect(paths, ['schools/TB-001/lesson_plan_attachments/slides.pdf']);
    AuthService.currentUser = null;
  });

  testWidgets('lesson plan card expands with sequence and file tiles', (
    tester,
  ) async {
    final week = LessonPlan.mondayOf(DateTime.utc(2026, 9, 7));
    final plan = LessonPlan(
      id: 'LP-VIEW',
      schoolId: 'TB-001',
      title: 'Science week 1',
      className: 'Grade 4A',
      subject: 'Science',
      weekStart: week,
      objectives: 'Identify plant parts',
      successCriteria: 'I can label a diagram',
      starter: 'Mystery plant photo',
      activities: 'Guided labelling',
      plenary: 'Exit ticket',
      attachmentPaths: const [
        'schools/TB-001/lesson_plan_attachments/worksheet.pdf',
        'schools/TB-001/lesson_plan_attachments/diagram.jpg',
      ],
      createdAt: week,
      updatedAt: week,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              LessonPlanViewCard(plan: plan),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Science week 1'), findsOneWidget);
    await tester.tap(find.text('Science week 1'));
    await tester.pumpAndSettle();

    expect(find.text('Identify plant parts'), findsOneWidget);
    expect(find.text('Success criteria'), findsOneWidget);
    expect(find.text('Starter / hook'), findsOneWidget);
    expect(find.text('Main teaching & learning'), findsOneWidget);
    expect(find.text('Plenary'), findsOneWidget);
    expect(find.text('worksheet.pdf'), findsOneWidget);
    expect(find.text('diagram.jpg'), findsOneWidget);
    expect(find.text('Resources & worksheets'), findsOneWidget);
    expect(find.byType(PlatformPathImage), findsNothing);
    expect(find.byType(LessonPlanAttachmentList), findsOneWidget);
  });

  testWidgets('expanded lesson plan stays open after a parent rebuild', (
    tester,
  ) async {
    final week = LessonPlan.mondayOf(DateTime.utc(2026, 9, 7));
    final plan = LessonPlan(
      id: 'LP-KEEP',
      schoolId: 'TB-001',
      title: 'Kept open',
      className: 'Grade 4A',
      subject: 'Science',
      weekStart: week,
      objectives: 'Stay visible after rebuild',
      createdAt: week,
      updatedAt: week,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Rebuild'),
                  ),
                  Expanded(
                    child: LessonPlanViewCard(
                      key: ValueKey(plan.id),
                      plan: plan,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Kept open'));
    await tester.pumpAndSettle();
    expect(find.text('Stay visible after rebuild'), findsOneWidget);

    await tester.tap(find.text('Rebuild'));
    await tester.pump();
    expect(find.text('Stay visible after rebuild'), findsOneWidget);
  });
}
