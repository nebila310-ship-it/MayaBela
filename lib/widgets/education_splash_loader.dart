import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mayabela/theme/classroom_palette.dart';

/// One lap of letters, one lap of numbers, then a graduation cap.
/// The cap is the finish line. The lap starts again.
class EducationSplashLoader extends StatefulWidget {
  const EducationSplashLoader({
    super.key,
    this.size = 300,
    this.showLabel = true,
  });

  final double size;
  final bool showLabel;

  static const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
  static const numbers = ['1', '2', '3', '4', '5', '6', '7', '8'];
  static const glyphColors = <Color>[
    ClassroomPalette.pink,
    ClassroomPalette.orange,
    ClassroomPalette.amber,
    ClassroomPalette.green,
    ClassroomPalette.teal,
    ClassroomPalette.cyan,
    ClassroomPalette.blue,
    ClassroomPalette.purple,
  ];

  @override
  State<EducationSplashLoader> createState() => _EducationSplashLoaderState();
}

class _EducationSplashLoaderState extends State<EducationSplashLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle;

  @override
  void initState() {
    super.initState();
    _cycle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6400),
    )..repeat();
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.size <= 0
        ? const SizedBox.shrink()
        : SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: _cycle,
              builder: (context, _) {
                final reduce =
                    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
                return _MilestoneRing(
                  t: reduce ? 0.9 : _cycle.value,
                  size: widget.size,
                );
              },
            ),
          );
    if (!widget.showLabel) return scene;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        scene,
        const SizedBox(height: 12),
        const Text(
          'OPENING CLASS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
            color: ClassroomPalette.purple,
          ),
        ),
      ],
    );
  }
}

class _MilestoneRing extends StatelessWidget {
  const _MilestoneRing({required this.t, required this.size});

  /// 0–0.4 letters, 0.4–0.8 numbers, 0.8–1 graduation cap.
  final double t;
  final double size;

  @override
  Widget build(BuildContext context) {
    final capPhase = t >= 0.8;
    final glyphs = capPhase
        ? const <String>[]
        : (t < 0.4 ? EducationSplashLoader.letters : EducationSplashLoader.numbers);
    final lap = capPhase ? 1.0 : ((t < 0.4 ? t / 0.4 : (t - 0.4) / 0.4));
    final turn = lap * math.pi * 2;
    final capT = capPhase ? ((t - 0.8) / 0.2).clamp(0.0, 1.0) : 0.0;
    final radius = size * 0.40;

    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: Size.square(size),
          painter: _TrackPainter(radius: radius),
        ),
        if (!capPhase)
          for (var i = 0; i < glyphs.length; i++)
            Transform.rotate(
              angle: turn + (i * math.pi * 2 / glyphs.length),
              child: Transform.translate(
                offset: Offset(0, -radius),
                child: Transform.rotate(
                  angle: -(turn + (i * math.pi * 2 / glyphs.length)),
                  child: Text(
                    glyphs[i],
                    style: TextStyle(
                      fontSize: size * 0.105,
                      fontWeight: FontWeight.w900,
                      color: EducationSplashLoader.glyphColors[i],
                      shadows: const [
                        Shadow(color: Color(0xCCFFFFFF), blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        if (capPhase)
          Opacity(
            opacity: Curves.easeOut.transform(capT.clamp(0.0, 1.0)),
            child: Transform.scale(
              scale: 0.35 + 0.65 * Curves.elasticOut.transform(capT),
              child: CustomPaint(
                size: Size.square(size * 0.42),
                painter: const _GraduationCapPainter(),
              ),
            ),
          ),
      ],
    );
  }
}

class _TrackPainter extends CustomPainter {
  const _TrackPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFC2185B),
          Color(0xFFE37400),
          Color(0xFFF9AB00),
          Color(0xFF1E8E3E),
          Color(0xFF00897B),
          Color(0xFF1A73E8),
          Color(0xFF6A1B9A),
          Color(0xFFC2185B),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      center + Offset(0, -radius),
      6,
      Paint()..color = const Color(0xFFF9AB00),
    );
  }

  @override
  bool shouldRepaint(covariant _TrackPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

class _GraduationCapPainter extends CustomPainter {
  const _GraduationCapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.translate(w / 2, h / 2);
    final board = Path()
      ..moveTo(0, -h * 0.32)
      ..lineTo(w * 0.48, -h * 0.02)
      ..lineTo(0, h * 0.28)
      ..lineTo(-w * 0.48, -h * 0.02)
      ..close();
    canvas.drawPath(board, Paint()..color = const Color(0xFF6A1B9A));
    final shine = Path()
      ..moveTo(0, -h * 0.24)
      ..lineTo(w * 0.32, -h * 0.04)
      ..lineTo(0, h * 0.08)
      ..lineTo(-w * 0.2, -h * 0.08)
      ..close();
    canvas.drawPath(shine, Paint()..color = const Color(0xFFAB47BC));
    canvas.drawCircle(
      Offset(0, -h * 0.02),
      w * 0.05,
      Paint()..color = const Color(0xFFFFD54F),
    );
    canvas.drawLine(
      Offset.zero,
      Offset(w * 0.18, h * 0.32),
      Paint()
        ..color = const Color(0xFFF9AB00)
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(w * 0.18, h * 0.36),
      w * 0.06,
      Paint()..color = const Color(0xFFE37400),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
