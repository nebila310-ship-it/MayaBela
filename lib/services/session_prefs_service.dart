import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/models/school_lifecycle.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

/// Persists the logged-in session so a browser/app refresh stays on the
/// dashboard instead of dumping the user back at login.
class SessionPrefsService {
  SessionPrefsService._();
  static final instance = SessionPrefsService._();

  static const _usernameKey = 'session_username';
  static const _schoolKey = 'session_school_id';
  static const _roleKey = 'session_role_key';
  static const _staffRolesKey = 'session_staff_roles';

  Future<void> saveActiveSession() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, user.username);
    await prefs.setString(_roleKey, user.roleKey);
    if (user.staffRoles.isNotEmpty) {
      await prefs.setStringList(_staffRolesKey, user.staffRoles);
    } else {
      await prefs.remove(_staffRolesKey);
    }

    final school = AuthService.activeSchoolId;
    if (school != null && school.isNotEmpty) {
      await prefs.setString(_schoolKey, school);
    } else {
      await prefs.remove(_schoolKey);
    }
  }

  Future<bool> restoreActiveSession() async {
    await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);

    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString(_usernameKey);
    final savedSchool = prefs.getString(_schoolKey);

    if (SupabaseBootstrap.isInitialized &&
        savedUsername != null &&
        savedUsername.isNotEmpty) {
      // supabase_flutter recovers persistSession during initialize; wait briefly.
      for (var i = 0; i < 20; i++) {
        if (SupabaseBootstrap.client.auth.currentSession != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    if (await SchoolAuthCloudService.instance.restoreFromFirebaseAuth()) {
      return true;
    }

    if (SupabaseBootstrap.isInitialized) {
      try {
        await SupabaseBootstrap.client.auth
            .refreshSession()
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
      if (await SchoolAuthCloudService.instance.restoreFromFirebaseAuth()) {
        return true;
      }
    }

    return restoreSavedLocalSession(
      username: savedUsername,
      schoolId: savedSchool,
    );
  }

  /// Keep the last dashboard user after a slow/failed cloud token refresh.
  Future<bool> restoreSavedLocalSession({
    String? username,
    String? schoolId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final user = (username ?? prefs.getString(_usernameKey) ?? '').trim();
    final school = (schoolId ?? prefs.getString(_schoolKey) ?? '').trim();
    if (user.isEmpty) return false;

    if (AuthService.findUser(user) == null) {
      final role = (prefs.getString(_roleKey) ?? '').trim();
      if (role.isEmpty) return false;
      AuthService.mergePersistedUser(
        RegisteredUser(
          username: user,
          password: '',
          roleKey: role,
          schoolId: school.isEmpty ? null : school,
          staffRoles: prefs.getStringList(_staffRolesKey) ?? const [],
        ),
      );
    }

    if (school.isNotEmpty &&
        SchoolRegistryService.instance.lookup(school) == null) {
      SchoolRegistryService.instance.upsertSchool(
        SchoolRecord(
          id: school.toUpperCase(),
          name: school.toUpperCase(),
          status: SchoolLifecycleStatus.active,
        ),
      );
    }

    return AuthService.restoreSession(
      user,
      schoolId: school.isEmpty ? null : school,
    );
  }

  Future<void> clearActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_schoolKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_staffRolesKey);
  }
}
