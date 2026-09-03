import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/qa_monitor_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/qa_monitor_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/web_erp/pages/web_qa_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    QaMonitorService.resetForTests();
    CurriculumService.resetForTests();
    ExamService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'qa.monitor',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [
        StaffRoles.qualityAssurance,
        StaffRoles.vicePresident,
      ],
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('observation, survey, and research serialize', () {
    final now = DateTime.utc(2026, 9, 3);
    final obs = TeachingObservation(
      id: 'OBS-0001',
      schoolId: 'TB-001',
      teacherName: 'Ms. Sara',
      planning: 4,
      instruction: 5,
      engagement: 4,
      assessment: 3,
      observedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    final survey = QaSurvey(
      id: 'SVY-0001',
      schoolId: 'TB-001',
      title: 'Term pulse',
      published: true,
      createdAt: now,
      updatedAt: now,
    );
    expect(TeachingObservation.fromMap(obs.toMap()).averageScore, 4);
    expect(QaSurvey.fromMap(survey.toMap()).published, isTrue);
  });

  test('QA can observe, audit curriculum, and never writes exams', () async {
    final unit = await CurriculumService.instance.createUnit(
      title: 'Living things',
      subject: 'Science',
      standardCodes: const ['NS-4.1'],
      schoolId: 'TB-001',
    );
    final obs = await QaMonitorService.instance.recordObservation(
      teacherName: 'Ms. Sara',
      teacherUsername: 'sara.t',
      subject: 'Science',
      curriculumUnitId: unit.id,
      schoolId: 'TB-001',
    );
    expect(obs.id.startsWith('OBS-'), isTrue);
    final audit = await QaMonitorService.instance.recordAudit(
      curriculumUnitId: unit.id,
      verdict: AuditVerdict.gaps,
      notes: 'Standard NS-4.1 not covered this week',
      schoolId: 'TB-001',
    );
    expect(audit.standardCodes, contains('NS-4.1'));
    expect(ExamService.instance.attempts, isEmpty);
    expect(ExamService.instance.papers, isEmpty);
  });

  test('parents see published surveys only and not observations', () async {
    await QaMonitorService.instance.recordObservation(
      teacherName: 'Ms. Sara',
      schoolId: 'TB-001',
    );
    final draft = await QaMonitorService.instance.createSurvey(
      title: 'Draft pulse',
      audience: SurveyAudience.parent,
      schoolId: 'TB-001',
    );
    final live = await QaMonitorService.instance.createSurvey(
      title: 'Parent pulse',
      audience: SurveyAudience.parent,
      schoolId: 'TB-001',
    );
    await QaMonitorService.instance.publishSurvey(live.id);
    expect(QaMonitorService.instance.surveysForSchool('TB-001'), hasLength(2));

    AuthService.currentUser = RegisteredUser(
      username: 'parent.i',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
    );
    expect(QaMonitorService.instance.observationsForSchool('TB-001'), isEmpty);
    expect(QaMonitorService.instance.auditsForSchool('TB-001'), isEmpty);
    expect(QaMonitorService.instance.researchForSchool('TB-001'), isEmpty);
    final visible = QaMonitorService.instance.surveysForSchool('TB-001');
    expect(visible, hasLength(1));
    expect(visible.first.id, live.id);
    expect(visible.any((row) => row.id == draft.id), isFalse);

    final response = await QaMonitorService.instance.submitSurveyResponse(
      surveyId: live.id,
      answers: const {'Q-0001': '5'},
    );
    expect(response.id.startsWith('SVR-'), isTrue);
    expect(QaMonitorService.instance.analyticsForSchool().atRisk, 0);
  });

  test('classroom teacher only sees a shared observation', () async {
    final hidden = await QaMonitorService.instance.recordObservation(
      teacherName: 'Ms. Sara',
      teacherUsername: 'sara.t',
      schoolId: 'TB-001',
    );
    final shared = await QaMonitorService.instance.recordObservation(
      teacherName: 'Ms. Sara',
      teacherUsername: 'sara.t',
      schoolId: 'TB-001',
    );
    await QaMonitorService.instance.shareObservation(shared.id);

    AuthService.currentUser = RegisteredUser(
      username: 'sara.t',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    final visible = QaMonitorService.instance.observationsForSchool('TB-001');
    expect(visible, hasLength(1));
    expect(visible.first.id, shared.id);
    expect(visible.any((row) => row.id == hidden.id), isFalse);
  });

  test('monitoring aliases to QA and syncs on the standard lane', () {
    expect(ModuleAccess.canView('qa_surveys'), isTrue);
    expect(ModuleAccess.canManage('observations'), isTrue);
    expect(ModuleAccess.normalize('surveys'), 'quality_assurance');
    expect(ModuleAccess.normalize('academic_audits'), 'quality_assurance');
    expect(ModuleAccess.normalize('action_research'), 'quality_assurance');
    expect(AppCollections.qaSurveys, 'qa_surveys');
    expect(
      CloudSyncEngine.standardPriority,
      containsAll([
        'teaching_observations',
        'academic_audits',
        'qa_surveys',
        'qa_survey_responses',
        'action_research',
      ]),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.i',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      containsAll(['qa_surveys', 'qa_survey_responses']),
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      isNot(contains('teaching_observations')),
    );
  });

  testWidgets('QA desk shows Phase I tabs', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WebQaPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Quality Assurance'), findsOneWidget);
    expect(find.text('Findings'), findsOneWidget);
    expect(find.text('Observations'), findsOneWidget);
    expect(find.text('Surveys'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
  });
}
