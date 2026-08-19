import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mayabela/models/bus_route.dart';

class BusMapWidget extends StatefulWidget {
  const BusMapWidget({
    super.key,
    required this.route,
    this.liveBusLatLng,
    this.expanded = false,
    this.onMapCreated,
    this.onLivePosition,
  });

  final BusRoute route;
  final LatLng? liveBusLatLng;
  final bool expanded;
  final void Function(GoogleMapController controller)? onMapCreated;
  final void Function(LatLng position)? onLivePosition;

  @override
  State<BusMapWidget> createState() => _BusMapWidgetState();
}

class _BusMapWidgetState extends State<BusMapWidget> {
  GoogleMapController? _controller;
  LatLng? _lastLiveTarget;

  bool get _supportsMap {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void didUpdateWidget(covariant BusMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final live = widget.liveBusLatLng;
    if (live != null &&
        live != _lastLiveTarget &&
        widget.onLivePosition != null) {
      _lastLiveTarget = live;
      widget.onLivePosition!(live);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsMap) {
      return _fallbackMap('Map available on Android & iOS');
    }

    final route = widget.route;
    final simulated = route.busPosition;
    if (simulated == null || route.stops.isEmpty) {
      return _fallbackMap('Route data unavailable');
    }

    final busLatLng = widget.liveBusLatLng ?? LatLng(simulated.lat, simulated.lng);
    final usingLiveGps = widget.liveBusLatLng != null;
    final stopPoints = route.stops
        .map((s) => LatLng(s.latitude, s.longitude))
        .toList();

    final markers = <Marker>{
      for (var i = 0; i < route.stops.length; i++)
        Marker(
          markerId: MarkerId('stop-$i'),
          position: stopPoints[i],
          infoWindow: InfoWindow(
            title: route.stops[i].name,
            snippet: route.stops[i].scheduledTime,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            route.stops[i].status == StopStatus.completed
                ? BitmapDescriptor.hueGreen
                : route.stops[i].status == StopStatus.current
                    ? BitmapDescriptor.hueOrange
                    : BitmapDescriptor.hueAzure,
          ),
        ),
      Marker(
        markerId: const MarkerId('bus'),
        position: busLatLng,
        infoWindow: InfoWindow(
          title: route.busNumber,
          snippet: usingLiveGps ? 'Live GPS' : route.statusLabel,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('route'),
        points: stopPoints,
        color: Colors.blue,
        width: 4,
      ),
    };

    final mapHeight = widget.expanded ? null : 220.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.expanded ? 12 : 16),
      child: SizedBox(
        height: mapHeight,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: busLatLng,
            zoom: 14,
          ),
          markers: markers,
          polylines: polylines,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: widget.expanded,
          onMapCreated: (controller) {
            _controller = controller;
            widget.onMapCreated?.call(controller);
            if (!usingLiveGps) {
              _fitBounds(stopPoints);
            }
          },
        ),
      ),
    );
  }

  Future<void> _fitBounds(List<LatLng> points) async {
    if (_controller == null || points.length < 2) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || _controller == null) return;
    await _controller!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
  }

  Widget _fallbackMap(String message) {
    final height = widget.expanded ? 200.0 : 220.0;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 48, color: Colors.blue.shade300),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
