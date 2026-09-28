import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/setup/dashboard_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LessonPlanService.resetForTests();
    AuthService.currentUser = null;
    AuthService.clearCloudAccessScope();
  });

  tearDown(() {
    AuthService.currentUser = null;
    AuthService.clearCloudAccessScope();
  });

  test('5B and Grade 5B are the same class for queries and local match', () {
    final compact = StudentRegistryService.classNameQueryValues('5B');
    final roster = StudentRegistryService.classNameQueryValues('Grade 5B');
    expect(compact, contains('5B'));
    expect(compact, contains('Grade 5B'));
    expect(roster, contains('5B'));
    expect(roster, contains('Grade 5B'));
    expect(StudentRegistryService.classNamesMatch('5B', 'Grade 5B'), isTrue);
    expect(StudentRegistryService.classNamesMatch('Grade 5B', '5 B'), isTrue);
  });

  test('teacher assigned to 5B expands cloud className whereIn values', () {
    AuthService.currentUser = RegisteredUser(
      username: 'abebe.homeroom',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    AuthService.applyCloudAccessScope(assignedClassNames: const ['5B']);
    final values = AuthService.cloudClassNameQueryValues();
    expect(values, contains('5B'));
    expect(values, contains('Grade 5B'));
    expect(values.length, lessThanOrEqualTo(10));
  });

  test('parent collections include lesson plans on the standard lane', () {
    AuthService.currentUser = RegisteredUser(
      username: 'parent.loop',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      contains(AppCollections.lessonPlans),
    );
  });

  test('parent dashboard includes the lesson plans tile', () {
    registerAllDashboards();
    final ids = sectionDefinitionsFor(AuthService.roleParent)
        .expand((s) => s.entryIds)
        .toSet();
    expect(ids, contains('lesson_plans'));
    expect(ids, contains('homework'));
    expect(ids, contains('grades'));
    expect(ids, contains('attendance'));
    expect(
      DashboardRegistry.find(AuthService.roleParent, 'lesson_plans'),
      isNotNull,
    );
  });

  test('homework posted as Grade 5B is visible when filtering 5B', () {
    SchoolDataService.instance.applyPersistedHomework([
      HomeworkItem(
        id: 'HW-LOOP-1',
        className: 'Grade 5B',
        subject: 'Mathematics',
        description: 'Page 12',
        teacherName: 'Abebe',
        teacherId: 'TCH-1004',
        postedAt: DateTime.utc(2026, 9, 1),
      ),
    ]);
    final found = SchoolDataService.instance.getHomeworkForClass('5B');
    expect(found.map((h) => h.id), contains('HW-LOOP-1'));
  });

  test('parents only see published lesson plans for an aliased class', () async {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.loop',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    final draft = await LessonPlanService.instance.createPlan(
      title: 'Week 1',
      className: 'Grade 5B',
      subject: 'Science',
      schoolId: 'TB-001',
    );
    await LessonPlanService.instance.createPlan(
      title: 'Hidden draft',
      className: 'Grade 5B',
      subject: 'Science',
      schoolId: 'TB-001',
    );
    await LessonPlanService.instance.setStatus(
      draft.id,
      LessonPlanStatus.published,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.loop',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    final visible = LessonPlanService.instance.publishedForClass(
      '5B',
      schoolId: 'TB-001',
    );
    expect(visible.map((p) => p.title), ['Week 1']);
    expect(
      LessonPlanService.instance.forSchool('TB-001').every((p) => p.isPublished),
      isTrue,
    );
  });

  test('VP homework desk is view-only; teachers still own posting', () {
    AuthService.currentUser = RegisteredUser(
      username: 'vp.loop',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
    expect(ModuleAccess.canView('homework'), isTrue);
    expect(ModuleAccess.canManage('homework'), isFalse);
    expect(ModuleAccess.canView('attendance'), isTrue);
    expect(ModuleAccess.canView('calendar'), isTrue);
    expect(ModuleAccess.canManage('calendar'), isFalse);
  });

  test('Student Affairs can approve parent links; staffs still cannot', () {
    AuthService.currentUser = RegisteredUser(
      username: 'sa.loop',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.studentAffairs],
    );
    expect(ModuleAccess.canView('parents'), isTrue);
    expect(ModuleAccess.canManage('parents'), isTrue);

    AuthService.currentUser = RegisteredUser(
      username: 'ict.staff',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.staffs],
    );
    expect(ModuleAccess.canManage('parents'), isFalse);
    expect(
      AuthService.hasPermission(SchoolPermissions.manageParentLinks),
      isFalse,
    );
  });
}
