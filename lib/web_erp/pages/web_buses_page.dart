import 'package:flutter/material.dart';

import 'package:mayabela/models/bus_record.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/persistence/bus_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/web_erp/pages/web_hr_register_driver_page.dart';
import 'package:mayabela/web_erp/pages/web_transport_live_gps_page.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/widgets/mobile_erp_host.dart';

/// First-class bus registry management for the web ERP (Phase E).
class WebBusesPage extends StatefulWidget {
  const WebBusesPage({super.key});

  @override
  State<WebBusesPage> createState() => _WebBusesPageState();
}

class _WebBusesPageState extends State<WebBusesPage> {
  @override
  void initState() {
    super.initState();
    BusPersistenceService.instance.loadIntoService();
  }

  bool get _canManage =>
      ModuleAccess.canManage('transport') ||
      BusRegistryService.instance.canManage;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        BusRegistryService.instance,
        TransportService.instance,
      ]),
      builder: (context, _) {
        final schoolId = AuthService.activeSchoolId;
        final buses = BusRegistryService.instance.busesForSchool(schoolId);
        final drivers = schoolId == null
            ? DriverRegistryService.instance.getAllDrivers()
            : DriverRegistryService.instance.driversForSchool(schoolId);

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
                        Text('Buses', style: WebErpTheme.sectionTitle(context)),
                        const SizedBox(height: 4),
                        Text(
                          'Plate, capacity, route, and driver assignment. '
                          'Students stay linked via transport ID (BUS-*).',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (_canManage)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MobileErpHost(
                                  title: 'Live GPS',
                                  child: WebTransportLiveGpsPage(),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.gps_fixed),
                          label: const Text('Live GPS'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MobileErpHost(
                                  title: 'Register driver',
                                  child: WebHrRegisterDriverPage(),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: const Text('Register Driver'),
                        ),
                        FilledButton.icon(
                          onPressed: _showAddOrEdit,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Bus'),
                        ),
                      ],
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
                  _stat(
                    context,
                    'Assigned Drivers',
                    '${buses.where((b) => b.assignedDriverId != null).length}',
                    Icons.person,
                  ),
                  _stat(
                    context,
                    'Total Capacity',
                    '${buses.fold<int>(0, (s, b) => s + b.capacity)}',
                    Icons.event_seat,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (buses.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: WebErpTheme.cardDecoration(context),
                  child: Center(
                    child: Text(
                      'No buses yet. Add a bus or create a driver to seed one.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  decoration: WebErpTheme.cardDecoration(context),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Bus')),
                        DataColumn(label: Text('Plate')),
                        DataColumn(label: Text('Route')),
                        DataColumn(label: Text('Capacity')),
                        DataColumn(label: Text('Driver')),
                        DataColumn(label: Text('Riders')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final bus in buses)
                          DataRow(
                            cells: [
                              DataCell(Text('${bus.busNumber}\n${bus.busId}',
                                  style: const TextStyle(height: 1.3))),
                              DataCell(Text(
                                  bus.plateNumber.isEmpty ? '—' : bus.plateNumber)),
                              DataCell(Text(
                                  bus.routeName.isEmpty ? '—' : bus.routeName)),
                              DataCell(Text('${bus.capacity}')),
                              DataCell(Text(_driverLabel(bus, drivers))),
                              DataCell(Text('${_riderCount(bus)}')),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_canManage) ...[
                                      IconButton(
                                        tooltip: 'Edit',
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () =>
                                            _showAddOrEdit(bus: bus),
                                      ),
                                      IconButton(
                                        tooltip: 'Assign driver',
                                        icon: const Icon(Icons.person_add_alt),
                                        onPressed: () =>
                                            _showAssignDriver(bus, drivers),
                                      ),
                                      IconButton(
                                        tooltip: 'Deactivate',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () =>
                                            _confirmDeactivate(bus),
                                      ),
                                    ] else
                                      const Text('—'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _driverLabel(BusRecord bus, List<AdminDriverRecord> drivers) {
    final id = bus.assignedDriverId;
    if (id == null || id.isEmpty) return 'Unassigned';
    for (final d in drivers) {
      if (d.driverId == id) return d.fullName;
    }
    return id;
  }

  int _riderCount(BusRecord bus) {
    final driverId = bus.assignedDriverId;
    if (driverId == null || driverId.isEmpty) return 0;
    return TransportService.instance.passengersForDriver(driverId).length;
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

  Future<void> _showAddOrEdit({BusRecord? bus}) async {
    final numberCtrl = TextEditingController(text: bus?.busNumber ?? '');
    final plateCtrl = TextEditingController(text: bus?.plateNumber ?? '');
    final routeCtrl = TextEditingController(text: bus?.routeName ?? '');
    final capacityCtrl =
        TextEditingController(text: '${bus?.capacity ?? 40}');
    final notesCtrl = TextEditingController(text: bus?.notes ?? '');
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(bus == null ? 'Add Bus' : 'Edit Bus'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bus number',
                  hintText: 'Bus 12',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: plateCtrl,
                decoration: const InputDecoration(labelText: 'Plate number'),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: routeCtrl,
                decoration: const InputDecoration(labelText: 'Route name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capacityCtrl,
                decoration: const InputDecoration(labelText: 'Capacity'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(bus == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final capacity = int.tryParse(capacityCtrl.text.trim()) ?? 40;

    if (bus == null) {
      final created = await BusRegistryService.instance.addBus(
        busNumber: numberCtrl.text,
        plateNumber: plateCtrl.text,
        routeName: routeCtrl.text,
        capacity: capacity,
        notes: notesCtrl.text,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(created == null
              ? 'Could not create bus.'
              : 'Bus ${created.busNumber} created.'),
        ),
      );
    } else {
      final saved = await BusRegistryService.instance.updateBus(
        bus.copyWith(
          busNumber: DriverRegistryService.normalizeBusNumber(numberCtrl.text),
          plateNumber: plateCtrl.text.trim().toUpperCase(),
          routeName: routeCtrl.text.trim(),
          capacity: capacity,
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(saved ? 'Bus updated.' : 'Could not update bus.')),
      );
    }
  }

  Future<void> _showAssignDriver(
    BusRecord bus,
    List<AdminDriverRecord> drivers,
  ) async {
    String? selected = bus.assignedDriverId;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Assign driver · ${bus.busNumber}'),
          content: SizedBox(
            width: 360,
            child: DropdownButtonFormField<String?>(
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'Driver'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Unassigned'),
                ),
                for (final d in drivers)
                  DropdownMenuItem<String?>(
                    value: d.driverId,
                    child: Text('${d.fullName} (${d.driverId})'),
                  ),
              ],
              onChanged: (v) => setLocal(() => selected = v),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final saved = await BusRegistryService.instance.assignDriver(
      busId: bus.busId,
      driverId: selected,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(saved ? 'Driver assignment saved.' : 'Could not assign.'),
      ),
    );
  }

  Future<void> _confirmDeactivate(BusRecord bus) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate bus?'),
        content: Text(
          'Deactivate ${bus.busNumber} (${bus.busId})? '
          'The driver will be unassigned. Students keep their BUS-* ID.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final saved = await BusRegistryService.instance.deactivateBus(bus.busId);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(saved ? 'Bus deactivated.' : 'Could not deactivate.'),
      ),
    );
  }
}
