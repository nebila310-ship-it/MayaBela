import 'package:flutter/material.dart';

import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/web_erp/router/web_erp_router.dart';
import 'package:mayabela/web_erp/shell/web_erp_navigation_scope.dart';
import 'package:mayabela/widgets/mobile_erp_host.dart';

/// Open an ERP route in the current shell, or push a hosted page outside it.
void webErpOpenRoute(BuildContext context, String routeId) {
  final scope = WebErpNavigationScope.maybeOf(context);
  if (scope != null) {
    scope.navigate(routeId);
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (pageContext) => WebErpNavigationScope(
        routeId: routeId,
        canGoBack: true,
        navigate: (next) => webErpOpenRoute(pageContext, next),
        goBack: () => Navigator.of(pageContext).maybePop(),
        child: MobileErpHost(
          title: webErpLabelForId(routeId),
          child: WebErpRouter.pageFor(
            routeId,
            onNavigate: (next) => webErpOpenRoute(pageContext, next),
          ),
        ),
      ),
    ),
  );
}
