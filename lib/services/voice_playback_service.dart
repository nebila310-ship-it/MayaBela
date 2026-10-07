import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/profile_photo_codec.dart';

/// Plays voice message attachments from this device or school-files.
class VoicePlaybackService {
  VoicePlaybackService._();

  static final VoicePlaybackService instance = VoicePlaybackService._();

  final AudioPlayer _player = AudioPlayer();
  String? _currentPath;

  Stream<PlayerState> get onStateChanged => _player.onPlayerStateChanged;
  String? get currentPath => _currentPath;

  Future<void> _ensureReady() async {
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setPlayerMode(PlayerMode.mediaPlayer);
  }

  Future<bool> play(String path) async {
    final value = path.trim();
    if (value.isEmpty) return false;

    try {
      await _ensureReady();
      if (_currentPath == value && _player.state == PlayerState.playing) {
        await _player.pause();
        return true;
      }
      if (_currentPath == value && _player.state == PlayerState.paused) {
        await _player.resume();
        return true;
      }
      await _player.stop();
      _currentPath = value;

      if (value.startsWith('http://') || value.startsWith('https://')) {
        final bytes =
            WebAttachmentCache.instance.read(value) ??
            await ProfilePhotoCodec.fetchRemoteBytes(value);
        if (bytes != null && bytes.isNotEmpty) {
          await _player.play(BytesSource(Uint8List.fromList(bytes)));
          return true;
        }
        await _player.play(UrlSource(value));
        return true;
      }

      final cached = WebAttachmentCache.instance.read(value);
      if (cached != null && cached.isNotEmpty) {
        await _player.play(BytesSource(Uint8List.fromList(cached)));
        return true;
      }

      final file = File(value);
      if (!await file.exists()) return false;
      await _player.play(DeviceFileSource(value));
      return true;
    } catch (_) {
      _currentPath = null;
      return false;
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _currentPath = null;
  }

  void dispose() {
    _player.dispose();
  }
}
