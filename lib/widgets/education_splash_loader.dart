import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mayabela/theme/classroom_palette.dart';

/// Opening scene: a graduation cap turns, a pencil travels with it,
/// and a book rests underneath. Used on the first Flutter frame.
class EducationSplashLoader extends StatefulWidget {
  const EducationSplashLoader({
    super.key,
    this.size = 240,
    this.showLabel = true,
  });

  final double size;
  final bool showLabel;

  @override
  State<EducationSplashLoader> createState() => _EducationSplashLoaderState();
}

class _EducationSplashLoaderState extends State<EducationSplashLoader>
    with TickerProviderStateMixin {
  late final AnimationController _orbit;
  late final AnimationController _cap;
  late final AnimationController _write;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
    _cap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _write = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbit.dispose();
    _cap.dispose();
    _write.dispose();
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
              animation: Listenable.merge([_orbit, _cap, _write]),
              builder: (context, _) {
                final reduce =
                    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
                final orbit = reduce ? 0.0 : _orbit.value;
                final capTurn = reduce ? 0.15 : _cap.value;
                final write = reduce ? 0.0 : _write.value;
                return _EducationScene(
                  orbit: orbit,
                  capTurn: capTurn,
                  write: write,
                );
              },
            ),
          );
    if (!widget.showLabel) return scene;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        scene,
        const SizedBox(height: 10),
        const _OpeningClassLabel(),
      ],
    );
  }
}

class _OpeningClassLabel extends StatefulWidget {
  const _OpeningClassLabel();

  @override
  State<_OpeningClassLabel> createState() => _OpeningClassLabelState();
}

class _OpeningClassLabelState extends State<_OpeningClassLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shift;

  static const _colors = <Color>[
    ClassroomPalette.purple,
    ClassroomPalette.blue,
    ClassroomPalette.teal,
    ClassroomPalette.orange,
    ClassroomPalette.pink,
  ];

  @override
  void initState() {
    super.initState();
    _shift = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
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
        final index = (_shift.value * _colors.length).floor() % _colors.length;
        return Text(
          'OPENING CLASS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
            color: _colors[index],
          ),
        );
      },
    );
  }
}

class _EducationScene extends StatelessWidget {
  const _EducationScene({
    required this.orbit,
    required this.capTurn,
    required this.write,
  });

  final double orbit;
  final double capTurn;
  final double write;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const _ColorWash(),
        const _LetterChip(letter: 'A', color: ClassroomPalette.pink, dx: -0.72, dy: -0.42),
        const _LetterChip(letter: 'B', color: ClassroomPalette.blue, dx: 0.74, dy: -0.18),
        const _LetterChip(letter: 'C', color: ClassroomPalette.green, dx: 0.62, dy: 0.55),
        Transform.rotate(
          angle: orbit * math.pi * 2,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Transform.rotate(
                  angle: capTurn * math.pi * 2,
                  child: const CustomPaint(
                    size: Size(58, 58),
                    painter: _GraduationCapPainter(),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Transform.rotate(
                  angle: -orbit * math.pi * 2 + (write - 0.5) * 0.45,
                  child: const CustomPaint(
                    size: Size(36, 64),
                    painter: _PencilPainter(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Transform.scale(
            scale: 1 + write * 0.06,
            child: const CustomPaint(
              size: Size(78, 36),
              painter: _OpenBookPainter(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorWash extends StatelessWidget {
  const _ColorWash();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        _Blob(color: Color(0xFFFFE082), alignment: Alignment(-0.85, -0.8), diameter: 72),
        _Blob(color: Color(0xFFCE93D8), alignment: Alignment(0.9, -0.72), diameter: 64),
        _Blob(color: Color(0xFF80DEEA), alignment: Alignment(0.86, 0.78), diameter: 70),
        _Blob(color: Color(0xFFA5D6A7), alignment: Alignment(-0.82, 0.7), diameter: 58),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.color,
    required this.alignment,
    required this.diameter,
  });

  final Color color;
  final Alignment alignment;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _LetterChip extends StatelessWidget {
  const _LetterChip({
    required this.letter,
    required this.color,
    required this.dx,
    required this.dy,
  });

  final String letter;
  final Color color;
  final double dx;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(dx, dy),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: color,
          shadows: const [
            Shadow(color: Color(0x33FFFFFF), blurRadius: 4),
          ],
        ),
      ),
    );
  }
}

class _GraduationCapPainter extends CustomPainter {
  const _GraduationCapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.translate(w / 2, h / 2);
    final board = Path()
      ..moveTo(0, -h * 0.30)
      ..lineTo(w * 0.46, -h * 0.02)
      ..lineTo(0, h * 0.26)
      ..lineTo(-w * 0.46, -h * 0.02)
      ..close();
    canvas.drawPath(board, Paint()..color = const Color(0xFF6A1B9A));
    final shine = Path()
      ..moveTo(0, -h * 0.24)
      ..lineTo(w * 0.34, -h * 0.04)
      ..lineTo(0, h * 0.08)
      ..lineTo(-w * 0.22, -h * 0.08)
      ..close();
    canvas.drawPath(shine, Paint()..color = const Color(0xFFAB47BC));
    canvas.drawCircle(
      const Offset(0, -1),
      3.4,
      Paint()..color = const Color(0xFFFFD54F),
    );
    final tassel = Paint()
      ..color = const Color(0xFFF9AB00)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(w * 0.18, h * 0.28), tassel);
    canvas.drawCircle(
      Offset(w * 0.18, h * 0.32),
      4.2,
      Paint()..color = const Color(0xFFE37400),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PencilPainter extends CustomPainter {
  const _PencilPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final left = w * 0.30;
    final bodyWidth = w * 0.40;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, h * 0.16, bodyWidth, h * 0.50),
      const Radius.circular(2),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFFF9AB00));
    canvas.drawRect(
      Rect.fromLTWH(left, h * 0.30, bodyWidth, h * 0.07),
      Paint()..color = const Color(0xFF1A73E8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, h * 0.06, bodyWidth, h * 0.12),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFF48FB1),
    );
    canvas.drawRect(
      Rect.fromLTWH(left, h * 0.16, bodyWidth, h * 0.05),
      Paint()..color = const Color(0xFF90A4AE),
    );
    final wood = Path()
      ..moveTo(left, h * 0.66)
      ..lineTo(left + bodyWidth, h * 0.66)
      ..lineTo(w / 2, h * 0.92)
      ..close();
    canvas.drawPath(wood, Paint()..color = const Color(0xFFFFCC80));
    final lead = Path()
      ..moveTo(left + bodyWidth * 0.28, h * 0.78)
      ..lineTo(left + bodyWidth * 0.72, h * 0.78)
      ..lineTo(w / 2, h * 0.92)
      ..close();
    canvas.drawPath(lead, Paint()..color = const Color(0xFF424242));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OpenBookPainter extends CustomPainter {
  const _OpenBookPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final left = Path()
      ..moveTo(w * 0.50, h * 0.22)
      ..quadraticBezierTo(w * 0.18, h * 0.05, w * 0.04, h * 0.28)
      ..lineTo(w * 0.08, h * 0.86)
      ..quadraticBezierTo(w * 0.24, h * 0.70, w * 0.50, h * 0.78)
      ..close();
    final right = Path()
      ..moveTo(w * 0.50, h * 0.22)
      ..quadraticBezierTo(w * 0.82, h * 0.05, w * 0.96, h * 0.28)
      ..lineTo(w * 0.92, h * 0.86)
      ..quadraticBezierTo(w * 0.76, h * 0.70, w * 0.50, h * 0.78)
      ..close();
    canvas.drawPath(left, Paint()..color = const Color(0xFF1A73E8));
    canvas.drawPath(right, Paint()..color = const Color(0xFF00897B));
    final pageL = Path()
      ..moveTo(w * 0.50, h * 0.30)
      ..quadraticBezierTo(w * 0.24, h * 0.18, w * 0.12, h * 0.34)
      ..lineTo(w * 0.15, h * 0.78)
      ..quadraticBezierTo(w * 0.28, h * 0.66, w * 0.50, h * 0.72)
      ..close();
    final pageR = Path()
      ..moveTo(w * 0.50, h * 0.30)
      ..quadraticBezierTo(w * 0.76, h * 0.18, w * 0.88, h * 0.34)
      ..lineTo(w * 0.85, h * 0.78)
      ..quadraticBezierTo(w * 0.72, h * 0.66, w * 0.50, h * 0.72)
      ..close();
    canvas.drawPath(pageL, Paint()..color = const Color(0xFFFFF8E1));
    canvas.drawPath(pageR, Paint()..color = const Color(0xFFE3F2FD));
    canvas.drawLine(
      Offset(w * 0.50, h * 0.24),
      Offset(w * 0.50, h * 0.80),
      Paint()
        ..color = const Color(0xFF6A1B9A)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
