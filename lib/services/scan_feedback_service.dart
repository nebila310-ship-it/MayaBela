import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Short beep + haptic when a QR scan is accepted successfully.
class ScanFeedbackService {
  ScanFeedbackService._();

  static final ScanFeedbackService instance = ScanFeedbackService._();

  final AudioPlayer _player = AudioPlayer();
  var _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setPlayerMode(PlayerMode.lowLatency);
    _ready = true;
  }

  Future<void> playScanSuccess() async {
    HapticFeedback.lightImpact();
    try {
      await _ensureReady();
      await _player.stop();
      await _player.play(
        AssetSource('sounds/scan_success.wav'),
        volume: 0.95,
      );
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }
}
