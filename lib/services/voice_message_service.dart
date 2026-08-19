import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:mayabela/models/announcement.dart';

/// Records voice clips with live amplitude samples for waveform UI.
class VoiceMessageService {
  VoiceMessageService._();
  static final instance = VoiceMessageService._();

  final AudioRecorder _recorder = AudioRecorder();
  final _amplitudeController = StreamController<List<double>>.broadcast();

  String? _activePath;
  bool _recording = false;
  StreamSubscription<Amplitude>? _amplitudeSub;
  List<double> _samples = [];

  static const _maxSamples = 48;

  bool get isRecording => _recording;
  Stream<List<double>> get amplitudeStream => _amplitudeController.stream;
  List<double> get currentSamples => List.unmodifiable(_samples);

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<bool> startRecording() async {
    if (_recording) return true;
    if (!await _recorder.hasPermission()) return false;

    final dir = await _voiceDir();
    final id = DateTime.now().millisecondsSinceEpoch;
    _activePath = '${dir.path}/voice_$id.m4a';
    _samples = [];
    _emitSamples();

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _activePath!,
    );

    _amplitudeSub?.cancel();
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 60))
        .listen(_onAmplitude);

    _recording = true;
    return true;
  }

  void _onAmplitude(Amplitude amplitude) {
    // dBFS is typically -45 (quiet) to 0 (loud); map to 0..1 bar height.
    final db = amplitude.current;
    final normalized = ((db + 45) / 45).clamp(0.05, 1.0);
    _samples.add(normalized);
    if (_samples.length > _maxSamples) {
      _samples.removeAt(0);
    }
    _emitSamples();
  }

  void _emitSamples() {
    if (_amplitudeController.isClosed) return;
    _amplitudeController.add(List.unmodifiable(_samples));
  }

  Future<AnnouncementAttachment?> stopRecording() async {
    if (!_recording) return null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    final path = await _recorder.stop();
    _recording = false;
    _samples = [];
    _emitSamples();

    final savedPath = path ?? _activePath;
    _activePath = null;
    if (savedPath == null || savedPath.isEmpty) return null;

    // Allow the encoder to flush the file on device.
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final file = File(savedPath);
    if (!await file.exists()) return null;

    final length = await file.length();
    if (length <= 0) return null;

    return AnnouncementAttachment(
      id: 'voice-${DateTime.now().millisecondsSinceEpoch}',
      fileName: 'voice_message.m4a',
      filePath: savedPath,
      fileSizeBytes: length,
    );
  }

  Future<void> cancelRecording() async {
    if (!_recording) return;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await _recorder.stop();
    _recording = false;
    _samples = [];
    _emitSamples();
    if (_activePath != null) {
      final file = File(_activePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    _activePath = null;
  }

  Future<Directory> _voiceDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/voice_messages');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
