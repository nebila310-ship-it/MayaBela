import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/platform_schools_cloud_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('draftSchool assigns id and billing defaults without persisting', () {
    final draft = SchoolRegistryService.instance.draftSchool(
      name: 'Alpha Prep',
      city: 'Addis Ababa',
      setup: SchoolSetup(
        academicYear: '2026/27',
        gradeLevels: const ['Grade 1'],
      ),
      adminUsername: '0911000003',
      ratePerStudentMonthEtb: 8,
      minimumMonthlyEtb: 500,
      adminInitialPassword: 'Welcome12!',
      adminFullName: 'Admin Test',
    );

    expect(draft.id.length, greaterThanOrEqualTo(5));
    expect(draft.name, 'Alpha Prep');
    expect(draft.ratePerStudentMonthEtb, 8);
    expect(draft.minimumMonthlyEtb, 500);
    expect(SchoolRegistryService.instance.lookup(draft.id), isNull);
  });

  test('PlatformCreateSchoolResult carries failure codes', () {
    const result = PlatformCreateSchoolResult(
      ok: false,
      errorCode: 'unauthorized',
      errorMessage: 'Owner PIN required.',
    );
    expect(result.ok, isFalse);
    expect(result.errorCode, 'unauthorized');
  });
}
