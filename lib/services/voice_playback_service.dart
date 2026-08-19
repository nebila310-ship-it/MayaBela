import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

/// Plays local voice message attachments inside the app.
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
    final file = File(path);
    if (!await file.exists()) return false;

    try {
      await _ensureReady();
      if (_currentPath == path && _player.state == PlayerState.playing) {
        await _player.pause();
        return true;
      }
      if (_currentPath == path && _player.state == PlayerState.paused) {
        await _player.resume();
        return true;
      }
      await _player.stop();
      _currentPath = path;
      await _player.play(DeviceFileSource(path));
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
