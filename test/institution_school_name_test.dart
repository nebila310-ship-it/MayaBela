import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/institution_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/institution_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/widgets/dashboard_welcome_card.dart';
import 'package:mayabela/widgets/school_branding_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.setLanguage('en');
    AuthService.currentUser = RegisteredUser(
      username: 'owner',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
    );
    AuthService.sessionSchoolId = schoolId;
    InstitutionService.instance.resetForTests();
    SchoolRegistryService.instance.applyPersistedSchools([
      SchoolRecord(id: schoolId, name: 'Maya School'),
    ]);
  });

  tearDown(() {
    AuthService.currentUser = null;
    AuthService.sessionSchoolId = null;
    InstitutionService.instance.resetForTests();
    SchoolRegistryService.instance.applyPersistedSchools(const []);
    AppLocale.instance.setLanguage('en');
  });

  test(
    'saved IM trading name wins over legal name and locale defaults',
    () async {
      final svc = InstitutionService.instance;
      expect(svc.savedPublicName(schoolId), isNull);
      expect(
        svc.displayNameFor(schoolId, fallback: 'Maya School'),
        'Maya School',
      );

      await svc.saveProfile(
        const InstitutionProfile(
          legalName: 'Fenote Raey Academy',
          tradingName: 'Fenote Raey',
        ),
        schoolId: schoolId,
      );

      expect(svc.savedPublicName(schoolId), 'Fenote Raey');
      expect(
        svc.displayNameFor(schoolId, fallback: 'Maya School'),
        'Fenote Raey',
      );
      expect(
        SchoolRegistryService.instance.displayName(schoolId),
        'Fenote Raey',
      );
    },
  );

  test(
    'saving IM profile does not wipe school year, city, or grades',
    () async {
      SchoolRegistryService.instance.applyPersistedSchools([
        SchoolRecord(
          id: schoolId,
          name: 'Maya School',
          city: 'Addis Ababa',
          academicYear: '2025/2026',
          gradeLevels: const ['Grade 1', 'Grade 2'],
          campuses: const ['Main Campus'],
        ),
      ]);

      await InstitutionService.instance.saveProfile(
        const InstitutionProfile(tradingName: 'Fenote Raey'),
        schoolId: schoolId,
      );

      final school = SchoolRegistryService.instance.lookup(schoolId)!;
      expect(school.name, 'Fenote Raey');
      expect(school.city, 'Addis Ababa');
      expect(school.academicYear, '2025/2026');
      expect(school.gradeLevels, ['Grade 1', 'Grade 2']);
      expect(school.campuses, ['Main Campus']);
    },
  );

  test('legal name is used when trading / display name is blank', () async {
    await InstitutionService.instance.saveProfile(
      const InstitutionProfile(legalName: 'Fenote Raey Academy'),
      schoolId: schoolId,
    );
    expect(
      InstitutionService.instance.displayNameFor(schoolId),
      'Fenote Raey Academy',
    );
    expect(
      SchoolRegistryService.instance.lookup(schoolId)?.name,
      'Fenote Raey Academy',
    );
  });

  test('Amharic hardcoded school name yields after a profile save', () async {
    AppLocale.instance.setLanguage('am');
    final localeName = AppLocale.instance.strings.schoolName(schoolId);
    expect(localeName, isNot(contains('Fenote')));

    expect(
      InstitutionService.instance.displayNameFor(
        schoolId,
        fallback: localeName,
      ),
      localeName,
    );

    await InstitutionService.instance.saveProfile(
      const InstitutionProfile(tradingName: 'Fenote Raey'),
      schoolId: schoolId,
    );

    expect(
      InstitutionService.instance.displayNameFor(
        schoolId,
        fallback: localeName,
      ),
      'Fenote Raey',
    );
  });

  testWidgets('admin dashboard welcome card shows the saved IM school name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: InstitutionService.instance,
            builder: (context, _) => const AdminDashboardSummary(),
          ),
        ),
      ),
    );
    expect(find.textContaining('Maya School'), findsWidgets);

    await InstitutionService.instance.saveProfile(
      const InstitutionProfile(tradingName: 'Fenote Raey'),
      schoolId: schoolId,
    );
    expect(InstitutionService.instance.displayNameFor(schoolId), 'Fenote Raey');
    await tester.pumpAndSettle();

    expect(find.textContaining('Fenote Raey'), findsWidgets);
    expect(find.textContaining('Maya School'), findsNothing);
  });

  testWidgets('school branding header follows the saved IM school name', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SchoolBrandingHeader(schoolId: schoolId)),
      ),
    );
    expect(find.text('Maya School'), findsOneWidget);

    await InstitutionService.instance.saveProfile(
      const InstitutionProfile(
        legalName: 'Fenote Raey Academy',
        tradingName: 'Fenote Raey',
      ),
      schoolId: schoolId,
    );
    await tester.pump();

    expect(find.text('Fenote Raey'), findsOneWidget);
    expect(find.text('Maya School'), findsNothing);
  });

  testWidgets(
    'compact header without school id does not fill the admin top bar',
    (tester) async {
      await InstitutionService.instance.saveProfile(
        const InstitutionProfile(tradingName: 'Fenote Raey'),
        schoolId: schoolId,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SchoolBrandingHeader(compact: true)),
        ),
      );
      expect(find.text('Fenote Raey'), findsNothing);
    },
  );

  test('empty registry name still shows the saved IM school name', () async {
    SchoolRegistryService.instance.applyPersistedSchools([
      SchoolRecord(id: schoolId, name: ''),
    ]);
    await InstitutionService.instance.saveProfile(
      const InstitutionProfile(tradingName: 'Fenote Raey'),
      schoolId: schoolId,
    );
    expect(
      InstitutionService.instance.displayNameFor(schoolId, fallback: ''),
      'Fenote Raey',
    );
    expect(SchoolRegistryService.instance.displayName(schoolId), 'Fenote Raey');
  });
}
