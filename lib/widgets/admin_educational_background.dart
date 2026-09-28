import 'package:flutter/material.dart';

import 'package:mayabela/theme/classroom_palette.dart';

/// Soft Classroom stream backdrop — light gray with colorful class orbs.
class AdminEducationalBackground extends StatelessWidget {
  const AdminEducationalBackground({
    super.key,
    this.accentColor = ClassroomPalette.teal,
  });

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final watermark = ClassroomPalette.ink.withValues(alpha: 0.045);

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF8F9FA),
                Color(0xFFE8F0FE),
                Color(0xFFE6F4EA),
                Color(0xFFFEF7E0),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.38, 0.72, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withValues(alpha: 0.06),
                Colors.transparent,
                ClassroomPalette.pink.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -40,
          right: -10,
          child: _SoftOrb(
            color: ClassroomPalette.blue.withValues(alpha: 0.22),
            size: 200,
          ),
        ),
        Positioned(
          top: 120,
          left: -50,
          child: _SoftOrb(
            color: ClassroomPalette.teal.withValues(alpha: 0.18),
            size: 170,
          ),
        ),
        Positioned(
          bottom: 90,
          right: -30,
          child: _SoftOrb(
            color: ClassroomPalette.orange.withValues(alpha: 0.16),
            size: 160,
          ),
        ),
        Positioned(
          bottom: -30,
          left: 40,
          child: _SoftOrb(
            color: ClassroomPalette.purple.withValues(alpha: 0.14),
            size: 140,
          ),
        ),
        Positioned(
          top: 280,
          right: 80,
          child: _SoftOrb(
            color: ClassroomPalette.pink.withValues(alpha: 0.10),
            size: 110,
          ),
        ),
        _WatermarkIcon(
          icon: Icons.menu_book_outlined,
          color: watermark,
          size: 72,
          top: 40,
          right: 24,
        ),
        _WatermarkIcon(
          icon: Icons.edit_note_rounded,
          color: watermark,
          size: 64,
          top: 120,
          left: 16,
        ),
        _WatermarkIcon(
          icon: Icons.school_outlined,
          color: watermark,
          size: 80,
          bottom: 140,
          right: 40,
        ),
        _WatermarkIcon(
          icon: Icons.palette_outlined,
          color: watermark,
          size: 56,
          bottom: 60,
          left: 28,
        ),
        _WatermarkIcon(
          icon: Icons.auto_stories_outlined,
          color: watermark,
          size: 48,
          centerHorizontally: true,
          bottom: 24,
        ),
      ],
    );
  }
}

class _WatermarkIcon extends StatelessWidget {
  const _WatermarkIcon({
    required this.icon,
    required this.color,
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.centerHorizontally = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final bool centerHorizontally;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: centerHorizontally ? 0 : left,
      right: centerHorizontally ? 0 : right,
      child: centerHorizontally
          ? Center(child: Icon(icon, size: size, color: color))
          : Icon(icon, size: size, color: color),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
