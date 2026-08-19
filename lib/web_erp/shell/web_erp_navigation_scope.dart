import 'package:flutter/material.dart';

/// Provides in-shell back/navigation for pages embedded in [WebErpAdminShell]
/// (they are not separate Navigator routes, so [Navigator.pop] does nothing).
class WebErpNavigationScope extends InheritedWidget {
  const WebErpNavigationScope({
    super.key,
    required this.routeId,
    required this.canGoBack,
    required this.navigate,
    required this.goBack,
    required super.child,
  });

  final String routeId;
  final bool canGoBack;
  final ValueChanged<String> navigate;
  final VoidCallback goBack;

  static WebErpNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WebErpNavigationScope>();
  }

  static WebErpNavigationScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'WebErpNavigationScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(WebErpNavigationScope oldWidget) {
    return routeId != oldWidget.routeId || canGoBack != oldWidget.canGoBack;
  }
}

/// Prefer Navigator pop when a real route exists; otherwise ERP shell history.
void webErpHandleBack(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
    return;
  }
  final scope = WebErpNavigationScope.maybeOf(context);
  if (scope != null) {
    scope.goBack();
    return;
  }
  Navigator.of(context).maybePop();
}
