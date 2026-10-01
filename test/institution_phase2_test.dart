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

  test('open risk with past review date is overdue and due soon', () {
    final row = InstitutionRisk(
      id: 'r1',
      title: 'Licence lapse',
      reviewDate: '2001-01-01',
      status: RiskStatus.open,
    );
    expect(row.isOverdue, isTrue);
    expect(row.reviewDueSoon, isTrue);
    expect(row.copyWith(status: RiskStatus.closed).isOverdue, isFalse);
  });

  test('committee, meeting, risk and partner persist on the school', () async {
    final svc = InstitutionService.instance;
    await svc.upsertCommittee(
      const InstitutionCommittee(
        id: 'com-1',
        name: 'Safeguarding committee',
        chairName: 'Amina Bekele',
        termsOfReference: 'Child protection oversight',
      ),
      schoolId: schoolId,
    );
    await svc.upsertMeeting(
      const InstitutionMeeting(
        id: 'mtg-1',
        title: 'Board 12 Sep 2026',
        heldOn: '2026-09-12',
        bodyKind: MeetingBodyKind.board,
        attendance: 'Chair, Principal',
      ),
      schoolId: schoolId,
    );
    await svc.upsertResolution(
      const InstitutionResolution(
        id: 'res-2',
        number: 'RES-10',
        title: 'Adopt safeguarding ToR',
        meetingId: 'mtg-1',
        meetingTitle: 'Board 12 Sep 2026',
      ),
      schoolId: schoolId,
    );
    await svc.upsertRisk(
      const InstitutionRisk(
        id: 'rsk-1',
        title: 'Operating licence lapse',
        owner: 'Principal',
        likelihood: RiskLikelihood.high,
        impact: RiskImpact.high,
        reviewDate: '2001-06-01',
      ),
      schoolId: schoolId,
    );
    await svc.upsertPartner(
      const InstitutionPartner(
        id: 'ptr-1',
        name: 'Ministry of Education',
        kind: PartnerKind.ministry,
        agreementRef: 'MOU-44',
      ),
      schoolId: schoolId,
    );

    final rec = svc.recordFor(schoolId);
    expect(rec.committees.single.name, 'Safeguarding committee');
    expect(rec.meetings.single.title, 'Board 12 Sep 2026');
    expect(rec.resolutions.single.meetingId, 'mtg-1');
    expect(rec.meetingTitleFor('mtg-1'), 'Board 12 Sep 2026');
    expect(rec.risks.single.title, 'Operating licence lapse');
    expect(rec.partners.single.kind, PartnerKind.ministry);

    final metrics = svc.metricsFor(schoolId);
    expect(metrics.activeCommittees, 1);
    expect(metrics.openRisks, 1);
    expect(metrics.risksDueSoon, 1);
    expect(metrics.activePartners, 1);
  });

  testWidgets('institution desk shows Phase 2 tabs', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebInstitutionPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Governance'), findsOneWidget);
    expect(find.text('Open risks'), findsOneWidget);

    await tester.tap(find.text('Governance'));
    await tester.pumpAndSettle();
    expect(find.text('Committees'), findsOneWidget);
    expect(find.text('Meetings'), findsOneWidget);
    expect(find.text('Risks'), findsOneWidget);
    expect(find.text('Partners'), findsOneWidget);
    expect(find.text('Resolutions'), findsOneWidget);
  });
}
