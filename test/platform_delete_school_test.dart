import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/platform_schools_cloud_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

SchoolRecord _school(String id, String name) {
  return SchoolRecord(
    id: id,
    name: name,
    city: 'Addis Ababa',
    academicYear: '2026/27',
    gradeLevels: const ['Grade 1'],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SchoolRegistryService.instance.applyPersistedSchools([]);
  });

  test('owner cloud list drops a school deleted on another PC', () {
    SchoolRegistryService.instance.applyPersistedSchools([
      _school('FEN101', 'Fenote Raey Academy'),
      _school('ALP202', 'Alpha Prep'),
    ]);

    SchoolRegistryService.instance.removeSchoolsNotInCloud(
      cloudIds: {'ALP202'},
    );

    expect(SchoolRegistryService.instance.lookup('FEN101'), isNull);
    expect(SchoolRegistryService.instance.lookup('ALP202')?.name, 'Alpha Prep');
  });

  test('empty successful cloud list removes every real school', () {
    SchoolRegistryService.instance.applyPersistedSchools([
      _school('FEN101', 'Fenote Raey Academy'),
      _school('TB-001', 'Maya School'),
    ]);

    SchoolRegistryService.instance.removeSchoolsNotInCloud(cloudIds: {});

    expect(SchoolRegistryService.instance.lookup('FEN101'), isNull);
    expect(SchoolRegistryService.instance.lookup('TB-001')?.name, 'Maya School');
  });

  test('cloud-listed TB-001 is kept when present', () {
    SchoolRegistryService.instance.applyPersistedSchools([
      _school('TB-001', 'Maya School'),
      _school('FEN101', 'Fenote Raey Academy'),
    ]);

    SchoolRegistryService.instance.removeSchoolsNotInCloud(
      cloudIds: {'TB-001', 'FEN101'},
    );

    expect(SchoolRegistryService.instance.lookup('TB-001'), isNotNull);
    expect(SchoolRegistryService.instance.lookup('FEN101'), isNotNull);
  });

  test('delete result carries failure so the console does not pretend success', () {
    const result = PlatformSchoolCloudResult(
      ok: false,
      errorCode: 'unauthorized',
      errorMessage: 'Owner PIN required.',
    );
    expect(result.ok, isFalse);
    expect(result.errorCode, 'unauthorized');
  });
}
