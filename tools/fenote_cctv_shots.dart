/// Local-only Fenote screenshot host for Admin CCTV and the dashboard
/// Quick Action. Not used by the production app.
import 'package:flutter/material.dart';
import 'package:mayabela/models/school_lifecycle.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/theme/app_theme.dart';
import 'package:mayabela/web_erp/pages/web_admin_overview_page.dart';
import 'package:mayabela/web_erp/pages/web_cctv_page.dart';
import 'package:mayabela/web_erp/services/web_erp_prefs_service.dart';
import 'package:mayabela/web_erp/shell/web_erp_sidebar.dart';
import 'package:mayabela/web_erp/shell/web_erp_top_bar.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/widgets/admin_educational_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _seedFenoteCctvDemo();
  final shot = Uri.base.queryParameters['shot'] ?? 'admin';
  runApp(FenoteCctvShotApp(shot: shot));
}

Future<void> _seedFenoteCctvDemo() async {
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
  await WebErpPrefsService.instance.load();
}

class FenoteCctvShotApp extends StatelessWidget {
  const FenoteCctvShotApp({super.key, required this.shot});

  final String shot;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fenote CCTV shots',
      locale: const Locale('en'),
      theme: AppTheme.light,
      home: _ErpShellShot(
        selectedId: shot == 'overview' ? 'dashboard' : 'cctv',
        child: shot == 'overview'
            ? const _OverviewShot()
            : const WebCctvPage(),
      ),
    );
  }
}

class _OverviewShot extends StatefulWidget {
  const _OverviewShot();

  @override
  State<_OverviewShot> createState() => _OverviewShotState();
}

class _OverviewShotState extends State<_OverviewShot> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (max > 0) {
        _scroll.jumpTo((max * 0.42).clamp(0, max));
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController(
      controller: _scroll,
      child: const WebAdminOverviewPage(),
    );
  }
}

class _ErpShellShot extends StatelessWidget {
  const _ErpShellShot({
    required this.selectedId,
    required this.child,
  });

  final String selectedId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WebErpTheme.paperBackdrop,
      body: Row(
        children: [
          WebErpSidebar(
            collapsed: false,
            selectedId: selectedId,
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
                    Expanded(child: child),
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
