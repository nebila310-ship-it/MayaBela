import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/institution_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/employee_registry_service.dart';
import 'package:mayabela/services/institution_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/web_erp/pages/web_institution_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'owner',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
      fullName: 'School Owner',
      linkedAdminId: 'ADM-1001',
    );
    InstitutionService.instance.resetForTests();
    EmployeeRegistryService.instance.applyPersistedEmployees(
      <EmployeeRecord>[],
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
    InstitutionService.instance.resetForTests();
    EmployeeRegistryService.instance.applyPersistedEmployees(
      <EmployeeRecord>[],
    );
  });

  InstitutionMeeting sampleMeeting({
    List<InstitutionStaffMember> invitees = const [],
    List<String> invitedKeys = const [],
  }) {
    return InstitutionMeeting(
      id: 'mtg-invite',
      title: 'Safeguarding board',
      heldOn: '2026-10-12',
      bodyKind: MeetingBodyKind.board,
      venue: 'Board room, Main Campus',
      meetingLink: 'https://zoom.us/j/123456',
      agenda: '1. Policy review\n2. Licence status',
      invitees: invitees,
      attachmentPaths: const ['/tmp/agenda.pdf'],
      invitedKeys: invitedKeys,
    );
  }

  test('invitation text includes agenda, venue, link and acknowledgement', () {
    final text =
        sampleMeeting(
          invitees: const [
            InstitutionStaffMember(
              kind: InstitutionStaffKind.teacher,
              personId: 'TCH-1001',
              name: 'Miss Belen',
            ),
          ],
        ).invitationText(
          toName: 'Miss Belen',
          schoolName: 'Fenote Raey Academy',
          senderName: 'School Owner',
        );
    expect(text, contains('Dear Miss Belen,'));
    expect(text, contains('Title: Safeguarding board'));
    expect(text, contains('Date: 2026-10-12'));
    expect(text, contains('Venue: Board room, Main Campus'));
    expect(text, contains('Join link: https://zoom.us/j/123456'));
    expect(text, contains('Agenda:'));
    expect(text, contains('Policy review'));
    expect(text, contains('Please acknowledge that you will attend.'));
    expect(text, contains('Fenote Raey Academy'));
  });

  test('meeting invitees and venue persist; legacy attendance still loads', () {
    final saved = InstitutionMeeting.fromMap(
      sampleMeeting(
        invitees: const [
          InstitutionStaffMember(
            kind: InstitutionStaffKind.teacher,
            personId: 'TCH-1001',
            name: 'Miss Belen',
          ),
          InstitutionStaffMember(
            kind: InstitutionStaffKind.admin,
            personId: 'ADM-1002',
            name: 'Mrs. Selam',
            title: 'Vice Principal',
          ),
        ],
      ).toMap(),
    );
    expect(saved.invitees.map((m) => m.personId), ['TCH-1001', 'ADM-1002']);
    expect(saved.attendance, 'Miss Belen, Mrs. Selam');
    expect(saved.venue, 'Board room, Main Campus');
    expect(saved.meetingLink, 'https://zoom.us/j/123456');
    expect(saved.attachmentPaths, ['/tmp/agenda.pdf']);

    final legacy = InstitutionMeeting.fromMap({
      'id': 'mtg-old',
      'title': 'Old board',
      'attendance': 'Chair, Principal',
    });
    expect(legacy.invitees, isEmpty);
    expect(legacy.attendance, 'Chair, Principal');
  });

  test(
    'staff directory includes teachers, employees and administrative staff',
    () {
      EmployeeRegistryService.instance.applyPersistedEmployees([
        EmployeeRecord(
          employeeId: 'EMP-9001',
          schoolId: schoolId,
          fullName: 'Amina Driver',
          jobTitle: 'Driver',
        ),
      ]);
      final staff = InstitutionService.instance.staffDirectory(schoolId);
      expect(staff.any((m) => m.personId == 'TCH-1001'), isTrue);
      expect(staff.any((m) => m.personId == 'EMP-9001'), isTrue);
      expect(staff.any((m) => m.personId == 'ADM-1001'), isTrue);
      expect(
        staff.firstWhere((m) => m.personId == 'ADM-1001').kind,
        InstitutionStaffKind.admin,
      );
    },
  );

  test('creating a meeting delivers the invite to teacher chat', () async {
    final meeting = sampleMeeting(
      invitees: const [
        InstitutionStaffMember(
          kind: InstitutionStaffKind.teacher,
          personId: 'TCH-1001',
          name: 'Miss Belen',
        ),
        InstitutionStaffMember(
          kind: InstitutionStaffKind.employee,
          personId: 'EMP-9001',
          name: 'Amina Driver',
          title: 'Driver',
        ),
      ],
    );
    await InstitutionService.instance.upsertMeeting(
      meeting,
      schoolId: schoolId,
    );
    final sent = await InstitutionService.instance.deliverMeetingInvites(
      meeting,
      schoolId: schoolId,
    );
    expect(sent, 1);

    final stored = InstitutionService.instance
        .recordFor(schoolId)
        .meetings
        .single;
    expect(stored.invitedKeys, contains('teacher:TCH-1001'));

    AuthService.currentUser = RegisteredUser(
      username: 'teacher',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: schoolId,
      fullName: 'Miss Belen',
      linkedTeacherId: 'TCH-1001',
    );
    final threads = SchoolDataService.instance.getConversationsForRole(
      AuthService.roleTeacher,
    );
    expect(
      threads.any(
        (c) => c.messages.any(
          (m) =>
              m.text.contains('Please acknowledge that you will attend.') &&
              m.text.contains('Miss Belen') &&
              m.attachments.any((a) => a.fileName == 'agenda.pdf'),
        ),
      ),
      isTrue,
    );

    final again = await InstitutionService.instance.deliverMeetingInvites(
      InstitutionService.instance.recordFor(schoolId).meetings.single,
      schoolId: schoolId,
    );
    expect(again, 0);
  });

  testWidgets(
    'meeting dialog invites staff and has venue, link and attachments',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WebInstitutionPage())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Governance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meetings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Invitees (attendance)'), findsOneWidget);
      expect(find.text('Miss Belen'), findsOneWidget);
      expect(find.textContaining('TCH-1001'), findsOneWidget);

      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration as InputDecoration?)?.labelText == 'Search staff',
        ),
        'ADM-1001',
      );
      await tester.pump();
      expect(find.text('School Admin'), findsOneWidget);
      expect(find.textContaining('ADM-1001'), findsWidgets);

      expect(find.text('Venue'), findsOneWidget);
      expect(find.text('Join link (Zoom or similar)'), findsOneWidget);
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('Add attachment'), findsOneWidget);
    },
  );
}
