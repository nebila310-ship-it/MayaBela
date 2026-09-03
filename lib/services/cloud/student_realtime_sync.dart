import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/cloud/session_cloud_sync.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/student_portal_sync_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';

/// Debounced live listeners for the signed-in student portal.
abstract final class StudentRealtimeSync {
  static final List<StreamSubscription<dynamic>> _subscriptions = [];
  static Timer? _debounce;
  static bool _active = false;
  static final _crud = DocumentStore();

  static void start() {
    if (!SupabaseBootstrap.isInitialized) return;
    if (AuthService.currentUser?.roleKey != AuthService.roleStudent) return;
    if (_active) return;
    _active = true;

    final collections = <String>[
      AppCollections.homework,
      AppCollections.learningMaterials,
      AppCollections.lessonPlans,
      AppCollections.curriculumUnits,
      AppCollections.curriculumFeedback,
      AppCollections.collegeGuidance,
      AppCollections.supportRequests,
      AppCollections.gradeReports,
      AppCollections.dailyActivities,
      AppCollections.announcements,
      AppCollections.calendarEvents,
      AppCollections.attendanceSessions,
      AppCollections.classTimetables,
      AppCollections.appNotifications,
      AppCollections.conversations,
      AppCollections.studentRegistry,
    ];

    for (final collection in collections) {
      _subscriptions.add(
        _crud.watchAll(collection).listen(_onCloudChange, onError: _logError),
      );
    }
  }

  static void stop() {
    _debounce?.cancel();
    _debounce = null;
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
    _active = false;
  }

  static void _onCloudChange(dynamic _) {
    _debounce?.cancel();
    final generation = AuthService.sessionGeneration;
    _debounce = Timer(const Duration(milliseconds: 900), () {
      if (!AuthService.isLiveGeneration(generation)) return;
      unawaited(_refreshStudentData());
    });
  }

  static Future<void> _refreshStudentData() async {
    final generation = AuthService.sessionGeneration;
    if (AuthService.currentUser?.roleKey != AuthService.roleStudent) return;
    try {
      await CloudAppStore.instance.pullForStudentSession();
      if (!AuthService.isLiveGeneration(generation)) return;
      await SessionCloudSync.applyStudentSessionLocally();
      if (!AuthService.isLiveGeneration(generation)) return;
      StudentPortalSyncService.instance.markDataChanged();
      SchoolContentSyncService.instance.markDataChanged();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('StudentRealtimeSync refresh failed: $error');
      }
    }
  }

  static void _logError(Object error) {
    if (kDebugMode) {
      debugPrint('StudentRealtimeSync: $error');
    }
  }
}
