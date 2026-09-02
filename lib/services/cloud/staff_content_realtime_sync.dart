import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/cloud/role_sync_coordinator.dart';
import 'package:mayabela/services/school_content_sync_service.dart';

/// Live listeners for teacher, admin, and parent school content.
abstract final class StaffContentRealtimeSync {
  static final List<StreamSubscription<dynamic>> _subscriptions = [];
  static Timer? _debounce;
  static bool _active = false;
  static bool _deferRefresh = true;
  static bool _ignoreSubscribeSnapshot = true;
  static final _crud = DocumentStore();

  static void deferLiveRefresh() => _deferRefresh = true;

  static void markInitialSyncComplete() => _deferRefresh = false;

  static const _staffRoles = {
    AuthService.roleTeacher,
    AuthService.roleAdmin,
    AuthService.roleParent,
  };

  static void start() {
    if (!SupabaseBootstrap.isInitialized) return;
    final role = AuthService.currentUser?.roleKey;
    if (role == null || !_staffRoles.contains(role)) return;
    if (_active) return;
    _active = true;
    _ignoreSubscribeSnapshot = true;

    final collections = <String>[
      AppCollections.homework,
      AppCollections.learningMaterials,
      AppCollections.gradeReports,
      AppCollections.schoolRegistry,
      AppCollections.gradeAuditLog,
      AppCollections.classTimetables,
      AppCollections.appNotifications,
      AppCollections.announcements,
      AppCollections.calendarEvents,
      AppCollections.dailyActivities,
      AppCollections.attendanceSessions,
      AppCollections.conversations,
      AppCollections.parentLinkRequests,
      AppCollections.fees,
      AppCollections.galleryPosts,
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
    _deferRefresh = true;
    _ignoreSubscribeSnapshot = true;
  }

  static void _onCloudChange(dynamic _) {
    if (_deferRefresh) return;
    _debounce?.cancel();
    final generation = AuthService.sessionGeneration;
    _debounce = Timer(const Duration(milliseconds: 900), () {
      if (!AuthService.isLiveGeneration(generation)) return;
      if (_ignoreSubscribeSnapshot) {
        _ignoreSubscribeSnapshot = false;
        return;
      }
      unawaited(_refreshStaffData());
    });
  }

  static Future<void> _refreshStaffData() async {
    final generation = AuthService.sessionGeneration;
    final role = AuthService.currentUser?.roleKey;
    if (role == null || !_staffRoles.contains(role)) return;
    try {
      RoleSyncCoordinator.log(
        'realtime-triggered gen=$generation reason=realtime-staff '
        'role=$role',
      );
      await RoleSyncCoordinator.requestFullRolePull(
        reason: 'realtime-staff',
        generation: generation,
      );
      if (!AuthService.isLiveGeneration(generation)) return;
      SchoolContentSyncService.instance.markDataChanged();
      NotificationService.instance.refreshBadges();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('StaffContentRealtimeSync refresh failed: $error');
      }
    }
  }

  static void _logError(Object error) {
    if (kDebugMode) {
      debugPrint('StaffContentRealtimeSync: $error');
    }
  }
}
