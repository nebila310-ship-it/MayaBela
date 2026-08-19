import 'package:flutter/material.dart';

import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/web_erp/services/web_erp_prefs_service.dart';

class WebErpBreadcrumbs extends StatelessWidget {
  const WebErpBreadcrumbs({
    super.key,
    required this.routeId,
    this.onNavigate,
    this.onBack,
    this.onToggleFavorite,
  });

  final String routeId;
  final ValueChanged<String>? onNavigate;
  final VoidCallback? onBack;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final item = webErpNavItemById(routeId);
    final section = item?.section;
    final isFav = WebErpPrefsService.instance.isFavorite(routeId);

    return Row(
      children: [
        if (onBack != null) ...[
          IconButton(
            tooltip: 'Back',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: onBack,
          ),
          const SizedBox(width: 4),
        ],
        _crumb(context, 'Home', 'dashboard'),
        const _Sep(),
        if (section != null) ...[
          Text(
            section,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const _Sep(),
        ],
        Flexible(
          child: Text(
            webErpLabelForId(routeId),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const Spacer(),
        if (routeId != 'dashboard')
          IconButton(
            tooltip: isFav ? 'Remove from favorites' : 'Pin to favorites',
            icon: Icon(isFav ? Icons.star : Icons.star_border, size: 20),
            onPressed: onToggleFavorite,
          ),
      ],
    );
  }

  Widget _crumb(BuildContext context, String label, String id) {
    return InkWell(
      onTap: onNavigate == null ? null : () => onNavigate!(id),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(
        Icons.chevron_right,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
