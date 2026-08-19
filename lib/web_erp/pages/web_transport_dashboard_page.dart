import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/persistence/bus_persistence_service.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/web_erp/pages/web_buses_page.dart';
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transport Dashboard',
                      style: WebErpTheme.sectionTitle(context),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: openBuses,
                    icon: const Icon(Icons.airport_shuttle_outlined),
                    label: const Text('Manage Buses'),
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

  Widget _stat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: WebErpTheme.cardDecoration(context),
      child: Row(
        children: [
          Icon(icon, color: WebErpTheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
