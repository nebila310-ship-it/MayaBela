import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/profile_photo_codec.dart';
import 'package:mayabela/widgets/profile_photo_view.dart';

/// Pick a photo, then let the user zoom / pan it into the circular frame.
Future<Uint8List?> pickAlignedProfilePhoto(BuildContext context) async {
  final raw = await ProfilePhotoCodec.pickBytes();
  if (raw == null) return null;
  if (!context.mounted) return null;
  return showProfilePhotoAlignDialog(context, bytes: raw);
}

Future<Uint8List?> showProfilePhotoAlignDialog(
  BuildContext context, {
  required Uint8List bytes,
}) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ProfilePhotoAlignDialog(bytes: bytes),
  );
}

void showProfilePhotoViewer(
  BuildContext context, {
  Uint8List? bytes,
  String? path,
  String? title,
}) {
  final provider = profilePhotoProvider(bytes: bytes, path: path);
  if (provider == null) return;
  showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title ?? 'Photo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.4,
                  maxScale: 6,
                  child: Center(
                    child: Image(
                      image: provider,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Pinch or scroll to zoom',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class ProfilePhotoAlignDialog extends StatefulWidget {
  const ProfilePhotoAlignDialog({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<ProfilePhotoAlignDialog> createState() => _ProfilePhotoAlignDialogState();
}

class _ProfilePhotoAlignDialogState extends State<ProfilePhotoAlignDialog> {
  static const _frame = 240.0;
  final _boundaryKey = GlobalKey();
  double _zoom = 1.2;
  double _baseZoom = 1.2;
  Offset _pan = Offset.zero;
  var _saving = false;

  void _nudgeZoom(double delta) {
    setState(() {
      _zoom = (_zoom + delta).clamp(1.0, 4.0);
      _baseZoom = _zoom;
    });
  }

  Future<void> _apply() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.pop(context, widget.bytes);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 512 / _frame);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final png = data?.buffer.asUint8List();
      if (!mounted) return;
      Navigator.pop(context, png == null || png.isEmpty ? widget.bytes : png);
    } catch (_) {
      if (mounted) Navigator.pop(context, widget.bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return AlertDialog(
      title: const Text('Align photo'),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            const Text(
              'Zoom and drag so the face sits in the circle, then save.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _nudgeZoom(event.scrollDelta.dy > 0 ? -0.15 : 0.15);
                }
              },
              child: GestureDetector(
                onScaleStart: (_) => _baseZoom = _zoom,
                onScaleUpdate: (details) {
                  setState(() {
                    _zoom = (_baseZoom * details.scale).clamp(1.0, 4.0);
                    _pan += details.focalPointDelta;
                  });
                },
                child: Container(
                  width: _frame + 8,
                  height: _frame + 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: ClipOval(
                    child: SizedBox(
                      width: _frame,
                      height: _frame,
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: Transform.translate(
                          offset: _pan,
                          child: Transform.scale(
                            scale: _zoom,
                            child: Image.memory(
                              widget.bytes,
                              width: _frame,
                              height: _frame,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'Zoom out',
                  onPressed: () => _nudgeZoom(-0.2),
                  icon: const Icon(Icons.zoom_out),
                ),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 4,
                    value: _zoom,
                    onChanged: (v) => setState(() {
                      _zoom = v;
                      _baseZoom = v;
                    }),
                  ),
                ),
                IconButton(
                  tooltip: 'Zoom in',
                  onPressed: () => _nudgeZoom(0.2),
                  icon: const Icon(Icons.zoom_in),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _apply,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Use photo'),
        ),
      ],
    );
  }
}

Future<Uint8List?> pickAlignedPhotoOrSnack(
  BuildContext context, {
  required Future<Uint8List?> Function() pick,
  String? Function()? errorOf,
}) async {
  final raw = await pick();
  if (!context.mounted) return null;
  if (raw == null) {
    final err = errorOf?.call();
    if (err != null && err.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
    return null;
  }
  return showProfilePhotoAlignDialog(context, bytes: raw);
}
