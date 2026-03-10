import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  Future<bool> hasPermission() async {
    return await Permission.microphone.isGranted;
  }

  Future<String> _generateFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/brunch_$timestamp.m4a';
  }

  Future<String?> startRecording() async {
    try {
      final granted = await requestPermission();
      if (!granted) return null;

      // Try AAC first; fall back to AMR-NB (widest emulator compatibility)
      String filePath = await _generateFilePath();
      try {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
            numChannels: 1,
          ),
          path: filePath,
        );
      } catch (_) {
        filePath = filePath.replaceAll('.m4a', '.3gp');
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.amrNb,
            sampleRate: 8000,
            numChannels: 1,
          ),
          path: filePath,
        );
      }
      _isRecording = true;
      return filePath;
    } catch (_) {
      _isRecording = false;
      return null;
    }
  }

  /// Stop recording. Returns (filePath, fileSizeBytes).
  /// filePath is null if recording failed.
  Future<(String?, int)> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      if (path == null) return (null, 0);

      // Give the OS a moment to flush the file buffer
      await Future.delayed(const Duration(milliseconds: 400));

      final file = File(path);
      if (!await file.exists()) return (null, 0);
      final size = await file.length();

      // A valid recording should have some content.
      // Even 1 second of AMR-NB audio is ~1.5KB minimum.
      if (size < 500) {
        await file.delete().catchError((_) => file);
        return (null, size);
      }

      return (path, size);
    } catch (_) {
      _isRecording = false;
      return (null, 0);
    }
  }

  Future<void> cancelRecording() async {
    try {
      await _recorder.cancel();
    } catch (_) {}
    _isRecording = false;
  }

  Stream<Amplitude> get amplitudeStream =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 100));

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
