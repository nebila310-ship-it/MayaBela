import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/institution_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/institution_service.dart';
import 'package:mayabela/web_erp/pages/web_institution_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-INTL';

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

  String ymd(DateTime d) => d.toIso8601String().split('T').first;

  test('licence visit dates drive overview next-visit metrics', () async {
    final svc = InstitutionService.instance;
    final visit = DateTime.now().add(const Duration(days: 21));
    await svc.upsertLicense(
      InstitutionLicense(
        id: 'lic-cis',
        title: 'CIS membership',
        accreditor: AccreditorBody.cis,
        number: 'CIS-441',
        visitStartsOn: ymd(visit),
        visitEndsOn: ymd(visit.add(const Duration(days: 3))),
        nextReportDue: ymd(visit.add(const Duration(days: 40))),
        expiresOn: ymd(DateTime.now().add(const Duration(days: 400))),
      ),
      schoolId: schoolId,
    );

    final rec = svc.recordFor(schoolId);
    expect(rec.nextVisitLicense?.id, 'lic-cis');
    final metrics = svc.metricsFor(schoolId);
    expect(metrics.daysUntilNextVisit, isNotNull);
    expect(metrics.daysUntilNextVisit, closeTo(21, 1));
  });

  test('seed SEF domains and persist evidence binder + goal link', () async {
    final svc = InstitutionService.instance;
    await svc.upsertGoal(
      const InstitutionStrategicGoal(
        id: 'goal-learn',
        title: 'Every learner progresses',
        horizon: '2026–2029',
        theme: 'Learning',
      ),
      schoolId: schoolId,
    );
    await svc.seedSefDomains(cycle: '2026/27', schoolId: schoolId);
    var rec = svc.recordFor(schoolId);
    expect(
      rec.sefEntries.map((e) => e.area),
      containsAll(InstitutionSefDomains.suggested),
    );
    expect(rec.draftSefCount, InstitutionSefDomains.suggested.length);

    final teaching = rec.sefEntries.firstWhere(
      (e) => e.area == 'Teaching & learning',
    );
    await svc.upsertSef(
      teaching.copyWith(
        evidence: 'Lesson study pack',
        evidencePaths: const ['/tmp/sef-teaching.pdf'],
        goalId: 'goal-learn',
        judgment: SefJudgment.good,
        status: SefStatus.inReview,
      ),
      schoolId: schoolId,
    );
    rec = svc.recordFor(schoolId);
    final saved = rec.sefEntries.firstWhere((e) => e.id == teaching.id);
    expect(saved.evidencePaths, ['/tmp/sef-teaching.pdf']);
    expect(rec.goalTitleFor(saved.goalId), 'Every learner progresses');
    expect(
      svc.metricsFor(schoolId).draftSef,
      InstitutionSefDomains.suggested.length - 1,
    );
  });

  test(
    'policy version, supersede, acknowledgement and overdue chase',
    () async {
      final svc = InstitutionService.instance;
      final yesterday = ymd(DateTime.now().subtract(const Duration(days: 1)));
      await svc.upsertPolicy(
        InstitutionPolicy(
          id: 'pol-safeguard',
          number: 'POL-001',
          title: 'Safeguarding',
          status: PolicyStatus.active,
          reviewDate: yesterday,
          version: 1,
          audience: PolicyAudience.staff,
          approvedOn: '2024-01-15',
        ),
        schoolId: schoolId,
      );

      expect(svc.recordFor(schoolId).policies.single.reviewOverdue, isTrue);
      expect(svc.metricsFor(schoolId).overduePolicies, 1);

      await svc.acknowledgePolicy(
        'pol-safeguard',
        'Amina Bekele',
        schoolId: schoolId,
      );
      expect(svc.recordFor(schoolId).policies.single.acknowledgements, [
        'Amina Bekele',
      ]);

      final replacement = InstitutionPolicy(
        id: 'pol-safeguard-v2',
        number: 'POL-001',
        title: 'Safeguarding',
        status: PolicyStatus.draft,
        audience: PolicyAudience.all,
      );
      await svc.supersedePolicy(
        svc
            .recordFor(schoolId)
            .policies
            .firstWhere((p) => p.id == 'pol-safeguard'),
        replacement: replacement,
        schoolId: schoolId,
      );
      final rec = svc.recordFor(schoolId);
      final old = rec.policies.firstWhere((p) => p.id == 'pol-safeguard');
      final next = rec.policies.firstWhere((p) => p.id == 'pol-safeguard-v2');
      expect(old.status, PolicyStatus.superseded);
      expect(next.version, 2);
      expect(next.supersedesId, 'pol-safeguard');
      expect(next.status, PolicyStatus.draft);
    },
  );

  test(
    'board pack quorum, approved minutes, and resolution linked to meeting',
    () async {
      final svc = InstitutionService.instance;
      await svc.upsertLeadership(
        const LeadershipSeat(
          id: 'lead-chair',
          seatType: LeadershipSeatType.boardChair,
          personName: 'Hanna Girma',
          declaredInterest: 'Spouse supplies stationery',
        ),
        schoolId: schoolId,
      );
      await svc.upsertMeeting(
        InstitutionMeeting(
          id: 'mtg-board',
          title: 'Board 12 Sep 2026',
          heldOn: '2026-09-12',
          agendaItems: const ['Policy pack', 'CIS visit window', 'Budget'],
          invitees: const [
            InstitutionStaffMember(
              kind: InstitutionStaffKind.admin,
              personId: 'ADM-1',
              name: 'Hanna Girma',
            ),
          ],
          apologies: 'Deputy chair',
          quorumRequired: 3,
          presentCount: 4,
          minutesStatus: MinutesStatus.approved,
        ),
        schoolId: schoolId,
      );
      await svc.upsertResolution(
        const InstitutionResolution(
          id: 'res-1',
          number: 'RES-12',
          title: 'Approve safeguarding v2',
          meetingId: 'mtg-board',
          meetingTitle: 'Board 12 Sep 2026',
          status: ResolutionStatus.open,
        ),
        schoolId: schoolId,
      );

      final rec = svc.recordFor(schoolId);
      final meeting = rec.meetings.single;
      expect(meeting.orderedAgenda, [
        'Policy pack',
        'CIS visit window',
        'Budget',
      ]);
      expect(meeting.quorumMet, isTrue);
      expect(meeting.minutesStatus, MinutesStatus.approved);
      expect(rec.leadership.single.declaredInterest, contains('stationery'));
      expect(rec.meetingTitleFor('mtg-board'), 'Board 12 Sep 2026');
      expect(rec.resolutions.single.meetingId, 'mtg-board');
      expect(
        meeting.invitationText(toName: 'Hanna Girma'),
        contains('1. Policy pack'),
      );
    },
  );

  test('scorecard KPI and SEF area map to a strategic goal', () async {
    final svc = InstitutionService.instance;
    await svc.upsertGoal(
      const InstitutionStrategicGoal(
        id: 'goal-safe',
        title: 'Safeguarding first',
        horizon: '2026–2029',
        theme: 'Safeguarding',
      ),
      schoolId: schoolId,
    );
    await svc.upsertKpi(
      const InstitutionKpi(
        id: 'kpi-1',
        name: 'Incidents closed in 5 days',
        goalId: 'goal-safe',
        status: KpiStatus.onTrack,
      ),
      schoolId: schoolId,
    );
    await svc.upsertSef(
      const InstitutionSefEntry(
        id: 'sef-safe',
        cycle: '2026/27',
        area: 'Safeguarding & wellbeing',
        goalId: 'goal-safe',
        judgment: SefJudgment.good,
      ),
      schoolId: schoolId,
    );
    final rec = svc.recordFor(schoolId);
    expect(rec.goalTitleFor(rec.kpis.single.goalId), 'Safeguarding first');
    expect(
      rec.goalTitleFor(rec.sefEntries.single.goalId),
      'Safeguarding first',
    );
  });

  test(
    'high-risk heat opens a CAPA once; licence and policy also open CAPA',
    () async {
      final svc = InstitutionService.instance;
      final risk = InstitutionRisk(
        id: 'rsk-high',
        title: 'CIS visit evidence gap',
        likelihood: RiskLikelihood.high,
        impact: RiskImpact.high,
        treatment: 'Bind minutes and policies before visit',
        residual: 'Medium after binder complete',
      );
      expect(risk.heatScore, 9);
      expect(risk.isHigh, isTrue);
      await svc.upsertRisk(risk, schoolId: schoolId);
      expect(svc.metricsFor(schoolId).highRisks, 1);

      final first = await svc.openCapaFromRisk(risk, schoolId: schoolId);
      final second = await svc.openCapaFromRisk(risk, schoolId: schoolId);
      expect(first.id, second.id);
      expect(first.source, CapaSource.risk);
      expect(first.riskId, 'rsk-high');
      expect(first.title, contains('CIS visit evidence gap'));

      await svc.upsertLicense(
        InstitutionLicense(
          id: 'lic-exp',
          title: 'MoE operating licence',
          accreditor: AccreditorBody.moe,
          expiresOn: '2001-01-01',
        ),
        schoolId: schoolId,
      );
      final fromLicense = await svc.openCapaFromLicense(
        svc.recordFor(schoolId).licenses.single,
        schoolId: schoolId,
      );
      expect(fromLicense.source, CapaSource.license);
      expect(fromLicense.licenseId, 'lic-exp');

      await svc.upsertPolicy(
        InstitutionPolicy(
          id: 'pol-overdue',
          number: 'POL-9',
          title: 'Data protection',
          status: PolicyStatus.active,
          reviewDate: '2001-01-01',
        ),
        schoolId: schoolId,
      );
      final fromPolicy = await svc.openCapaFromPolicy(
        svc.recordFor(schoolId).policies.single,
        schoolId: schoolId,
      );
      expect(fromPolicy.source, CapaSource.policy);
      expect(fromPolicy.policyId, 'pol-overdue');

      await svc.upsertSef(
        const InstitutionSefEntry(
          id: 'sef-weak',
          cycle: '2026/27',
          area: 'Governance & leadership',
          judgment: SefJudgment.emerging,
        ),
        schoolId: schoolId,
      );
      final fromSef = await svc.openCapaFromSef(
        svc.recordFor(schoolId).sefEntries.single,
        schoolId: schoolId,
      );
      expect(fromSef.source, CapaSource.sef);
      expect(fromSef.sefId, 'sef-weak');
      expect(svc.recordFor(schoolId).openCapaCount, 4);
    },
  );

  test('partner MOU file and renewal health match licence windows', () {
    final overdue = InstitutionPartner(
      id: 'ptr-1',
      name: 'Sister school MOU',
      renewsOn: '2001-01-01',
      attachmentPaths: const ['/tmp/mou.pdf'],
    );
    final soon = InstitutionPartner(
      id: 'ptr-2',
      name: 'Cambridge affiliation',
      kind: PartnerKind.accreditor,
      renewsOn: ymd(DateTime.now().add(const Duration(days: 10))),
    );
    expect(overdue.renewalHealth, LicenseHealth.expired);
    expect(soon.renewalHealth, LicenseHealth.expiring);
    expect(overdue.attachmentPaths, ['/tmp/mou.pdf']);
  });

  test('legacy records still load without the new fields', () {
    final rec = InstitutionRecord.fromMap({
      'schoolId': schoolId,
      'profile': {'legalName': 'Legacy Academy'},
      'policies': [
        {
          'id': 'p1',
          'number': 'POL-1',
          'title': 'Old policy',
          'status': 'active',
        },
      ],
      'licenses': [
        {'id': 'l1', 'title': 'Old licence', 'issuer': 'MoE'},
      ],
      'meetings': [
        {'id': 'm1', 'title': 'Old board', 'agenda': 'Item A\nItem B'},
      ],
      'risks': [
        {
          'id': 'r1',
          'title': 'Old risk',
          'likelihood': 'high',
          'impact': 'low',
        },
      ],
      'updatedAt': DateTime.now().toIso8601String(),
    });
    expect(rec.policies.single.version, 1);
    expect(rec.policies.single.audience, PolicyAudience.staff);
    expect(rec.licenses.single.accreditor, AccreditorBody.other);
    expect(rec.meetings.single.orderedAgenda, ['Item A', 'Item B']);
    expect(rec.meetings.single.minutesStatus, MinutesStatus.draft);
    expect(rec.risks.single.heatScore, 3);
    expect(rec.risks.single.isHigh, isFalse);
    expect(rec.goals, isEmpty);
  });

  testWidgets(
    'overview shows next visit, overdue policies, draft SEF and open CAPA',
    (tester) async {
      final svc = InstitutionService.instance;
      await svc.upsertLicense(
        InstitutionLicense(
          id: 'lic-wasc',
          title: 'WASC accreditation',
          accreditor: AccreditorBody.wasc,
          visitStartsOn: ymd(DateTime.now().add(const Duration(days: 12))),
        ),
        schoolId: schoolId,
      );
      await svc.upsertPolicy(
        InstitutionPolicy(
          id: 'pol-old',
          number: 'POL-2',
          title: 'Child protection',
          status: PolicyStatus.active,
          reviewDate: '2001-01-01',
        ),
        schoolId: schoolId,
      );
      await svc.seedSefDomains(cycle: '2026/27', schoolId: schoolId);
      await svc.upsertCapa(
        const InstitutionCapa(
          id: 'capa-1',
          number: 'CAPA-1',
          title: 'Close evidence gap',
        ),
        schoolId: schoolId,
      );

      await tester.binding.setSurfaceSize(const Size(1400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WebInstitutionPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Next accreditation visit'), findsOneWidget);
      expect(find.textContaining('WASC'), findsOneWidget);
      expect(find.text('Overdue policy reviews'), findsOneWidget);
      expect(find.text('SEF areas still draft'), findsOneWidget);
      expect(find.text('Open CAPA'), findsOneWidget);
    },
  );
}
