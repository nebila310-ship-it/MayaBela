import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/dosa_models.dart';
import 'package:mayabela/screens/parent_student_programs_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/dosa_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/web_erp/pages/web_student_programs_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DosaService.resetForTests();
    ExamService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'vp.dosa',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('club, scholarship, and grievance serialize', () {
    final now = DateTime.utc(2026, 9, 3);
    final club = ExtracurricularClub(
      id: 'CLB-0001',
      schoolId: 'TB-001',
      name: 'Science Gojo',
      kind: ClubKind.gojo,
      createdAt: now,
      updatedAt: now,
    );
    final grant = ScholarshipRecord(
      id: 'SCH-0001',
      schoolId: 'TB-001',
      studentId: 'STU-1001',
      studentName: 'Sara',
      snapshotAverage: 88,
      minAverage: 80,
      createdAt: now,
      updatedAt: now,
    );
    final grievance = Grievance(
      id: 'GRV-0001',
      schoolId: 'TB-001',
      authorUsername: 'parent.h',
      title: 'Bus wait',
      createdAt: now,
      updatedAt: now,
    );
    expect(ExtracurricularClub.fromMap(club.toMap()).kind, ClubKind.gojo);
    expect(ScholarshipRecord.fromMap(grant.toMap()).meetsThreshold, isTrue);
    expect(Grievance.fromMap(grievance.toMap()).title, 'Bus wait');
  });

  test('scholarship snapshots Phase B average and never writes exams', () async {
    SchoolDataService.instance.applyPersistedGradeReports([
      StudentGradeReport(
        studentId: 'STU-H001',
        studentName: 'Hana Bekele',
        className: 'Grade 11-H',
        term: 'Term 1',
        subjects: [
          SubjectGrade(subject: 'Math', score: 90, maxScore: 100),
          SubjectGrade(subject: 'Science', score: 80, maxScore: 100),
        ],
      ),
    ]);
    final grant = await DosaService.instance.applyScholarship(
      studentId: 'STU-H001',
      minAverage: 80,
      schoolId: 'TB-001',
    );
    expect(grant.snapshotAverage, 85);
    expect(grant.status, ScholarshipStatus.eligible);
    expect(ExamService.instance.attempts, isEmpty);
    expect(ExamService.instance.papers, isEmpty);
  });

  test('parents see own grievances and not leadership minutes', () async {
    final briefing = await DosaService.instance.recordMeeting(
      title: 'DoSA briefing',
      startsAt: DateTime.utc(2026, 9, 10),
      schoolId: 'TB-001',
    );
    final graduation = await DosaService.instance.recordMeeting(
      title: 'Graduation rehearsal',
      startsAt: DateTime.utc(2026, 9, 20),
      kind: DosaMeetingKind.graduation,
      schoolId: 'TB-001',
    );
    expect(briefing.calendarEventId, isNull);
    expect(graduation.calendarEventId, isNotNull);
    expect(DosaService.instance.meetingsForSchool('TB-001'), hasLength(2));
    expect(
      SchoolDataService.instance
          .getCalendarEvents()
          .any((event) => event.id == graduation.calendarEventId),
      isTrue,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.h',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
    );
    final visible = DosaService.instance.meetingsForSchool('TB-001');
    expect(visible, hasLength(1));
    expect(visible.first.kind, DosaMeetingKind.graduation);
    expect(visible.first.calendarEventId, isNotNull);
    expect(
      DosaService.instance.engagementForSchool('TB-001').upcomingMeetings,
      1,
    );

    final grievance = await DosaService.instance.fileGrievance(
      title: 'Bus wait time',
      details: 'Late pickup',
      studentId: 'STU-1001',
      schoolId: 'TB-001',
    );
    expect(grievance.id.startsWith('GRV-'), isTrue);
    expect(DosaService.instance.grievancesForSchool('TB-001'), hasLength(1));
  });

  test('student can join a published club', () async {
    final club = await DosaService.instance.createClub(
      name: 'Drama',
      schoolId: 'TB-001',
    );
    AuthService.currentUser = RegisteredUser(
      username: 'sara.h',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
      linkedStudentId: 'STU-1001',
    );
    final membership = await DosaService.instance.joinClub(
      clubId: club.id,
      studentId: 'STU-1001',
    );
    expect(membership.status, MembershipStatus.pending);
    expect(DosaService.instance.membershipsForSchool('TB-001'), hasLength(1));
  });

  test('staff can track internships and Gojo hours without writing grades', () async {
    final club = await DosaService.instance.createClub(
      name: 'Gojo service',
      kind: ClubKind.gojo,
      schoolId: 'TB-001',
    );
    final membership = await DosaService.instance.joinClub(
      clubId: club.id,
      studentId: 'STU-H002',
    );
    expect(membership.status, MembershipStatus.active);
    await DosaService.instance.addGojoHours(membership.id, 3);
    final intern = await DosaService.instance.addInternship(
      studentId: 'STU-H002',
      host: 'City clinic',
      role: 'Shadow',
      schoolId: 'TB-001',
    );
    expect(intern.id.startsWith('INT-'), isTrue);
    final snap = DosaService.instance.engagementForSchool('TB-001');
    expect(snap.gojoHours, 3);
    expect(snap.internships, 1);
    expect(ExamService.instance.attempts, isEmpty);
  });

  test('programs ride student affairs and sync on the standard lane', () {
    expect(ModuleAccess.canView('student_programs'), isTrue);
    expect(ModuleAccess.canManage('student_programs'), isTrue);
    expect(ModuleAccess.normalize('clubs'), 'student_affairs');
    expect(ModuleAccess.normalize('gojo'), 'student_affairs');
    expect(ModuleAccess.normalize('scholarships'), 'student_affairs');
    expect(ModuleAccess.normalize('grievances'), 'student_affairs');
    expect(ModuleAccess.normalize('internships'), 'student_affairs');
    expect(ModuleAccess.normalize('leadership_meetings'), 'student_affairs');
    expect(ModuleAccess.normalize('dosa'), 'student_affairs');
    expect(ModuleAccess.normalize('student_programs'), 'student_affairs');
    expect(AppCollections.extracurricularClubs, 'extracurricular_clubs');
    expect(
      CloudSyncEngine.standardPriority,
      containsAll([
        'extracurricular_clubs',
        'club_memberships',
        'scholarships',
        'grievances',
        'internships',
        'dosa_meetings',
      ]),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'sara.h',
      password: 'x',
      roleKey: AuthService.roleStudent,
      schoolId: 'TB-001',
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      containsAll(['extracurricular_clubs', 'scholarships', 'grievances']),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'owner.h',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    expect(ids, contains('student_programs'));
  });

  testWidgets('staff desk shows engagement chips and program tabs', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WebStudentProgramsPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Student programs'), findsOneWidget);
    expect(find.textContaining('Clubs'), findsWidgets);
    expect(find.textContaining('Gojo hours'), findsOneWidget);
    expect(find.textContaining('Leadership'), findsWidgets);
  });

  testWidgets('parent programs show events and not leadership minutes',
      (tester) async {
    await DosaService.instance.recordMeeting(
      title: 'DoSA closed briefing',
      startsAt: DateTime.utc(2026, 9, 12),
      schoolId: 'TB-001',
    );
    AuthService.currentUser = RegisteredUser(
      username: 'parent.h',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
    );
    await tester.pumpWidget(
      const MaterialApp(home: ParentStudentProgramsScreen()),
    );
    await tester.pump();
    expect(find.text('Student programs'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('File grievance'), findsOneWidget);
    expect(find.text('DoSA closed briefing'), findsNothing);
  });
}
