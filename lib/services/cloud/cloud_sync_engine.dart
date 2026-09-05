import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_flags.dart';
import 'package:mayabela/services/cloud/sync_cursor_store.dart';
import 'package:mayabela/services/cloud_sync_progress_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/cloud_outbox_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';

/// EDUABA mandatory background sync — every 5 seconds while authenticated.
///
/// Tick order (source of truth):
/// 1) flush outbox mutations
/// 2) pull delta by sync_cursor + role scope
/// 3) apply to local store
/// 4) emit reactive UI updates
/// 5) advance sync_cursor
///
/// See docs/EDUABA_ERP_INSTRUCTIONS.md §5.
abstract final class CloudSyncEngine {
  static const Duration interval = Duration(seconds: 5);

  static Timer? _timer;
  static var _started = false;
  static var _paused = false;
  static var _tickRunning = false;
  static var _tickIndex = 0;
  static var _consecutiveFailures = 0;
  static DateTime? _backoffUntil;
  static int? _engineGeneration;

  /// How often the standard lane is probed (every Nth 5s tick).
  static const standardTickEvery = 6;

  /// How often bus GPS is polled as a realtime backup (every Nth 5s tick ≈ 10s).
  /// Does not restore the old school-wide stream fan-out — only these collections.
  static const transportBackupTickEvery = 2;

  /// Already applied by dedicated realtime listeners — skip on fast ticks
  /// so a moving bus cannot trigger school-wide SELECTs.
  static const liveRealtimeCollections = <String>{
    AppCollections.conversations,
    AppCollections.appNotifications,
    AppCollections.busLivePositions,
    AppCollections.transportPassengerStatus,
    AppCollections.transportScans,
  };

  /// GPS / boarding backup when realtime drops a change. Passenger status
  /// and scans are included only if the current role pack already has them.
  static const transportBackupCollections = <String>[
    AppCollections.busLivePositions,
    AppCollections.transportPassengerStatus,
    AppCollections.transportScans,
  ];

  static bool get isStarted => _started;

  static bool get isPaused => _paused;

  static bool _engineIsLive(int generation) =>
      _started &&
      _engineGeneration == generation &&
      AuthService.isLiveGeneration(generation);

  /// Call after login / session restore when cloud claims exist.
  static void start() {
    if (!CloudSyncFlags.enabled) return;
    if (AuthService.currentUser == null) return;
    if (!SupabaseBootstrap.isInitialized) return;
    final generation = AuthService.sessionGeneration;
    stop();
    _paused = false;
    _started = true;
    _engineGeneration = generation;
    _consecutiveFailures = 0;
    _backoffUntil = null;
    _tickIndex = 0;
    _timer = Timer.periodic(interval, (_) {
      if (!_engineIsLive(generation)) return;
      unawaited(tick(reason: 'periodic'));
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (!_engineIsLive(generation)) return;
        unawaited(tick(reason: 'start'));
      }),
    );
    if (kDebugMode) {
      debugPrint(
        '[CloudSyncEngine] started role=${AuthService.currentUser?.roleKey}',
      );
    }
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
    _paused = false;
    _tickRunning = false;
    _engineGeneration = null;
  }

  static void pause() => _paused = true;

  static void resume() {
    _paused = false;
    if (!_started) return;
    unawaited(tick(reason: 'resume'));
  }

  static Future<void> tick({String reason = 'manual'}) async {
    if (!_started || _paused || _tickRunning) return;
    if (!CloudSyncFlags.enabled) return;
    final generation = _engineGeneration ?? AuthService.sessionGeneration;
    if (!_engineIsLive(generation)) {
      stop();
      return;
    }
    if (CloudSyncProgressService.instance.isLoading) {
      if (!CloudSyncProgressService.instance.isLoadingStale) return;
      CloudSyncProgressService.instance.completePartial(
        message: 'Ready',
      );
    }
    if (_backoffUntil != null && DateTime.now().isBefore(_backoffUntil!)) {
      return;
    }
    if (!SupabaseBootstrap.isInitialized) return;
    if (!await SchoolAuthCloudService.hasSchoolClaims()) {
      if (!_engineIsLive(generation)) return;
      if (!await SchoolAuthCloudService.instance.ensureValidSchoolJwt()) {
        return;
      }
    }
    if (!_engineIsLive(generation)) return;

    _tickRunning = true;
    try {
      await SyncCursorStore.instance.ensureLoaded();
      if (!_engineIsLive(generation)) return;
      await CloudOutboxService.instance.ensureLoaded();
      if (!_engineIsLive(generation)) return;

      // 1) Flush local mutations (write-behind).
      await CloudAppStore.instance.flushOutboxForSyncEngine();
      if (!_engineIsLive(generation)) return;

      // 2–5) Delta pull, apply only the collections that actually changed.
      _tickIndex++;
      final changed = await CloudAppStore.instance.pullRoleDeltaForSyncEngine(
        collections: probeCollectionsForTick(_tickIndex),
      );
      if (!_engineIsLive(generation)) return;
      if (changed) {
        SchoolContentSyncService.instance.markDataChanged();
      }

      _consecutiveFailures = 0;
      _backoffUntil = null;
      if (kDebugMode && reason != 'periodic') {
        debugPrint('[CloudSyncEngine] tick ok ($reason) changed=$changed');
      }
    } catch (e) {
      if (!_engineIsLive(generation)) return;
      _consecutiveFailures++;
      final seconds = (1 << _consecutiveFailures.clamp(0, 5)).clamp(5, 60);
      _backoffUntil = DateTime.now().add(Duration(seconds: seconds));
      if (kDebugMode) {
        debugPrint(
          '[CloudSyncEngine] tick failed ($reason): $e — backoff ${seconds}s',
        );
      }
    } finally {
      if (_engineGeneration == generation) {
        _tickRunning = false;
      }
    }
  }

  /// High-frequency collections (priority lane).
  static const highPriority = <String>[
    AppCollections.conversations,
    AppCollections.appNotifications,
    AppCollections.attendanceSessions,
    AppCollections.gradeReports,
    AppCollections.busLivePositions,
    AppCollections.parentLinkRequests,
    AppCollections.studentRegistry,
    AppCollections.teacherRegistry,
  ];

  /// Standard lane.
  static const standardPriority = <String>[
    AppCollections.homework,
    AppCollections.dailyActivities,
    AppCollections.announcements,
    AppCollections.learningMaterials,
    AppCollections.calendarEvents,
    AppCollections.galleryPosts,
    AppCollections.classTimetables,
    AppCollections.fees,
    AppCollections.buses,
    AppCollections.disciplineCases,
    AppCollections.leaveRequests,
    AppCollections.qaFindings,
    AppCollections.admissionApplications,
    AppCollections.examQuestions,
    AppCollections.examPapers,
    AppCollections.examAttempts,
    AppCollections.lessonPlans,
    AppCollections.curriculumUnits,
    AppCollections.curriculumFeedback,
    AppCollections.lessonPlanReviews,
    AppCollections.teacherEvaluations,
    AppCollections.academicMeetings,
    AppCollections.healthRecords,
    AppCollections.counselingRecords,
    AppCollections.iepPlans,
    AppCollections.collegeGuidance,
    AppCollections.supportRequests,
    AppCollections.safeguardingCases,
    AppCollections.extracurricularClubs,
    AppCollections.clubMemberships,
    AppCollections.scholarships,
    AppCollections.grievances,
    AppCollections.internships,
    AppCollections.dosaMeetings,
    AppCollections.teachingObservations,
    AppCollections.academicAudits,
    AppCollections.qaSurveys,
    AppCollections.qaSurveyResponses,
    AppCollections.actionResearch,
    AppCollections.mfaEnrollments,
    AppCollections.privacyConsents,
    AppCollections.dataRightsRequests,
    AppCollections.schoolBackups,
    AppCollections.ictDevices,
    AppCollections.ictWeeklyReviews,
    AppCollections.inventoryItems,
    AppCollections.classroomInventory,
    AppCollections.purchaseRequests,
    AppCollections.materialPurchaseRequests,
  ];

  /// Fast ticks probe the high-priority lane minus live GPS/messages.
  /// Every [transportBackupTickEvery] ticks also re-probe bus GPS (and any
  /// other transport collections in the role pack) so a dropped realtime
  /// event cannot leave the map stale for a full 30s.
  /// Every [standardTickEvery] ticks also probe the rest of the role pack
  /// (including a live-collection backup if realtime dropped a change).
  @visibleForTesting
  static List<String> probeCollectionsForTick(int tickIndex) {
    final role = collectionsForCurrentRole();
    if (tickIndex <= 0 || tickIndex % standardTickEvery == 0) {
      return role;
    }
    final roleSet = role.toSet();
    final fast = highPriority
        .where(roleSet.contains)
        .where((c) => !liveRealtimeCollections.contains(c))
        .toList();
    if (tickIndex % transportBackupTickEvery == 0) {
      for (final collection in transportBackupCollections) {
        if (roleSet.contains(collection) && !fast.contains(collection)) {
          fast.add(collection);
        }
      }
    }
    return fast;
  }

  static List<String> collectionsForCurrentRole() {
    final role = AuthService.currentUser?.roleKey;
    switch (role) {
      case AuthService.roleAdmin:
      case AuthService.roleTeacher:
        return [...highPriority, ...standardPriority];
      case AuthService.roleParent:
        return [
          AppCollections.parentLinkRequests,
          AppCollections.studentRegistry,
          AppCollections.gradeReports,
          AppCollections.attendanceSessions,
          AppCollections.homework,
          AppCollections.announcements,
          AppCollections.dailyActivities,
          AppCollections.conversations,
          AppCollections.appNotifications,
          AppCollections.busLivePositions,
          AppCollections.transportPassengerStatus,
          AppCollections.transportScans,
          AppCollections.fees,
          AppCollections.learningMaterials,
          AppCollections.galleryPosts,
          AppCollections.calendarEvents,
          AppCollections.classTimetables,
          AppCollections.disciplineCases,
          AppCollections.leaveRequests,
          AppCollections.lessonPlans,
          AppCollections.curriculumUnits,
          AppCollections.curriculumFeedback,
          AppCollections.healthRecords,
          AppCollections.counselingRecords,
          AppCollections.iepPlans,
          AppCollections.collegeGuidance,
          AppCollections.supportRequests,
          AppCollections.extracurricularClubs,
          AppCollections.clubMemberships,
          AppCollections.scholarships,
          AppCollections.grievances,
          AppCollections.internships,
          AppCollections.dosaMeetings,
          AppCollections.qaSurveys,
          AppCollections.qaSurveyResponses,
          AppCollections.privacyConsents,
          AppCollections.dataRightsRequests,
          AppCollections.mfaEnrollments,
        ];
      case AuthService.roleDriver:
        return [
          AppCollections.studentRegistry,
          AppCollections.buses,
          AppCollections.busLivePositions,
          AppCollections.transportPassengerStatus,
          AppCollections.transportScans,
          AppCollections.conversations,
          AppCollections.appNotifications,
        ];
      case AuthService.roleStudent:
        return [
          AppCollections.gradeReports,
          AppCollections.attendanceSessions,
          AppCollections.homework,
          AppCollections.learningMaterials,
          AppCollections.announcements,
          AppCollections.dailyActivities,
          AppCollections.conversations,
          AppCollections.appNotifications,
          AppCollections.calendarEvents,
          AppCollections.classTimetables,
          AppCollections.galleryPosts,
          AppCollections.examQuestions,
          AppCollections.examPapers,
          AppCollections.examAttempts,
          AppCollections.lessonPlans,
          AppCollections.curriculumUnits,
          AppCollections.curriculumFeedback,
          AppCollections.collegeGuidance,
          AppCollections.supportRequests,
          AppCollections.extracurricularClubs,
          AppCollections.clubMemberships,
          AppCollections.scholarships,
          AppCollections.grievances,
          AppCollections.internships,
          AppCollections.dosaMeetings,
          AppCollections.qaSurveys,
          AppCollections.qaSurveyResponses,
          AppCollections.privacyConsents,
          AppCollections.dataRightsRequests,
          AppCollections.mfaEnrollments,
        ];
      default:
        return highPriority;
    }
  }
}
