import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/curriculum_models.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/models/qa_monitor_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/qa_monitor_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CurriculumService.resetForTests();
    LessonPlanService.resetForTests();
    QaMonitorService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'vp.lead',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      fullName: 'Vice Principal',
      staffRoles: const [StaffRoles.vicePresident],
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('5.15 parent can submit school-wide feedback without a unit', () async {
    AuthService.currentUser = RegisteredUser(
      username: 'parent.lms',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      fullName: 'Mr Bekele',
    );
    final item = await CurriculumService.instance.addFeedback(
      curriculumUnitId: '',
      body: 'Please send term reports in the app, not on paper',
      rating: 5,
      schoolId: 'TB-001',
    );
    expect(item.isSchoolWide, isTrue);
    expect(item.status, CurriculumFeedbackStatus.open);
    expect(CurriculumService.instance.feedbackForSchool('TB-001'), hasLength(1));

    AuthService.currentUser = RegisteredUser(
      username: 'other.parent',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(CurriculumService.instance.feedbackForSchool('TB-001'), isEmpty);

    AuthService.currentUser = RegisteredUser(
      username: 'vp.lead',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
    expect(CurriculumService.instance.feedbackForSchool('TB-001'), hasLength(1));
  });

  test('5.16 publish and submitForReview queue DH review', () async {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.sci',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    final published = await LessonPlanService.instance.createPlan(
      title: 'Plants week 1',
      className: 'Grade 4A',
      subject: 'Science',
      schoolId: 'TB-001',
    );
    await LessonPlanService.instance.setStatus(
      published.id,
      LessonPlanStatus.published,
    );
    expect(published.reviewStatus, LessonPlanReviewStatus.pending);

    final resubmit = await LessonPlanService.instance.createPlan(
      title: 'Forces week 1',
      className: 'Grade 4A',
      subject: 'Science',
      schoolId: 'TB-001',
    );
    await LessonPlanService.instance.applyReview(
      id: resubmit.id,
      reviewStatus: LessonPlanReviewStatus.changesRequested,
    );
    await LessonPlanService.instance.submitForReview(resubmit.id);
    expect(resubmit.status, LessonPlanStatus.published);
    expect(resubmit.reviewStatus, LessonPlanReviewStatus.pending);
    expect(LessonPlanService.instance.pendingReviewCount('TB-001'), 2);
  });

  test('5.16 teacher sees shared observations; parents do not', () async {
    final now = DateTime.utc(2026, 9, 12);
    QaMonitorService.instance.applyPersistedData(
      observations: [
        TeachingObservation(
          id: 'OBS-LEAD-1',
          schoolId: 'TB-001',
          teacherName: 'Teacher Sci',
          teacherUsername: 'teacher.sci',
          className: 'Grade 4A',
          subject: 'Science',
          observedAt: now,
          createdAt: now,
          updatedAt: now,
          status: ObservationStatus.shared,
          planning: 4,
          instruction: 5,
          engagement: 4,
          assessment: 4,
        ),
      ],
    );

    AuthService.currentUser = RegisteredUser(
      username: 'teacher.sci',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    final mine = QaMonitorService.instance.observationsForSchool('TB-001');
    expect(mine, hasLength(1));
    expect(mine.first.averageScore, 4.25);

    AuthService.currentUser = RegisteredUser(
      username: 'parent.lms',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(QaMonitorService.instance.observationsForSchool('TB-001'), isEmpty);
  });

  test('5.17 review notifies the teacher and can link to an evaluation',
      () async {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.sci',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    final plan = await LessonPlanService.instance.createPlan(
      title: 'Fractions',
      className: 'Grade 5B',
      subject: 'Mathematics',
      schoolId: 'TB-001',
    );
    await LessonPlanService.instance.submitForReview(plan.id);

    AuthService.currentUser = RegisteredUser(
      username: 'vp.lead',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      fullName: 'Vice Principal',
      staffRoles: const [StaffRoles.vicePresident],
    );
    final review = await CurriculumService.instance.reviewLessonPlan(
      lessonPlanId: plan.id,
      decision: LessonPlanReviewDecision.approved,
      notes: 'Clear objectives',
    );
    expect(plan.reviewStatus, LessonPlanReviewStatus.approved);
    expect(
      NotificationService.instance.itemsForTests().any(
            (n) =>
                n.title == 'Lesson plan approved' &&
                n.recipientRole == AuthService.roleTeacher,
          ),
      isTrue,
    );

    final eval = await CurriculumService.instance.recordEvaluation(
      teacherId: 'T-0001',
      teacherName: 'Teacher Sci',
      teacherUsername: 'teacher.sci',
      periodLabel: 'Term 1',
      lessonPlanReviewIds: [review.id],
      schoolId: 'TB-001',
    );
    expect(eval.lessonPlanReviewIds, [review.id]);
  });

  test('5.17 academic meetings stay on academic_meetings and staff calendar',
      () async {
    final meeting = await CurriculumService.instance.recordMeeting(
      title: 'Science department briefing',
      startsAt: DateTime.utc(2026, 9, 20, 9),
      agenda: 'Alignment gaps',
      attendeeRoles: const ['teachers', 'section_director'],
      publishToCalendar: true,
      schoolId: 'TB-001',
    );
    expect(meeting.calendarEventId, isNotNull);
    expect(meeting.attendeeRoles, contains('teachers'));
    expect(meeting.endsAt, isNotNull);

    final events = SchoolDataService.instance.getCalendarEvents();
    final event = events.firstWhere((e) => e.id == meeting.calendarEventId);
    expect(event.audience, 'staff');
    expect(
      SchoolDataService.instance.calendarEventVisibleToRole(
        event,
        AuthService.roleTeacher,
      ),
      isTrue,
    );
    expect(
      SchoolDataService.instance.calendarEventVisibleToRole(
        event,
        AuthService.roleParent,
      ),
      isFalse,
    );

    await CurriculumService.instance.updateMeeting(
      meeting.id,
      notes: 'Bring week-3 plans',
    );
    expect(meeting.notes, 'Bring week-3 plans');

    AuthService.currentUser = RegisteredUser(
      username: 'parent.lms',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(CurriculumService.instance.meetingsForSchool('TB-001'), isEmpty);
  });

  test('5.17 alignment counts unlinked plans by subject', () async {
    final unit = await CurriculumService.instance.createUnit(
      title: 'Living things',
      subject: 'Science',
      schoolId: 'TB-001',
      standardCodes: const ['MoE-PRI'],
    );
    final linked = await LessonPlanService.instance.createPlan(
      title: 'Plants',
      className: 'Grade 4A',
      subject: 'Science',
      schoolId: 'TB-001',
      curriculumUnitId: unit.id,
    );
    final unlinked = await LessonPlanService.instance.createPlan(
      title: 'Fractions',
      className: 'Grade 4A',
      subject: 'Mathematics',
      schoolId: 'TB-001',
    );
    await LessonPlanService.instance.submitForReview(linked.id);
    await LessonPlanService.instance.submitForReview(unlinked.id);

    final alignment = CurriculumService.instance.alignmentForSchool('TB-001');
    expect(alignment.publishedPlanCount, 2);
    expect(alignment.linkedPublishedPlanCount, 1);
    expect(alignment.unlinkedBySubject['Mathematics'], 1);
    expect(alignment.unlinkedBySubject.containsKey('Science'), isFalse);
  });
}
