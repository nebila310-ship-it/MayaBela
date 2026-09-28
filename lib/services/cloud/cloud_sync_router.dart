import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_idle_sync.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/cloud/cloud_sync_flags.dart';
import 'package:mayabela/services/cloud_sync_progress_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/cloud_outbox_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/staff_registry_notifier.dart';

/// EDUABA cloud sync routes.
///
/// - [publishNow] — user action: upload one record immediately
/// - [downloadForCurrentRole] — login: pull what the role needs
/// - [syncCycle] — delegates to [CloudSyncEngine] (5s delta reconciler)
abstract final class CloudSyncRouter {
  /// Ensure Supabase session has school claims (refresh once if needed).
  static Future<bool> ensureCloudSession() async {
    if (!CloudSyncFlags.enabled) return false;
    if (!SupabaseBootstrap.isInitialized) {
      await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: false);
    }
    if (!SupabaseBootstrap.isInitialized) return false;
    if (AuthService.currentUser == null) return false;
    return SchoolAuthCloudService.instance.ensureValidSchoolJwt();
  }

  /// ROUTE A — action write: push one registry row to cloud now.
  static Future<bool> publishNow({
    required String collection,
    required Map<String, dynamic> record,
    String? schoolId,
    String? docId,
  }) async {
    if (!CloudSyncFlags.enabled) return false;
    if (!await ensureCloudSession()) {
      final id = (docId ?? record['id'] ?? record['studentId'] ??
              record['teacherId'] ?? record['_docId'] ?? '')
          .toString()
          .trim();
      if (id.isNotEmpty) {
        await CloudOutboxService.instance.enqueue(
          collection: collection,
          docId: id,
          schoolId: schoolId,
          data: record,
          reason: 'publishNow: no cloud session',
        );
      } else {
        await CloudOutboxService.instance.markFullPushNeeded(
          reason: 'publishNow: no cloud session',
        );
      }
      return false;
    }
    final result = await SchoolAuthCloudService.instance.upsertRegistryRecord(
      collection: collection,
      record: record,
      schoolId: schoolId,
      docId: docId,
    );
    if (!result.ok) {
      final id = (docId ?? record['id'] ?? record['studentId'] ??
              record['teacherId'] ?? record['_docId'] ?? '')
          .toString()
          .trim();
      if (id.isNotEmpty) {
        await CloudOutboxService.instance.enqueue(
          collection: collection,
          docId: id,
          schoolId: schoolId,
          data: record,
          reason: 'publishNow failed: ${result.errorMessage ?? result.errorCode}',
        );
      } else {
        await CloudOutboxService.instance.markFullPushNeeded(
          reason: 'publishNow failed: ${result.errorMessage ?? result.errorCode}',
        );
      }
      if (kDebugMode) {
        debugPrint(
          '[CloudSyncRouter] publishNow failed '
          '${result.errorCode}: ${result.errorMessage}',
        );
      }
      return false;
    }
    return true;
  }

  /// ROUTE B — login download: pull role pack into local services.
  static Future<void> downloadForCurrentRole({bool trackProgress = false}) async {
    if (!CloudSyncFlags.enabled) return;
    if (!await ensureCloudSession()) {
      throw StateError(
        SupabaseBootstrap.lastAuthError ??
            'School cloud sign-in required. Sign in again to sync.',
      );
    }
    final role = AuthService.currentUser?.roleKey;
    switch (role) {
      case AuthService.roleAdmin:
        await CloudAppStore.instance.pullForAdminSession(
          trackProgress: trackProgress,
        );
      case AuthService.roleTeacher:
        await CloudAppStore.instance.pullForTeacherSession();
      case AuthService.roleParent:
        await CloudAppStore.instance.pullForParentSession();
      case AuthService.roleDriver:
        await CloudAppStore.instance.pullForDriverSession();
      case AuthService.roleStudent:
        await CloudAppStore.instance.pullForStudentSession();
      default:
        break;
    }
    StaffRegistryNotifier.instance.notifyChanged();
    SchoolContentSyncService.instance.markDataChanged();
  }

  /// Publish every student/teacher for the active school.
  static Future<void> publishActiveSchoolDirectories() async {
    if (!CloudSyncFlags.enabled) return;
    await CloudAppStore.instance.publishActiveSchoolDirectories();
  }

  /// Convenience for student enroll Save.
  static Future<bool> publishStudent(Map<String, dynamic> record) {
    return publishNow(
      collection: AppCollections.studentRegistry,
      record: record,
      schoolId: record['schoolId']?.toString(),
      docId: record['studentId']?.toString(),
    );
  }

  /// Live sync cycle — EDUABA CloudSyncEngine (delta + outbox).
  static Future<void> syncCycle({String reason = 'tick'}) async {
    if (!CloudSyncFlags.enabled) return;
    if (AuthService.currentUser == null) return;
    if (CloudSyncProgressService.instance.isLoading) return;
    if (!CloudSyncEngine.isStarted) {
      CloudSyncEngine.start();
      CloudIdleSync.onEngineStarted();
      return;
    }
    await CloudSyncEngine.tick(reason: reason);
  }
}
