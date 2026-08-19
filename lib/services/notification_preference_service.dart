import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/notification_preference.dart';
import 'package:mayabela/services/auth_service.dart';

class NotificationPreferenceService extends ChangeNotifier {
  NotificationPreferenceService._();
  static final instance = NotificationPreferenceService._();

  static const _storageKey = 'notification_prefs_by_role';

  final Map<String, Map<String, bool>> _byRole = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  static List<NotificationPreferenceKey> keysForRole(String roleKey) {
    return switch (roleKey) {
      AuthService.roleParent => [
          NotificationPreferenceKey.master,
          NotificationPreferenceKey.homework,
          NotificationPreferenceKey.messages,
          NotificationPreferenceKey.transport,
          NotificationPreferenceKey.announcements,
          NotificationPreferenceKey.grades,
          NotificationPreferenceKey.attendance,
          NotificationPreferenceKey.gallery,
          NotificationPreferenceKey.dailyActivity,
          NotificationPreferenceKey.fees,
          NotificationPreferenceKey.calendar,
        ],
      AuthService.roleTeacher => [
          NotificationPreferenceKey.master,
          NotificationPreferenceKey.messages,
          NotificationPreferenceKey.announcements,
          NotificationPreferenceKey.grades,
          NotificationPreferenceKey.attendance,
          NotificationPreferenceKey.gallery,
          NotificationPreferenceKey.dailyActivity,
          NotificationPreferenceKey.calendar,
        ],
      AuthService.roleAdmin => [
          NotificationPreferenceKey.master,
          NotificationPreferenceKey.messages,
          NotificationPreferenceKey.announcements,
          NotificationPreferenceKey.attendance,
          NotificationPreferenceKey.fees,
          NotificationPreferenceKey.calendar,
        ],
      AuthService.roleDriver => [
          NotificationPreferenceKey.master,
          NotificationPreferenceKey.messages,
          NotificationPreferenceKey.announcements,
          NotificationPreferenceKey.calendar,
        ],
      _ => [
          NotificationPreferenceKey.master,
          NotificationPreferenceKey.messages,
        ],
    };
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _byRole.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final map = entry.value as Map<String, dynamic>;
          _byRole[entry.key] = {
            for (final item in map.entries) item.key: item.value as bool,
          };
        }
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_byRole));
  }

  bool isEnabled(String roleKey, NotificationPreferenceKey key) {
    if (key != NotificationPreferenceKey.master &&
        !isEnabled(roleKey, NotificationPreferenceKey.master)) {
      return false;
    }
    return _byRole[roleKey]?[key.name] ?? true;
  }

  Future<void> setEnabled(
    String roleKey,
    NotificationPreferenceKey key,
    bool value,
  ) async {
    _byRole.putIfAbsent(roleKey, () => {});
    _byRole[roleKey]![key.name] = value;
    await _persist();
    notifyListeners();
  }

  Future<void> enableAllForRole(String roleKey) async {
    _byRole.putIfAbsent(roleKey, () => {});
    for (final key in keysForRole(roleKey)) {
      _byRole[roleKey]![key.name] = true;
    }
    await _persist();
    notifyListeners();
  }
}
