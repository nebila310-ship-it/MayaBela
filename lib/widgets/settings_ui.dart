import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';

/// Neutral settings palette — intentionally distinct from role dashboard colors.
class SettingsPalette {
  SettingsPalette._();

  static const primary = Color(0xFF475569);
  static const accent = Color(0xFF7C3AED);
  static const accentSoft = Color(0xFFEDE9FE);
  static const deep = Color(0xFF334155);
  static const surface = Color(0xFFF1F5F9);
  static const card = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const muted = Color(0xFF64748B);

  static const headerGradient = [
    Color(0xFF334155),
    Color(0xFF475569),
    Color(0xFF64748B),
  ];
}

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? scheme.surfaceContainerHigh : SettingsPalette.card;
    final borderColor = isDark ? scheme.outlineVariant : SettingsPalette.border;
    final titleColor = isDark ? scheme.onSurface : SettingsPalette.deep;
    final subtitleColor = isDark ? scheme.onSurfaceVariant : SettingsPalette.muted;
    final iconBg = isDark
        ? scheme.primaryContainer.withValues(alpha: 0.35)
        : SettingsPalette.accentSoft;
    final iconColor = isDark ? scheme.primary : SettingsPalette.accent;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : SettingsPalette.deep)
                .withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: titleColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Custom switch with sliding thumb animation (on / off).
class AnimatedSettingsSwitch extends StatelessWidget {
  const AnimatedSettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  static const _width = 52.0;
  static const _height = 30.0;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onChanged != null;
    final trackColor = !active
        ? Colors.grey.shade300
        : (value ? SettingsPalette.accent : Colors.grey.shade400);

    return GestureDetector(
      onTap: active ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: _width,
        height: _height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(_height / 2),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: _height - 6,
            height: _height - 6,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsToggleTile extends StatelessWidget {
  const SettingsToggleTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dimmed = !enabled || onChanged == null;
    final titleColor = dimmed
        ? scheme.onSurface.withValues(alpha: 0.45)
        : (isDark ? scheme.onSurface : SettingsPalette.deep);
    final subtitleColor = dimmed
        ? scheme.onSurface.withValues(alpha: 0.35)
        : (isDark ? scheme.onSurfaceVariant : SettingsPalette.muted);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                icon,
                size: 22,
                color: dimmed
                    ? scheme.onSurface.withValues(alpha: 0.35)
                    : (isDark ? scheme.primary : SettingsPalette.primary),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: titleColor,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSettingsSwitch(
            value: value,
            onChanged: onChanged,
            enabled: enabled,
          ),
        ],
      ),
    );
  }
}

/// Segmented language control with sliding highlight animation.
class AnimatedLanguageSelector extends StatelessWidget {
  const AnimatedLanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final selected = AppLocale.instance.code;
        final options = [
          ('en', s.english),
          ('am', s.amharic),
          ('om', s.oromo),
        ];
        final index = options.indexWhere((o) => o.$1 == selected);
        final activeIndex = index < 0 ? 0 : index;

        return LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / options.length;
            return Container(
              height: 48,
              decoration: BoxDecoration(
                color: SettingsPalette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SettingsPalette.border),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: activeIndex * segmentWidth + 4,
                    top: 4,
                    bottom: 4,
                    width: segmentWidth - 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: SettingsPalette.accent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: SettingsPalette.accent.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final (code, label) in options)
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => AppLocale.instance.setLanguage(code),
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: selected == code
                                        ? Colors.white
                                        : SettingsPalette.deep,
                                  ),
                                  child: Text(label),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class SettingsActionTile extends StatelessWidget {
  const SettingsActionTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SettingsPalette.surface.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SettingsPalette.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SettingsPalette.border),
                ),
                child: Icon(icon, size: 20, color: SettingsPalette.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: SettingsPalette.deep,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: SettingsPalette.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade500,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsFaqList extends StatelessWidget {
  const SettingsFaqList({super.key, required this.items});

  final List<({String question, String answer})> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: SettingsPalette.surface.withValues(alpha: 0.5),
              collapsedBackgroundColor:
                  SettingsPalette.surface.withValues(alpha: 0.35),
              iconColor: SettingsPalette.accent,
              collapsedIconColor: SettingsPalette.muted,
              title: Text(
                items[i].question,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: SettingsPalette.deep,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    items[i].answer,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: SettingsPalette.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class AnimatedLockTimeoutChip extends StatelessWidget {
  const AnimatedLockTimeoutChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? SettingsPalette.accent : SettingsPalette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? SettingsPalette.accent : SettingsPalette.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: SettingsPalette.accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: selected ? Colors.white : SettingsPalette.deep,
          ),
        ),
      ),
    );
  }
}
