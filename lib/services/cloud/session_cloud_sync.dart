import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/database/school_database_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud_bootstrap_service.dart';
import 'package:mayabela/services/cloud_sync_progress_service.dart';
import 'package:mayabela/services/device_cloud_sync_state.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/cloud_outbox_service.dart';
import 'package:mayabela/services/cloud/cloud_idle_sync.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/cloud/cloud_sync_flags.dart';
import 'package:mayabela/services/cloud/cloud_sync_router.dart';
import 'package:mayabela/services/cloud/realtime_messaging_bootstrap.dart';
import 'package:mayabela/services/cloud/role_cloud_live_sync.dart';
import 'package:mayabela/services/cloud/staff_content_realtime_sync.dart';
import 'package:mayabela/services/cloud/sync_cursor_store.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_portal_sync_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/staff_registry_notifier.dart';
import 'package:mayabela/utils/startup_profiler.dart';

/// Refreshes role-relevant cloud data on login and session restore.
abstract final class SessionCloudSync {
  static Duration get _cloudPullTimeout =>
      kIsWeb ? const Duration(seconds: 60) : const Duration(seconds: 30);
  static Duration get _adminCloudPullTimeout =>
      kIsWeb ? const Duration(seconds: 120) : const Duration(seconds: 45);

  static bool _isLive(int generation) => AuthService.isLiveGeneration(generation);

  /// Local apply + login pull/push, then start EDUABA 5s CloudSyncEngine.
  static Future<void> startSessionWithCloudSync() async {
    final generation = AuthService.sessionGeneration;
    if (!_isLive(generation)) return;
    RoleCloudLiveSync.stop();
    StaffContentRealtimeSync.deferLiveRefresh();
    try {
      await applyLocalForCurrentUser();
      if (!_isLive(generation)) return;
      if (!CloudSyncFlags.enabled) {
        CloudSyncProgressService.instance.reset();
        return;
      }
      // Drop sticky Queued state from previous failed auth sessions.
      await CloudOutboxService.instance.ensureLoaded();
      if (!_isLive(generation)) return;
      if (!await SchoolAuthCloudService.instance.ensureValidSchoolJwt()) {
        if (!_isLive(generation)) return;
        await CloudOutboxService.instance.clear();
        final progress = CloudSyncProgressService.instance;
        progress.begin(totalSteps: 1, message: 'Connecting to cloud…');
        progress.fail(
          'Cloud session missing — sign out and sign in again as Admin',
        );
        return;
      }
      if (!_isLive(generation)) return;
      // Keep cursors on the same school so the 5s engine does not treat
      // every sign-in as a first-time full download. School switch wipes.
      await SyncCursorStore.instance.ensureLoaded();
      if (!_isLive(generation)) return;
      await SyncCursorStore.instance.bindToSchool(AuthService.activeSchoolId);
      if (!_isLive(generation)) return;
      await syncRoleWithProgress();
      if (_isLive(generation) && CloudSyncProgressService.instance.isReady) {
        await SyncCursorStore.instance.markRoleBoot(
          CloudSyncEngine.collectionsForCurrentRole(),
        );
      }
    } finally {
      if (_isLive(generation)) {
        StaffContentRealtimeSync.markInitialSyncComplete();
        await RealtimeMessagingBootstrap.onSessionStarted();
        // Start the live loop even if JWT claims are still catching up after a
        // browser refresh — ticks no-op until school claims are present.
        if (_isLive(generation) &&
            CloudSyncFlags.enabled &&
            AuthService.currentUser != null) {
          CloudSyncEngine.start();
          CloudIdleSync.onEngineStarted();
        }
      }
    }
  }

  /// Live cycle — no-op while sync is disabled.
  static Future<void> runLiveIntegrationCycle() async {
    if (!CloudSyncFlags.enabled) return;
    await CloudSyncRouter.syncCycle(reason: 'live');
  }

  /// Pull login accounts from Firestore before validating credentials (new device).
  static Future<void> ensureCloudCredentialsForLogin() async {
    if (!DeviceCloudSyncState.shouldPullCredentialsBeforeLogin) return;
    CloudBootstrapService.resetIfRegistriesEmpty();
    try {
      await CloudBootstrapService.ensureLoginCredentialsFromCloud()
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SessionCloudSync] ensureCloudCredentialsForLogin: $e');
      }
    }
  }

  /// Fast path: local registry/enrollment only (no network).
  static Future<void> applyLocalForCurrentUser() async {
    final generation = AuthService.sessionGeneration;
    await StartupProfiler.track('session.applyLocal', () async {
      final user = AuthService.currentUser;
      if (user == null || !_isLive(generation)) return;

      switch (user.roleKey) {
        case AuthService.roleParent:
          await _applyParentSessionLocally();
        case AuthService.roleTeacher:
        case AuthService.roleAdmin:
          AuthService.alignTeacherSessionWithRegistry();
          if (user.roleKey == AuthService.roleAdmin) {
            AuthService.alignDriverSessionWithRegistry();
          }
          await _applyStaffSessionLocally(skipDatabaseSync: true);
        case AuthService.roleDriver:
          AuthService.alignDriverSessionWithRegistry();
          await _applyDriverSessionLocally(skipDatabaseSync: true);
        case AuthService.roleStudent:
          await applyStudentSessionLocally(skipDatabaseSync: true);
        default:
          break;
      }
    });
  }

  /// Background cloud refresh — disabled while [CloudSyncFlags.enabled] is false.
  static Future<void> pullCloudInBackground() async {
    if (!CloudSyncFlags.enabled) return;
    final generation = AuthService.sessionGeneration;
    final user = AuthService.currentUser;
    if (!_isLive(generation) || user == null || !SupabaseBootstrap.isInitialized) {
      return;
    }
    if (AuthService.isPublicDemoStudentSession) return;
    if (AuthService.isPublicDemoDriverSession) return;

    await StartupProfiler.track('session.pullCloud', () async {
      if (!_isLive(generation)) return;
      switch (user.roleKey) {
        case AuthService.roleParent:
          await _pullIfReady(
            ({bool trackProgress = false}) =>
                CloudAppStore.instance.pullForParentSession(),
          );
          if (!_isLive(generation)) return;
          await _applyParentSessionLocally();
          SchoolContentSyncService.instance.markDataChanged();
        case AuthService.roleTeacher:
          await _pullIfReady(
            ({bool trackProgress = false}) =>
                CloudAppStore.instance.pullForTeacherSession(),
          );
          if (!_isLive(generation)) return;
          AuthService.alignTeacherSessionWithRegistry();
          await _applyStaffSessionLocally();
          SchoolContentSyncService.instance.markDataChanged();
        case AuthService.roleAdmin:
          await _pullIfReady(
            ({bool trackProgress = false}) =>
                CloudAppStore.instance.pullForAdminSession(),
          );
          if (!_isLive(generation)) return;
          AuthService.alignTeacherSessionWithRegistry();
          AuthService.alignDriverSessionWithRegistry();
          await _applyStaffSessionLocally();
          SchoolContentSyncService.instance.markDataChanged();
        case AuthService.roleDriver:
          await _pullIfReady(
            ({bool trackProgress = false}) =>
                CloudAppStore.instance.pullForDriverSession(),
          );
          if (!_isLive(generation)) return;
          AuthService.alignDriverSessionWithRegistry();
          await _applyDriverSessionLocally();
        case AuthService.roleStudent:
          StudentPortalSyncService.instance.beginSync();
          try {
            await _pullIfReady(
              ({bool trackProgress = false}) =>
                  CloudAppStore.instance.pullForStudentSession(),
            );
            if (!_isLive(generation)) return;
            await applyStudentSessionLocally();
            StudentPortalSyncService.instance.completeSync();
            SchoolContentSyncService.instance.markDataChanged();
          } catch (_) {
            if (!_isLive(generation)) return;
            StudentPortalSyncService.instance.failSync(
              'Could not load school data. Some information may be outdated.',
            );
            await applyStudentSessionLocally();
          }
        default:
          break;
      }
    });
  }

  /// Applies local state then refreshes cloud data in the background.
  static Future<void> onSessionStarted() async {
    final generation = AuthService.sessionGeneration;
    if (!_isLive(generation)) return;
    await applyLocalForCurrentUser();
    if (!_isLive(generation)) return;
    unawaited(pullCloudInBackground());
  }

  static Future<void> onParentSessionStarted({bool trackProgress = false}) async {
    final generation = AuthService.sessionGeneration;
    if (!_isLive(generation)) return;
    if (trackProgress) CloudSyncProgressService.instance.step('Loading parent data…');
    await _pullIfReady(
      ({bool trackProgress = false}) =>
          CloudAppStore.instance.pullForParentSession(),
      trackProgress: trackProgress,
    );
    if (!_isLive(generation)) return;
    if (trackProgress) CloudSyncProgressService.instance.step('Applying data…');
    await _applyParentSessionLocally();
    SchoolContentSyncService.instance.markDataChanged();
  }

  static Future<void> onTeacherSessionStarted({bool trackProgress = false}) async {
    final generation = AuthService.sessionGeneration;
    if (!_isLive(generation)) return;
    if (trackProgress) CloudSyncProgressService.instance.step('Loading teacher data…');
    await _pullIfReady(
      ({bool trackProgress = false}) =>
          CloudAppStore.instance.pullForTeacherSession(),
      trackProgress: trackProgress,
    );
    if (!_isLive(generation)) return;
    if (trackProgress) CloudSyncProgressService.instance.step('Applying data…');
    AuthService.alignTeacherSessionWithRegistry();
    await _applyStaffSessionLocally();
    StaffRegistryNotifier.instance.notifyChanged();
    SchoolContentSyncService.instance.markDataChanged();
  }

  static Future<void> onAdminSessionStarted({bool trackProgress = false}) async {
    final generation = AuthService.sessionGeneration;
    if (!_isLive(generation)) return;
    await _pullIfReady(
      ({bool trackProgress = false}) =>
          CloudAppStore.instance.pullForAdminSession(
            trackProgress: trackProgress,
          ),
      trackProgress: trackProgress,
    );
    if (!_isLive(generation)) return;
    if (trackProgress) CloudSyncProgressService.instance.step('Applying data…');
    AuthService.alignTeacherSessionWithRegistry();
    AuthService.alignDriverSessionWithRegistry();
    await _applyStaffSessionLocally();
    await AuthService.persistRegistryLoginAccounts();
    StaffRegistryNotifier.instance.notifyChanged();
    SchoolContentSyncService.instance.markDataChanged();
  }

  static Future<void> onDriverSessionStarted({bool trackProgress = false}) async {
    final generation = AuthService.sessionGeneration;
    if (!_isLive(generation)) return;
    if (AuthService.isPublicDemoDriverSession) {
      AuthService.alignDriverSessionWithRegistry();
      await _applyDriverSessionLocally(skipDatabaseSync: true);
      return;
    }
    if (trackProgress) CloudSyncProgressService.instance.step('Loading driver data…');
    await _pullIfReady(
      ({bool trackProgress = false}) =>
          CloudAppStore.instance.pullForDriverSession(),
      trackProgress: trackProgress,
    );
    if (!_isLive(generation)) return;
    if (trackProgress) CloudSyncProgressService.instance.step('Applying data…');
    AuthService.alignDriverSessionWithRegistry();
    await _applyDriverSessionLocally();
  }

  static Future<void> onStudentSessionStarted({bool trackProgress = false}) async {
    final generation = AuthService.sessionGeneration;
    if (!_isLive(generation)) return;
    if (AuthService.isPublicDemoStudentSession) {
      StudentPortalSyncService.instance.beginSync();
      await applyStudentSessionLocally(skipDatabaseSync: true);
      StudentPortalSyncService.instance.completeSync();
      SchoolContentSyncService.instance.markDataChanged();
      return;
    }
    StudentPortalSyncService.instance.beginSync();
    try {
      if (trackProgress) {
        CloudSyncProgressService.instance.step('Loading student data…');
      }
      await _pullIfReady(
        ({bool trackProgress = false}) =>
            CloudAppStore.instance.pullForStudentSession(),
        trackProgress: trackProgress,
      );
      if (!_isLive(generation)) return;
      if (trackProgress) CloudSyncProgressService.instance.step('Applying data…');
      await applyStudentSessionLocally();
      StudentPortalSyncService.instance.completeSync();
      SchoolContentSyncService.instance.markDataChanged();
    } catch (_) {
      if (!_isLive(generation)) return;
      StudentPortalSyncService.instance.failSync(
        'Could not load school data. Some information may be outdated.',
      );
      await applyStudentSessionLocally();
      if (trackProgress) {
        CloudSyncProgressService.instance.fail('Could not load all school data');
      }
    }
  }

  /// Full role-specific cloud refresh — blocks until complete.
  static Future<void> awaitRoleCloudSync({bool trackProgress = false}) async {
    final generation = AuthService.sessionGeneration;
    if (!_isLive(generation)) return;
    final role = AuthService.currentUser?.roleKey;
    switch (role) {
      case AuthService.roleAdmin:
        await onAdminSessionStarted(trackProgress: trackProgress);
      case AuthService.roleTeacher:
        await onTeacherSessionStarted(trackProgress: trackProgress);
      case AuthService.roleParent:
        await onParentSessionStarted(trackProgress: trackProgress);
      case AuthService.roleDriver:
        await onDriverSessionStarted(trackProgress: trackProgress);
      case AuthService.roleStudent:
        await onStudentSessionStarted(trackProgress: trackProgress);
      default:
        await pullCloudInBackground();
    }
  }

  /// Sync with bottom progress bar (mobile + web).
  static Future<void> syncRoleWithProgress() async {
    final generation = AuthService.sessionGeneration;
    if (!CloudSyncFlags.enabled) {
      if (_isLive(generation)) {
        CloudSyncProgressService.instance.reset();
      }
      return;
    }
    if (!_isLive(generation)) return;

    final progress = CloudSyncProgressService.instance;
    if (progress.isLoading) return;

    CloudBootstrapService.resetIfRegistriesEmpty();

    if (!SupabaseBootstrap.isInitialized) {
      await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: false);
    }
    if (!_isLive(generation)) return;
    if (!SupabaseBootstrap.isInitialized) {
      progress.begin(totalSteps: 1, message: 'Connecting to cloud…');
      progress.fail('Cloud is not configured for this app build');
      return;
    }

    final role = AuthService.currentUser?.roleKey;
    final totalSteps = _progressStepsForCurrentRole();
    progress.begin(totalSteps: totalSteps, message: 'Connecting to cloud…');
    progress.step('Signing in to cloud…');

    if (!await SchoolAuthCloudService.instance.ensureValidSchoolJwt()) {
      if (_isLive(generation)) {
        progress.fail(_authFailureMessage());
      }
      return;
    }
    if (!_isLive(generation)) return;

    // Download cloud first so this browser sees other devices' data.
    // Uploading full local state before pull was overwriting shared IDs.
    try {
      if (role == AuthService.roleAdmin) {
        await _syncAdminWithProgress();
        return;
      }
      await awaitRoleCloudSync(trackProgress: true);
      if (!_isLive(generation)) return;
      // Then upload school directories (clear router route) before Ready.
      progress.step('Uploading to cloud…');
      try {
        await CloudSyncRouter.publishActiveSchoolDirectories().timeout(
          _cloudPullTimeout,
        );
        if (!_isLive(generation)) return;
        await CloudAppStore.instance.uploadLocalLeftoversToCloud().timeout(
          _cloudPullTimeout,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SessionCloudSync] post-pull upload failed: $e');
        }
      }
      if (!_isLive(generation)) return;
      if (progress.isLoading) {
        await CloudOutboxService.instance.clear();
        progress.complete(message: 'Ready');
      }
    } catch (e) {
      if (!_isLive(generation)) return;
      if (kDebugMode) {
        debugPrint('[SessionCloudSync] syncRoleWithProgress failed: $e');
      }
      if (progress.isLoading) {
        progress.fail(_friendlySyncError(e));
      }
    }
  }

  static Future<void> _syncAdminWithProgress() async {
    final generation = AuthService.sessionGeneration;
    final progress = CloudSyncProgressService.instance;
    try {
      CloudBootstrapService.resetIfRegistriesEmpty();

      progress.step('Downloading from cloud…');
      await CloudAppStore.instance
          .pullForAdminSession()
          .timeout(_adminCloudPullTimeout);
      if (!_isLive(generation)) return;

      progress.step('Uploading to cloud…');
      try {
        await CloudSyncRouter.publishActiveSchoolDirectories()
            .timeout(_adminCloudPullTimeout);
        if (!_isLive(generation)) return;
        await CloudAppStore.instance
            .uploadLocalLeftoversToCloud()
            .timeout(_adminCloudPullTimeout);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SessionCloudSync] admin leftover upload failed: $e');
        }
      }
      if (!_isLive(generation)) return;

      progress.step('Applying data…');
      AuthService.alignTeacherSessionWithRegistry();
      AuthService.alignDriverSessionWithRegistry();
      await _applyStaffSessionLocally();
      if (!_isLive(generation)) return;
      await AuthService.persistRegistryLoginAccounts();
      if (!_isLive(generation)) return;
      StaffRegistryNotifier.instance.notifyChanged();
      SchoolContentSyncService.instance.markDataChanged();
      await CloudOutboxService.instance.clear();
      progress.complete(message: 'Ready');
    } catch (e) {
      if (!_isLive(generation)) return;
      if (kDebugMode) {
        debugPrint('[SessionCloudSync] admin sync failed: $e');
      }
      if (progress.isLoading) {
        progress.fail(_friendlySyncError(e));
      }
    }
  }

  static String _authFailureMessage() {
    final detail = SupabaseBootstrap.lastAuthError;
    if (detail != null &&
        detail.toLowerCase().contains('missing school role')) {
      return 'Cloud session incomplete — sign out and sign in again';
    }
    if (detail != null && detail.toLowerCase().contains('sign in required')) {
      return 'Cloud sign-in required — use school login (not local-only)';
    }
    if (detail != null && detail.isNotEmpty) {
      return 'Cloud sign-in required — sign in again to sync';
    }
    return 'Cloud sign-in failed — check Supabase Auth / school-login';
  }

  static String _friendlySyncError(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('permission') ||
        text.contains('row-level security') ||
        text.contains('42501') ||
        text.contains('jwt')) {
      return 'Cloud access denied — school login session missing or expired';
    }
    if (text.contains('network') ||
        text.contains('unavailable') ||
        text.contains('failed host lookup') ||
        text.contains('timeout') ||
        text.contains('timed out')) {
      return 'Network/timeout — check internet and try again';
    }
    if (text.contains('anonymous') || text.contains('auth')) {
      return _authFailureMessage();
    }
    return 'Sync failed — sign out, sign in again, then retry';
  }

  static int _progressStepsForCurrentRole() {
    return switch (AuthService.currentUser?.roleKey) {
      AuthService.roleAdmin => 5,
      AuthService.roleTeacher => 4,
      AuthService.roleParent => 4,
      AuthService.roleDriver => 4,
      AuthService.roleStudent => 4,
      _ => 3,
    };
  }

  static Future<bool> _pullIfReady(
    Future<void> Function({bool trackProgress}) pull, {
    bool trackProgress = false,
  }) async {
    final generation = AuthService.sessionGeneration;
    if (!_isLive(generation)) return false;
    if (!SupabaseBootstrap.isInitialized) return false;
    if (!await SupabaseBootstrap.ensureAnonymousAuthReady()) {
      if (trackProgress && _isLive(generation)) {
        CloudSyncProgressService.instance.fail(_authFailureMessage());
      }
      return false;
    }
    if (!_isLive(generation)) return false;
    final role = AuthService.currentUser?.roleKey;
    final timeout = role == AuthService.roleAdmin
        ? _adminCloudPullTimeout
        : _cloudPullTimeout;
    try {
      await pull(trackProgress: trackProgress).timeout(timeout);
      return _isLive(generation);
    } catch (e) {
      if (!_isLive(generation)) return false;
      if (kDebugMode) {
        debugPrint('[SessionCloudSync] cloud pull timed out/failed: $e');
      }
      if (trackProgress) {
        final progress = CloudSyncProgressService.instance;
        if (progress.displayPercent >= 35) {
          progress.completePartial(message: 'Ready');
          unawaited(_retryPullIfLive(generation, pull));
          return true;
        }
        progress.fail(_friendlySyncError(e));
      } else {
        unawaited(_retryPullIfLive(generation, pull));
      }
      return false;
    }
  }

  static Future<void> _retryPullIfLive(
    int generation,
    Future<void> Function({bool trackProgress}) pull,
  ) async {
    if (!_isLive(generation)) return;
    await pull(trackProgress: false);
  }

  static Future<void> _applyParentSessionLocally() async {
    final user = AuthService.currentUser;
    if (user == null || user.roleKey != AuthService.roleParent) return;

    EnrollmentService.instance.ensureSeeded();
    final approved =
        EnrollmentService.instance.approvedStudentIdsForParent(user.username);
    if (approved.isNotEmpty) {
      AuthService.updateParentLinks(user.username, approved);
    }

    if (SchoolDatabaseService.instance.isInitialized) {
      try {
        await SchoolDatabaseService.instance
            .syncParentEnrollmentForUser(user.username)
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    for (final studentId in approved) {
      SchoolDataService.instance.syncChildFromRegistry(studentId);
    }
    SchoolDataService.instance.syncEnrollmentFromRegistry(
      schoolId: user.schoolId ?? AuthService.activeSchoolId,
    );
  }

  static Future<void> _applyStaffSessionLocally({
    bool skipDatabaseSync = false,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final schoolId = user.schoolId ?? AuthService.activeSchoolId;

    if (!skipDatabaseSync && SchoolDatabaseService.instance.isInitialized) {
      try {
        await SchoolDatabaseService.instance
            .syncFromRegistries()
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    SchoolDataService.instance.syncEnrollmentFromRegistry(schoolId: schoolId);
  }

  static Future<void> _applyDriverSessionLocally({
    bool skipDatabaseSync = false,
  }) async {
    final user = AuthService.currentUser;
    if (user == null || user.roleKey != AuthService.roleDriver) return;

    if (!skipDatabaseSync && SchoolDatabaseService.instance.isInitialized) {
      try {
        await SchoolDatabaseService.instance
            .syncFromRegistries()
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    final driverId = AuthService.resolvedLinkedDriverId;
    if (driverId != null) {
      for (final student in StudentRegistryService.instance.getAllStudents()) {
        if (!student.transportEnabled) continue;
        if (!DriverRegistryService.instance
            .transportReferenceMatchesDriver(student.transportId, driverId)) {
          continue;
        }
        SchoolDataService.instance.syncChildFromRegistry(student.studentId);
      }
    }
  }

  static Future<void> applyStudentSessionLocally({
    bool skipDatabaseSync = false,
  }) async {
    final user = AuthService.currentUser;
    if (user == null || user.roleKey != AuthService.roleStudent) return;

    final studentId = user.linkedStudentId?.trim().toUpperCase();
    if (studentId != null && studentId.isNotEmpty) {
      SchoolDataService.instance.syncChildFromRegistry(studentId);
    }

    if (!skipDatabaseSync && SchoolDatabaseService.instance.isInitialized) {
      try {
        await SchoolDatabaseService.instance
            .syncFromRegistries()
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    SchoolDataService.instance.syncEnrollmentFromRegistry(
      schoolId: user.schoolId ?? AuthService.activeSchoolId,
    );
  }
}
