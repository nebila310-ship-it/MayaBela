import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:mayabela/models/bus_route.dart';
import 'package:mayabela/widgets/free_street_map.dart';

class BusMapWidget extends StatelessWidget {
  const BusMapWidget({
    super.key,
    required this.route,
    this.liveBusLatLng,
    this.expanded = false,
    this.onMapCreated,
  });

  final BusRoute route;
  final LatLng? liveBusLatLng;
  final bool expanded;
  final ValueChanged<MapController>? onMapCreated;

  @override
  Widget build(BuildContext context) {
    final simulated = route.busPosition;
    final live = liveBusLatLng;
    if (live == null && (simulated == null || route.stops.isEmpty)) {
      return _fallbackMap('Route data unavailable');
    }

    final busLatLng = live ?? LatLng(simulated!.lat, simulated.lng);

    final map = FreeStreetMap(
      center: busLatLng,
      liveBus: busLatLng,
      busLabel: route.busNumber,
      stops: route.stops,
      expanded: expanded,
      onMapReady: onMapCreated,
    );

    if (expanded) {
      return map;
    }
    return SizedBox(height: 220, child: map);
  }

  Widget _fallbackMap(String message) {
    final height = expanded ? 200.0 : 220.0;
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
