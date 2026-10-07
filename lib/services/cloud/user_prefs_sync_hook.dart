import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Lets local pref stores notify cloud sync without importing DocumentStore.
abstract final class UserPrefsSyncHook {
  static const stampKey = 'user_cloud_prefs_local_updated_at';

  static DateTime? lastLocalChangeUtc;
  static void Function()? onLocalChanged;

  static void noteLocalChanged() {
    lastLocalChangeUtc = DateTime.now().toUtc();
    unawaited(_persistStamp());
    onLocalChanged?.call();
  }

  static Future<void> _persistStamp() async {
    final at = lastLocalChangeUtc;
    if (at == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(stampKey, at.toIso8601String());
    } catch (_) {}
  }
}
