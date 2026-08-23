import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
/// Live GPS position published by a driver's phone.
class BusLivePosition {
  const BusLivePosition({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.heading,
    this.speedMps,
  });

  final String driverId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? heading;
  final double? speedMps;

  static const _freshWindow = Duration(minutes: 2);

  bool get isFresh => DateTime.now().difference(timestamp) < _freshWindow;

  int get minutesAgo => DateTime.now().difference(timestamp).inMinutes;

  String get mapsUrl =>
      'https://www.google.com/maps?q=$latitude,$longitude';
}

enum BusGpsFreshness { live, stale, waiting }

/// GPS hub — publishes driver location to Firestore for cross-device parent tracking.
class BusLiveLocationService extends ChangeNotifier {  BusLiveLocationService._();
  static final instance = BusLiveLocationService._();

  final Map<String, BusLivePosition> _positions = {};
  StreamSubscription<Position>? _gpsSub;
  String? _sharingDriverId;
  LocationPermission? _lastPermission;

  String? get sharingDriverId => _sharingDriverId;
  bool get isSharing => _sharingDriverId != null;
  LocationPermission? get lastPermission => _lastPermission;

  BusLivePosition? positionFor(String driverId) {
    final id = driverId.trim().toUpperCase();
    return _positions[id];
  }

  BusGpsFreshness freshnessFor(String driverId) {
    final pos = positionFor(driverId);
    if (pos == null) return BusGpsFreshness.waiting;
    return pos.isFresh ? BusGpsFreshness.live : BusGpsFreshness.stale;
  }

  @visibleForTesting
  void clearPositions() {
    _positions.clear();
    notifyListeners();
  }

  void applyCloudPosition(BusLivePosition position) {
    final id = position.driverId.trim().toUpperCase();
    _positions[id] = position;
    notifyListeners();
  }

  void _publishPosition(BusLivePosition position) {
    if (!SupabaseBootstrap.isInitialized) return;
    unawaited(CloudAppStore.instance.pushBusPosition(position));
  }
  bool isDriverSharing(String driverId) {
    final id = driverId.trim().toUpperCase();
    return _sharingDriverId?.toUpperCase() == id;
  }

  Future<LocationPermission> ensurePermission() async {
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _lastPermission = LocationPermission.denied;
      notifyListeners();
      return _lastPermission!;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    _lastPermission = permission;
    notifyListeners();
    return permission;
  }

  /// Driver: stream phone GPS and publish under [driverId].
  Future<bool> startSharing(String driverId) async {
    final id = driverId.trim().toUpperCase();
    if (id.isEmpty) return false;

    final permission = await ensurePermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    if (_sharingDriverId?.toUpperCase() == id && _gpsSub != null) {
      return true;
    }

    await stopSharing();

    _sharingDriverId = id;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 8,
    );

    _gpsSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) {
        _positions[id] = BusLivePosition(
          driverId: id,
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: position.timestamp,
          heading: position.heading,
          speedMps: position.speed,
        );
        _publishPosition(_positions[id]!);
        notifyListeners();      },
      onError: (_) {
        notifyListeners();
      },
    );

    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      _positions[id] = BusLivePosition(
        driverId: id,
        latitude: current.latitude,
        longitude: current.longitude,
        timestamp: current.timestamp,
        heading: current.heading,
        speedMps: current.speed,
      );
      _publishPosition(_positions[id]!);    } catch (_) {
      // Stream may still deliver once GPS locks.
    }

    notifyListeners();
    return true;
  }

  Future<void> stopSharing() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    if (_sharingDriverId != null) {
      _sharingDriverId = null;
      notifyListeners();
    }
  }

  /// Demo helper: seed a position when GPS is unavailable on desktop emulators.
  void seedDemoPosition({
    required String driverId,
    required double latitude,
    required double longitude,
  }) {
    final id = driverId.trim().toUpperCase();
    _positions[id] = BusLivePosition(
      driverId: id,
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
    );
    _publishPosition(_positions[id]!);
    notifyListeners();
  }
}