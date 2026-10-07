import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/cloud/school_account_ids.dart';
import 'package:mayabela/services/cloud/user_prefs_sync_hook.dart';
import 'package:mayabela/services/notification_preference_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/web_erp/services/web_erp_prefs_service.dart';

/// Syncs this-device UI prefs to the signed-in user's cloud doc so a second
/// laptop matches after login. Never stores passwords, owner PIN, or tokens.
class UserCloudPreferences {
  UserCloudPreferences._({DocumentStore? crud})
    : _crud = crud ?? DocumentStore();

  static final instance = UserCloudPreferences._();

  static const pushDebounce = Duration(milliseconds: 800);

  static const secretKeys = {
    'password',
    'passwordHash',
    'pin',
    'pinHash',
    'jwt',
    'accessToken',
    'refreshToken',
    'rememberMePassword',
    'token',
    'platform_owner_pin_hash',
    'login_saved_entries',
    'entries',
  };

  final DocumentStore _crud;
  Timer? _pushTimer;
  var _started = false;
  var _applying = false;

  void ensureStarted() {
    if (_started) return;
    _started = true;
    UserPrefsSyncHook.onLocalChanged = _onLocalChanged;
  }

  void _onLocalChanged() {
    if (_applying) return;
    unawaited(_writeLocalStamp(DateTime.now().toUtc()));
    _schedulePush();
  }

  void _schedulePush() {
    if (AuthService.currentUser == null) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(pushDebounce, () {
      unawaited(pushToCloud());
    });
  }

  @visibleForTesting
  Map<String, dynamic> buildSnapshot() {
    final user = AuthService.currentUser;
    final schoolId = (AuthService.activeSchoolId ?? user?.schoolId ?? '')
        .trim()
        .toUpperCase();
    final stamp =
        UserPrefsSyncHook.lastLocalChangeUtc ?? DateTime.now().toUtc();
    return sanitize({
      'username': user?.username.trim().toLowerCase() ?? '',
      'schoolId': schoolId,
      'languageCode': AppLocale.instance.code,
      ...UserPreferencesService.instance.toCloudMap(),
      ...WebErpPrefsService.instance.toCloudMap(),
      'notificationPrefsByRole': NotificationPreferenceService.instance
          .toCloudMap(),
      'notificationReadIds': NotificationService.instance.cloudReadIds(),
      'updatedAt': stamp.toIso8601String(),
    });
  }

  @visibleForTesting
  static Map<String, dynamic> sanitize(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    for (final entry in raw.entries) {
      if (isSecretKey(entry.key)) continue;
      out[entry.key] = entry.value;
    }
    return out;
  }

  @visibleForTesting
  static bool isSecretKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return false;
    if (secretKeys.contains(k)) return true;
    final lower = k.toLowerCase();
    return lower.contains('password') ||
        lower.contains('pinhash') ||
        lower.contains('pin_hash') ||
        lower == 'jwt' ||
        lower.endsWith('token');
  }

  @visibleForTesting
  Future<void> applySnapshot(Map<String, dynamic> raw) async {
    final data = sanitize(raw);
    _applying = true;
    try {
      final language = '${data['languageCode'] ?? ''}'.trim();
      if (language.isNotEmpty) {
        AppLocale.instance.applyFromCloud(language);
      }
      await UserPreferencesService.instance.applyFromCloud(data);
      await WebErpPrefsService.instance.applyFromCloud(data);
      await NotificationPreferenceService.instance.applyFromCloud(
        data['notificationPrefsByRole'],
      );
      final reads = data['notificationReadIds'];
      if (reads is List) {
        await NotificationService.instance.applyCloudReadIds(
          reads.map((e) => '$e'),
        );
      }
    } finally {
      _applying = false;
    }
  }

  Future<void> pullFromCloud() async {
    ensureStarted();
    final user = AuthService.currentUser;
    if (user == null || !_crud.available) return;
    final schoolId = (AuthService.activeSchoolId ?? user.schoolId ?? '')
        .trim()
        .toUpperCase();
    if (schoolId.isEmpty) return;
    final docId = schoolAccountDocId(schoolId, user.username);
    Map<String, dynamic>? remote;
    try {
      remote = await _crud.readDoc(
        collection: AppCollections.userPreferences,
        docId: docId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserCloudPreferences pull: $e');
      }
      return;
    }
    if (remote == null) {
      await pushToCloud();
      return;
    }
    final cloudAt = DateTime.tryParse('${remote['updatedAt'] ?? ''}')?.toUtc();
    final localAt = await _readLocalStamp();
    if (localAt != null &&
        cloudAt != null &&
        localAt.isAfter(cloudAt.add(const Duration(seconds: 1)))) {
      await pushToCloud();
      return;
    }
    await applySnapshot(remote);
    if (cloudAt != null) await _writeLocalStamp(cloudAt);
  }

  Future<void> pushToCloud() async {
    ensureStarted();
    final user = AuthService.currentUser;
    if (user == null || !_crud.available) return;
    final schoolId = (AuthService.activeSchoolId ?? user.schoolId ?? '')
        .trim()
        .toUpperCase();
    if (schoolId.isEmpty) return;
    try {
      await _crud.createOrUpdate(
        collection: AppCollections.userPreferences,
        docId: schoolAccountDocId(schoolId, user.username),
        data: buildSnapshot(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserCloudPreferences push: $e');
      }
    }
  }

  Future<DateTime?> _readLocalStamp() async {
    DateTime? stored;
    try {
      final prefs = await SharedPreferences.getInstance();
      stored = DateTime.tryParse(
        prefs.getString(UserPrefsSyncHook.stampKey) ?? '',
      )?.toUtc();
    } catch (_) {}
    final hook = UserPrefsSyncHook.lastLocalChangeUtc;
    if (stored == null) return hook;
    if (hook == null) return stored;
    return hook.isAfter(stored) ? hook : stored;
  }

  Future<void> _writeLocalStamp(DateTime at) async {
    UserPrefsSyncHook.lastLocalChangeUtc = at.toUtc();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        UserPrefsSyncHook.stampKey,
        at.toUtc().toIso8601String(),
      );
    } catch (_) {}
  }

  @visibleForTesting
  void resetForTests() {
    _pushTimer?.cancel();
    _pushTimer = null;
    _started = false;
    _applying = false;
    UserPrefsSyncHook.onLocalChanged = null;
    UserPrefsSyncHook.lastLocalChangeUtc = null;
  }
}
