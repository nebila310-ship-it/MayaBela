import 'package:flutter/material.dart';

import 'package:mayabela/theme/classroom_palette.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

/// Category panel wrapping a group of dashboard module cards.
class DashboardModuleSection extends StatelessWidget {
  const DashboardModuleSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.accent,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? WebErpTheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: ClassroomPalette.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
