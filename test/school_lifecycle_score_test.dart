import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/school_lifecycle.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/services/school_onboarding_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/widgets/school_onboarding_checklist_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoliveService.resetForTests();
  });

  test('scorecard lists create-school through go-live parameters', () {
    final school = SchoolRecord(
      id: 'FR-SCORE',
      name: 'Fenote Raey Academy',
      status: SchoolLifecycleStatus.active,
    );
    final checklist = SchoolOnboardingService.instance.forSchool(school);

    expect(checklist.phases.map((p) => p.key).toList(), [
      'create',
      'admin',
      'people',
      'daily',
      'academics',
      'campus',
      'golive',
    ]);
    expect(checklist.totalCount, greaterThanOrEqualTo(25));
    expect(checklist.steps.every((s) => s.parameter.isNotEmpty), isTrue);
    expect(checklist.steps.map((s) => s.key).toSet().length, checklist.totalCount);

    final named = checklist.steps.firstWhere((s) => s.key == 'school_named');
    expect(named.done, isTrue);
    expect(checklist.steps.firstWhere((s) => s.key == 'logo').done, isFalse);
    expect(checklist.steps.firstWhere((s) => s.key == 'students').done, isFalse);
    expect(checklist.scorePercent, lessThan(40));
    expect(checklist.scoreBand, anyOf('Starting', 'Building'));
  });

  test('demo school earns create and people points from seed data', () {
    SchoolRegistryService.instance.ensureLocalDemoSchool();
    final school = SchoolRegistryService.instance.lookup('TB-001');
    expect(school, isNotNull);
    final checklist = SchoolOnboardingService.instance.forSchool(school!);

    expect(checklist.steps.firstWhere((s) => s.key == 'school_named').done, isTrue);
    expect(checklist.steps.firstWhere((s) => s.key == 'academic_year').done, isTrue);
    expect(checklist.steps.firstWhere((s) => s.key == 'grade_levels').done, isTrue);
    expect(checklist.steps.firstWhere((s) => s.key == 'live').done, isTrue);
    expect(checklist.steps.firstWhere((s) => s.key == 'students').done, isTrue);
    expect(checklist.steps.firstWhere((s) => s.key == 'teachers').done, isTrue);
    expect(checklist.scorePercent, greaterThan(30));
    expect(
      checklist.phases.firstWhere((p) => p.key == 'create').percent,
      greaterThan(50),
    );
  });

  testWidgets('owner card shows the score and each phase', (tester) async {
    final school = SchoolRecord(
      id: 'FR-UI',
      name: 'Fenote Raey Academy',
      academicYear: '2026/27',
      city: 'Addis Ababa',
      gradeLevels: const ['Grade 1', 'Grade 4'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SchoolOnboardingChecklistCard(school: school),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('school-lifecycle-scorecard')), findsOneWidget);
    expect(find.textContaining('School score'), findsOneWidget);
    expect(find.textContaining('1. Create school'), findsOneWidget);
    expect(find.textContaining('7. Go-live'), findsOneWidget);
    expect(find.text('School name saved'), findsOneWidget);
  });
}
