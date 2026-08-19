import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/bus_route.dart';
import 'package:mayabela/services/bus_live_location_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/widgets/bus_map_widget.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

enum BusTrackingView { parent, driver }

class BusTrackingScreen extends StatefulWidget {
  const BusTrackingScreen({
    super.key,
    this.view = BusTrackingView.parent,
    this.childName,
  });

  final BusTrackingView view;
  final String? childName;

  @override
  State<BusTrackingScreen> createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen> {
  final _data = SchoolDataService.instance;
  final _live = BusLiveLocationService.instance;
  final _transport = TransportService.instance;
  Timer? _timer;
  late String _selectedChild;
  bool _driverSharingStarted = false;
  GoogleMapController? _mapController;
  LatLng? _lastCameraTarget;

  @override
  void initState() {
    super.initState();
    final children = _data.getChildren();
    _selectedChild = widget.childName ??
        (children.isNotEmpty ? children.first.name : 'Sara Bekele');

    if (widget.view == BusTrackingView.driver) {
      _startDriverGpsSharing();
    }

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        if (widget.view == BusTrackingView.driver &&
            _live.positionFor(_driverId ?? '')?.isFresh != true) {
          _data.simulateBusMovement();
        }
        setState(() {});
      }
    });
  }

  String? get _selectedStudentId {
    final child = _data.getChildByName(_selectedChild);
    if (child?.studentId != null) return child!.studentId;
    return StudentRegistryService.instance
        .lookupByName(_selectedChild)
        ?.studentId;
  }

  String? get _driverId {
    if (widget.view == BusTrackingView.driver) {
      return _transport.linkedDriverId;
    }
    final studentId = _selectedStudentId;
    if (studentId != null) {
      return _transport.driverIdForStudent(studentId);
    }
    return _transport.driverIdForChildName(_selectedChild);
  }

  Future<void> _startDriverGpsSharing() async {
    if (_driverSharingStarted) return;
    final id = _transport.linkedDriverId;
    if (id == null) return;
    _driverSharingStarted = true;
    await _live.startSharing(id);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
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

  ChildBusAssignment? get _assignment {
    final studentId = _selectedStudentId;
    if (studentId != null) {
      return _data.getBusAssignmentForStudent(studentId) ??
          _data.getBusAssignmentForChild(_selectedChild);
    }
    return _data.getBusAssignmentForChild(_selectedChild);
  }

  BusRoute get _route {
    if (widget.view == BusTrackingView.driver) {
      return _data.getDriverRoute();
    }
    final assignment = _assignment;
    return _data.getBusRoute(assignment?.routeId ?? 'route-bole')!;
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final isDriver = widget.view == BusTrackingView.driver;

    return ListenableBuilder(
      listenable: Listenable.merge([_live, AppLocale.instance]),
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final livePos = _driverId != null ? _live.positionFor(_driverId!) : null;
        final liveLatLng = livePos != null
            ? LatLng(livePos.latitude, livePos.longitude)
            : null;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: isDriver ? Colors.orange : Colors.blue,
            title: Text(isDriver ? s.myRoute : s.busTracking),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _data.simulateBusMovement();
                  setState(() {});
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              _data.simulateBusMovement();
              setState(() {});
            },
            child: ListView(
              padding: listPagePadding(context),
              children: [
                if (!isDriver) _childSelector(s),
                _busInfoCard(route, s),
                const SizedBox(height: 16),
                _liveStatusCard(route, s),
                const SizedBox(height: 16),
                Text(
                  s.googleMap,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                BusMapWidget(
                  route: route,
                  liveBusLatLng: liveLatLng,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (liveLatLng != null) {
                      _maybeMoveCamera(liveLatLng);
                    }
                  },
                  onLivePosition:
                      liveLatLng != null ? _maybeMoveCamera : null,
                ),
                const SizedBox(height: 16),
                _routeMap(route, s),
                const SizedBox(height: 16),
                _stopsList(route, s),
                if (isDriver) ...[
                  const SizedBox(height: 16),
                  _driverActions(route, s),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _childSelector(AppStrings s) {
    final children = _data.getChildren();
    if (children.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        key: ValueKey(_selectedChild),
        initialValue: _selectedChild,
        decoration: InputDecoration(
          labelText: s.trackBusFor,
          border: const OutlineInputBorder(),
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

  Widget _busInfoCard(BusRoute route, AppStrings s) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.directions_bus, size: 36, color: Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.busNumber,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(route.routeName),
                  Text(s.driverLabel(route.driverName)),
                  Text('${s.plateNumber}: ${route.plateNumber}'),
                  if (_assignment != null && widget.view == BusTrackingView.parent)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        s.stopLabel(_assignment!.stopName),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveStatusCard(BusRoute route, AppStrings s) {
    final eta = route.etaMinutes;
    final statusColor = switch (route.tripStatus) {
      TripStatus.notStarted => Colors.grey,
      TripStatus.inProgress => Colors.green,
      TripStatus.completed => Colors.indigo,
    };

    return Card(
      color: statusColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.radar, size: 40, color: statusColor),
            const SizedBox(height: 8),
            Text(
              route.statusLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            if (eta != null && route.tripStatus == TripStatus.inProgress) ...[
              const SizedBox(height: 8),
              Text(
                s.etaMin(eta),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
            if (route.tripStatus == TripStatus.completed)
              Text(
                s.busReachedSchoolSafely,
                style: const TextStyle(color: Colors.indigo),
              ),
          ],
        ),
      ),
    );
  }

  Widget _routeMap(BusRoute route, AppStrings s) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.liveRoute,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 80,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalStops = route.stops.length;
                  final busPosition =
                      _busPosition(route, totalStops, constraints.maxWidth);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 20,
                        right: 20,
                        top: 34,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        top: 34,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: busPosition / constraints.maxWidth,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.blue, Colors.teal],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      ...List.generate(totalStops, (index) {
                        if (totalStops <= 1) return const SizedBox.shrink();
                        final x = 20 +
                            (constraints.maxWidth - 40) *
                                (index / (totalStops - 1));
                        final isCompleted =
                            route.stops[index].status == StopStatus.completed;
                        final isCurrent =
                            route.stops[index].status == StopStatus.current;

                        return Positioned(
                          left: x - 8,
                          top: 26,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted
                                  ? Colors.green
                                  : isCurrent
                                      ? Colors.orange
                                      : Colors.grey.shade400,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        );
                      }),
                      Positioned(
                        left: busPosition - 18,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_bus,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(route.stops.first.name, style: const TextStyle(fontSize: 11)),
                Text(route.stops.last.name, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _busPosition(BusRoute route, int totalStops, double width) {
    if (totalStops <= 1) return 20;
    if (route.tripStatus == TripStatus.completed) return width - 20;
    if (route.tripStatus == TripStatus.notStarted) return 20;

    final segmentWidth = (width - 40) / (totalStops - 1);
    final base = 20 + segmentWidth * route.currentStopIndex;
    return base + segmentWidth * route.progressToNextStop;
  }

  Widget _stopsList(BusRoute route, AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.routeStops,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...route.stops.map((stop) {
          final icon = switch (stop.status) {
            StopStatus.completed => Icons.check_circle,
            StopStatus.current => Icons.directions_bus,
            StopStatus.pending => Icons.radio_button_unchecked,
          };
          final color = switch (stop.status) {
            StopStatus.completed => Colors.green,
            StopStatus.current => Colors.orange,
            StopStatus.pending => Colors.grey,
          };

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(icon, color: color),
              title: Text(
                stop.name,
                style: TextStyle(
                  fontWeight: stop.status == StopStatus.current
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.scheduledAt(stop.scheduledTime)),
                  if (stop.students.isNotEmpty)
                    Text(s.studentsAtStop(stop.students.join(', '))),
                  if (stop.status == StopStatus.current && stop.etaMinutes != null)
                    Text(
                      s.etaMin(stop.etaMinutes!),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _driverActions(BusRoute route, AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.driverControls,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (route.tripStatus == TripStatus.notStarted)
          ElevatedButton.icon(
            onPressed: () {
              _data.startDriverRoute();
              setState(() {});
            },
            icon: const Icon(Icons.play_arrow),
            label: Text(s.startRoute),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        if (route.tripStatus == TripStatus.inProgress) ...[
          ElevatedButton.icon(
            onPressed: () {
              _data.markStopComplete();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(s.stopMarkedComplete),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.check),
            label: Text(s.completeCurrentStop),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              _data.endDriverRoute();
              setState(() {});
            },
            icon: const Icon(Icons.flag),
            label: Text(s.endRouteAtSchool),
          ),
        ],
        if (route.tripStatus == TripStatus.completed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s.routeCompletedToday)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
