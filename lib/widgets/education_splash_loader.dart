import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gold rider laps the ring and lights each letter it passes, then each
/// number, then a graduation cap marks the finish. [center] sits in its own
/// medallion inside the ring so the orbit never crosses the school mark.
class EducationSplashLoader extends StatefulWidget {
  const EducationSplashLoader({
    super.key,
    this.size = 300,
    this.showLabel = true,
    this.center,
  });

  final double size;
  final bool showLabel;
  final Widget? center;

  static const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
  static const numbers = ['1', '2', '3', '4', '5', '6', '7', '8'];
  static const glyphColors = <Color>[
    Color(0xFFFFD54F),
    Color(0xFFFFB74D),
    Color(0xFFF48FB1),
    Color(0xFFCE93D8),
    Color(0xFF90CAF9),
    Color(0xFF4DD0E1),
    Color(0xFF80CBC4),
    Color(0xFFC5E1A5),
  ];

  static const gold = Color(0xFFFFD54F);

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
      duration: const Duration(milliseconds: 6600),
    )..repeat();
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final scene = widget.size <= 0
        ? const SizedBox.shrink()
        : SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: _cycle,
              builder: (context, child) => _MilestoneOrbit(
                t: reduce ? 0.9 : _cycle.value,
                size: widget.size,
                center: child,
              ),
              child: widget.center,
            ),
          );
    if (!widget.showLabel) return scene;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        scene,
        if (widget.size > 0) const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [Color(0xFFFFE082), Colors.white, Color(0xFFFFB300)],
          ).createShader(rect),
          child: const Text(
            'OPENING CLASS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ShimmerBar(controller: _cycle, still: reduce),
      ],
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  const _ShimmerBar({required this.controller, required this.still});

  final Animation<double> controller;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: 150,
        height: 3,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final x = still ? 0.3 : (controller.value * 4.4) % 1.0;
            return CustomPaint(painter: _BarPainter(x));
          },
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter(this.x);

  final double x;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
    final w = size.width * 0.4;
    final left = -w + (size.width + w) * x;
    final rect = Rect.fromLTWH(left, 0, w, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00FFD54F), Color(0xFFFFD54F), Color(0xFF26C6DA)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.x != x;
}

class _MilestoneOrbit extends StatelessWidget {
  const _MilestoneOrbit({required this.t, required this.size, this.center});

  /// 0–0.4 letters lap, 0.4–0.8 numbers lap, 0.8–1 graduation cap.
  final double t;
  final double size;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final capPhase = t >= 0.8;
    final glyphs = t < 0.4
        ? EducationSplashLoader.letters
        : EducationSplashLoader.numbers;
    final lap = capPhase ? 1.0 : (t < 0.4 ? t / 0.4 : (t - 0.4) / 0.4);
    final capT = capPhase ? ((t - 0.8) / 0.2).clamp(0.0, 1.0) : 0.0;
    final ringRadius = size * 0.41;
    final glyphRadius = size * 0.475;
    final medal = size * 0.58;
    final c = size / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _OrbitPainter(
              radius: ringRadius,
              lap: lap,
              showRider: !capPhase,
            ),
          ),
        ),
        for (var i = 0; i < glyphs.length; i++)
          _glyph(i, glyphs[i], lap, c, glyphRadius),
        Positioned(
          left: c - medal / 2,
          top: c - medal / 2,
          width: medal,
          height: medal,
          child: _Medallion(
            glow: capPhase ? math.sin(capT * math.pi) : 0,
            child: center,
          ),
        ),
        if (capPhase)
          Positioned(
            left: c - size * 0.1,
            top: c - ringRadius - size * 0.13,
            width: size * 0.2,
            height: size * 0.2,
            child: Opacity(
              opacity: Curves.easeOut.transform((capT * 3).clamp(0.0, 1.0)),
              child: Transform.scale(
                scale: 0.4 + 0.6 * Curves.elasticOut.transform(capT),
                child: const CustomPaint(painter: _GraduationCapPainter()),
              ),
            ),
          ),
      ],
    );
  }

  Widget _glyph(int i, String ch, double lap, double c, double r) {
    final at = (i + 0.5) / 8;
    final angle = -math.pi / 2 + at * math.pi * 2;
    final since = lap - at;
    final lit = since >= 0;
    final pop = lit && since < 0.08 ? math.sin(since / 0.08 * math.pi) : 0.0;
    final box = size * 0.1;
    final color = lit
        ? Color.lerp(
            EducationSplashLoader.glyphColors[i],
            EducationSplashLoader.gold,
            pop,
          )!
        : Colors.white.withValues(alpha: 0.28);
    return Positioned(
      left: c + r * math.cos(angle) - box / 2,
      top: c + r * math.sin(angle) - box / 2,
      width: box,
      height: box,
      child: Transform.scale(
        scale: 1 + 0.45 * pop,
        child: Center(
          child: Text(
            ch,
            style: TextStyle(
              fontSize: size * 0.056,
              fontWeight: FontWeight.w800,
              color: color,
              shadows: lit
                  ? [
                      Shadow(
                        color: color.withValues(alpha: 0.8),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _Medallion extends StatelessWidget {
  const _Medallion({required this.glow, this.child});

  final double glow;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE082),
            Color(0xFFFFB300),
            Color(0xFF8D6E63),
            Color(0xFFFFE082),
          ],
          stops: [0, 0.4, 0.7, 1],
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFFFFE082).withValues(alpha: 0.45 * glow),
            blurRadius: 44,
            spreadRadius: 2 * glow,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipOval(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.4),
                colors: [Colors.white, Color(0xFFF6F7FB), Color(0xFFE8EAF6)],
                stops: [0, 0.7, 1],
              ),
            ),
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.8,
                heightFactor: 0.8,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({
    required this.radius,
    required this.lap,
    required this.showRider,
  });

  final double radius;
  final double lap;
  final bool showRider;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white.withValues(alpha: 0.14),
    );
    if (lap > 0) {
      final sweep = lap * math.pi * 2;
      final fill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.max(sweep, 0.01),
          colors: const [
            Color(0xFFFFE082),
            Color(0xFFFFB300),
            Color(0xFF26C6DA),
            Color(0xFFCE93D8),
          ],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = const Color(0x55FFC107)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawArc(rect, -math.pi / 2, sweep, false, fill);
    }
    if (showRider) {
      final a = -math.pi / 2 + lap * math.pi * 2;
      final p = center + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.drawCircle(
        p,
        14,
        Paint()
          ..color = const Color(0xAAFFC107)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawCircle(p, 11, Paint()..color = const Color(0x73FFD54F));
      canvas.drawCircle(p, 7, Paint()..color = const Color(0xFFFFF8E1));
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) =>
      old.lap != lap || old.radius != radius || old.showRider != showRider;
}

class _GraduationCapPainter extends CustomPainter {
  const _GraduationCapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFFFF8E1);
    final crown = Path()
      ..moveTo(16, 30)
      ..lineTo(16, 42)
      ..cubicTo(16, 48, 48, 48, 48, 42)
      ..lineTo(48, 30)
      ..lineTo(32, 38)
      ..close();
    final board = Path()
      ..moveTo(32, 10)
      ..lineTo(60, 24)
      ..lineTo(32, 38)
      ..lineTo(4, 24)
      ..close();
    canvas.drawShadow(board, Colors.black, 4, false);
    canvas.drawPath(crown, Paint()..color = const Color(0xFFFF8F00));
    canvas.drawPath(crown, edge);
    canvas.drawPath(board, Paint()..color = EducationSplashLoader.gold);
    canvas.drawPath(board, edge);
    canvas.drawPath(
      Path()
        ..moveTo(32, 14)
        ..lineTo(50, 23)
        ..lineTo(32, 30)
        ..lineTo(18, 22)
        ..close(),
      Paint()..color = const Color(0xFFFFE082),
    );
    canvas.drawCircle(
      const Offset(32, 24),
      2.6,
      Paint()..color = const Color(0xFF1A237E),
    );
    canvas.drawPath(
      Path()
        ..moveTo(32, 24)
        ..lineTo(52, 32)
        ..lineTo(52, 46),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFF8E1),
    );
    canvas.drawCircle(
      const Offset(52, 49),
      3.4,
      Paint()..color = const Color(0xFFFFF8E1),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
