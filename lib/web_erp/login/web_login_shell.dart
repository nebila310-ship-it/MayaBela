import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Abstract education / tech background (inspired by EMS login — no stock photo).
class WebLoginBackground extends StatelessWidget {
  const WebLoginBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WebLoginBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _WebLoginBackgroundPainter extends CustomPainter {
  static const _formulas = [
    'E = mc²',
    'x + y + z = 0',
    '∫ f(x) dx',
    'a² + b² = c²',
    'lim x→∞',
    'π ≈ 3.14',
    '∑ n=1',
    'f(x) = ax + b',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE8F4FC),
          Color(0xFFB8E4F5),
          Color(0xFF7EC8E8),
          Color(0xFFD4EEF9),
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    _drawHexGrid(canvas, size);
    _drawFormulas(canvas, size);
    _drawGraduateSilhouette(canvas, size);
    _drawFloatingIcons(canvas, size);
  }

  void _drawHexGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const r = 28.0;
    final h = r * math.sqrt(3);
    for (var row = -1; row < size.height / h + 2; row++) {
      for (var col = -1; col < size.width / (r * 1.5) + 2; col++) {
        final x = col * r * 1.5 + (row.isOdd ? r * 0.75 : 0);
        final y = row * h * 0.5;
        _hexagon(canvas, Offset(x, y), r, paint);
      }
    }
  }

  void _hexagon(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 3 * i - math.pi / 6;
      final p = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawFormulas(Canvas canvas, Size size) {
    final rng = math.Random(42);
    for (var i = 0; i < _formulas.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: _formulas[i],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45 + rng.nextDouble() * 0.2),
            fontSize: 11 + rng.nextDouble() * 6,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          size.width * (0.05 + rng.nextDouble() * 0.55),
          size.height * (0.05 + rng.nextDouble() * 0.85),
        ),
      );
    }
  }

  void _drawGraduateSilhouette(Canvas canvas, Size size) {
    final cx = size.width * 0.78;
    final cy = size.height * 0.42;
    final headR = size.shortestSide * 0.18;

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1565C0).withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: headR * 1.8));
    canvas.drawCircle(Offset(cx, cy), headR * 1.8, glow);

    final head = Paint()..color = const Color(0xFF0D47A1).withValues(alpha: 0.55);
    canvas.drawCircle(Offset(cx, cy), headR, head);

    final cap = Path()
      ..moveTo(cx - headR * 1.1, cy - headR * 0.55)
      ..lineTo(cx + headR * 1.1, cy - headR * 0.55)
      ..lineTo(cx + headR * 0.9, cy - headR * 0.75)
      ..lineTo(cx - headR * 0.9, cy - headR * 0.75)
      ..close();
    canvas.drawPath(cap, head);

    final circuit = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + headR * 0.85 * math.cos(a), cy + headR * 0.85 * math.sin(a)),
        circuit,
      );
    }
    canvas.drawCircle(Offset(cx, cy), headR * 0.3, circuit);
  }

  void _drawFloatingIcons(Canvas canvas, Size size) {
    final iconPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.2), 18, iconPaint);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.12), 12, iconPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.35, size.height * 0.75),
          width: 40,
          height: 28,
        ),
        const Radius.circular(6),
      ),
      iconPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Soft brand watermark on the web login background (left of the sign-in card).
class WebLoginWatermark extends StatelessWidget {
  const WebLoginWatermark({super.key});

  static const assetPath = 'assets/branding/majo_login_watermark.png';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mark = math.min(size.width * 0.38, size.height * 0.52).clamp(220.0, 420.0);

    return IgnorePointer(
      child: Align(
        alignment: const Alignment(-0.62, 0.02),
        child: ShaderMask(
          shaderCallback: (rect) => RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [
              Colors.white,
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.42, 1.0],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: Opacity(
            opacity: 0.12,
            child: Image.asset(
              assetPath,
              width: mark,
              height: mark,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dark navy login card with optional left speech-bubble notch.
class WebLoginCard extends StatelessWidget {
  const WebLoginCard({
    super.key,
    required this.child,
    this.showNotch = true,
  });

  final Widget child;
  final bool showNotch;

  static const cardColor = Color(0xFF162236);
  static const accentOrange = Color(0xFFFFB020);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
        if (showNotch)
          Positioned(
            left: -13,
            top: 0,
            bottom: 0,
            child: Center(
              child: CustomPaint(
                size: const Size(14, 24),
                painter: _LeftNotchPainter(),
              ),
            ),
          ),
      ],
    );
  }
}

class _LeftNotchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = WebLoginCard.cardColor;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

InputDecoration webLoginFieldDecoration({
  required String label,
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  const fieldBg = Color(0xFF1E2F45);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: fieldBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: WebLoginCard.accentOrange, width: 1.5),
    ),
  );
}
