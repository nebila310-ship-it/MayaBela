import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mayabela/maps/free_map_links.dart';
import 'package:mayabela/models/transport_passenger.dart';
import 'package:mayabela/screens/transport_live_map_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_live_location_service.dart';
import 'package:mayabela/services/persistence/bus_persistence_service.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/widgets/free_street_map.dart';
import 'package:mayabela/widgets/mobile_erp_host.dart';

/// Web ERP live bus GPS. Positions come from the driver phone via
/// `bus_live_positions`. The in-page map uses free OSM/Carto/Esri tiles.
class WebTransportLiveGpsPage extends StatefulWidget {
  const WebTransportLiveGpsPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebTransportLiveGpsPage> createState() =>
      _WebTransportLiveGpsPageState();
}

class _WebTransportLiveGpsPageState extends State<WebTransportLiveGpsPage> {
  Timer? _tick;
  String? _selectedDriverId;

  @override
  void initState() {
    super.initState();
    BusPersistenceService.instance.loadIntoService();
    _tick = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _openExternalMap(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the map link.')),
      );
    }
  }

  void _openInAppMap(String driverId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MobileErpHost(
          title: 'Live bus map',
          child: TransportLiveMapScreen(
            driverId: driverId,
            showPassengersAction: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        BusLiveLocationService.instance,
        TransportService.instance,
      ]),
      builder: (context, _) {
        final schoolId = AuthService.activeSchoolId;
        final buses = TransportService.instance.busesForSchool(schoolId);
        final live = BusLiveLocationService.instance;
        final selected = buses.isEmpty
            ? null
            : buses.cast<TransportBusSummary>().firstWhere(
                  (b) =>
                      _selectedDriverId != null &&
                      b.driverId == _selectedDriverId,
                  orElse: () => buses.first,
                );
        final selectedPos = selected == null || selected.driverId.isEmpty
            ? null
            : live.positionFor(selected.driverId);
        final selectedFresh = selected == null || selected.driverId.isEmpty
            ? BusGpsFreshness.waiting
            : live.freshnessFor(selected.driverId);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live bus GPS',
                          style: WebErpTheme.sectionTitle(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A moving pin appears only while a driver is signed in '
                          'on a phone with location on. The map uses OpenStreetMap, '
                          'CARTO, and Esri — no Google Maps key required.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onNavigate != null)
                    OutlinedButton.icon(
                      onPressed: () => widget.onNavigate!('add_driver'),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Register driver'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (buses.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: WebErpTheme.cardDecoration(context),
                  child: const Text(
                    'No buses yet. Register a driver in Human Resource → '
                    'Transport, or add a bus first.',
                  ),
                )
              else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final bus in buses)
                      _BusGpsChip(
                        bus: bus,
                        freshness: bus.driverId.isEmpty
                            ? BusGpsFreshness.waiting
                            : live.freshnessFor(bus.driverId),
                        selected: bus.driverId == selected?.driverId,
                        onTap: bus.driverId.isEmpty
                            ? null
                            : () => setState(
                                  () => _selectedDriverId = bus.driverId,
                                ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: WebErpTheme.cardDecoration(context),
                  child: selected == null
                      ? const Text('Select a bus.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${selected.busNumber} · ${selected.driverName}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (selected.routeName.isNotEmpty)
                                  selected.routeName,
                                if (selected.plateNumber.isNotEmpty)
                                  selected.plateNumber,
                                if (selected.busId != null) selected.busId!,
                                '${selected.passengerCount} student(s)',
                              ].join(' · '),
                            ),
                            const SizedBox(height: 12),
                            _GpsStatusBanner(
                              freshness: selectedFresh,
                              position: selectedPos,
                              hasDriver: selected.driverId.isNotEmpty,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 360,
                              width: double.infinity,
                              child: FreeStreetMap(
                                center: selectedPos == null
                                    ? null
                                    : LatLng(
                                        selectedPos.latitude,
                                        selectedPos.longitude,
                                      ),
                                liveBus: selectedPos == null
                                    ? null
                                    : LatLng(
                                        selectedPos.latitude,
                                        selectedPos.longitude,
                                      ),
                                busLabel: selected.busNumber,
                                expanded: true,
                              ),
                            ),
                            if (selectedPos != null) ...[
                              const SizedBox(height: 12),
                              SelectableText(
                                '${selectedPos.latitude.toStringAsFixed(6)}, '
                                '${selectedPos.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () => _openExternalMap(
                                      FreeMapLinks.openStreetMap(
                                        latitude: selectedPos.latitude,
                                        longitude: selectedPos.longitude,
                                      ),
                                    ),
                                    icon: const Icon(Icons.public),
                                    label: const Text('OpenStreetMap'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _openExternalMap(
                                      FreeMapLinks.googleMaps(
                                        latitude: selectedPos.latitude,
                                        longitude: selectedPos.longitude,
                                      ),
                                    ),
                                    icon: const Icon(Icons.map_outlined),
                                    label: const Text('Google Maps'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _openExternalMap(
                                      FreeMapLinks.appleMaps(
                                        latitude: selectedPos.latitude,
                                        longitude: selectedPos.longitude,
                                      ),
                                    ),
                                    icon: const Icon(Icons.phone_iphone),
                                    label: const Text('Apple Maps'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _openInAppMap(selected.driverId),
                                    icon: const Icon(Icons.fullscreen),
                                    label: const Text('Full map'),
                                  ),
                                ],
                              ),
                            ] else if (selected.driverId.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _openInAppMap(selected.driverId),
                                icon: const Icon(Icons.fullscreen),
                                label: const Text('Open waiting map'),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BusGpsChip extends StatelessWidget {
  const _BusGpsChip({
    required this.bus,
    required this.freshness,
    required this.selected,
    required this.onTap,
  });

  final TransportBusSummary bus;
  final BusGpsFreshness freshness;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (freshness) {
      BusGpsFreshness.live => ('Live', Colors.green),
      BusGpsFreshness.stale => ('Stale', Colors.orange),
      BusGpsFreshness.waiting => (
          bus.driverId.isEmpty ? 'No driver' : 'Waiting',
          Colors.blueGrey,
        ),
    };
    return FilterChip(
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
      avatar: Icon(Icons.directions_bus, color: color, size: 18),
      label: Text('${bus.busNumber} · $label'),
    );
  }
}

class _GpsStatusBanner extends StatelessWidget {
  const _GpsStatusBanner({
    required this.freshness,
    required this.position,
    required this.hasDriver,
  });

  final BusGpsFreshness freshness;
  final BusLivePosition? position;
  final bool hasDriver;

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (freshness) {
      BusGpsFreshness.live => (
          Colors.green.shade700,
          'Live GPS from the driver phone.',
        ),
      BusGpsFreshness.stale => (
          Colors.orange.shade800,
          'Last GPS update ${position?.minutesAgo ?? 0} min ago. Ask the driver to open the app.',
        ),
      BusGpsFreshness.waiting => (
          Colors.blueGrey.shade700,
          hasDriver
              ? 'Waiting for driver GPS. The driver must sign in as Driver on a phone and open Passengers or Live Map with location on.'
              : 'This bus has no assigned driver yet. Register or assign a driver first.',
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: TextStyle(color: color, height: 1.35)),
    );
  }
}
