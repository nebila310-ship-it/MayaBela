import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/voice_playback_service.dart';

class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({
    super.key,
    required this.attachment,
    this.isOutgoing = false,
    this.accent = const Color(0xFF4F46E5),
  });

  final AnnouncementAttachment attachment;
  final bool isOutgoing;
  final Color accent;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final _playback = VoicePlaybackService.instance;
  StreamSubscription<PlayerState>? _stateSub;
  PlayerState _state = PlayerState.stopped;
  var _missingFile = false;

  @override
  void initState() {
    super.initState();
    _refreshFileState();
    _stateSub = _playback.onStateChanged.listen((state) {
      if (!mounted) return;
      if (_playback.currentPath != widget.attachment.filePath) {
        setState(() => _state = PlayerState.stopped);
        return;
      }
      setState(() => _state = state);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshFileState() async {
    final exists = await File(widget.attachment.filePath).exists();
    if (!mounted) return;
    setState(() => _missingFile = !exists);
  }

  Future<void> _togglePlay() async {
    if (_missingFile) {
      _showSnack(AppLocale.instance.strings.voicePlaybackFailed);
      return;
    }
    final ok = await _playback.play(widget.attachment.filePath);
    if (!mounted) return;
    if (!ok) {
      setState(() => _missingFile = true);
      _showSnack(AppLocale.instance.strings.voicePlaybackFailed);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool get _isActive =>
      _playback.currentPath == widget.attachment.filePath &&
      _state == PlayerState.playing;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final fg = widget.isOutgoing ? Colors.white : widget.accent;
    final bg = widget.isOutgoing
        ? Colors.white.withValues(alpha: 0.16)
        : widget.accent.withValues(alpha: 0.08);
    final service = AnnouncementAttachmentService.instance;
    final sizeLabel = service.formatFileSize(widget.attachment.fileSizeBytes);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _missingFile ? null : _togglePlay,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isOutgoing
                    ? Colors.white24
                    : widget.accent.withValues(alpha: 0.15),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _missingFile
                        ? Icons.error_outline_rounded
                        : (_isActive
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded),
                    color: _missingFile ? Colors.red.shade400 : fg,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _missingFile ? s.voiceUnavailable : s.voiceMessageLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: fg,
                        ),
                      ),
                      if (sizeLabel.isNotEmpty)
                        Text(
                          sizeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: widget.isOutgoing
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
