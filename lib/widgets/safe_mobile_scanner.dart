import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/widgets/web_camera_preview_stub.dart'
    if (dart.library.html) 'package:mayabela/widgets/web_camera_preview_web.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera QR scanner that mounts [MobileScanner] after the camera is ready.
///
/// Phone browsers require a tap before `getUserMedia`, so web shows a Start
/// camera button instead of opening the camera on its own.
class SafeMobileScanner extends StatefulWidget {
  const SafeMobileScanner({
    super.key,
    required this.onCode,
    this.height = 260,
    this.unavailableMessage = 'Camera scanner is not available on this device.',
    this.errorMessage = 'Unable to start the camera scanner.',
    this.permissionDeniedMessage =
        'Camera permission is required to scan QR codes.',
    this.startingMessage = 'Starting camera…',
    this.retryLabel = 'Try again',
    this.borderRadius = 16,
    this.showLoadingIndicator = false,
    this.sameCodeCooldown = const Duration(seconds: 2),
    this.onLiveChanged,
  });

  final void Function(String code) onCode;
  final double height;
  final String unavailableMessage;
  final String errorMessage;
  final String permissionDeniedMessage;
  final String startingMessage;
  final String retryLabel;
  final double borderRadius;
  final bool showLoadingIndicator;
  /// Ignore repeat reads of the same QR within this window.
  final Duration sameCodeCooldown;
  /// True once the camera preview is running.
  final ValueChanged<bool>? onLiveChanged;

  @override
  State<SafeMobileScanner> createState() => _SafeMobileScannerState();
}

class _SafeMobileScannerState extends State<SafeMobileScanner> {
  MobileScannerController? _controller;
  var _scannerKey = 0;
  var _starting = false;
  var _cameraLive = false;
  String? _startError;
  final _lastSeenByCode = <String, DateTime>{};

  bool get _canScan {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    if (!_canScan) return;
    if (kIsWeb) prepareWebQrScanner();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_ensureController(autostart: !kIsWeb));
    });
  }

  MobileScannerController _createController() {
    return MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.unrestricted,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  Future<void> _ensureController({required bool autostart}) async {
    if (!mounted || _controller != null || _starting) return;
    if (autostart) {
      // Give the route time to attach before CameraX starts.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted || _controller != null) return;
    }

    final controller = _createController();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _scannerKey++;
      _controller = controller;
    });
    if (!autostart) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _beginScan();
  }

  Future<void> _beginScan() async {
    final controller = _controller;
    if (controller == null || _starting) return;
    _starting = true;
    _startError = null;
    _setLive(false);
    if (mounted) setState(() {});

    try {
      await controller.start();
      if (!mounted) return;
      final error = controller.value.error;
      if (error != null) {
        final message = _messageForError(error);
        if (mounted) setState(() => _startError = message);
        await _swapControllerAfterFailure();
        return;
      }
      if (!mounted) return;
      setState(() => _scannerKey++);
      _setLive(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        markWebCameraPreviewInline();
      });
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) markWebCameraPreviewInline();
    } catch (_) {
      if (mounted) setState(() => _startError = widget.errorMessage);
      await _swapControllerAfterFailure();
    } finally {
      _starting = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _swapControllerAfterFailure() async {
    final old = _controller;
    _controller = null;
    _setLive(false);
    if (old != null) {
      await old.dispose();
    }
    if (!mounted) return;
    final next = _createController();
    setState(() {
      _scannerKey++;
      _controller = next;
    });
    await WidgetsBinding.instance.endOfFrame;
  }

  void _setLive(bool live) {
    if (_cameraLive == live) return;
    _cameraLive = live;
    widget.onLiveChanged?.call(live);
  }

  void _handleDetect(BarcodeCapture capture) {
    final now = DateTime.now();
    final codes = <String>{};
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        codes.add(value);
      }
    }

    for (final code in codes) {
      final lastSeen = _lastSeenByCode[code];
      if (lastSeen != null &&
          now.difference(lastSeen) < widget.sameCodeCooldown) {
        continue;
      }
      _lastSeenByCode[code] = now;
      widget.onCode(code);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _messageForError(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return widget.permissionDeniedMessage;
      case MobileScannerErrorCode.controllerNotAttached:
      case MobileScannerErrorCode.controllerInitializing:
      case MobileScannerErrorCode.controllerAlreadyInitialized:
        return widget.errorMessage;
      default:
        final details = error.errorDetails?.message?.trim();
        if (details == null || details.isEmpty || _looksLikeNativeCrash(details)) {
          return widget.errorMessage;
        }
        return details;
    }
  }

  bool _looksLikeNativeCrash(String message) {
    final lower = message.toLowerCase();
    return lower.contains('virtual method') ||
        lower.contains('null object reference') ||
        lower.contains('mlkit') ||
        RegExp(r'\bm\d+\.\w+\.\w+\.\w+\b').hasMatch(message);
  }

  @override
  Widget build(BuildContext context) {
    if (!_canScan) {
      return _messageCard(
        widget.unavailableMessage,
        Icons.no_photography_outlined,
      );
    }

    final controller = _controller;
    if (controller == null) {
      return _loadingCard();
    }

    final scanner = _scannerView(controller);
    if (_startError != null) {
      return Stack(
        children: [
          Offstage(child: scanner),
          _messageCard(
            _startError!,
            Icons.no_photography_outlined,
            onRetry: _starting ? null : () => unawaited(_beginScan()),
          ),
        ],
      );
    }

    if (kIsWeb && !_cameraLive) {
      final strings = AppLocale.instance.strings;
      return Stack(
        children: [
          Offstage(child: scanner),
          _starting
              ? _loadingCard()
              : _messageCard(
                  strings.startCameraHint,
                  Icons.photo_camera_outlined,
                  onRetry: () => unawaited(_beginScan()),
                  actionLabel: strings.startCamera,
                  actionIcon: Icons.photo_camera_outlined,
                ),
        ],
      );
    }

    return scanner;
  }

  Widget _scannerView(MobileScannerController controller) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        height: widget.height,
        child: MobileScanner(
          key: ValueKey(_scannerKey),
          controller: controller,
          placeholderBuilder: (_) => _loadingCard(),
          errorBuilder: (context, error) => _messageCard(
            _messageForError(error),
            error.errorCode == MobileScannerErrorCode.permissionDenied
                ? Icons.no_photography_outlined
                : Icons.error_outline,
            onRetry: _starting ? null : () => unawaited(_beginScan()),
          ),
          onDetect: _handleDetect,
        ),
      ),
    );
  }

  Widget _loadingCard() {
    return SizedBox(
      height: widget.height,
      child: Center(
        child: widget.showLoadingIndicator
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF00D4FF),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.startingMessage,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }

  Widget _messageCard(
    String message,
    IconData icon, {
    VoidCallback? onRetry,
    String? actionLabel,
    IconData? actionIcon,
  }) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D4FF).withValues(alpha: 0.12),
            const Color(0xFF7C4DFF).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: const Color(0xFF00D4FF).withValues(alpha: 0.35),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: const Color(0xFF5B21B6)),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.blueGrey.shade800,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: Icon(actionIcon ?? Icons.refresh),
                  label: Text(actionLabel ?? widget.retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
