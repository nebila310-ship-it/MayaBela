import 'package:flutter/material.dart';

/// Soft school-themed backdrop for the admin dashboard (background only).
class AdminEducationalBackground extends StatelessWidget {
  const AdminEducationalBackground({
    super.key,
    this.accentColor = const Color(0xFF4527A0),
  });

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final watermark = Color.lerp(accentColor, const Color(0xFF37474F), 0.35)!
        .withValues(alpha: 0.075);

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF0E6D8),
                Color(0xFFDCE8F4),
                Color(0xFFCFDBEA),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withValues(alpha: 0.04),
                Colors.transparent,
                const Color(0xFF37474F).withValues(alpha: 0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        CustomPaint(
          painter: _NotebookLinesPainter(
            lineColor: accentColor.withValues(alpha: 0.085),
            marginColor: const Color(0xFFE57373).withValues(alpha: 0.22),
          ),
        ),
        Positioned(
          top: -30,
          right: -20,
          child: _SoftOrb(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.18),
            size: 180,
          ),
        ),
        Positioned(
          bottom: 80,
          left: -40,
          child: _SoftOrb(
            color: const Color(0xFFFF9800).withValues(alpha: 0.14),
            size: 160,
          ),
        ),
        Positioned(
          bottom: -20,
          right: 30,
          child: _SoftOrb(
            color: accentColor.withValues(alpha: 0.14),
            size: 120,
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
          icon: Icons.calculate_outlined,
          color: watermark,
          size: 56,
          bottom: 60,
          left: 28,
        ),
        _WatermarkIcon(
          icon: Icons.auto_stories_outlined,
          color: watermark,
          size: 48,
          bottom: 24,
          right: null,
          left: null,
          centerHorizontally: true,
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

/// Faint notebook ruled lines — classroom paper feel.
class _NotebookLinesPainter extends CustomPainter {
  _NotebookLinesPainter({
    required this.lineColor,
    required this.marginColor,
  });

  final Color lineColor;
  final Color marginColor;

  @override
  void paint(Canvas canvas, Size size) {
    const lineSpacing = 32.0;
    const topOffset = 48.0;
    const marginX = 56.0;

    final linePaint = Paint()..color = lineColor;
    for (var y = topOffset; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final marginPaint = Paint()
      ..color = marginColor
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(marginX, 0),
      Offset(marginX, size.height),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _NotebookLinesPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.marginColor != marginColor;
}
