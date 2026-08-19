import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/cloud/app_data_maps.dart';
import 'package:mayabela/models/transport_passenger.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_live_location_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/transport_service.dart';

/// Live listeners for transport state, bus GPS, and notifications.
abstract final class TransportRealtimeSync {
  static StreamSubscription<List<Map<String, dynamic>>>? _statusSub;
  static StreamSubscription<List<Map<String, dynamic>>>? _busSub;
  static StreamSubscription<List<Map<String, dynamic>>>? _notificationSub;
  static StreamSubscription<List<Map<String, dynamic>>>? _scanSub;
  static final _crud = DocumentStore();

  static void start() {
    if (!SupabaseBootstrap.isInitialized) return;
    stop();

    _statusSub = _crud
        .watchAll(AppCollections.transportPassengerStatus)
        .listen(_onPassengerStatus, onError: _logError);

    _busSub = _crud
        .watchAll(AppCollections.busLivePositions)
        .listen(_onBusPositions, onError: _logError);

    _notificationSub = _crud
        .watchAll(AppCollections.appNotifications)
        .listen(_onNotifications, onError: _logError);

    _scanSub = _crud
        .watchAll(AppCollections.transportScans)
        .listen(_onTransportScans, onError: _logError);
  }

  static void stop() {
    unawaited(_statusSub?.cancel());
    unawaited(_busSub?.cancel());
    unawaited(_notificationSub?.cancel());
    unawaited(_scanSub?.cancel());
    _statusSub = null;
    _busSub = null;
    _notificationSub = null;
    _scanSub = null;
  }

  static void _onPassengerStatus(List<Map<String, dynamic>> docs) {
    for (final map in docs) {
      try {
        final studentId =
            (map['studentId'] as String? ?? '${map['_docId']}').toUpperCase();
        final status = AppDataMaps.transportPassengerStatusFromName(
          map['status'] as String?,
        );
        TransportService.instance.applyCloudPassengerStatus(studentId, status);
      } catch (_) {}
    }
  }

  static void _onBusPositions(List<Map<String, dynamic>> docs) {
    for (final map in docs) {
      try {
        BusLiveLocationService.instance.applyCloudPosition(
          AppDataMaps.busPositionFromMap(map),
        );
      } catch (_) {}
    }
  }

  static void _onNotifications(List<Map<String, dynamic>> docs) {
    if (AuthService.currentUser?.roleKey == null) return;

    final parsed = <AppNotification>[];
    for (final map in docs) {
      try {
        parsed.add(AppDataMaps.appNotificationFromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      NotificationService.instance.applyCloudNotifications(parsed);
    }
  }

  static void _onTransportScans(List<Map<String, dynamic>> docs) {
    final parsed = <TransportScanRecord>[];
    for (final map in docs) {
      try {
        parsed.add(AppDataMaps.transportScanFromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      TransportService.instance.applyCloudScanHistory(parsed);
    }
  }

  static void _logError(Object error) {
    if (kDebugMode) {
      debugPrint('TransportRealtimeSync: $error');
    }
  }
}
