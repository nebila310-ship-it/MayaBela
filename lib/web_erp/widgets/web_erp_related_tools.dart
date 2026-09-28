import 'package:flutter/material.dart';

import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/web_erp/shell/web_erp_navigation_scope.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

class WebErpRelatedTool {
  const WebErpRelatedTool({
    required this.routeId,
    required this.label,
    required this.icon,
    this.subtitle,
  });

  final String routeId;
  final String label;
  final IconData icon;
  final String? subtitle;
}

/// In-page shortcuts for tools that share a parent ERP module instead of a
/// second top-level sidebar item (so APK and web catalogs stay identical).
class WebErpRelatedToolsCard extends StatelessWidget {
  const WebErpRelatedToolsCard({
    super.key,
    required this.tools,
    this.title = 'Related tools',
  });

  final List<WebErpRelatedTool> tools;
  final String title;

  @override
  Widget build(BuildContext context) {
    final visible =
        tools.where((tool) => ModuleAccess.canView(tool.routeId)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(title, style: WebErpTheme.sectionTitle(context)),
          ),
          for (final tool in visible)
            ListTile(
              leading: Icon(tool.icon, color: WebErpTheme.primary),
              title: Text(tool.label),
              subtitle:
                  tool.subtitle == null ? null : Text(tool.subtitle!),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final scope = WebErpNavigationScope.maybeOf(context);
                if (scope != null) {
                  scope.navigate(tool.routeId);
                }
              },
            ),
        ],
      ),
    );
  }
}
