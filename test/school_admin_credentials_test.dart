import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_admin_credentials_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

void main() {
  test('does not treat the redacted marker as a usable temp password', () {
    final school = SchoolRecord(
      id: 'FR-001',
      name: 'Fenote Raey Academy',
      adminInitialPassword: AuthService.passwordRedactedMarker,
    );
    final creds = SchoolAdminCredentialsService.instance;
    expect(creds.passwordForSchool(school), isNull);
    expect(creds.schoolHasPassword(school), isFalse);
    expect(
      creds.passwordLabel(school),
      contains('Hidden after save'),
    );
    expect(creds.passwordLabel(school).toLowerCase(), isNot(contains('__redacted__')));
  });

  test('still shows a real temp password when one is stored', () {
    final school = SchoolRecord(
      id: 'FR-001',
      name: 'Fenote Raey Academy',
      adminInitialPassword: 'BridgeWalk12!',
    );
    final creds = SchoolAdminCredentialsService.instance;
    expect(creds.passwordForSchool(school), 'BridgeWalk12!');
    expect(creds.passwordLabel(school), 'BridgeWalk12!');
    expect(creds.schoolHasPassword(school), isTrue);
  });

  test('admin email is blank when none is registered', () {
    final school = SchoolRecord(id: 'FR-001', name: 'Fenote Raey Academy');
    expect(
      SchoolAdminCredentialsService.instance.adminEmailForSchool(school),
      isNull,
    );
  });

  test('admin email uses the school record and ignores synthetic mailboxes', () {
    final withEmail = SchoolRecord(
      id: 'FR-001',
      name: 'Fenote Raey Academy',
      adminEmail: '  Director@Fenote.et ',
    );
    final synthetic = SchoolRecord(
      id: 'FR-002',
      name: 'Fenote Raey Academy',
      adminEmail: '0911000003@fr-002.mayabela.local',
    );
    final creds = SchoolAdminCredentialsService.instance;
    expect(creds.adminEmailForSchool(withEmail), 'director@fenote.et');
    expect(creds.adminEmailForSchool(synthetic), isNull);
  });
}
