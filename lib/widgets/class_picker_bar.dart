import 'package:flutter/material.dart';

import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_educational_background.dart';

/// Warm-themed horizontal class selector for attendance, homework, and similar screens.
class ClassPickerBar extends StatelessWidget {
  const ClassPickerBar({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.accent = TeacherTheme.primaryDark,
  });

  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.12)),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.class_outlined, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (options.length == 1)
            _SelectedChip(name: options.first, accent: accent, selected: true)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final name in options) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _SelectedChip(
                        name: name,
                        accent: accent,
                        selected: name == selected,
                        onTap: () => onSelected(name),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({
    required this.name,
    required this.accent,
    required this.selected,
    this.onTap,
  });

  final String name;
  final Color accent;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? accent : accent.withValues(alpha: 0.25),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.groups_outlined,
                size: 16,
                color: selected ? Colors.white : accent,
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: selected ? Colors.white : accent.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps screen body content over the warm educational gradient.
class WarmScreenBody extends StatelessWidget {
  const WarmScreenBody({
    super.key,
    required this.child,
    this.accentColor = TeacherTheme.primaryDark,
  });

  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AdminEducationalBackground(accentColor: accentColor),
        Positioned.fill(child: child),
      ],
    );
  }
}

EdgeInsets warmListPadding(BuildContext context) => listPagePadding(context);
