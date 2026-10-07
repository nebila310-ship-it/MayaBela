import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/cloud/user_prefs_sync_hook.dart';

class UserPreferencesService extends ChangeNotifier {
  UserPreferencesService._();
  static final instance = UserPreferencesService._();

  static const _compactKey = 'user_pref_compact_dashboard';
  static const _cardOrderKey = 'user_pref_card_order_v1';
  static const _holidaysKey = 'user_pref_ethiopian_holidays';
  static const _deviceCalKey = 'user_pref_sync_device_calendar';
  static const _soundsKey = 'user_pref_notification_sounds';
  static const _autoNotifKey = 'user_pref_auto_open_notifications';
  static const _hapticKey = 'user_pref_haptic_feedback';
  static const _darkModeKey = 'user_pref_dark_mode';
  static const _sidebarCollapsedKey = 'user_pref_classroom_sidebar_collapsed';

  final Map<String, List<String>> _cardOrder = {};
  bool compactDashboard = false;
  bool classroomSidebarCollapsed = false;
  bool showEthiopianHolidays = true;
  bool syncEventsToDeviceCalendar = true;
  bool notificationSounds = true;
  bool autoOpenNotifications = false;
  bool hapticFeedback = true;
  bool darkMode = false;

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    final prefs = await SharedPreferences.getInstance();
    compactDashboard = prefs.getBool(_compactKey) ?? false;
    showEthiopianHolidays = prefs.getBool(_holidaysKey) ?? true;
    syncEventsToDeviceCalendar = prefs.getBool(_deviceCalKey) ?? true;
    notificationSounds = prefs.getBool(_soundsKey) ?? true;
    autoOpenNotifications = prefs.getBool(_autoNotifKey) ?? false;
    hapticFeedback = prefs.getBool(_hapticKey) ?? true;
    darkMode = prefs.getBool(_darkModeKey) ?? false;
    classroomSidebarCollapsed = prefs.getBool(_sidebarCollapsedKey) ?? false;

    final raw = prefs.getString(_cardOrderKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _cardOrder.clear();
        for (final entry in decoded.entries) {
          final list = entry.value;
          if (list is List) {
            _cardOrder[entry.key] = list.map((e) => e.toString()).toList();
          }
        }
      } catch (_) {
        _cardOrder.clear();
      }
    }
  }

  Future<void> _persist({bool syncCloud = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_compactKey, compactDashboard);
    await prefs.setBool(_holidaysKey, showEthiopianHolidays);
    await prefs.setBool(_deviceCalKey, syncEventsToDeviceCalendar);
    await prefs.setBool(_soundsKey, notificationSounds);
    await prefs.setBool(_autoNotifKey, autoOpenNotifications);
    await prefs.setBool(_hapticKey, hapticFeedback);
    await prefs.setBool(_darkModeKey, darkMode);
    await prefs.setBool(_sidebarCollapsedKey, classroomSidebarCollapsed);
    await prefs.setString(_cardOrderKey, jsonEncode(_cardOrder));
    if (syncCloud) UserPrefsSyncHook.noteLocalChanged();
  }

  Map<String, dynamic> toCloudMap() => {
    'compactDashboard': compactDashboard,
    'classroomSidebarCollapsed': classroomSidebarCollapsed,
    'showEthiopianHolidays': showEthiopianHolidays,
    'syncEventsToDeviceCalendar': syncEventsToDeviceCalendar,
    'notificationSounds': notificationSounds,
    'autoOpenNotifications': autoOpenNotifications,
    'hapticFeedback': hapticFeedback,
    'darkMode': darkMode,
    'cardOrder': {
      for (final entry in _cardOrder.entries)
        entry.key: List<String>.from(entry.value),
    },
  };

  Future<void> applyFromCloud(Map<String, dynamic> data) async {
    compactDashboard = data['compactDashboard'] as bool? ?? compactDashboard;
    classroomSidebarCollapsed =
        data['classroomSidebarCollapsed'] as bool? ?? classroomSidebarCollapsed;
    showEthiopianHolidays =
        data['showEthiopianHolidays'] as bool? ?? showEthiopianHolidays;
    syncEventsToDeviceCalendar =
        data['syncEventsToDeviceCalendar'] as bool? ??
        syncEventsToDeviceCalendar;
    notificationSounds =
        data['notificationSounds'] as bool? ?? notificationSounds;
    autoOpenNotifications =
        data['autoOpenNotifications'] as bool? ?? autoOpenNotifications;
    hapticFeedback = data['hapticFeedback'] as bool? ?? hapticFeedback;
    darkMode = data['darkMode'] as bool? ?? darkMode;
    final order = data['cardOrder'];
    if (order is Map) {
      _cardOrder
        ..clear()
        ..addEntries(
          order.entries
              .where((e) => e.value is List)
              .map(
                (e) => MapEntry(
                  e.key.toString(),
                  (e.value as List).map((v) => v.toString()).toList(),
                ),
              ),
        );
    }
    notifyListeners();
    await _persist(syncCloud: false);
  }

  @visibleForTesting
  void resetForTests() {
    compactDashboard = false;
    classroomSidebarCollapsed = false;
    showEthiopianHolidays = true;
    syncEventsToDeviceCalendar = true;
    notificationSounds = true;
    autoOpenNotifications = false;
    hapticFeedback = true;
    darkMode = false;
    _cardOrder.clear();
    _loaded = false;
  }

  List<String> getOrder(String roleKey, List<String> defaultOrder) {
    final saved = _cardOrder[roleKey];
    if (saved == null || saved.isEmpty) return List.from(defaultOrder);
    final valid = saved.where(defaultOrder.contains).toList();
    for (final id in defaultOrder) {
      if (!valid.contains(id)) valid.add(id);
    }
    return valid;
  }

  void setOrder(String roleKey, List<String> order) {
    _cardOrder[roleKey] = List.from(order);
    notifyListeners();
    _persist();
  }

  void resetOrder(String roleKey, List<String> defaultOrder) {
    _cardOrder.remove(roleKey);
    notifyListeners();
    _persist();
  }

  void setCompactDashboard(bool value) {
    compactDashboard = value;
    notifyListeners();
    _persist();
  }

  void setShowEthiopianHolidays(bool value) {
    showEthiopianHolidays = value;
    notifyListeners();
    _persist();
  }

  void setSyncEventsToDeviceCalendar(bool value) {
    syncEventsToDeviceCalendar = value;
    notifyListeners();
    _persist();
  }

  void setNotificationSounds(bool value) {
    notificationSounds = value;
    notifyListeners();
    _persist();
  }

  void setAutoOpenNotifications(bool value) {
    autoOpenNotifications = value;
    notifyListeners();
    _persist();
  }

  void setHapticFeedback(bool value) {
    hapticFeedback = value;
    notifyListeners();
    _persist();
  }

  void setDarkMode(bool value) {
    darkMode = value;
    notifyListeners();
    _persist();
  }

  void setClassroomSidebarCollapsed(bool value) {
    classroomSidebarCollapsed = value;
    notifyListeners();
    _persist();
  }
}
