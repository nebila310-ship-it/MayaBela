import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/bus_route.dart';
import 'package:mayabela/screens/transport_screens.dart';
import 'package:mayabela/services/bus_live_location_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/widgets/bus_map_widget.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

/// Full-screen Google Map showing a bus live GPS position from the driver's phone.
class TransportLiveMapScreen extends StatefulWidget {
  const TransportLiveMapScreen({
    super.key,
    required this.driverId,
    this.childName,
    this.showPassengersAction = false,
    this.autoStartDriverSharing = false,
  });

  final String driverId;
  final String? childName;
  final bool showPassengersAction;
  final bool autoStartDriverSharing;

  @override
  State<TransportLiveMapScreen> createState() => _TransportLiveMapScreenState();
}

class _TransportLiveMapScreenState extends State<TransportLiveMapScreen> {
  final _live = BusLiveLocationService.instance;
  final _transport = TransportService.instance;
  final _data = SchoolDataService.instance;
  Timer? _refreshTimer;
  GoogleMapController? _mapController;
  LatLng? _lastCameraTarget;
  String? _selectedChild;
  bool _sharingStarted = false;

  @override
  void initState() {
    super.initState();
    final children = _data.getChildren();
    _selectedChild = widget.childName ??
        (children.isNotEmpty ? children.first.name : null);

    if (widget.autoStartDriverSharing) {
      _startDriverSharing();
    }

    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _startDriverSharing() async {
    if (_sharingStarted) return;
    _sharingStarted = true;
    final ok = await _live.startSharing(widget.driverId);
    if (!mounted) return;
    if (!ok) {
      final s = AppLocale.instance.strings;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.busGpsPermissionDenied)),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  BusRoute? _routeForDriver(String driverId) =>
      _data.routeForDriverId(driverId);

  String? _driverIdForChild(String childName) {
    final child = _data.getChildByName(childName);
    if (child?.studentId != null) {
      return _transport.driverIdForStudent(child!.studentId!);
    }
    final record = StudentRegistryService.instance.lookupByName(childName);
    if (record != null) {
      return _transport.driverIdForStudent(record.studentId);
    }
    final assignment = _data.getBusAssignmentForChild(childName);
    if (assignment?.studentId != null) {
      return _transport.driverIdForStudent(assignment!.studentId!);
    }
    if (assignment == null) return null;
    final route = _data.getBusRoute(assignment.routeId);
    if (route == null) return null;
    for (final driver in _transport.busesForSchool(null)) {
      if (driver.busNumber == route.busNumber ||
          driver.plateNumber == route.plateNumber) {
        return driver.driverId;
      }
    }
    return null;
  }

  String get _activeDriverId {
    if (_selectedChild != null) {
      return _driverIdForChild(_selectedChild!) ?? widget.driverId;
    }
    return widget.driverId;
  }

  void _maybeMoveCamera(LatLng target) {
    if (_mapController == null) return;
    if (_lastCameraTarget != null) {
      final latDiff = (target.latitude - _lastCameraTarget!.latitude).abs();
      final lngDiff = (target.longitude - _lastCameraTarget!.longitude).abs();
      if (latDiff < 0.00005 && lngDiff < 0.00005) return;
    }
    _lastCameraTarget = target;
    _mapController!.animateCamera(CameraUpdate.newLatLng(target));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_live, AppLocale.instance]),
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final driverId = _activeDriverId;
        final driver = _transport.driverForId(driverId);
        final route = _routeForDriver(driverId);
        final livePos = _live.positionFor(driverId);
        final isSharing = _live.isDriverSharing(driverId);
        final isLive = livePos?.isFresh == true;

        LatLng? liveLatLng;
        if (livePos != null) {
          liveLatLng = LatLng(livePos.latitude, livePos.longitude);
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            title: Text(s.busLiveLocation),
            actions: [
              if (widget.showPassengersAction)
                IconButton(
                  tooltip: s.passengers,
                  icon: const Icon(Icons.groups_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransportPassengerListScreen(
                        driverId: driverId,
                        readOnly: true,
                      ),
                    ),
                  ),
                ),
              if (widget.autoStartDriverSharing)
                IconButton(
                  tooltip: s.shareMyLocation,
                  icon: Icon(
                    isSharing ? Icons.gps_fixed : Icons.gps_off,
                    color: isSharing ? Colors.lightGreenAccent : Colors.white70,
                  ),
                  onPressed: () async {
                    if (isSharing) {
                      await _live.stopSharing();
                    } else {
                      await _startDriverSharing();
                    }
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              if (_selectedChild != null && widget.childName == null)
                _childSelector(s),
              if (widget.childName != null || _selectedChild != null)
                _childOnboardBanner(s),
              _statusBanner(s, isLive, isSharing, livePos),
              if (driver != null) _busInfoStrip(driver, s),
              Expanded(
                child: route != null
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: BusMapWidget(
                          route: route,
                          liveBusLatLng: liveLatLng,
                          expanded: true,
                          onMapCreated: (controller) {
                            _mapController = controller;
                            if (liveLatLng != null) {
                              _maybeMoveCamera(liveLatLng);
                            }
                          },
                          onLivePosition: liveLatLng != null
                              ? _maybeMoveCamera
                              : null,
                        ),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            driver == null
                                ? (widget.childName != null
                                    ? s.parentBusLinkPrompt
                                    : s.transportNoAssignedBus)
                                : s.busRouteMapUnavailable,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _childOnboardBanner(AppStrings s) {
    final childName = widget.childName ?? _selectedChild;
    if (childName == null) return const SizedBox.shrink();

    final passenger = () {
      final child = _data.getChildByName(childName);
      if (child?.studentId != null) {
        return _transport.passengerForStudent(child!.studentId!);
      }
      final record = StudentRegistryService.instance.lookupByName(childName);
      if (record != null) {
        return _transport.passengerForStudent(record.studentId);
      }
      return _transport.passengerForChildName(childName);
    }();
    if (passenger == null) return const SizedBox.shrink();

    final onboard = passenger.isOnboard;
    final bg = onboard ? Colors.green.shade50 : Colors.orange.shade50;
    final color = onboard ? Colors.green.shade800 : Colors.orange.shade900;
    final icon = onboard ? Icons.directions_bus_filled : Icons.person_outline;
    final label = onboard ? s.transportOnboard : s.transportWaiting;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  childName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _childSelector(AppStrings s) {
    final children = _data.getChildren();
    if (children.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: listPagePadding(context).copyWith(bottom: 0, top: 8),
      child: DropdownButtonFormField<String>(
        key: ValueKey(_selectedChild),
        initialValue: _selectedChild,
        decoration: InputDecoration(
          labelText: s.trackBusFor,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: children
            .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _selectedChild = value);
        },
      ),
    );
  }

  Widget _statusBanner(
    AppStrings s,
    bool isLive,
    bool isSharing,
    BusLivePosition? livePos,
  ) {
    final Color bg;
    final IconData icon;
    final String message;

    if (isLive) {
      bg = Colors.green.shade50;
      icon = Icons.gps_fixed;
      message = s.busGpsLive;
    } else if (livePos != null) {
      bg = Colors.orange.shade50;
      icon = Icons.gps_not_fixed;
      message = s.busGpsLastSeen(
        DateTime.now().difference(livePos.timestamp).inMinutes.clamp(0, 999),
      );
    } else if (isSharing) {
      bg = Colors.blue.shade50;
      icon = Icons.satellite_alt;
      message = s.busGpsAcquiring;
    } else {
      bg = Colors.grey.shade100;
      icon = Icons.location_off_outlined;
      message = s.busGpsWaitingForDriver;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: bg,
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade800, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _busInfoStrip(AdminDriverRecord driver, AppStrings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.directions_bus, color: Colors.blue, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver.busNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${driver.routeName} · ${s.driverLabel(driver.fullName)}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            driver.plateNumber,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
