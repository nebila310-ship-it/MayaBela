import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';

class StaffPalette {
  StaffPalette._({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.gradient,
    required this.icon,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final List<Color> gradient;
  final IconData icon;

  static StaffPalette teachers = StaffPalette._(
    primary: const Color(0xFF3949AB),
    secondary: const Color(0xFF5C6BC0),
    accent: const Color(0xFF7986CB),
    gradient: const [Color(0xFF283593), Color(0xFF3949AB), Color(0xFF5C6BC0)],
    icon: Icons.school_rounded,
  );

  static StaffPalette transport = StaffPalette._(
    primary: const Color(0xFFE65100),
    secondary: const Color(0xFFEF6C00),
    accent: const Color(0xFFFFB74D),
    gradient: const [Color(0xFFBF360C), Color(0xFFE65100), Color(0xFFFF9800)],
    icon: Icons.directions_bus_rounded,
  );

  static StaffPalette employees = StaffPalette._(
    primary: const Color(0xFF546E7A),
    secondary: const Color(0xFF78909C),
    accent: const Color(0xFF90A4AE),
    gradient: const [Color(0xFF37474F), Color(0xFF546E7A), Color(0xFF78909C)],
    icon: Icons.badge_outlined,
  );

  static StaffPalette students = StaffPalette._(
    primary: const Color(0xFF00796B),
    secondary: const Color(0xFF26A69A),
    accent: const Color(0xFF4DB6AC),
    gradient: const [Color(0xFF004D40), Color(0xFF00796B), Color(0xFF26A69A)],
    icon: Icons.person_rounded,
  );
}

class StaffStatChip extends StatelessWidget {
  const StaffStatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.32),
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                      shadows: [
                        Shadow(
                          color: Color(0x44000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StaffMemberCard extends StatelessWidget {
  const StaffMemberCard({
    super.key,
    required this.palette,
    required this.name,
    required this.subtitle,
    required this.staffId,
    required this.avatar,
    required this.onTap,
    this.trailingChip,
    this.extraChips = const [],
  });

  final StaffPalette palette;
  final String name;
  final String subtitle;
  final String staffId;
  final Widget avatar;
  final VoidCallback onTap;
  final String? trailingChip;
  final List<String> extraChips;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                palette.primary.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.primary.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: palette.gradient),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: avatar,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _miniChip(staffId, palette.primary),
                          if (trailingChip != null)
                            _miniChip(trailingChip!, palette.secondary),
                          for (final chip in extraChips)
                            _miniChip(chip, palette.accent),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: palette.primary.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Large profile photo — editable only when [onChangePhoto] is provided (admin screens).
class AdminProfilePhotoHeader extends StatelessWidget {
  const AdminProfilePhotoHeader({
    super.key,
    required this.palette,
    required this.name,
    required this.staffId,
    required this.avatar,
    required this.subtitleLines,
    this.onChangePhoto,
  });

  final StaffPalette palette;
  final String name;
  final String staffId;
  final Widget avatar;
  final List<String> subtitleLines;
  final VoidCallback? onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Icon(
              palette.icon,
              size: 140,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white,
                        child: avatar,
                      ),
                    ),
                    if (onChangePhoto != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 4,
                          child: InkWell(
                            onTap: onChangePhoto,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: palette.primary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  staffId,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final line in subtitleLines) ...[
                  const SizedBox(height: 4),
                  Text(
                    line,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
                if (onChangePhoto != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s.adminOnlyPhotoHint,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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

class StaffInfoTile extends StatelessWidget {
  const StaffInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final valueColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A1A1A);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StaffActionGrid extends StatelessWidget {
  const StaffActionGrid({super.key, required this.actions});

  final List<StaffActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: actions
          .map(
            (action) => SizedBox(
              width: (MediaQuery.of(context).size.width - 52) / 2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: action.onPressed,
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          action.color.withValues(alpha: 0.16),
                          action.color.withValues(alpha: 0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: action.color.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Column(
                        children: [
                          Icon(action.icon, color: action.color, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            action.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: action.color.darken(0.15),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class StaffActionItem {
  const StaffActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
}

extension _ColorShade on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}

class StaffAddBannerButton extends StatelessWidget {
  const StaffAddBannerButton({
    super.key,
    required this.label,
    required this.palette,
    required this.onPressed,
  });

  final String label;
  final StaffPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: palette.gradient),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
