import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/staff_registry_notifier.dart';
import 'package:mayabela/utils/auth_navigation.dart';
import 'package:mayabela/web_erp/router/web_erp_router.dart';
import 'package:mayabela/web_erp/services/web_erp_prefs_service.dart';
import 'package:mayabela/web_erp/shell/web_erp_breadcrumbs.dart';
import 'package:mayabela/web_erp/shell/web_erp_navigation_scope.dart';
import 'package:mayabela/web_erp/shell/web_erp_sidebar.dart';
import 'package:mayabela/web_erp/shell/web_erp_top_bar.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/widgets/web_global_search_dialog.dart';
import 'package:mayabela/web_erp/widgets/web_session_timeout.dart';
import 'package:mayabela/widgets/admin_educational_background.dart';

/// Shared school ERP shell — sidebar, top bar, routed content.
/// Used on web and on the Admin/Staff APK so both show the same modules.
class WebErpAdminShell extends StatefulWidget {
  const WebErpAdminShell({super.key});

  @override
  State<WebErpAdminShell> createState() => _WebErpAdminShellState();
}

class _WebErpAdminShellState extends State<WebErpAdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _routeId = 'dashboard';
  final List<String> _routeStack = <String>[];

  @override
  void initState() {
    super.initState();
    unawaited(WebErpPrefsService.instance.load());
  }

  bool get _canGoBack =>
      _routeStack.isNotEmpty || _routeId != 'dashboard';

  void _navigate(String routeId) {
    if (routeId == 'logout') {
      AuthNavigation.performLogout();
      return;
    }
    if (routeId == _routeId) {
      _scaffoldKey.currentState?.closeDrawer();
      return;
    }
    if (routeId == 'dashboard') {
      _routeStack.clear();
    } else {
      _routeStack.add(_routeId);
      if (_routeStack.length > 40) {
        _routeStack.removeAt(0);
      }
    }
    setState(() => _routeId = routeId);
    WebErpPrefsService.instance.recordVisit(routeId);
    _scaffoldKey.currentState?.closeDrawer();
  }

  void _goBack() {
    if (_routeStack.isNotEmpty) {
      final prev = _routeStack.removeLast();
      setState(() => _routeId = prev);
      return;
    }
    if (_routeId != 'dashboard') {
      setState(() => _routeId = 'dashboard');
    }
  }

  void _openSearch() {
    showWebGlobalSearchDialog(context, onSelectRoute: _navigate);
  }

  Widget _pageBody({required bool narrow}) {
    return Column(
      children: [
        WebErpTopBar(
          onNavigate: _navigate,
          onOpenSearch: _openSearch,
          onOpenMenu: narrow
              ? () => _scaffoldKey.currentState?.openDrawer()
              : null,
          onBack: _canGoBack ? _goBack : null,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(narrow ? 12 : 20, 12, narrow ? 12 : 20, 0),
          child: WebErpBreadcrumbs(
            routeId: _routeId,
            onNavigate: _navigate,
            onBack: _canGoBack ? _goBack : null,
            onToggleFavorite: () =>
                WebErpPrefsService.instance.toggleFavorite(_routeId),
          ),
        ),
        if (ModuleAccess.isReadOnly(_routeId))
          Padding(
            padding: EdgeInsets.fromLTRB(
              narrow ? 12 : 20, 8, narrow ? 12 : 20, 0,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined,
                      size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocale.instance.strings.moduleReadOnlyBanner,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(_routeId),
              child: WebErpRouter.pageFor(
                _routeId,
                onNavigate: _navigate,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        WebErpPrefsService.instance,
        SchoolContentSyncService.instance,
        StaffRegistryNotifier.instance,
      ]),
      builder: (context, _) {
        final narrow = WebViewport.isNarrow(context);
        final collapsed = narrow
            ? false
            : WebErpPrefsService.instance.sidebarCollapsed;

        final sidebar = WebErpSidebar(
          collapsed: collapsed,
          selectedId: _routeId,
          onSelect: _navigate,
          onToggleCollapse: narrow
              ? () => _scaffoldKey.currentState?.closeDrawer()
              : () => WebErpPrefsService.instance
                  .setSidebarCollapsed(!collapsed),
          inDrawer: narrow,
        );

        return WebErpNavigationScope(
          routeId: _routeId,
          canGoBack: _canGoBack,
          navigate: _navigate,
          goBack: _goBack,
          child: PopScope(
            canPop: !_canGoBack,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              _goBack();
            },
            child: WebSessionTimeoutWrapper(
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                      _openSearch,
                  const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                      _openSearch,
                  const SingleActivator(LogicalKeyboardKey.slash, control: true):
                      _openSearch,
                },
                child: Focus(
                  autofocus: !narrow,
                  child: narrow
                      ? Scaffold(
                          key: _scaffoldKey,
                          backgroundColor: WebErpTheme.paperBackdrop,
                          drawer: Drawer(child: sidebar),
                          body: Stack(
                            fit: StackFit.expand,
                            children: [
                              const AdminEducationalBackground(
                                accentColor: WebErpTheme.primary,
                              ),
                              _pageBody(narrow: true),
                            ],
                          ),
                        )
                      : Scaffold(
                          backgroundColor: WebErpTheme.paperBackdrop,
                          body: Row(
                            children: [
                              sidebar,
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    const AdminEducationalBackground(
                                      accentColor: WebErpTheme.primary,
                                    ),
                                    _pageBody(narrow: false),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
