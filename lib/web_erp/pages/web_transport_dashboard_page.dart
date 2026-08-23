import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_live_location_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/persistence/bus_persistence_service.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/web_erp/pages/web_buses_page.dart';
import 'package:mayabela/web_erp/pages/web_hr_register_driver_page.dart';
import 'package:mayabela/web_erp/pages/web_transport_live_gps_page.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/widgets/mobile_erp_host.dart';

class WebTransportDashboardPage extends StatefulWidget {
  const WebTransportDashboardPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebTransportDashboardPage> createState() =>
      _WebTransportDashboardPageState();
}

class _WebTransportDashboardPageState extends State<WebTransportDashboardPage> {
  @override
  void initState() {
    super.initState();
    BusPersistenceService.instance.loadIntoService();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        BusRegistryService.instance,
        TransportService.instance,
        BusLiveLocationService.instance,
      ]),
      builder: (context, _) {
        final schoolId = AuthService.activeSchoolId;
        final buses = TransportService.instance.busesForSchool(schoolId);
        final drivers = schoolId == null
            ? DriverRegistryService.instance.getAllDrivers()
            : DriverRegistryService.instance.driversForSchool(schoolId);
        final routes = buses
            .map((b) => b.routeName.trim())
            .where((r) => r.isNotEmpty)
            .toSet()
            .length;

        void openBuses() {
          if (widget.onNavigate != null) {
            widget.onNavigate!('transport_buses');
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const MobileErpHost(
                title: 'Buses',
                child: WebBusesPage(),
              ),
            ),
          );
        }

        void openLiveGps() {
          if (widget.onNavigate != null) {
            widget.onNavigate!('transport_live_gps');
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const MobileErpHost(
                title: 'Live GPS',
                child: WebTransportLiveGpsPage(),
              ),
            ),
          );
        }

        void openRegisterDriver() {
          if (widget.onNavigate != null) {
            widget.onNavigate!('add_driver');
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const MobileErpHost(
                title: 'Register driver',
                child: WebHrRegisterDriverPage(),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transport',
                style: WebErpTheme.sectionTitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                'Register drivers, watch live GPS, and manage school buses.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _actionTile(
                    context,
                    key: const ValueKey('hr-register-driver'),
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Register Driver',
                    subtitle: 'Link a driver to a bus and students',
                    filled: true,
                    onTap: openRegisterDriver,
                  ),
                  _actionTile(
                    context,
                    key: const ValueKey('hr-live-gps'),
                    icon: Icons.gps_fixed,
                    title: 'Live GPS',
                    subtitle: 'Track buses on the map',
                    onTap: openLiveGps,
                  ),
                  _actionTile(
                    context,
                    icon: Icons.airport_shuttle_outlined,
                    title: 'Manage Buses',
                    subtitle: 'Plates, routes, and riders',
                    onTap: openBuses,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _stat(context, 'Active Buses', '${buses.length}',
                      Icons.directions_bus),
                  _stat(context, 'Routes', '$routes', Icons.route),
                  _stat(context, 'Drivers', '${drivers.length}', Icons.person),
                  _stat(
                    context,
                    'Onboard Now',
                    '${buses.fold<int>(0, (s, b) => s + b.onboardCount)}',
                    Icons.airline_seat_recline_normal,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                decoration: WebErpTheme.cardDecoration(context),
                child: buses.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No buses registered yet.')),
                      )
                    : DataTable(
                        columns: const [
                          DataColumn(label: Text('Bus')),
                          DataColumn(label: Text('Plate')),
                          DataColumn(label: Text('Route')),
                          DataColumn(label: Text('Driver')),
                          DataColumn(label: Text('GPS')),
                          DataColumn(label: Text('Riders')),
                          DataColumn(label: Text('Onboard')),
                        ],
                        rows: [
                          for (final b in buses)
                            DataRow(
                              cells: [
                                DataCell(Text(b.busNumber)),
                                DataCell(Text(
                                    b.plateNumber.isEmpty ? '—' : b.plateNumber)),
                                DataCell(Text(
                                    b.routeName.isEmpty ? '—' : b.routeName)),
                                DataCell(Text(b.driverName)),
                                DataCell(
                                  Text(
                                    b.driverId.isEmpty
                                        ? 'No driver'
                                        : switch (BusLiveLocationService
                                            .instance
                                            .freshnessFor(b.driverId)) {
                                            BusGpsFreshness.live => 'Live',
                                            BusGpsFreshness.stale => 'Stale',
                                            BusGpsFreshness.waiting =>
                                              'Waiting',
                                          },
                                  ),
                                  onTap: widget.onNavigate == null
                                      ? null
                                      : () => widget
                                          .onNavigate!('transport_live_gps'),
                                ),
                                DataCell(Text('${b.passengerCount}')),
                                DataCell(Text('${b.onboardCount}')),
                              ],
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionTile(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final fg = filled ? Colors.white : WebErpTheme.paperInk;
    return Material(
      key: key,
      color: filled ? WebErpTheme.primary : WebErpTheme.paper.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: filled
                ? null
                : Border.all(color: WebErpTheme.paperEdge.withValues(alpha: 0.75)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: filled ? Colors.white : WebErpTheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  color: filled ? Colors.white.withValues(alpha: 0.9) : Colors.brown.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: WebErpTheme.cardDecoration(context),
      child: Row(
        children: [
          Icon(icon, color: WebErpTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
