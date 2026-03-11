import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_kit/whisper_kit.dart';
import '../models/transcript_segment.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

/// Result from on-device Whisper transcription (same shape as ElevenLabs for UI).
class LocalTranscriptionResult {
  final String text;
  final String? languageCode;
  final List<TranscriptSegment> segments;

  LocalTranscriptionResult({
    required this.text,
    this.languageCode,
    required this.segments,
  });
}

/// On-device transcription using Whisper. No API key required.
/// Supported on Android; on other platforms [isSupported] is false.
class LocalTranscriptionService {
  static LocalTranscriptionService? _instance;
  LocalTranscriptionService._();
  static LocalTranscriptionService get instance {
    _instance ??= LocalTranscriptionService._();
    return _instance!;
  }

  static const _maxFileSizeBytes = 25 * 1024 * 1024; // 25 MB

  /// True when running on Android (whisper_kit is Android-focused).
  bool get isSupported => Platform.isAndroid;

  /// Transcribe an audio file on-device. Converts to WAV 16kHz mono if needed, then runs Whisper.
  /// Throws [LocalTranscriptionException] on error.
  Future<LocalTranscriptionResult> transcribe(String audioFilePath) async {
    if (!isSupported) {
      throw LocalTranscriptionException(
        'On-device transcription is only supported on Android.');
    }

    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw LocalTranscriptionException('Audio file not found.');
    }
    final fileSize = await file.length();
    if (fileSize < 500) {
      throw LocalTranscriptionException(
          'Audio file is empty. Check that your microphone was working during recording.');
    }
    if (fileSize > _maxFileSizeBytes) {
      throw LocalTranscriptionException(
          'File too large (max 25 MB). Current: ${(fileSize / 1048576).toStringAsFixed(1)} MB');
    }

    final isWav = audioFilePath.toLowerCase().endsWith('.wav');
    String pathToUse = audioFilePath;
    File? tempWav;

    if (!isWav) {
      final wavPath = await _convertToWav(audioFilePath);
      if (wavPath == null) {
        throw LocalTranscriptionException(
            'Could not convert audio to WAV. Try recording in a supported format.');
      }
      tempWav = File(wavPath);
      pathToUse = wavPath;
    }

    try {
      final whisper = Whisper(
        model: WhisperModel.base,
        onDownloadProgress: (received, total) {
          // Optional: could report progress to UI
        },
      );
      final request = TranscribeRequest(
        audio: pathToUse,
        language: 'auto',
        isNoTimestamps: false,
      );
      final response = await whisper.transcribe(transcribeRequest: request);

      final text = response.text.trim();
      if (text.isEmpty && (response.segments == null || response.segments!.isEmpty)) {
        throw LocalTranscriptionException(
            'No speech detected. Make sure the microphone was working during recording.');
      }

      final segments = _mapSegments(response.segments);
      final fullText = text.isNotEmpty
          ? text
          : segments.map((s) => s.text).join(' ').trim();

      return LocalTranscriptionResult(
        text: fullText,
        languageCode: null,
        segments: segments,
      );
    } catch (e) {
      if (e is LocalTranscriptionException) rethrow;
      throw LocalTranscriptionException('Transcription failed: $e');
    } finally {
      if (tempWav != null && await tempWav.exists()) {
        try {
          await tempWav.delete();
        } catch (_) {}
      }
    }
  }

  /// Convert audio to WAV 16kHz mono 16-bit PCM for Whisper.
  Future<String?> _convertToWav(String inputPath) async {
    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/brunch_whisper_${DateTime.now().millisecondsSinceEpoch}.wav';
    final session = await FFmpegKit.executeWithArguments([
      '-i', inputPath,
      '-acodec', 'pcm_s16le',
      '-ac', '1',
      '-ar', '16000',
      outputPath,
    ]);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      final out = File(outputPath);
      if (await out.exists()) return outputPath;
    }
    return null;
  }

  List<TranscriptSegment> _mapSegments(List<WhisperTranscribeSegment>? raw) {
    if (raw == null || raw.isEmpty) return [];
    return raw.map((s) {
      final start = s.fromTs.inMilliseconds / 1000.0;
      final end = s.toTs.inMilliseconds / 1000.0;
      return TranscriptSegment(
        speakerLabel: 'Speaker 1',
        text: s.text.trim(),
        startTimeSeconds: start,
        endTimeSeconds: end,
      );
    }).toList();
  }
}

class LocalTranscriptionException implements Exception {
  final String message;
  LocalTranscriptionException(this.message);
  @override
  String toString() => message;
}
