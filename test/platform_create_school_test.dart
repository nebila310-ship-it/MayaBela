import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/platform_schools_cloud_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(draft.adminEmail, isNull);
    expect(SchoolRegistryService.instance.lookup(draft.id), isNull);
  });

  test('draftSchool stores a real admin email and copyWith can add or clear it', () {
    final draft = SchoolRegistryService.instance.draftSchool(
      name: 'Alpha Prep',
      city: 'Addis Ababa',
      setup: SchoolSetup(
        academicYear: '2026/27',
        gradeLevels: const ['Grade 1'],
      ),
      adminUsername: '0911000003',
      adminEmail: '  Admin@Alpha.et ',
    );
    expect(draft.adminEmail, 'admin@alpha.et');
    expect(draft.toJson()['adminEmail'], 'admin@alpha.et');

    final cleared = draft.copyWith(adminEmail: null);
    expect(cleared.adminEmail, isNull);
    expect(cleared.toJson()['adminEmail'], isNull);

    final added = SchoolRecord.fromJson(cleared.toJson()).copyWith(
      adminEmail: 'new@alpha.et',
    );
    expect(added.adminEmail, 'new@alpha.et');
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

  test('treats GoTrue email-already-registered as a reused admin account', () {
    expect(
      PlatformSchoolCloudResult.isAuthEmailAlreadyRegistered(
        'A user with this email address has already been registered',
      ),
      isTrue,
    );
    expect(
      PlatformSchoolCloudResult.isAuthEmailAlreadyRegistered(
        'Auth user failed: email_exists',
      ),
      isTrue,
    );
    expect(
      PlatformSchoolCloudResult.isAuthEmailAlreadyRegistered(
        'Owner PIN required.',
      ),
      isFalse,
    );
    expect(
      PlatformSchoolCloudResult.isAuthEmailAlreadyRegistered(
        'School ID FR-001 already exists in cloud.',
      ),
      isFalse,
    );
  });

  test('owner console can register a school admin without an email', () async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.clearSession();
    expect(
      AuthService.registerSchoolAdmin(
        schoolName: 'Alpha Prep',
        city: 'Addis Ababa',
        adminFullName: 'Admin Test',
        adminPhone: '0911888001',
        password: 'Welcome12!',
        schoolId: 'ALP801',
      ),
      isNull,
    );
    final admin = AuthService.adminUserForSchool('ALP801');
    expect(admin?.email, isNull);

    AuthService.updateAdminEmailForSchool('ALP801', 'later@alpha.et');
    expect(AuthService.adminUserForSchool('ALP801')?.email, 'later@alpha.et');
  });

  test('owner console rejects a malformed admin email when one is typed', () {
    expect(
      AuthService.registerSchoolAdmin(
        schoolName: 'Alpha Prep',
        city: 'Addis Ababa',
        adminFullName: 'Admin Test',
        adminPhone: '0911888002',
        adminEmail: 'not-an-email',
        password: 'Welcome12!',
        schoolId: 'ALP802',
      ),
      'invalid_email',
    );
  });
}
