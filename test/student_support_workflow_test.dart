import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/student_support_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSupportService.resetForTests();
    ExamService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'vp.care',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('health, IEP, and safeguarding serialize', () {
    final now = DateTime.utc(2026, 9, 3);
    final health = HealthRecord(
      id: 'HR-0001',
      schoolId: 'TB-001',
      studentId: 'STU-1001',
      studentName: 'Sara',
      type: HealthRecordType.vaccination,
      title: 'MMR',
      details: 'Dose 2',
      staffNotes: 'Clinic only',
      createdAt: now,
      updatedAt: now,
    );
    final iep = IepPlan(
      id: 'IP-0001',
      schoolId: 'TB-001',
      studentId: 'STU-1001',
      studentName: 'Sara',
      goals: 'Reading fluency',
      staffNotes: 'Internal',
      createdAt: now,
      updatedAt: now,
    );
    final cp = SafeguardingCase(
      id: 'SG-0001',
      schoolId: 'TB-001',
      studentId: 'STU-1001',
      studentName: 'Sara',
      title: 'Concern',
      details: 'Restricted',
      createdAt: now,
      updatedAt: now,
    );
    expect(HealthRecord.fromMap(health.toMap()).staffNotes, 'Clinic only');
    expect(HealthRecord.fromMap(health.toMap(includeStaffNotes: false)).staffNotes, '');
    expect(IepPlan.fromMap(iep.toMap()).goals, 'Reading fluency');
    expect(SafeguardingCase.fromMap(cp.toMap()).isOpen, isTrue);
  });

  test('parents never see safeguarding or counseling staff notes', () async {
    await StudentSupportService.instance.addCounselingRecord(
      studentId: 'STU-1001',
      kind: CounselingKind.session,
      title: 'Check-in',
      parentSummary: 'Talked about homework habits',
      staffNotes: 'Private clinical note',
      schoolId: 'TB-001',
    );
    await StudentSupportService.instance.openSafeguardingCase(
      studentId: 'STU-1001',
      title: 'Restricted file',
      details: 'Do not share',
      schoolId: 'TB-001',
    );
    expect(
      StudentSupportService.instance.counselingForSchool('TB-001').first.staffNotes,
      'Private clinical note',
    );
    expect(
      StudentSupportService.instance.safeguardingForSchool('TB-001'),
      hasLength(1),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.g',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
    );
    final visible = StudentSupportService.instance.counselingForSchool('TB-001');
    expect(visible, hasLength(1));
    expect(visible.first.parentSummary, 'Talked about homework habits');
    expect(visible.first.staffNotes, isEmpty);
    expect(StudentSupportService.instance.safeguardingForSchool('TB-001'), isEmpty);

    AuthService.currentUser = RegisteredUser(
      username: 'sara.g',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
      linkedStudentId: 'STU-1001',
    );
    expect(StudentSupportService.instance.counselingForSchool('TB-001'), isEmpty);
    expect(StudentSupportService.instance.healthForSchool('TB-001'), isEmpty);
    expect(StudentSupportService.instance.iepForSchool('TB-001'), isEmpty);
    expect(StudentSupportService.instance.safeguardingForSchool('TB-001'), isEmpty);
  });

  test('parent can file a support request and sign an IEP without grades', () async {
    final plan = await StudentSupportService.instance.addIepPlan(
      studentId: 'STU-1001',
      goals: 'Stay on task',
      stage: IepStage.draftPlan,
      schoolId: 'TB-001',
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.g',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
    );
    final request = await StudentSupportService.instance.submitSupportRequest(
      studentId: 'STU-1001',
      kind: SupportRequestKind.counselingAppointment,
      body: 'Please schedule a check-in',
    );
    expect(request.id.startsWith('SR-'), isTrue);
    expect(request.status, SupportRequestStatus.open);

    final signed = await StudentSupportService.instance.signIepPlan(plan.id);
    expect(signed.parentAgreed, isTrue);
    expect(signed.parentSignedAt, isNotNull);
    expect(signed.stage, IepStage.parentAgreement);
    expect(ExamService.instance.attempts, isEmpty);
    expect(ExamService.instance.papers, isEmpty);
  });

  test('care desk aliases to student affairs; safeguarding is its own module', () {
    expect(ModuleAccess.canView('student_support'), isTrue);
    expect(ModuleAccess.canManage('student_support'), isTrue);
    expect(ModuleAccess.normalize('health'), 'student_affairs');
    expect(ModuleAccess.normalize('student_support'), 'student_affairs');
    expect(ModuleAccess.canView('safeguarding'), isTrue);
    expect(ModuleAccess.canManage('safeguarding'), isTrue);
    expect(ModuleAccess.normalize('safeguarding'), 'safeguarding');

    expect(AppCollections.healthRecords, 'health_records');
    expect(AppCollections.safeguardingCases, 'safeguarding_cases');
    expect(
      CloudSyncEngine.standardPriority,
      containsAll([
        'health_records',
        'counseling_records',
        'iep_plans',
        'college_guidance',
        'support_requests',
        'safeguarding_cases',
      ]),
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      contains('safeguarding_cases'),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'qa.g',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.qualityAssurance],
    );
    expect(ModuleAccess.canView('safeguarding'), isFalse);
    expect(ModuleAccess.canManage('safeguarding'), isFalse);

    AuthService.currentUser = RegisteredUser(
      username: 'parent.g',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      containsAll(['health_records', 'support_requests']),
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      isNot(contains('safeguarding_cases')),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'sara.g',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      containsAll(['college_guidance', 'support_requests']),
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      isNot(contains('safeguarding_cases')),
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      isNot(contains('health_records')),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'owner.g',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    expect(ids, containsAll(['student_support', 'safeguarding']));
  });
}
