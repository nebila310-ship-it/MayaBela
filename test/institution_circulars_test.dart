import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/institution_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/institution_service.dart';
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
