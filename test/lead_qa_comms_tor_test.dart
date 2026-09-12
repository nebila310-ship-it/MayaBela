import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/curriculum_models.dart';
import 'package:mayabela/models/dosa_models.dart';
import 'package:mayabela/models/qa_monitor_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/dosa_service.dart';
import 'package:mayabela/services/lms_classroom_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/qa_monitor_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/student_sis_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DosaService.resetForTests();
    QaMonitorService.resetForTests();
    CurriculumService.resetForTests();
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

  test('5.18 leadership meetings land on the staff calendar only', () async {
    final briefing = await DosaService.instance.recordMeeting(
      title: 'DoSA briefing',
      startsAt: DateTime.utc(2026, 9, 18, 9),
      agenda: 'Club hours',
      schoolId: 'TB-001',
    );
    expect(briefing.calendarEventId, isNotNull);
    await DosaService.instance.updateMeeting(
      id: briefing.id,
      notes: 'Bring week-3 lists',
    );
    await DosaService.instance.addMeetingTask(
      meetingId: briefing.id,
      title: 'Collect Gojo hours',
    );
    expect(briefing.notes, 'Bring week-3 lists');
    expect(briefing.tasks, hasLength(1));

    final event = SchoolDataService.instance
        .getCalendarEvents()
        .firstWhere((row) => row.id == briefing.calendarEventId);
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
  });

  test('5.18 club evaluation and SIS hours stay on club_memberships', () async {
    final club = await DosaService.instance.createClub(
      name: 'Science Gojo',
      kind: ClubKind.gojo,
      schoolId: 'TB-001',
    );
    final member = await DosaService.instance.joinClub(
      clubId: club.id,
      studentId: 'STU-1001',
    );
    await DosaService.instance.addGojoHours(member.id, 4);
    await DosaService.instance.evaluateMembership(
      id: member.id,
      engagementRating: 5,
      evaluationNotes: 'Led the Saturday session',
    );
    expect(member.engagementRating, 5);
    expect(member.evaluationNotes, 'Led the Saturday session');
    expect(DosaService.instance.gojoHoursForStudent('STU-1001'), 4);
    expect(
      DosaService.instance.engagementForSchool('TB-001').evaluatedMembers,
      1,
    );
    expect(
      DosaService.instance.engagementForSchool('TB-001').activeByClub,
      containsPair('Science Gojo', 1),
    );

    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-1001',
        fullName: 'Sara Bekele',
        grade: 'Grade 4',
        className: 'Grade 4A',
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2015, 1, 1),
      ),
    ]);
    final sis = StudentSisProfile.load('STU-1001');
    expect(sis?.clubNames, contains('Science Gojo'));
    expect(sis?.gojoHours, 4);
    expect(sis?.groupingSummary, contains('4 Gojo hours'));
  });

  test('5.18 leadership chat and club discussion reuse conversations', () async {
    final chatId = DosaService.instance.openLeadershipChat();
    final conversation = SchoolDataService.instance
        .getConversations()
        .firstWhere((row) => row.id == chatId);
    expect(conversation.name, 'DoSA leadership');
    expect(conversation.groupStaffIds, contains('vp.lead'));
    expect(conversation.groupParentNames, isEmpty);

    final club = await DosaService.instance.createClub(
      name: 'Chess',
      schoolId: 'TB-001',
    );
    final discussionId = DosaService.instance.ensureClubDiscussion(club.id);
    expect(
      SchoolDataService.instance
          .getConversations()
          .firstWhere((row) => row.id == discussionId)
          .name,
      'Chess club discussion',
    );
  });

  test('5.19 QA audit lifecycle and research stay on QA stores', () async {
    final unit = await CurriculumService.instance.createUnit(
      title: 'Living things',
      subject: 'Science',
      schoolId: 'TB-001',
    );
    final audit = await QaMonitorService.instance.recordAudit(
      curriculumUnitId: unit.id,
      verdict: AuditVerdict.gaps,
      status: AuditStatus.inProgress,
      notes: 'Need more codes',
      schoolId: 'TB-001',
    );
    await QaMonitorService.instance.updateAudit(
      id: audit.id,
      status: AuditStatus.completed,
      verdict: AuditVerdict.aligned,
    );
    expect(audit.status, AuditStatus.completed);
    expect(audit.verdict, AuditVerdict.aligned);

    final observation = await QaMonitorService.instance.recordObservation(
      teacherName: 'Teacher Sci',
      teacherUsername: 'teacher.sci',
      subject: 'Science',
      curriculumUnitId: unit.id,
      planning: 4,
      instruction: 5,
      engagement: 3,
      assessment: 4,
      schoolId: 'TB-001',
    );
    expect(observation.instruction, 5);
    expect(observation.curriculumUnitId, unit.id);

    final cycle = await QaMonitorService.instance.recordResearch(
      title: 'Exit tickets',
      inquiry: 'Do weekly tickets raise quiz scores?',
      method: 'Compare two Grade 4 sections',
      schoolId: 'TB-001',
    );
    await QaMonitorService.instance.updateResearchStatus(
      cycle.id,
      ActionResearchStatus.active,
    );
    await QaMonitorService.instance.updateResearch(
      id: cycle.id,
      findings: 'Section B improved',
      nextSteps: 'Share the prompt bank',
      status: ActionResearchStatus.complete,
    );
    expect(cycle.method, 'Compare two Grade 4 sections');
    expect(cycle.findings, 'Section B improved');
    expect(cycle.status, ActionResearchStatus.complete);

    AuthService.currentUser = RegisteredUser(
      username: 'parent.lms',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(QaMonitorService.instance.flaggedProfilesForSchool(), isEmpty);
  });

  test('5.20 class discussion stamps students; announcements notify them',
      () async {
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-4A1',
        fullName: 'Kidus Assefa',
        grade: 'Grade 4',
        className: 'Grade 4A',
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2015, 3, 3),
        fatherName: 'Mr Assefa',
      ),
    ]);
    final id = LmsClassroomService.instance.ensureClassDiscussion('Grade 4A');
    final thread = SchoolDataService.instance
        .getConversations()
        .firstWhere((row) => row.id == id);
    expect(thread.linkedStudentIds, contains('STU-4A1'));
    expect(thread.groupParentNames, contains('Mr Assefa'));

    AuthService.currentUser = RegisteredUser(
      username: 'admin.comms',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    SchoolDataService.instance.addAnnouncement(
      title: 'Sports day',
      body: 'Bring water bottles',
      author: 'Admin',
      audienceKeys: const [AnnouncementAudiences.students],
    );
    expect(
      NotificationService.instance.itemsForTests().any(
            (n) =>
                n.title == 'New announcement' &&
                n.body.contains('Sports day') &&
                n.recipientRole == AuthService.roleStudent,
          ),
      isTrue,
    );
  });
}
