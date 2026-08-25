import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/models/cloud/app_data_maps.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/school_registry_persistence_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

class SchoolAuthCloudResult {
  const SchoolAuthCloudResult({
    required this.ok,
    this.errorCode,
    this.errorMessage,
    this.profile,
    this.teacherSynced = false,
  });

  final bool ok;
  final String? errorCode;
  final String? errorMessage;
  final RegisteredUser? profile;
  final bool teacherSynced;
}

/// Server-side school login via Supabase Edge Functions + Auth session.
class SchoolAuthCloudService {
  SchoolAuthCloudService._();
  static final instance = SchoolAuthCloudService._();

  static Future<bool>? _ensureJwtInFlight;

  bool get isAvailable => SupabaseBootstrap.isInitialized;

  static Future<bool> hasSchoolClaims() async {
    if (!SupabaseBootstrap.isInitialized) return false;
    final session = SupabaseBootstrap.client.auth.currentSession;
    if (session == null || session.accessToken.trim().isEmpty) return false;
    final meta = session.user.appMetadata;
    if (schoolClaimsArePresent(meta)) return true;
    // Some restore paths leave appMetadata empty while the JWT still carries
    // role/schoolId — read the access-token payload as a fallback.
    return schoolClaimsArePresent(_claimsFromAccessToken(session.accessToken));
  }

  /// School id for RLS upserts: session, login profile, then JWT claims.
  static String? resolvedSchoolId() {
    final fromAuth = AuthService.activeSchoolId?.trim();
    if (fromAuth != null && fromAuth.isNotEmpty) {
      return fromAuth.toUpperCase();
    }
    final fromUser = AuthService.currentUser?.schoolId?.trim();
    if (fromUser != null && fromUser.isNotEmpty) {
      return fromUser.toUpperCase();
    }
    if (!SupabaseBootstrap.isInitialized) return null;
    try {
      final session = SupabaseBootstrap.client.auth.currentSession;
      if (session == null) return null;
      final meta = session.user.appMetadata;
      final fromMeta = '${meta['schoolId'] ?? meta['school_id'] ?? ''}'.trim();
      if (fromMeta.isNotEmpty) return fromMeta.toUpperCase();
      final fromJwt = _claimsFromAccessToken(session.accessToken);
      final tokenSchool =
          '${fromJwt['schoolId'] ?? fromJwt['school_id'] ?? ''}'.trim();
      if (tokenSchool.isNotEmpty) return tokenSchool.toUpperCase();
    } catch (_) {}
    return null;
  }

  @visibleForTesting
  static bool schoolClaimsArePresent(Map<String, dynamic>? meta) {
    if (meta == null || meta.isEmpty) return false;
    final role = '${meta['role'] ?? ''}'.trim().toLowerCase();
    if (role.isEmpty || role == 'authenticated' || role == 'anon') {
      return false;
    }
    final schoolId = '${meta['schoolId'] ?? meta['school_id'] ?? ''}'.trim();
    return schoolId.isNotEmpty;
  }

  @visibleForTesting
  static bool accessTokenIsFresh(
    int? expiresAtUnixSeconds, {
    DateTime? now,
    Duration minTtl = const Duration(seconds: 90),
  }) {
    if (expiresAtUnixSeconds == null) return true;
    final nowSec = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return expiresAtUnixSeconds - nowSec >= minTtl.inSeconds;
  }

  static Map<String, dynamic> schoolClaimsFromAccessToken(String accessToken) =>
      _claimsFromAccessToken(accessToken);

  static Map<String, dynamic> _claimsFromAccessToken(String accessToken) {
    try {
      final parts = accessToken.split('.');
      if (parts.length < 2) return const {};
      var payload = parts[1];
      final rem = payload.length % 4;
      if (rem > 0) payload = payload.padRight(payload.length + (4 - rem), '=');
      final normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      final decoded = jsonDecode(utf8.decode(base64.decode(normalized)));
      if (decoded is! Map) return const {};
      final map = Map<String, dynamic>.from(decoded);
      final appMeta = map['app_metadata'];
      if (appMeta is Map) {
        return Map<String, dynamic>.from(appMeta);
      }
      // Some tokens flatten custom claims at the root.
      return map;
    } catch (_) {
      return const {};
    }
  }

  /// Confirm school role claims before cloud writes.
  ///
  /// Do not refresh a still-valid token: [refreshSession] on every Send can
  /// drop app_metadata claims (or sign the user out on a raced refresh) while
  /// the teacher can still read parent messages. Only refresh when the access
  /// token is expired or about to expire.
  Future<bool> ensureValidSchoolJwt({bool forceRefresh = false}) async {
    if (!isAvailable) return false;
    final inFlight = _ensureJwtInFlight;
    if (inFlight != null) return inFlight;
    final run = _ensureValidSchoolJwtUnlocked(forceRefresh: forceRefresh);
    _ensureJwtInFlight = run;
    try {
      return await run;
    } finally {
      if (identical(_ensureJwtInFlight, run)) {
        _ensureJwtInFlight = null;
      }
    }
  }

  Future<bool> _ensureValidSchoolJwtUnlocked({
    required bool forceRefresh,
  }) async {
    try {
      await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);

      if (!forceRefresh && await _currentSessionIsUsable()) return true;

      final session = SupabaseBootstrap.client.auth.currentSession;
      final tokenExpiring = session != null &&
          !accessTokenIsFresh(session.expiresAt);
      if (session != null && tokenExpiring) {
        try {
          await SupabaseBootstrap.client.auth
              .refreshSession()
              .timeout(const Duration(seconds: 8));
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'SchoolAuthCloudService.refreshSession skipped: $e',
            );
          }
          // Keep the existing token if it still carries school claims.
          if (await hasSchoolClaims()) return true;
        }
        if (await hasSchoolClaims()) return true;
      }

      if (!forceRefresh && await hasSchoolClaims()) return true;

      // Session exists but school claims missing/stale — re-stamp metadata and
      // pull a fresh JWT (school-refresh-claims now returns new tokens).
      if (SupabaseBootstrap.client.auth.currentSession != null) {
        final refreshed = await refreshAccessClaims(
          username: AuthService.currentUser?.username,
          schoolId: resolvedSchoolId(),
        );
        if (refreshed.ok && await hasSchoolClaims()) return true;
      }

      // Last resort: school password still in memory from this browser session.
      if (await _trySilentReLogin()) return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SchoolAuthCloudService.ensureValidSchoolJwt: $e');
      }
    }
    return await hasSchoolClaims();
  }

  Future<bool> _currentSessionIsUsable() async {
    if (!await hasSchoolClaims()) return false;
    final session = SupabaseBootstrap.client.auth.currentSession;
    if (session == null) return false;
    return accessTokenIsFresh(session.expiresAt);
  }

  Future<bool> _trySilentReLogin() async {
    final user = AuthService.currentUser;
    if (user == null) return false;
    final pass = user.password.trim();
    if (pass.isEmpty || pass == AuthService.passwordRedactedMarker) {
      return false;
    }
    final result = await login(
      roleKey: user.roleKey,
      username: user.username,
      password: pass,
      schoolId: user.schoolId ?? AuthService.activeSchoolId,
    );
    return result.ok && await hasSchoolClaims();
  }

  /// Re-authenticate the current Admin/staff user, then confirm school JWT.
  Future<bool> reauthenticateWithPassword(String password) async {
    final user = AuthService.currentUser;
    if (user == null || password.trim().isEmpty) return false;
    final result = await login(
      roleKey: user.roleKey,
      username: user.username,
      password: password.trim(),
      schoolId: user.schoolId ?? AuthService.activeSchoolId,
    );
    return result.ok && await hasSchoolClaims();
  }

  Future<Map<String, dynamic>?> _invoke(
    String name,
    Map<String, dynamic> body,
  ) async {
    final res = await SupabaseBootstrap.client.functions.invoke(
      name,
      body: body,
    );
    final data = res.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  Map<String, dynamic>? _detailsMap(Object? details) {
    if (details is Map) {
      return Map<String, dynamic>.from(details);
    }
    if (details is String) {
      final t = details.trim();
      if (t.startsWith('{')) {
        try {
          // ignore: avoid_dynamic_calls
          final decoded = t; // parsed below via regex fallbacks
          final codeMatch =
              RegExp(r'"code"\s*:\s*"([^"]+)"').firstMatch(decoded);
          final errMatch =
              RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(decoded);
          if (codeMatch != null || errMatch != null) {
            return {
              if (codeMatch != null) 'code': codeMatch.group(1),
              if (errMatch != null) 'error': errMatch.group(1),
            };
          }
        } catch (_) {}
      }
    }
    return null;
  }

  String _mapFunctionsError(FunctionException e) {
    final mapped = _detailsMap(e.details);
    final code = mapped?['code']?.toString().trim();
    if (code != null && code.isNotEmpty && code != 'error') {
      return code;
    }
    final details = '${e.details}'.toLowerCase();
    if (details.contains('rate')) return 'rate_limited';
    if (details.contains('school_blocked')) return 'school_inactive';
    if (details.contains('admin authentication') ||
        details.contains('admin sign-in')) {
      return 'denied';
    }
    if (details.contains('school')) return 'school_mismatch';
    if (details.contains('password')) return 'password_too_short';
    if (details.contains('role')) return 'role_mismatch';
    if (e.status == 401 || e.status == 403) return 'denied';
    if (e.status == 404) return 'cloud_required';
    return 'invalid';
  }

  String? _functionsErrorMessage(FunctionException e) {
    final mapped = _detailsMap(e.details);
    final err = mapped?['error']?.toString().trim();
    if (err != null && err.isNotEmpty) return err;
    final raw = '${e.details}'.trim();
    if (raw.isNotEmpty && raw.length < 240) return raw;
    return null;
  }

  Future<SchoolAuthCloudResult> login({
    required String roleKey,
    required String username,
    required String password,
    String? schoolId,
  }) async {
    if (!isAvailable) {
      return const SchoolAuthCloudResult(ok: false, errorCode: 'cloud_required');
    }

    try {
      await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);

      final data = await _invoke('school-login', {
        'username': username.trim(),
        'password': password,
        'roleKey': roleKey,
        if (schoolId != null && schoolId.trim().isNotEmpty)
          'schoolId': schoolId.trim().toUpperCase(),
      });

      if (data == null || data['error'] != null) {
        return SchoolAuthCloudResult(
          ok: false,
          errorCode: (data?['code'] as String?) ?? 'invalid',
        );
      }

      final refreshToken = data['refresh_token'] as String?;
      final accessToken = data['access_token'] as String?;
      final profileMap = Map<String, dynamic>.from(data['profile'] as Map);
      if (refreshToken == null || refreshToken.isEmpty) {
        return const SchoolAuthCloudResult(ok: false, errorCode: 'invalid');
      }

      await SupabaseBootstrap.client.auth.setSession(
        refreshToken,
        accessToken: accessToken,
      );
      try {
        await SupabaseBootstrap.client.auth.refreshSession();
      } catch (_) {}

      // Heal missing/stale app_metadata so Admin writes work on first try.
      if (!await hasSchoolClaims()) {
        final healed = await refreshAccessClaims(username: username.trim());
        if (!healed.ok) {
          return const SchoolAuthCloudResult(ok: false, errorCode: 'invalid');
        }
      }
      if (!await hasSchoolClaims()) {
        return const SchoolAuthCloudResult(ok: false, errorCode: 'invalid');
      }

      final profile = _userFromProfile(profileMap);
      AuthService.mergePersistedUser(profile);
      // The server is authoritative for staff roles: an empty list means the
      // roles were revoked, so it must overwrite any locally cached grants.
      final merged = AuthService.findUser(profile.username);
      if (merged != null) {
        merged.staffRoles = List<String>.from(profile.staffRoles);
        merged.staffPermissions = List<String>.from(profile.staffPermissions);
      }
      AuthService.setSession(merged ?? profile);
      // Heal session if auth doc lost roles but local/cloud teacher registry
      // still has administration staffRoles.
      final sessionUser = AuthService.currentUser;
      if (sessionUser != null &&
          sessionUser.roleKey == AuthService.roleTeacher &&
          sessionUser.staffRoles.isEmpty) {
        final record = TeacherRegistryService.instance.resolveForAuthUser(
          linkedTeacherId: sessionUser.linkedTeacherId,
          username: sessionUser.username,
          phone: sessionUser.phone,
          schoolId: sessionUser.schoolId,
        );
        if (record != null && record.staffRoles.isNotEmpty) {
          sessionUser.staffRoles = List<String>.from(record.staffRoles);
        }
      }
      _applyAccessScopeFromProfile(profileMap);
      _hydrateSchoolFromLogin(data['school'], profile.schoolId);
      final resolvedSchoolId = (schoolId != null && schoolId.trim().isNotEmpty)
          ? schoolId.trim().toUpperCase()
          : profile.schoolId?.trim().toUpperCase();
      if (resolvedSchoolId != null && resolvedSchoolId.isNotEmpty) {
        AuthService.applySchoolContext(resolvedSchoolId);
      }

      return SchoolAuthCloudResult(ok: true, profile: profile);
    } on FunctionException catch (e) {
      if (kDebugMode) {
        debugPrint('SchoolAuthCloudService.login: ${e.status} ${e.details}');
      }
      return SchoolAuthCloudResult(
        ok: false,
        errorCode: _mapFunctionsError(e),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SchoolAuthCloudService.login failed: $e');
      }
      final text = e.toString().toLowerCase();
      if (text.contains('not-found') ||
          text.contains('not found') ||
          text.contains('unavailable') ||
          text.contains('failed host lookup') ||
          text.contains('network')) {
        return const SchoolAuthCloudResult(
          ok: false,
          errorCode: 'cloud_required',
        );
      }
      return const SchoolAuthCloudResult(ok: false, errorCode: 'invalid');
    }
  }

  Future<SchoolAuthCloudResult> changePassword({
    required String newPassword,
    String? currentPassword,
    String? username,
  }) async {
    if (!isAvailable) {
      return const SchoolAuthCloudResult(ok: false, errorCode: 'cloud_required');
    }
    try {
      final data = await _invoke('school-change-password', {
        'newPassword': newPassword,
        'currentPassword': ?currentPassword,
        'username': ?username,
      });
      if (data == null || data['error'] != null) {
        return SchoolAuthCloudResult(
          ok: false,
          errorCode: (data?['code'] as String?) ?? 'invalid',
        );
      }
      return const SchoolAuthCloudResult(ok: true);
    } on FunctionException catch (e) {
      return SchoolAuthCloudResult(
        ok: false,
        errorCode: _mapFunctionsError(e),
      );
    } catch (_) {
      return const SchoolAuthCloudResult(ok: false, errorCode: 'invalid');
    }
  }

  Future<SchoolAuthCloudResult> registerParent({
    required RegisteredUser user,
    required String password,
    List<ParentChildRegistration> children = const [],
  }) async {
    if (!isAvailable) {
      return const SchoolAuthCloudResult(ok: false, errorCode: 'cloud_required');
    }
    try {
      final data = await _invoke('school-register-parent', {
        'username': user.username,
        'password': password,
        'schoolId': user.schoolId,
        'email': user.email,
        'phone': user.phone,
        'fullName': user.fullName,
        'children': children
            .map(
              (child) => {
                'studentId': child.studentId,
                'dateOfBirth':
                    '${child.dateOfBirth.year.toString().padLeft(4, '0')}-'
                    '${child.dateOfBirth.month.toString().padLeft(2, '0')}-'
                    '${child.dateOfBirth.day.toString().padLeft(2, '0')}',
                'relationship': child.relationship.name,
                'hasMedicalCondition': child.hasMedicalCondition,
                if (child.medicalConditionDetails != null)
                  'medicalConditionDetails': child.medicalConditionDetails,
                if (child.otherMedicalInfo != null)
                  'otherMedicalInfo': child.otherMedicalInfo,
              },
            )
            .toList(),
      });
      if (data == null || data['error'] != null) {
        return SchoolAuthCloudResult(
          ok: false,
          errorCode: (data?['code'] as String?) ?? 'invalid',
        );
      }
      return const SchoolAuthCloudResult(ok: true);
    } on FunctionException catch (e) {
      return SchoolAuthCloudResult(
        ok: false,
        errorCode: _mapFunctionsError(e),
      );
    } catch (_) {
      return const SchoolAuthCloudResult(ok: false, errorCode: 'invalid');
    }
  }

  /// Permanently removes a school login so the phone/username can be reused.
  Future<SchoolAuthCloudResult> deleteAccount({
    required String username,
    required String schoolId,
  }) async {
    if (!isAvailable) {
      return const SchoolAuthCloudResult(ok: false, errorCode: 'cloud_required');
    }
    try {
      await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
      try {
        await SupabaseBootstrap.client.auth.refreshSession();
      } catch (_) {}

      final data = await _invoke('school-delete-account', {
        'username': username.trim().toLowerCase(),
        'schoolId': schoolId.trim().toUpperCase(),
      });
      if (data == null || data['error'] != null) {
        return SchoolAuthCloudResult(
          ok: false,
          errorCode: (data?['code'] as String?) ?? 'invalid',
          errorMessage: data?['error']?.toString(),
        );
      }
      return const SchoolAuthCloudResult(ok: true);
    } on FunctionException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'SchoolAuthCloudService.deleteAccount: ${e.status} ${e.details}',
        );
      }
      return SchoolAuthCloudResult(
        ok: false,
        errorCode: _mapFunctionsError(e),
        errorMessage: _functionsErrorMessage(e),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SchoolAuthCloudService.deleteAccount failed: $e');
      }
      return SchoolAuthCloudResult(
        ok: false,
        errorCode: 'invalid',
        errorMessage: e.toString(),
      );
    }
  }

  /// Service-role registry upsert (bypasses client RLS mismatches).
  Future<SchoolAuthCloudResult> upsertRegistryRecord({
    required String collection,
    required Map<String, dynamic> record,
    String? schoolId,
    String? docId,
  }) async {
    return upsertRegistryBatch(
      collection: collection,
      schoolId: schoolId,
      records: [record],
      docId: docId,
    );
  }

  /// Batch service-role registry upsert (one or many rows).
  Future<SchoolAuthCloudResult> upsertRegistryBatch({
    required String collection,
    required List<Map<String, dynamic>> records,
    String? schoolId,
    String? docId,
  }) async {
    if (!isAvailable) {
      return const SchoolAuthCloudResult(ok: false, errorCode: 'cloud_required');
    }
    if (records.isEmpty) {
      return const SchoolAuthCloudResult(ok: true);
    }
    final sid = (schoolId ??
            records.first['schoolId']?.toString() ??
            AuthService.activeSchoolId ??
            '')
        .trim()
        .toUpperCase();
    if (sid.isEmpty) {
      return const SchoolAuthCloudResult(
        ok: false,
        errorCode: 'invalid',
        errorMessage: 'schoolId is required',
      );
    }
    try {
      await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
      try {
        await SupabaseBootstrap.client.auth.refreshSession();
      } catch (_) {}

      final payload = records
          .map(
            (r) => Map<String, dynamic>.from(r)
              ..remove('_docId')
              ..remove('initialPassword'),
          )
          .toList();
      final data = await _invoke('school-upsert-registry', {
        'collection': collection,
        'schoolId': sid,
        'records': payload,
        if (docId != null && docId.trim().isNotEmpty) 'docId': docId.trim(),
      });
      if (data == null || data['error'] != null) {
        return SchoolAuthCloudResult(
          ok: false,
          errorCode: (data?['code'] as String?) ?? 'invalid',
          errorMessage: data?['error']?.toString(),
        );
      }
      return const SchoolAuthCloudResult(ok: true);
    } on FunctionException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'SchoolAuthCloudService.upsertRegistryBatch: ${e.status} ${e.details}',
        );
      }
      return SchoolAuthCloudResult(
        ok: false,
        errorCode: _mapFunctionsError(e),
        errorMessage: _functionsErrorMessage(e),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SchoolAuthCloudService.upsertRegistryBatch failed: $e');
      }
      return SchoolAuthCloudResult(
        ok: false,
        errorCode: 'invalid',
        errorMessage: e.toString(),
      );
    }
  }

  Future<SchoolAuthCloudResult> upsertAccount({
    required RegisteredUser user,
    String? password,
    List<String>? staffRoles,
    List<String>? staffPermissions,
    Map<String, dynamic>? teacherRecord,
  }) async {
    if (!isAvailable) {
      return const SchoolAuthCloudResult(ok: false, errorCode: 'cloud_required');
    }
    return _upsertAccountOnce(
      user: user,
      password: password,
      staffRoles: staffRoles,
      staffPermissions: staffPermissions,
      teacherRecord: teacherRecord,
      allowAuthRetry: true,
    );
  }

  Future<SchoolAuthCloudResult> _upsertAccountOnce({
    required RegisteredUser user,
    String? password,
    List<String>? staffRoles,
    List<String>? staffPermissions,
    Map<String, dynamic>? teacherRecord,
    required bool allowAuthRetry,
  }) async {
    try {
      await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
      if (!await ensureValidSchoolJwt()) {
        return const SchoolAuthCloudResult(
          ok: false,
          errorCode: 'denied',
          errorMessage:
              'Cloud session expired. Enter your Admin password to continue, then try again.',
        );
      }

      final teacherPayload = teacherRecord == null
          ? null
          : (Map<String, dynamic>.from(teacherRecord)
            ..remove('initialPassword')
            ..remove('_docId'));
      // Only send staffRoles when the caller explicitly passes them. Profile
      // syncs must not wipe administration roles with an empty list.
      final body = {
        'username': user.username,
        'roleKey': user.roleKey,
        'schoolId': (user.schoolId ?? AuthService.activeSchoolId ?? '')
            .trim()
            .toUpperCase(),
        'email': user.email,
        'phone': user.phone,
        'fullName': user.fullName,
        'linkedStudentIds': user.linkedStudentIds,
        'linkedTeacherId': user.linkedTeacherId,
        'linkedAdminId': user.linkedAdminId,
        'linkedDriverId': user.linkedDriverId,
        'linkedStudentId': user.linkedStudentId,
        'mustChangePassword': user.mustChangePassword,
        if (password != null && password.isNotEmpty) 'password': password,
        if (staffRoles != null) 'staffRoles': staffRoles,
        if (staffPermissions != null) 'staffPermissions': staffPermissions,
        if (teacherPayload != null) 'teacherRecord': teacherPayload,
      };

      final data = await _invoke('school-upsert-account', body);
      if (data == null || data['error'] != null) {
        final err = data?['error']?.toString() ?? '';
        if (allowAuthRetry && _looksLikeJwtFailure(err)) {
          if (await ensureValidSchoolJwt()) {
            return _upsertAccountOnce(
              user: user,
              password: password,
              staffRoles: staffRoles,
              staffPermissions: staffPermissions,
              teacherRecord: teacherRecord,
              allowAuthRetry: false,
            );
          }
        }
        return SchoolAuthCloudResult(
          ok: false,
          errorCode: (data?['code'] as String?) ?? 'invalid',
          errorMessage: data?['error']?.toString(),
        );
      }
      return SchoolAuthCloudResult(
        ok: true,
        teacherSynced: data['teacherSynced'] == true,
      );
    } on FunctionException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'SchoolAuthCloudService.upsertAccount: ${e.status} ${e.details}',
        );
      }
      final msg = _functionsErrorMessage(e) ?? '';
      if (allowAuthRetry &&
          (e.status == 401 ||
              e.status == 403 ||
              _looksLikeJwtFailure(msg))) {
        if (await ensureValidSchoolJwt()) {
          return _upsertAccountOnce(
            user: user,
            password: password,
            staffRoles: staffRoles,
            staffPermissions: staffPermissions,
            teacherRecord: teacherRecord,
            allowAuthRetry: false,
          );
        }
      }
      return SchoolAuthCloudResult(
        ok: false,
        errorCode: _mapFunctionsError(e),
        errorMessage: _functionsErrorMessage(e),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SchoolAuthCloudService.upsertAccount failed: $e');
      }
      return SchoolAuthCloudResult(
        ok: false,
        errorCode: 'invalid',
        errorMessage: e.toString(),
      );
    }
  }

  bool _looksLikeJwtFailure(String message) {
    final t = message.toLowerCase();
    return t.contains('jwt') ||
        t.contains('sign in') ||
        t.contains('authentication') ||
        t.contains('expired') ||
        t.contains('missing sub') ||
        t.contains('cloud session');
  }

  Future<void> signOutCloud() async {
    await SupabaseBootstrap.signOutCloud();
  }

  /// Restore AuthService session from Supabase Auth app_metadata.
  Future<bool> restoreFromFirebaseAuth() async {
    if (!isAvailable) return false;
    final user = SupabaseBootstrap.client.auth.currentUser;
    if (user == null) return false;

    try {
      Map<String, dynamic> claims = Map<String, dynamic>.from(user.appMetadata);
      final session = SupabaseBootstrap.client.auth.currentSession;
      if (session != null &&
          (claims['role'] == null ||
              claims['schoolId'] == null ||
              claims['username'] == null)) {
        final fromJwt = _claimsFromAccessToken(session.accessToken);
        fromJwt.forEach((key, value) {
          if (value == null) return;
          final existing = claims[key];
          if (existing == null || '$existing'.trim().isEmpty) {
            claims[key] = value;
          }
        });
      }
      final role = claims['role'] as String?;
      final schoolId = claims['schoolId'] as String?;
      final username = claims['username'] as String?;
      if (role == null || schoolId == null || username == null) return false;

      final existing = AuthService.findUser(username);
      final claimLinkedIds = _stringList(claims['linkedStudentIds']);
      final profile = RegisteredUser(
        username: username,
        password: '',
        roleKey: role,
        schoolId: schoolId,
        linkedStudentId: (claims['linkedStudentId'] as String?)?.isEmpty ?? true
            ? existing?.linkedStudentId
            : claims['linkedStudentId'] as String?,
        linkedTeacherId: (claims['linkedTeacherId'] as String?)?.isEmpty ?? true
            ? existing?.linkedTeacherId
            : claims['linkedTeacherId'] as String?,
        linkedDriverId: (claims['linkedDriverId'] as String?)?.isEmpty ?? true
            ? existing?.linkedDriverId
            : claims['linkedDriverId'] as String?,
        email: existing?.email,
        phone: existing?.phone,
        fullName: existing?.fullName,
        linkedStudentIds: claimLinkedIds.isNotEmpty
            ? claimLinkedIds
            : (existing?.linkedStudentIds ?? const []),
        linkedAdminId: existing?.linkedAdminId,
        mustChangePassword: existing?.mustChangePassword ?? false,
      );
      AuthService.mergePersistedUser(profile);
      AuthService.applyCloudAccessScope(
        linkedClassNames: _stringList(claims['linkedClassNames']),
        linkedStudentNames: _stringList(claims['linkedStudentNames']),
        assignedClassNames: _stringList(claims['assignedClassNames']),
        linkedStudentIds: claimLinkedIds,
      );
      if (SchoolRegistryService.instance.lookup(schoolId) == null) {
        _hydrateSchoolFromLogin({
          'id': schoolId,
          'name': (claims['schoolName'] as String?)?.trim().isNotEmpty == true
              ? claims['schoolName']
              : schoolId,
          'status': 'active',
        }, schoolId);
      }
      return AuthService.restoreSession(username, schoolId: schoolId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SchoolAuthCloudService.restoreFromFirebaseAuth: $e');
      }
      return false;
    }
  }

  Future<SchoolAuthCloudResult> refreshAccessClaims({
    String? username,
    String? schoolId,
  }) async {
    if (!isAvailable) {
      return const SchoolAuthCloudResult(ok: false, errorCode: 'cloud_required');
    }
    try {
      final sid = (schoolId ?? resolvedSchoolId() ?? '').trim().toUpperCase();
      final data = await _invoke('school-refresh-claims', {
        if (username != null && username.trim().isNotEmpty)
          'username': username.trim(),
        if (sid.isNotEmpty) 'schoolId': sid,
      });
      if (data == null || data['error'] != null) {
        return SchoolAuthCloudResult(
          ok: false,
          errorCode: (data?['code'] as String?) ?? 'invalid',
        );
      }
      final refresh = data['refresh_token'] as String?;
      final access = data['access_token'] as String?;
      if (refresh != null && refresh.isNotEmpty) {
        await SupabaseBootstrap.client.auth.setSession(
          refresh,
          accessToken: access,
        );
      } else {
        // Metadata was updated server-side without a new refresh_token — pull
        // the updated app_metadata into the current JWT.
        try {
          await SupabaseBootstrap.client.auth.refreshSession();
        } catch (_) {}
      }
      if (!await hasSchoolClaims()) {
        try {
          await SupabaseBootstrap.client.auth.refreshSession();
        } catch (_) {}
      }
      final profileMap = data['profile'] is Map
          ? Map<String, dynamic>.from(data['profile'] as Map)
          : <String, dynamic>{};
      if (profileMap.isNotEmpty) {
        _applyAccessScopeFromProfile(profileMap);
        final profile = _userFromProfile(profileMap);
        AuthService.mergePersistedUser(profile);
      }
      return SchoolAuthCloudResult(
        ok: true,
        profile: profileMap.isEmpty ? null : _userFromProfile(profileMap),
      );
    } on FunctionException catch (e) {
      return SchoolAuthCloudResult(
        ok: false,
        errorCode: _mapFunctionsError(e),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SchoolAuthCloudService.refreshAccessClaims: $e');
      }
      return const SchoolAuthCloudResult(ok: false, errorCode: 'invalid');
    }
  }

  void _applyAccessScopeFromProfile(Map<String, dynamic> profileMap) {
    AuthService.applyCloudAccessScope(
      linkedClassNames: _stringList(profileMap['linkedClassNames']),
      linkedStudentNames: _stringList(profileMap['linkedStudentNames']),
      assignedClassNames: _stringList(profileMap['assignedClassNames']),
      linkedStudentIds: _stringList(profileMap['linkedStudentIds']),
    );
  }

  void _hydrateSchoolFromLogin(dynamic raw, String? fallbackSchoolId) {
    try {
      Map<String, dynamic>? map;
      if (raw is Map) {
        map = Map<String, dynamic>.from(raw);
      } else if (fallbackSchoolId != null && fallbackSchoolId.trim().isNotEmpty) {
        map = {
          'id': fallbackSchoolId.trim().toUpperCase(),
          'name': fallbackSchoolId.trim().toUpperCase(),
          'status': 'active',
        };
      }
      if (map == null) return;
      final id = (map['id'] as String?)?.trim().toUpperCase() ??
          fallbackSchoolId?.trim().toUpperCase();
      if (id == null || id.isEmpty) return;
      map['id'] = id;
      final school = AppDataMaps.schoolFromMap(map);
      SchoolRegistryService.instance.upsertSchool(school);
      // Persist so the next open of this browser still knows the school.
      // ignore: discarded_futures
      SchoolRegistryPersistenceService.instance.saveFromService(pushCloud: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SchoolAuthCloudService._hydrateSchoolFromLogin: $e');
      }
    }
  }

  List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  RegisteredUser _userFromProfile(Map<String, dynamic> map) {
    return RegisteredUser(
      username: map['username'] as String,
      password: '',
      roleKey: map['roleKey'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      schoolId: map['schoolId'] as String?,
      fullName: map['fullName'] as String?,
      linkedStudentIds: (map['linkedStudentIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      linkedTeacherId: map['linkedTeacherId'] as String?,
      linkedAdminId: map['linkedAdminId'] as String?,
      linkedDriverId: map['linkedDriverId'] as String?,
      linkedStudentId: map['linkedStudentId'] as String?,
      mustChangePassword: map['mustChangePassword'] as bool? ?? false,
      staffRoles: (map['staffRoles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      staffPermissions: (map['staffPermissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (map['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
