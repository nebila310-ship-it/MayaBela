import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/institution_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/institution_service.dart';
import 'package:mayabela/web_erp/pages/web_institution_page.dart';
import 'package:mayabela/web_erp/pages/web_school_management_page.dart';
import 'package:mayabela/web_erp/router/web_erp_router.dart';

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

  test('license health flags expiry within 60 days', () {
    final expired = InstitutionLicense(
      id: 'l1',
      title: 'Fire certificate',
      expiresOn: '2001-01-01',
    );
    final expiring = InstitutionLicense(
      id: 'l2',
      title: 'Operating license',
      expiresOn: DateTime.now()
          .add(const Duration(days: 10))
          .toIso8601String()
          .split('T')
          .first,
    );
    final valid = InstitutionLicense(
      id: 'l3',
      title: 'Accreditation',
      expiresOn: DateTime.now()
          .add(const Duration(days: 400))
          .toIso8601String()
          .split('T')
          .first,
    );
    expect(expired.health, LicenseHealth.expired);
    expect(expiring.health, LicenseHealth.expiring);
    expect(valid.health, LicenseHealth.valid);
  });

  test('open resolution past due date is overdue', () {
    final row = InstitutionResolution(
      id: 'r1',
      number: 'RES-1',
      title: 'Appoint principal',
      dueDate: '2001-01-01',
      status: ResolutionStatus.open,
    );
    expect(row.isOverdue, isTrue);
    expect(row.copyWith(status: ResolutionStatus.done).isOverdue, isFalse);
  });

  test(
    'profile, license and resolution persist on the active school',
    () async {
      final svc = InstitutionService.instance;
      await svc.saveProfile(
        const InstitutionProfile(
          legalName: 'Fenote Raey Academy',
          legalForm: InstitutionLegalForm.academy,
          registrationNumber: 'EDU-44',
        ),
        schoolId: schoolId,
      );
      await svc.upsertLicense(
        InstitutionLicense(
          id: 'lic-1',
          title: 'MoE operating license',
          expiresOn: '2001-06-01',
        ),
        schoolId: schoolId,
      );
      await svc.upsertResolution(
        const InstitutionResolution(
          id: 'res-1',
          number: 'RES-9',
          title: 'Approve safeguarding policy',
          owner: 'Principal',
          dueDate: '2001-01-01',
        ),
        schoolId: schoolId,
      );

      final rec = svc.recordFor(schoolId);
      expect(rec.profile.legalName, 'Fenote Raey Academy');
      expect(rec.profile.legalForm, InstitutionLegalForm.academy);
      expect(rec.licenses.single.title, 'MoE operating license');
      expect(rec.resolutions.single.number, 'RES-9');

      final metrics = svc.metricsFor(schoolId);
      expect(metrics.expiredLicenses, 1);
      expect(metrics.overdueResolutions, 1);
      expect(metrics.openResolutions, 1);
    },
  );

  test('router still maps institution to the Phase 1 desk', () {
    expect(WebErpRouter.pageFor('institution'), isA<WebInstitutionPage>());
    expect(WebErpRouter.pageFor('school'), isA<WebSchoolManagementPage>());
  });

  testWidgets(
    'institution desk shows Phase 1 tabs and related operational desks',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WebInstitutionPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Institutional Management'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Identity'), findsOneWidget);
      expect(find.text('Governance'), findsOneWidget);
      expect(find.text('Improvement'), findsOneWidget);
      expect(find.text('Estate'), findsOneWidget);
      expect(find.text('School Management'), findsOneWidget);
      expect(find.text('Campus Management'), findsOneWidget);
      expect(find.textContaining('Academic year'), findsWidgets);

      await tester.tap(find.text('Identity'));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Structure'), findsOneWidget);

      await tester.tap(find.text('Governance'));
      await tester.pumpAndSettle();
      expect(find.text('Leadership'), findsOneWidget);
      expect(find.text('Policies'), findsOneWidget);
      expect(find.text('Licenses'), findsOneWidget);
      expect(find.text('Resolutions'), findsOneWidget);
    },
  );
}
