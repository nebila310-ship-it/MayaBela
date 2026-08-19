import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/voice_message_service.dart';

/// Chat composer: attachment + message/waveform field + mic beside send.
class MessageVoiceInputBar extends StatefulWidget {
  const MessageVoiceInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onSendVoice,
    required this.onPickAttachment,
    this.accent = const Color(0xFF4F46E5),
    this.enabled = true,
    this.pickingAttachment = false,
    this.hintText,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final void Function(AnnouncementAttachment attachment) onSendVoice;
  final VoidCallback onPickAttachment;
  final Color accent;
  final bool enabled;
  final bool pickingAttachment;
  final String? hintText;

  @override
  State<MessageVoiceInputBar> createState() => _MessageVoiceInputBarState();
}

class _MessageVoiceInputBarState extends State<MessageVoiceInputBar> {
  final _voice = VoiceMessageService.instance;
  StreamSubscription<List<double>>? _ampSub;
  List<double> _samples = const [];
  bool _recording = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _recording = _voice.isRecording;
    _samples = _voice.currentSamples;
    _ampSub = _voice.amplitudeStream.listen((samples) {
      if (!mounted) return;
      setState(() => _samples = samples);
    });
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!widget.enabled || _busy || _recording) return;
    setState(() => _busy = true);
    try {
      final started = await _voice.startRecording();
      if (!mounted) return;
      if (!started) {
        _showSnack(AppLocale.instance.strings.voicePermissionDenied);
      } else {
        setState(() => _recording = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopAndSend() async {
    if (!_recording || _busy) return;
    setState(() => _busy = true);
    try {
      final attachment = await _voice.stopRecording();
      if (!mounted) return;
      setState(() => _recording = false);
      if (attachment != null) {
        widget.onSendVoice(attachment);
      } else {
        _showSnack(AppLocale.instance.strings.voiceRecordFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final canInteract = widget.enabled && !_busy;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          tooltip: s.messageAddAttachment,
          onPressed: canInteract && !widget.pickingAttachment
              ? widget.onPickAttachment
              : null,
          icon: widget.pickingAttachment
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.accent,
                  ),
                )
              : Icon(Icons.attach_file_rounded, color: widget.accent),
        ),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _recording
                  ? widget.accent.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _recording
                    ? widget.accent.withValues(alpha: 0.45)
                    : Colors.grey.shade200,
              ),
            ),
            child: _recording
                ? Row(
                    children: [
                      Icon(Icons.mic_rounded, color: Colors.red.shade600, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: VoiceWaveform(samples: _samples, color: widget.accent),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.voiceHoldToRecord.split(',').first,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : TextField(
                    controller: widget.controller,
                    enabled: canInteract,
                    decoration: InputDecoration(
                      hintText: widget.hintText ?? s.typeMessage,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => widget.onSend(),
                  ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: _recording ? s.voiceStopRecording : s.voiceStartRecording,
          onPressed: canInteract
              ? () async {
                  if (_recording) {
                    await _stopAndSend();
                  } else {
                    await _startRecording();
                  }
                }
              : null,
          icon: _busy
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.accent,
                  ),
                )
              : Icon(
                  _recording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                  color: _recording ? Colors.red : widget.accent,
                ),
        ),
        IconButton.filled(
          onPressed: canInteract && !_recording ? widget.onSend : null,
          icon: const Icon(Icons.send_rounded),
          style: IconButton.styleFrom(
            backgroundColor: widget.accent,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Live amplitude bars from microphone input.
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.samples,
    required this.color,
  });

  final List<double> samples;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WaveformPainter(samples: samples, color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.samples, required this.color});

  final List<double> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 48;
    final barWidth = size.width / barCount;
    final gap = barWidth * 0.28;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < barCount; i++) {
      final sampleIndex = samples.length - barCount + i;
      final amplitude = sampleIndex >= 0 ? samples[sampleIndex] : 0.04;
      final barHeight = (amplitude * size.height).clamp(3.0, size.height);
      final x = i * barWidth + gap / 2;
      final y = (size.height - barHeight) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth - gap, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.samples != samples || oldDelegate.color != color;
  }
}
