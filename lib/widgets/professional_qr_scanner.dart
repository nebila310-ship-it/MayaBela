import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mayabela/widgets/qr_scanner_theme.dart';
import 'package:mayabela/widgets/safe_mobile_scanner.dart';

/// Bright, polished QR scanner panel with frame overlay and scan animation.
class ProfessionalQrScannerPanel extends StatefulWidget {
  const ProfessionalQrScannerPanel({
    super.key,
    required this.onCode,
    this.title,
    this.subtitle,
    this.height = 340,
    this.theme = QrScannerTheme.attendance,
    this.footerHint,
    this.statusMessage,
    this.statusSuccess = false,
    this.unavailableMessage = 'Camera scanner is not available on this device.',
    this.errorMessage = 'Unable to start the camera scanner.',
    this.permissionDeniedMessage =
        'Camera permission is required to scan QR codes.',
    this.startingMessage = 'Starting camera…',
    this.retryLabel = 'Try again',
  });

  final void Function(String code) onCode;
  final String? title;
  final String? subtitle;
  final double height;
  final QrScannerTheme theme;
  final String? footerHint;
  final String? statusMessage;
  final bool statusSuccess;
  final String unavailableMessage;
  final String errorMessage;
  final String permissionDeniedMessage;
  final String startingMessage;
  final String retryLabel;

  @override
  State<ProfessionalQrScannerPanel> createState() =>
      _ProfessionalQrScannerPanelState();
}

class _ProfessionalQrScannerPanelState extends State<ProfessionalQrScannerPanel>
    with SingleTickerProviderStateMixin {
  Color get _primary => widget.theme.primary;
  Color get _secondary => widget.theme.secondary;
  Color get _accent => widget.theme.accent;

  late final AnimationController _lineController;
  var _flashSuccess = false;

  @override
  void initState() {
    super.initState();
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _lineController.dispose();
    super.dispose();
  }

  void _handleCode(String code) {
    setState(() => _flashSuccess = true);
    widget.onCode(code);
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _flashSuccess = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'Scan QR Code';
    final subtitle = widget.subtitle ??
        'Align the student QR inside the frame for instant lookup.';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primary.withValues(alpha: 0.14),
            _secondary.withValues(alpha: 0.12),
            _accent.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _primary.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _secondary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primary, _secondary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_flashSuccess ? _accent : _primary)
                        .withValues(alpha: 0.35),
                    blurRadius: _flashSuccess ? 28 : 16,
                    spreadRadius: _flashSuccess ? 2 : 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SafeMobileScanner(
                      height: widget.height,
                      onCode: _handleCode,
                      unavailableMessage: widget.unavailableMessage,
                      errorMessage: widget.errorMessage,
                      permissionDeniedMessage: widget.permissionDeniedMessage,
                      startingMessage: widget.startingMessage,
                      retryLabel: widget.retryLabel,
                      borderRadius: 20,
                      showLoadingIndicator: true,
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _lineController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _QrFramePainter(
                                lineProgress: _lineController.value,
                                flash: _flashSuccess,
                                primary: _primary,
                                accent: _accent,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (widget.statusMessage != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _ScannerStatusOverlay(
                          message: widget.statusMessage!,
                          success: widget.statusSuccess,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _accent.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: _secondary.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.footerHint ??
                          widget.theme.footerHint ??
                          'Align QR inside the frame for instant scan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrFramePainter extends CustomPainter {
  _QrFramePainter({
    required this.lineProgress,
    required this.flash,
    required this.primary,
    required this.accent,
  });

  final double lineProgress;
  final bool flash;
  final Color primary;
  final Color accent;

  Color get _corner => primary;
  Color get _cornerAlt => accent;
  Color get _flashColor => accent;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.42);
    final frameSize = math.min(size.width, size.height) * 0.62;
    final left = (size.width - frameSize) / 2;
    final top = (size.height - frameSize) / 2;
    final rect = Rect.fromLTWH(left, top, frameSize, frameSize);

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16))),
      ),
      overlay,
    );

    final cornerPaint = Paint()
      ..color = flash ? _flashColor : _corner
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const arm = 28.0;
    void corner(Offset start, Offset hEnd, Offset vEnd) {
      canvas.drawLine(start, hEnd, cornerPaint);
      canvas.drawLine(start, vEnd, cornerPaint);
    }

    corner(rect.topLeft, rect.topLeft + const Offset(arm, 0),
        rect.topLeft + const Offset(0, arm));
    corner(rect.topRight, rect.topRight + const Offset(-arm, 0),
        rect.topRight + const Offset(0, arm));
    corner(rect.bottomLeft, rect.bottomLeft + const Offset(arm, 0),
        rect.bottomLeft + const Offset(0, -arm));
    corner(rect.bottomRight, rect.bottomRight + const Offset(-arm, 0),
        rect.bottomRight + const Offset(0, -arm));

    final lineY = top + 12 + (frameSize - 24) * lineProgress;
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          _corner.withValues(alpha: 0),
          _cornerAlt,
          _corner.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(left + 8, lineY, frameSize - 16, 2))
      ..strokeWidth = 2.5;

    canvas.drawLine(
      Offset(left + 12, lineY),
      Offset(left + frameSize - 12, lineY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _QrFramePainter oldDelegate) =>
      oldDelegate.lineProgress != lineProgress || oldDelegate.flash != flash;
}

class _ScannerStatusOverlay extends StatelessWidget {
  const _ScannerStatusOverlay({
    required this.message,
    required this.success,
  });

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final bg = success ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final fg = success ? const Color(0xFF166534) : const Color(0xFFB91C1C);
    final icon = success ? Icons.check_circle_rounded : Icons.error_rounded;

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.96),
          border: Border(
            bottom: BorderSide(color: fg.withValues(alpha: 0.25)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen modal with the professional scanner layout.
/// Return `true` from [onCode] to close the dialog after a successful scan.
Future<void> showProfessionalQrScanDialog({
  required BuildContext context,
  required bool Function(String code) onCode,
  String? title,
  String? subtitle,
  String? cancelLabel,
  String unavailableMessage = 'Camera scanner is not available on this device.',
  String errorMessage = 'Unable to start the camera scanner.',
  String permissionDeniedMessage =
      'Camera permission is required to scan QR codes.',
  String startingMessage = 'Starting camera…',
  String retryLabel = 'Try again',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfessionalQrScannerPanel(
              title: title,
              subtitle: subtitle,
              onCode: (code) {
                if (onCode(code)) Navigator.pop(ctx);
              },
              unavailableMessage: unavailableMessage,
              errorMessage: errorMessage,
              permissionDeniedMessage: permissionDeniedMessage,
              startingMessage: startingMessage,
              retryLabel: retryLabel,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF5B21B6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(cancelLabel ?? 'Cancel'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
