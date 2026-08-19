import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/transport_passenger.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_live_location_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/screens/transport_live_map_screen.dart';
import 'package:mayabela/screens/transport_qr_scanner_screen.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_staff_ui.dart';

/// Admin: all buses. Driver: assigned bus only (opens passenger list directly).
class TransportBusListScreen extends StatefulWidget {
  const TransportBusListScreen({
    super.key,
    this.adminMode = false,
  });

  final bool adminMode;

  @override
  State<TransportBusListScreen> createState() => _TransportBusListScreenState();
}

class _TransportBusListScreenState extends State<TransportBusListScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.adminMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpenDriverBus());
    }
  }

  void _maybeOpenDriverBus() {
    if (!mounted) return;
    final transport = TransportService.instance;
    final linked = transport.linkedDriverId;
    if (linked == null) return;

    final buses = transport.busesForSchool(AuthService.activeSchoolId);
    final mine = buses.where((b) => b.driverId == linked).toList();
    if (mine.length == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TransportPassengerListScreen(driverId: mine.first.driverId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = StaffPalette.transport;
    final transport = TransportService.instance;
    final schoolId = AuthService.activeSchoolId;

    return ListenableBuilder(
      listenable: Listenable.merge([
        transport,
        BusRegistryService.instance,
      ]),
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        var buses = transport.busesForSchool(schoolId);

        if (!widget.adminMode) {
          final linked = transport.linkedDriverId;
          if (linked == null) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: palette.primary,
                title: Text(s.transportBusList),
              ),
              body: Center(child: Text(s.transportNoAssignedBus)),
            );
          }
          buses = buses.where((b) => b.driverId == linked).toList();
        }

        return Scaffold(
          backgroundColor: palette.primary.withValues(alpha: 0.04),
          appBar: AppBar(
            backgroundColor: palette.primary,
            foregroundColor: Colors.white,
            title: Text(s.transportBusList),
          ),
          body: buses.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      s.noTransportStaff,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              : ListView(
                  padding: listPagePadding(context),
                  children: [
                    Text(
                      s.transportBusListHint,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...buses.map(
                      (bus) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TransportBusCard(
                          bus: bus,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TransportLiveMapScreen(
                                driverId: bus.driverId,
                                showPassengersAction: widget.adminMode,
                              ),
                            ),
                          ),
                          onPassengersTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TransportPassengerListScreen(
                                driverId: bus.driverId,
                                readOnly: widget.adminMode,
                              ),
                            ),
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
}

class _TransportBusCard extends StatelessWidget {
  const _TransportBusCard({
    required this.bus,
    required this.onTap,
    this.onPassengersTap,
  });

  final TransportBusSummary bus;
  final VoidCallback onTap;
  final VoidCallback? onPassengersTap;

  @override
  Widget build(BuildContext context) {
    final palette = StaffPalette.transport;
    final s = AppLocale.instance.strings;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                palette.primary.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.primary.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.1),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: palette.gradient),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.directions_bus_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bus.busNumber,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            bus.routeName,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _OnboardBadge(
                      onboard: bus.onboardCount,
                      total: bus.passengerCount,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _infoChip(Icons.person_outline, bus.driverName, palette.primary),
                    _infoChip(
                      Icons.confirmation_number_outlined,
                      bus.plateNumber,
                      palette.secondary,
                    ),
                    _infoChip(Icons.badge_outlined, bus.driverId, palette.accent),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.map_outlined, color: palette.primary, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          s.busLiveLocation,
                          style: TextStyle(
                            color: palette.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Icon(Icons.chevron_right, color: palette.primary, size: 20),
                      ],
                    ),
                    if (onPassengersTap != null)
                      TextButton.icon(
                        onPressed: onPassengersTap,
                        icon: const Icon(Icons.groups_outlined, size: 18),
                        label: Text(s.viewPassengerList),
                        style: TextButton.styleFrom(
                          foregroundColor: palette.secondary,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class TransportPassengerListScreen extends StatefulWidget {
  const TransportPassengerListScreen({
    super.key,
    required this.driverId,
    this.readOnly = false,
  });

  final String driverId;
  final bool readOnly;

  @override
  State<TransportPassengerListScreen> createState() =>
      _TransportPassengerListScreenState();
}

class _TransportPassengerListScreenState
    extends State<TransportPassengerListScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.readOnly) {
      // EDUABA §3.5 — GPS sharing is required while driver is on route.
      unawaited(_ensureRequiredGps());
    }
  }

  Future<void> _ensureRequiredGps() async {
    final ok =
        await BusLiveLocationService.instance.startSharing(widget.driverId);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'GPS sharing is required while on duty. Enable location permission '
          'so parents can track the bus.',
        ),
        duration: Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = StaffPalette.transport;
    final transport = TransportService.instance;
    final driver = transport.driverForId(widget.driverId);

    return ListenableBuilder(
      listenable: transport,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final passengers = transport.passengersForDriver(widget.driverId);
        final onboard = passengers.where((p) => p.isOnboard).length;

        return Scaffold(
          backgroundColor: palette.primary.withValues(alpha: 0.04),
          appBar: AppBar(
            backgroundColor: palette.primary,
            foregroundColor: Colors.white,
            title: Text(s.passengers),
            actions: [
              IconButton(
                tooltip: AppLocale.instance.strings.busLiveLocation,
                icon: const Icon(Icons.map_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransportLiveMapScreen(
                      driverId: widget.driverId,
                      showPassengersAction: false,
                      autoStartDriverSharing: !widget.readOnly,
                    ),
                  ),
                ),
              ),
              if (!widget.readOnly)
                IconButton(
                  tooltip: s.scanQr,
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () => _openScanner(context),
                ),
            ],
          ),
          floatingActionButton: widget.readOnly
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openScanner(context),
                  backgroundColor: palette.primary,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(s.scanQr),
                ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (driver != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        palette.primary.withValues(alpha: 0.12),
                        palette.accent.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: palette.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${driver.busNumber} · ${driver.routeName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${driver.fullName} · ${driver.plateNumber}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: s.transportOnboard,
                        value: '$onboard',
                        color: Colors.green.shade700,
                        icon: Icons.check_circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        label: s.transportWaiting,
                        value: '${passengers.length - onboard}',
                        color: Colors.red.shade700,
                        icon: Icons.radio_button_unchecked,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        label: s.passengers,
                        value: '${passengers.length}',
                        color: palette.primary,
                        icon: Icons.people,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _legendDot(Colors.green.shade600, s.transportOnboard),
                    const SizedBox(width: 16),
                    _legendDot(Colors.red.shade600, s.transportWaiting),
                  ],
                ),
              ),
              Expanded(
                child: passengers.isEmpty
                    ? Center(
                        child: Text(
                          s.transportNoPassengers,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        padding: listPagePadding(context),
                        itemCount: passengers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final p = passengers[index];
                          return _PassengerTile(passenger: p);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openScanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransportQrScannerScreen(driverId: widget.driverId),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _OnboardBadge extends StatelessWidget {
  const _OnboardBadge({required this.onboard, required this.total});

  final int onboard;
  final int total;

  @override
  Widget build(BuildContext context) {
    final color = onboard > 0 ? Colors.green.shade700 : Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$onboard / $total',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _PassengerTile extends StatelessWidget {
  const _PassengerTile({required this.passenger});

  final TransportPassenger passenger;

  @override
  Widget build(BuildContext context) {
    final onboard = passenger.isOnboard;
    final statusColor = onboard ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: onboard ? 0.35 : 0.25),
          width: onboard ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.12),
              border: Border.all(color: statusColor, width: 2),
            ),
            child: Icon(
              onboard ? Icons.directions_bus_filled : Icons.person_outline,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passenger.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${passenger.className} · ${passenger.grade}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              onboard
                  ? AppLocale.instance.strings.transportOnboard
                  : AppLocale.instance.strings.transportWaiting,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
