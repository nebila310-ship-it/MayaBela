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

  test('open CAPA past due is overdue; closed CAPA is not', () {
    final row = InstitutionCapa(
      id: 'c1',
      number: 'CAPA-1',
      title: 'Renew operating licence',
      dueDate: '2001-01-01',
      status: CapaStatus.open,
    );
    expect(row.isOverdue, isTrue);
    expect(row.copyWith(status: CapaStatus.done).isOverdue, isFalse);
  });

  test('archive retention lapses on or after the until date', () {
    final lapsed = InstitutionArchiveItem(
      id: 'a1',
      title: 'Board minutes 2018',
      series: ArchiveSeries.minutes,
      retentionUntil: '2001-01-01',
    );
    expect(lapsed.retentionLapsed, isTrue);
    expect(
      lapsed.copyWith(status: ArchiveStatus.destroyed).retentionLapsed,
      isFalse,
    );
  });

  test('SEF, CAPA, KPI, property and archive persist on the school', () async {
    final svc = InstitutionService.instance;
    await svc.upsertSef(
      const InstitutionSefEntry(
        id: 'sef-1',
        cycle: '2025/26',
        area: 'Leadership and management',
        judgment: SefJudgment.good,
        status: SefStatus.published,
      ),
      schoolId: schoolId,
    );
    await svc.upsertCapa(
      const InstitutionCapa(
        id: 'capa-1',
        number: 'CAPA-3',
        title: 'Close licence gap',
        source: CapaSource.sef,
        sefId: 'sef-1',
        dueDate: '2001-06-01',
      ),
      schoolId: schoolId,
    );
    await svc.upsertKpi(
      const InstitutionKpi(
        id: 'kpi-1',
        name: 'Board meetings on schedule',
        theme: KpiTheme.governance,
        target: '4',
        actual: '2',
        status: KpiStatus.offTrack,
      ),
      schoolId: schoolId,
    );
    await svc.upsertProperty(
      const InstitutionProperty(
        id: 'prop-1',
        name: 'Main campus block A',
        kind: PropertyKind.building,
      ),
      schoolId: schoolId,
    );
    await svc.upsertArchive(
      const InstitutionArchiveItem(
        id: 'arc-1',
        title: 'Board minutes 2018',
        series: ArchiveSeries.minutes,
        retentionUntil: '2001-01-01',
      ),
      schoolId: schoolId,
    );

    final rec = svc.recordFor(schoolId);
    expect(rec.sefEntries.single.area, 'Leadership and management');
    expect(rec.capas.single.sefId, 'sef-1');
    expect(rec.sefTitleFor('sef-1'), contains('Leadership'));
    expect(rec.kpis.single.status, KpiStatus.offTrack);
    expect(rec.properties.single.kind, PropertyKind.building);
    expect(rec.archive.single.retentionLapsed, isTrue);

    final metrics = svc.metricsFor(schoolId);
    expect(metrics.openCapas, 1);
    expect(metrics.overdueCapas, 1);
    expect(metrics.kpisOffTrack, 1);
    expect(metrics.retentionLapsed, 1);
  });

  testWidgets('institution desk shows Phase 3 tabs', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebInstitutionPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Improvement'), findsOneWidget);
    expect(find.text('Estate'), findsOneWidget);
    expect(find.text('Open CAPA'), findsOneWidget);

    await tester.tap(find.text('Improvement'));
    await tester.pumpAndSettle();
    expect(find.text('SEF'), findsOneWidget);
    expect(find.text('CAPA'), findsOneWidget);
    expect(find.text('Scorecard'), findsOneWidget);

    await tester.tap(find.text('Estate'));
    await tester.pumpAndSettle();
    expect(find.text('Property'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
  });
}
