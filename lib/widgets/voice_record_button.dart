import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/voice_message_service.dart';

/// Mic button — hold to record; sends on release when [sendOnRelease] is true.
class VoiceRecordButton extends StatefulWidget {
  const VoiceRecordButton({
    super.key,
    required this.onRecorded,
    this.color,
    this.enabled = true,
    this.sendOnRelease = false,
  });

  final ValueChanged<AnnouncementAttachment> onRecorded;
  final Color? color;
  final bool enabled;
  final bool sendOnRelease;

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  final _voice = VoiceMessageService.instance;
  bool _busy = false;

  Future<void> _finishRecording() async {
    if (!_voice.isRecording) return;
    setState(() => _busy = true);
    try {
      final attachment = await _voice.stopRecording();
      if (!mounted) return;
      if (attachment != null) {
        widget.onRecorded(attachment);
      } else {
        _showSnack(AppLocale.instance.strings.voiceRecordFailed);
      }
      setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startRecording() async {
    if (!widget.enabled || _busy || _voice.isRecording) return;
    setState(() => _busy = true);
    try {
      final started = await _voice.startRecording();
      if (!mounted) return;
      if (!started) {
        _showSnack(AppLocale.instance.strings.voicePermissionDenied);
      }
      setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleRecord() async {
    if (!widget.enabled || _busy) return;
    if (_voice.isRecording) {
      await _finishRecording();
    } else {
      await _startRecording();
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
    final recording = _voice.isRecording;
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    if (widget.sendOnRelease) {
      return GestureDetector(
        onLongPressStart: (_) => _startRecording(),
        onLongPressEnd: (_) => _finishRecording(),
        onLongPressCancel: () {
          if (_voice.isRecording) _finishRecording();
        },
        child: IconButton(
          tooltip: AppLocale.instance.strings.voiceHoldToRecord,
          onPressed: null,
          icon: _busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              : Icon(
                  recording ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: recording ? Colors.red : color,
                ),
        ),
      );
    }

    return IconButton(
      tooltip: recording
          ? AppLocale.instance.strings.voiceStopRecording
          : AppLocale.instance.strings.voiceStartRecording,
      onPressed: (!widget.enabled || _busy) ? null : _toggleRecord,
      icon: _busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(
              recording ? Icons.stop_circle_rounded : Icons.mic_rounded,
              color: recording ? Colors.red : color,
            ),
    );
  }
}

/// Chip shown while a voice clip waits to be sent.
class PendingVoiceAttachmentChip extends StatelessWidget {
  const PendingVoiceAttachmentChip({super.key, required this.onRemove});

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return InputChip(
      avatar: const Icon(Icons.mic_rounded, size: 18),
      label: Text(s.voiceMessageReady),
      onDeleted: onRemove,
    );
  }
}
