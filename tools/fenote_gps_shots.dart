/// Local-only Fenote screenshot host for Live GPS, parent bus map, and
/// driver Report Issue. Not used by the production app.
import 'package:flutter/material.dart';
import 'package:mayabela/models/school_lifecycle.dart';
import 'package:mayabela/screens/driver_dashboard.dart';
import 'package:mayabela/screens/transport_live_map_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_live_location_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/theme/app_theme.dart';
import 'package:mayabela/web_erp/pages/web_transport_live_gps_page.dart';
import 'package:mayabela/web_erp/services/web_erp_prefs_service.dart';
import 'package:mayabela/web_erp/shell/web_erp_sidebar.dart';
import 'package:mayabela/web_erp/shell/web_erp_top_bar.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/widgets/admin_educational_background.dart';
import 'package:mayabela/widgets/report_issue_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _seedFenoteGpsDemo();
  final shot = Uri.base.queryParameters['shot'] ?? 'admin';
  runApp(FenoteGpsShotApp(shot: shot));
}

Future<void> _seedFenoteGpsDemo() async {
  SchoolRegistryService.instance.upsertSchool(
    SchoolRecord(
      id: 'TB-001',
      name: 'Fenote Raey Academy',
      city: 'Addis Ababa',
      academicYear: '2025/2026',
      campuses: const ['Main Campus'],
      status: SchoolLifecycleStatus.active,
      adminFullName: 'Director',
    ),
  );

  AuthService.setSession(
    RegisteredUser(
      username: 'admin',
      password: AuthService.demoPassword,
      roleKey: AuthService.roleAdmin,
      phone: '0911000003',
      fullName: 'Director',
      schoolId: 'TB-001',
    ),
  );
  AuthService.ensureRegistryLoginAccounts();
  BusRegistryService.instance.seedFromDriversIfEmpty();
  await WebErpPrefsService.instance.load();

  BusLiveLocationService.instance.applyCloudPosition(
    BusLivePosition(
      driverId: 'DRV-1001',
      latitude: 8.9932,
      longitude: 38.7894,
      timestamp: DateTime.now(),
      heading: 312,
      speedMps: 7.4,
    ),
  );
}

class FenoteGpsShotApp extends StatelessWidget {
  const FenoteGpsShotApp({super.key, required this.shot});

  final String shot;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fenote GPS shots',
      locale: const Locale('en'),
      theme: AppTheme.light,
      home: _shotHome(shot),
    );
  }

  Widget _shotHome(String shot) {
    return switch (shot) {
      'parent' => const TransportLiveMapScreen(
          driverId: 'DRV-1001',
          childName: 'Sara Bekele',
        ),
      'driver-map' => const TransportLiveMapScreen(
          driverId: 'DRV-1001',
          showPassengersAction: true,
        ),
      'driver-issue' => const _DriverIssueShot(),
      _ => const _AdminLiveGpsShot(),
    };
  }
}

class _AdminLiveGpsShot extends StatelessWidget {
  const _AdminLiveGpsShot();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WebErpTheme.paperBackdrop,
      body: Row(
        children: [
          WebErpSidebar(
            collapsed: false,
            selectedId: 'transport_live_gps',
            onSelect: (_) {},
            onToggleCollapse: () {},
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const AdminEducationalBackground(
                  accentColor: WebErpTheme.primary,
                ),
                Column(
                  children: [
                    WebErpTopBar(
                      onNavigate: (_) {},
                      onOpenSearch: () {},
                    ),
                    const Expanded(child: WebTransportLiveGpsPage()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverIssueShot extends StatefulWidget {
  const _DriverIssueShot();

  @override
  State<_DriverIssueShot> createState() => _DriverIssueShotState();
}

class _DriverIssueShotState extends State<_DriverIssueShot> {
  @override
  void initState() {
    super.initState();
    AuthService.setSession(
      RegisteredUser(
        username: 'driver',
        password: AuthService.demoPassword,
        roleKey: AuthService.roleDriver,
        phone: '0911667788',
        fullName: 'Ato Getu',
        schoolId: 'TB-001',
        linkedDriverId: 'DRV-1001',
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await ReportIssueDialog.showTransport(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const DriverDashboard();
  }
}
