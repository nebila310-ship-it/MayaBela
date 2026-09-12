import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_support_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSupportService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'vp.care',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('5.11 counseling appointments and SEL analytics stay on care stores',
      () async {
    await StudentSupportService.instance.addCounselingRecord(
      studentId: 'STU-1001',
      kind: CounselingKind.appointment,
      title: 'Week-3 check-in',
      startsAt: DateTime.utc(2026, 9, 20),
      schoolId: 'TB-001',
    );
    expect(
      StudentSupportService.instance
          .upcomingCounselingAppointments(
            schoolId: 'TB-001',
            now: DateTime.utc(2026, 9, 12),
          )
          .single
          .title,
      'Week-3 check-in',
    );

    await StudentSupportService.instance.addSelObservation(
      studentId: 'STU-1001',
      domain: SelDomain.selfManagement,
      rating: 4,
      schoolId: 'TB-001',
    );
    await StudentSupportService.instance.addSelObservation(
      studentId: 'STU-1002',
      domain: SelDomain.relationship,
      rating: 2,
      schoolId: 'TB-001',
    );
    final analytics = StudentSupportService.instance.selAnalytics('TB-001');
    expect(analytics.observations, 2);
    expect(analytics.studentsCovered, 2);
    expect(analytics.overall, 3);
    expect(analytics.domainAverages[SelDomain.selfManagement], 4);
  });

  test('5.12 college lifecycle, session, and calendar event reuse', () async {
    expect(
      StudentSupportPlaybook.collegeLifecycle(CollegeStage.exploring),
      'Direction',
    );
    expect(
      StudentSupportPlaybook.collegeLifecycle(CollegeStage.readiness),
      'Readiness',
    );
    expect(
      StudentSupportPlaybook.collegeLifecycle(CollegeStage.applying),
      'Application',
    );
    expect(
      StudentSupportPlaybook.collegeLifecycle(CollegeStage.accepted),
      'Decision',
    );

    final plan = await StudentSupportService.instance.upsertCollegePlan(
      studentId: 'STU-1001',
      stage: CollegeStage.readiness,
      portfolio: 'Personal statement draft',
      schoolId: 'TB-001',
    );
    expect(CollegeGuidancePlan.fromMap(plan.toMap()).stage, CollegeStage.readiness);

    await StudentSupportService.instance.scheduleCollegeAppointment(
      studentId: 'STU-1001',
      when: DateTime.utc(2026, 9, 22),
    );
    expect(
      StudentSupportService.instance
          .upcomingCollegeAppointments(
            schoolId: 'TB-001',
            now: DateTime.utc(2026, 9, 12),
          )
          .single
          .nextAppointmentAt,
      DateTime.utc(2026, 9, 22),
    );

    await StudentSupportService.instance.addCollegeArtifact(
      studentId: 'STU-1001',
      title: 'University fair attendance',
      kind: CollegeArtifactKind.event,
    );
    expect(
      StudentSupportService.instance
          .collegeForStudent('STU-1001')!
          .artifacts
          .single
          .kind,
      CollegeArtifactKind.event,
    );

    StudentSupportService.instance.scheduleCollegeGuidanceEvent(
      title: 'UCAS workshop',
      date: DateTime.utc(2026, 10, 2),
    );
    expect(
      SchoolDataService.instance
          .getVisibleCalendarEvents()
          .where((e) => e.type == CalendarEventType.collegeGuidance)
          .map((e) => e.title),
      contains('UCAS workshop'),
    );
  });

  test('5.13 IEP intake, evaluation, student training, and clinic forms',
      () async {
    final plan = await StudentSupportService.instance.addIepPlan(
      studentId: 'STU-1001',
      intakeAssessment: 'EP screen: working memory',
      goals: 'Stay on task for 15 minutes',
      schoolId: 'TB-001',
    );
    expect(
      IepPlan.fromMap(plan.toMap()).intakeAssessment,
      contains('working memory'),
    );

    await StudentSupportService.instance.addIepEvaluation(
      id: plan.id,
      notes: 'Met term goal in literacy',
      evaluatedAt: DateTime.utc(2026, 9, 11),
    );
    await StudentSupportService.instance.addIepTraining(
      planId: plan.id,
      topic: 'Self-advocacy',
      audience: 'student',
    );
    final updated =
        StudentSupportService.instance.iepForSchool('TB-001').single;
    expect(updated.stage, IepStage.review);
    expect(updated.evaluationNotes, contains('literacy'));
    expect(updated.trainingSessions.single.audience, 'student');

    final checkup = await StudentSupportService.instance.addHealthRecord(
      studentId: 'STU-1001',
      type: HealthRecordType.medicalCheckup,
      title: 'Annual SEN check-up',
      schoolId: 'TB-001',
    );
    final accident = await StudentSupportService.instance.addHealthRecord(
      studentId: 'STU-1001',
      type: HealthRecordType.accident,
      title: 'Playground fall',
      notifyParent: true,
      schoolId: 'TB-001',
    );
    expect(HealthRecord.fromMap(checkup.toMap()).type, HealthRecordType.medicalCheckup);
    expect(accident.parentNotifiedAt, isNotNull);
    expect(
      StudentSupportService.instance
          .clinicSummaryForDate(DateTime.now(), 'TB-001')
          .checkups,
      1,
    );
    expect(
      StudentSupportService.instance
          .clinicSummaryForDate(DateTime.now(), 'TB-001')
          .accidents,
      1,
    );
  });
}
