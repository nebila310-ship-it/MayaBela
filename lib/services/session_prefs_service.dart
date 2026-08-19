import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';

/// Persists the logged-in session so the app can restore it after a full close.
/// Prefers Firebase Auth custom-token session; local username is a fallback hint.
class SessionPrefsService {
  SessionPrefsService._();
  static final instance = SessionPrefsService._();

  static const _usernameKey = 'session_username';
  static const _schoolKey = 'session_school_id';

  Future<void> saveActiveSession() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, user.username);

    final school = AuthService.activeSchoolId;
    if (school != null && school.isNotEmpty) {
      await prefs.setString(_schoolKey, school);
    } else {
      await prefs.remove(_schoolKey);
    }
  }

  Future<bool> restoreActiveSession() async {
    await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);

    // Prefer a live Supabase school JWT (role + schoolId in app_metadata).
    if (await SchoolAuthCloudService.instance.restoreFromFirebaseAuth()) {
      return true;
    }

    // Soft recovery: refresh an expired token, then restore from claims.
    try {
      await SupabaseBootstrap.client.auth.refreshSession();
    } catch (_) {}
    if (await SchoolAuthCloudService.instance.restoreFromFirebaseAuth()) {
      return true;
    }

    // Do not restore a local-only UI session without cloud claims — that leaves
    // Admin "Online" while sync/staff create fail with "missing sub claim".
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_schoolKey);
    return false;
  }

  Future<void> clearActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_schoolKey);
  }
}
