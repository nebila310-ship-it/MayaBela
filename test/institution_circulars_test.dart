import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/institution_models.dart';
import 'package:mayabela/services/auth_service.dart';
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
    );
    InstitutionService.instance.resetForTests();
  });

  tearDown(() {
    AuthService.currentUser = null;
    InstitutionService.instance.resetForTests();
  });

  test('circular keeps attachments and intended audience', () async {
    await InstitutionService.instance.upsertCircular(
      const OfficialCircular(
        id: 'cir-1',
        number: 'CIR-2026-014',
        title: 'Exam timetable',
        issuedOn: '2026-10-02',
        audience: CircularAudience.teachers,
        attachmentPaths: ['/tmp/exam.pdf', '/tmp/cover.docx'],
      ),
      schoolId: schoolId,
    );
    final row = InstitutionService.instance
        .recordFor(schoolId)
        .circulars
        .single;
    expect(row.audience, CircularAudience.teachers);
    expect(row.attachmentPaths, ['/tmp/exam.pdf', '/tmp/cover.docx']);
    expect(OfficialCircular.audienceLabel(row.audience), 'Teachers');

    final restored = OfficialCircular.fromMap(row.toMap());
    expect(restored.audience, CircularAudience.teachers);
    expect(restored.attachmentPaths, hasLength(2));

    final legacy = OfficialCircular.fromMap({
      'id': 'cir-old',
      'number': 'CIR-1',
      'title': 'Old circular',
    });
    expect(legacy.audience, CircularAudience.both);
    expect(legacy.attachmentPaths, isEmpty);
  });

  test('circular notice text states purpose and attachments', () {
    const circular = OfficialCircular(
      id: 'cir-text',
      number: 'CIR-2026-014',
      title: 'Exam timetable',
      issuedOn: '2026-10-02',
      body: 'Final exams begin on 20 October.',
      audience: CircularAudience.teachers,
      attachmentPaths: ['/tmp/exam.pdf'],
    );
    final text = circular.noticeText(
      toName: 'Miss Belen',
      schoolName: 'Fenote Raey Academy',
      senderName: 'School Owner',
    );
    expect(text, contains('Dear Miss Belen,'));
    expect(text, contains('Number: CIR-2026-014'));
    expect(text, contains('Title: Exam timetable'));
    expect(text, contains('Intended for: Teachers'));
    expect(text, contains('Purpose / information:'));
    expect(text, contains('Final exams begin on 20 October.'));
    expect(
      text,
      contains('Attachments: 1 file(s) included with this circular.'),
    );
    expect(
      text,
      contains('Please read this circular and keep it for your records.'),
    );
  });

  test('teacher circular is delivered to teacher chat with the file', () async {
    AuthService.currentUser = RegisteredUser(
      username: 'owner',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
      fullName: 'School Owner',
      linkedAdminId: 'ADM-1001',
    );
    const circular = OfficialCircular(
      id: 'cir-send',
      number: 'CIR-9',
      title: 'Exam timetable',
      body: 'Final exams begin on 20 October.',
      audience: CircularAudience.teachers,
      attachmentPaths: ['/tmp/exam.pdf'],
    );
    await InstitutionService.instance.upsertCircular(
      circular,
      schoolId: schoolId,
    );
    final sent = await InstitutionService.instance.deliverCircularNotices(
      circular,
      schoolId: schoolId,
    );
    expect(sent, greaterThan(0));
    expect(
      InstitutionService.instance
          .recordFor(schoolId)
          .circulars
          .single
          .deliveredKeys,
      contains('teacher:TCH-1001'),
    );

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
              m.text.contains('Purpose / information:') &&
              m.text.contains('Final exams begin on 20 October.') &&
              m.attachments.any((a) => a.fileName == 'exam.pdf'),
        ),
      ),
      isTrue,
    );

    final again = await InstitutionService.instance.deliverCircularNotices(
      InstitutionService.instance.recordFor(schoolId).circulars.single,
      schoolId: schoolId,
    );
    expect(again, 0);
  });

  testWidgets('circular dialog offers audience and attachments', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebInstitutionPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Governance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Policies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add circular'));
    await tester.pumpAndSettle();

    expect(find.text('Intended for'), findsOneWidget);
    expect(find.text('Both'), findsOneWidget);
    expect(find.text('Add attachment'), findsOneWidget);
  });
}
