import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/school_content_sync_service.dart';

/// Live listeners for time-sensitive staff queues only.
///
/// Homework, grades, LIA desks, and the rest ride the 5s/30s poll. Watching
/// ~40 `app_documents` collections and then downloading the whole school on
/// any change is what melted the free-plan PostgREST CPU.
abstract final class StaffContentRealtimeSync {
  static final List<StreamSubscription<dynamic>> _subscriptions = [];
  static Timer? _debounce;
  static bool _active = false;
  static bool _deferRefresh = true;
  static final _crud = DocumentStore();

  static void deferLiveRefresh() => _deferRefresh = true;

  static void markInitialSyncComplete() => _deferRefresh = false;

  static const _staffRoles = {
    AuthService.roleTeacher,
    AuthService.roleAdmin,
    AuthService.roleParent,
  };

  /// Parent-link approvals need to land while a teacher is on the queue.
  /// Messages, notifications, and GPS have their own listeners.
  static const _liveCollections = [
    AppCollections.parentLinkRequests,
  ];

  @visibleForTesting
  static List<String> get watchedCollections =>
      List<String>.unmodifiable(_liveCollections);

  static void start() {
    if (!SupabaseBootstrap.isInitialized) return;
    final role = AuthService.currentUser?.roleKey;
    if (role == null || !_staffRoles.contains(role)) return;
    if (_active) return;
    _active = true;

    for (final collection in _liveCollections) {
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
  }

  static void _onCloudChange(dynamic _) {
    if (_deferRefresh) return;
    _debounce?.cancel();
    final generation = AuthService.sessionGeneration;
    _debounce = Timer(const Duration(milliseconds: 900), () {
      if (!AuthService.isLiveGeneration(generation)) return;
      unawaited(_refreshLiveQueue());
    });
  }

  static Future<void> _refreshLiveQueue() async {
    final generation = AuthService.sessionGeneration;
    final role = AuthService.currentUser?.roleKey;
    if (role == null || !_staffRoles.contains(role)) return;
    try {
      await CloudAppStore.instance.pullMappedCollections(_liveCollections);
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
