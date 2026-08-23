import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:mayabela/maps/free_map_links.dart';
import 'package:mayabela/models/bus_route.dart';

/// Interactive street/satellite map using free tile hosts (no Google key).
class FreeStreetMap extends StatefulWidget {
  const FreeStreetMap({
    super.key,
    this.center,
    this.zoom = 14,
    this.liveBus,
    this.busLabel,
    this.stops = const [],
    this.expanded = false,
    this.showStyleToggle = true,
    this.mapController,
    this.onMapReady,
  });

  final LatLng? center;
  final double zoom;
  final LatLng? liveBus;
  final String? busLabel;
  final List<BusStop> stops;
  final bool expanded;
  final bool showStyleToggle;
  final MapController? mapController;
  final ValueChanged<MapController>? onMapReady;

  @override
  State<FreeStreetMap> createState() => _FreeStreetMapState();
}

class _FreeStreetMapState extends State<FreeStreetMap> {
  late final MapController _controller;
  var _ownsController = false;
  var _style = FreeMapStyle.streets;
  LatLng? _lastFollowed;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.mapController == null;
    _controller = widget.mapController ?? MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onMapReady?.call(_controller);
      _fitIfNeeded();
    });
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FreeStreetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final live = widget.liveBus;
    if (live != null && live != _lastFollowed) {
      _lastFollowed = live;
      try {
        _controller.move(live, _controller.camera.zoom);
      } catch (_) {
        // Controller is not attached yet on the first frame.
      }
    }
  }

  void _fitIfNeeded() {
    if (widget.liveBus != null) return;
    final points = [
      for (final stop in widget.stops) LatLng(stop.latitude, stop.longitude),
    ];
    if (points.length < 2) return;
    try {
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(48),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bus = widget.liveBus;
    final fallback = LatLng(FreeMapLinks.addisLat, FreeMapLinks.addisLng);
    final center = widget.center ??
        bus ??
        (widget.stops.isNotEmpty
            ? LatLng(widget.stops.first.latitude, widget.stops.first.longitude)
            : fallback);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.expanded ? 12 : 16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: center,
              initialZoom: widget.zoom,
              backgroundColor: const Color(0xFFE8EEF4),
            ),
            children: [
              TileLayer(
                urlTemplate: _style.urlTemplate,
                subdomains: _style.subdomains,
                userAgentPackageName: 'com.mayabela.app',
                fallbackUrl: FreeMapStyle.osm.urlTemplate,
              ),
              if (widget.stops.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        for (final stop in widget.stops)
                          LatLng(stop.latitude, stop.longitude),
                      ],
                      color: const Color(0xFF1565C0),
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < widget.stops.length; i++)
                    Marker(
                      point: LatLng(
                        widget.stops[i].latitude,
                        widget.stops[i].longitude,
                      ),
                      width: 34,
                      height: 34,
                      alignment: Alignment.topCenter,
                      child: Tooltip(
                        message: widget.stops[i].name,
                        child: Icon(
                          Icons.location_on,
                          color: switch (widget.stops[i].status) {
                            StopStatus.completed => Colors.green.shade700,
                            StopStatus.current => Colors.orange.shade800,
                            StopStatus.pending => Colors.blue.shade700,
                          },
                          size: 30,
                        ),
                      ),
                    ),
                  if (bus != null)
                    Marker(
                      point: bus,
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: Tooltip(
                        message: widget.busLabel ?? 'Bus',
                        child: const Icon(
                          Icons.directions_bus,
                          color: Color(0xFFC62828),
                          size: 36,
                        ),
                      ),
                    ),
                ],
              ),
              SimpleAttributionWidget(
                source: Text(_style.attribution),
                alignment: Alignment.bottomLeft,
              ),
            ],
          ),
          if (widget.showStyleToggle)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.white.withValues(alpha: 0.94),
                elevation: 2,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final style in FreeMapStyle.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ChoiceChip(
                            label: Text(style.label),
                            selected: _style == style,
                            onSelected: (_) => setState(() => _style = style),
                            visualDensity: VisualDensity.compact,
                            labelStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
