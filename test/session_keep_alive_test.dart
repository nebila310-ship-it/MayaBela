import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/session_prefs_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'KEEP-001';
  const username = 'keep.alive.teacher';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    AuthService.sessionSchoolId = null;
    SchoolRegistryService.instance.applyPersistedSchools([
      SchoolRecord(
        id: schoolId,
        name: 'Keep Alive School',
      ),
    ]);
    AuthService.mergePersistedUser(
      RegisteredUser(
        username: username,
        password: 'secret',
        roleKey: AuthService.roleTeacher,
        schoolId: schoolId,
        fullName: 'Keep Alive',
      ),
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
    AuthService.sessionSchoolId = null;
  });

  test('browser refresh restores the local dashboard session', () async {
    expect(
      AuthService.restoreSession(username, schoolId: schoolId),
      isTrue,
    );
    await SessionPrefsService.instance.saveActiveSession();

    AuthService.currentUser = null;
    AuthService.sessionSchoolId = null;

    final restored =
        await SessionPrefsService.instance.restoreSavedLocalSession();
    expect(restored, isTrue);
    expect(AuthService.currentUser?.username, username);
    expect(AuthService.activeSchoolId, schoolId);
  });

  test('local restore hydrates a missing school instead of sending login',
      () async {
    SchoolRegistryService.instance.applyPersistedSchools(const []);
    expect(SchoolRegistryService.instance.lookup(schoolId), isNull);

    SharedPreferences.setMockInitialValues({
      'session_username': username,
      'session_school_id': schoolId,
      'session_role_key': AuthService.roleTeacher,
    });

    final restored =
        await SessionPrefsService.instance.restoreSavedLocalSession();
    expect(restored, isTrue);
    expect(AuthService.currentUser?.username, username);
    expect(SchoolRegistryService.instance.lookup(schoolId), isNotNull);
  });

  test('local restore rebuilds a missing user from saved role', () async {
    SharedPreferences.setMockInitialValues({
      'session_username': 'new.phone.parent',
      'session_school_id': schoolId,
      'session_role_key': AuthService.roleParent,
    });

    final restored =
        await SessionPrefsService.instance.restoreSavedLocalSession();
    expect(restored, isTrue);
    expect(AuthService.currentUser?.username, 'new.phone.parent');
    expect(AuthService.currentUser?.roleKey, AuthService.roleParent);
  });

  test('JWT payload supplies school claims when app_metadata is empty', () {
    final token = _unsignedJwt({
      'app_metadata': {
        'role': 'parent',
        'schoolId': 'ABC-9',
        'username': '0911223344',
      },
    });
    final claims = SchoolAuthCloudService.schoolClaimsFromAccessToken(token);
    expect(claims['role'], 'parent');
    expect(claims['schoolId'], 'ABC-9');
    expect(claims['username'], '0911223344');
  });

  test('malformed access tokens do not throw', () {
    expect(
      SchoolAuthCloudService.schoolClaimsFromAccessToken('not-a-jwt'),
      isEmpty,
    );
  });
}

String _unsignedJwt(Map<String, dynamic> payload) {
  String encode(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');

  return '${encode({'alg': 'none'})}.${encode(payload)}.sig';
}
