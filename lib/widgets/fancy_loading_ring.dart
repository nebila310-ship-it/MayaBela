import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mayabela/theme/classroom_palette.dart';

/// Color-shifting, pattern-changing ring so a long load does not look frozen.
class FancyLoadingRing extends StatefulWidget {
  const FancyLoadingRing({
    super.key,
    this.size = 72,
    this.showLabel = true,
  });

  final double size;
  final bool showLabel;

  static const palette = <Color>[
    ClassroomPalette.teal,
    ClassroomPalette.cyan,
    ClassroomPalette.blue,
    ClassroomPalette.purple,
    ClassroomPalette.pink,
    ClassroomPalette.orange,
    ClassroomPalette.amber,
    ClassroomPalette.green,
  ];

  @override
  State<FancyLoadingRing> createState() => _FancyLoadingRingState();
}

class _FancyLoadingRingState extends State<FancyLoadingRing>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _shift;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shift = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    _shift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = widget.size <= 0
        ? const SizedBox.shrink()
        : SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: Listenable.merge([_spin, _shift]),
              builder: (context, _) {
                return CustomPaint(
                  painter: _FancyLoadingRingPainter(
                    spin: _spin.value,
                    shift: _shift.value,
                  ),
                );
              },
            ),
          );
    if (!widget.showLabel) return ring;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ring,
        const SizedBox(height: 10),
        const _ShiftingLoadingLabel(),
      ],
    );
  }
}

class _ShiftingLoadingLabel extends StatefulWidget {
  const _ShiftingLoadingLabel();

  @override
  State<_ShiftingLoadingLabel> createState() => _ShiftingLoadingLabelState();
}

class _ShiftingLoadingLabelState extends State<_ShiftingLoadingLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shift;

  @override
  void initState() {
    super.initState();
    _shift = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _shift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shift,
      builder: (context, _) {
        final colors = FancyLoadingRing.palette;
        final start = (_shift.value * colors.length).floor() % colors.length;
        return Text(
          'LOADING',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.6,
            color: colors[start],
          ),
        );
      },
    );
  }
}

class _FancyLoadingRingPainter extends CustomPainter {
  _FancyLoadingRingPainter({
    required this.spin,
    required this.shift,
  });

  final double spin;
  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final colors = FancyLoadingRing.palette;
    final offset = (shift * colors.length).floor();
    final swept = <Color>[
      for (var i = 0; i < colors.length; i++) colors[(i + offset) % colors.length],
      colors[offset % colors.length],
    ];

    final outerRect = Rect.fromCircle(center: center, radius: radius - 5);
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: spin * math.pi * 2,
        colors: swept,
      ).createShader(outerRect);

    final dashOn = 16 + 28 * (0.5 + 0.5 * math.sin(shift * math.pi * 2));
    final dashOff = 10 + 18 * (0.5 + 0.5 * math.cos(shift * math.pi * 2));
    _dashedCircle(
      canvas,
      center,
      radius - 5,
      outerPaint,
      dashOn,
      dashOff,
      spin * math.pi * 2,
    );

    final innerRect = Rect.fromCircle(center: center, radius: radius - 16);
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -spin * math.pi * 2,
        colors: swept.reversed.toList(),
      ).createShader(innerRect);
    _dashedCircle(
      canvas,
      center,
      radius - 16,
      innerPaint,
      8 + 10 * shift,
      14 + 8 * (1 - shift),
      -spin * math.pi * 2.4,
    );

    final beadAngle = spin * math.pi * 2;
    final bead = Offset(
      center.dx + math.cos(beadAngle - math.pi / 2) * (radius - 5),
      center.dy + math.sin(beadAngle - math.pi / 2) * (radius - 5),
    );
    final beadColor = colors[offset % colors.length];
    canvas.drawCircle(
      bead,
      5,
      Paint()
        ..color = beadColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(bead, 4, Paint()..color = beadColor);
  }

  void _dashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
    double dashOn,
    double dashOff,
    double rotation,
  ) {
    final circumference = 2 * math.pi * radius;
    final on = dashOn.clamp(4, 80);
    final off = dashOff.clamp(4, 80);
    var travelled = 0.0;
    var drawing = true;
    while (travelled < circumference) {
      final span = drawing ? on : off;
      final next = math.min(travelled + span, circumference);
      if (drawing) {
        final start = rotation + (travelled / radius);
        final sweep = (next - travelled) / radius;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          paint,
        );
      }
      travelled = next;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(covariant _FancyLoadingRingPainter oldDelegate) {
    return oldDelegate.spin != spin || oldDelegate.shift != shift;
  }
}
