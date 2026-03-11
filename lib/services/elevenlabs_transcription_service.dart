import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/transcript_segment.dart';

/// Result from ElevenLabs Scribe API with optional speaker diarization.
class ElevenLabsTranscriptionResult {
  final String text;
  final String? languageCode;
  final List<TranscriptSegment> segments;

  ElevenLabsTranscriptionResult({
    required this.text,
    this.languageCode,
    required this.segments,
  });
}

class ElevenLabsTranscriptionService {
  static const _baseUrl = 'https://api.elevenlabs.io/v1/speech-to-text';
  static const _maxFileSizeBytes = 2 * 1024 * 1024 * 1024; // 2 GB per docs (we use 25 MB in practice)

  static ElevenLabsTranscriptionService? _instance;
  ElevenLabsTranscriptionService._();
  static ElevenLabsTranscriptionService get instance {
    _instance ??= ElevenLabsTranscriptionService._();
    return _instance!;
  }

  /// Transcribe with Scribe v2, diarization on (speaker labels).
  /// language_code omitted = auto-detect (English / Afrikaans etc.).
  Future<ElevenLabsTranscriptionResult> transcribe(
      String audioFilePath, String apiKey) async {
    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw ElevenLabsTranscriptionException('Audio file not found.');
    }
    final fileSize = await file.length();
    if (fileSize < 500) {
      throw ElevenLabsTranscriptionException(
          'Audio file is empty. Check that your microphone was working.');
    }
    if (fileSize > 25 * 1024 * 1024) {
      throw ElevenLabsTranscriptionException(
          'File too large (max 25 MB). Current: ${(fileSize / 1048576).toStringAsFixed(1)} MB');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(_baseUrl),
    );
    request.headers['xi-api-key'] = apiKey;
    request.headers['Accept'] = 'application/json';
    request.fields['model_id'] = 'scribe_v2';
    request.fields['diarize'] = 'true';
    request.fields['tag_audio_events'] = 'true';
    // language_code omitted = auto-detect (English & Afrikaans)

    final fileName = audioFilePath.split(Platform.pathSeparator).last;
    request.files.add(
      await http.MultipartFile.fromPath('file', audioFilePath,
          filename: fileName),
    );

    http.StreamedResponse response;
    try {
      response = await request.send().timeout(
        const Duration(minutes: 10),
        onTimeout: () => throw ElevenLabsTranscriptionException(
            'Request timed out. Check your internet connection.'),
      );
    } catch (e) {
      if (e is ElevenLabsTranscriptionException) rethrow;
      throw ElevenLabsTranscriptionException(
          'Network error. Check your internet connection.');
    }

    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      _throwError(response.statusCode, body);
    }

    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      // Handle multichannel response (transcripts array)
      final chunk = json['transcripts'] != null
          ? (json['transcripts'] as List<dynamic>).first as Map<String, dynamic>
          : json;
      final text = (chunk['text'] as String?)?.trim() ?? '';
      final languageCode = chunk['language_code'] as String?;
      final words = chunk['words'] as List<dynamic>? ?? [];

      if (text.isEmpty && words.isEmpty) {
        throw ElevenLabsTranscriptionException(
            'No speech detected. Make sure the microphone was working during recording.');
      }

      final segments = _buildSegmentsFromWords(words);
      final fullText = text.isNotEmpty ? text : segments.map((s) => s.text).join(' ').trim();

      return ElevenLabsTranscriptionResult(
        text: fullText,
        languageCode: languageCode,
        segments: segments,
      );
    } catch (e) {
      if (e is ElevenLabsTranscriptionException) rethrow;
      throw ElevenLabsTranscriptionException(
          'Could not parse ElevenLabs response.');
    }
  }

  List<TranscriptSegment> _buildSegmentsFromWords(List<dynamic> words) {
    if (words.isEmpty) return [];

    final segments = <TranscriptSegment>[];
    String? currentSpeakerId;
    final currentWords = <String>[];
    double? segmentStart;
    double? segmentEnd;

    for (final w in words) {
      final map = w as Map<String, dynamic>;
      final speakerId = map['speaker_id'] as String?;
      final wordText = (map['text'] as String?)?.trim() ?? '';
      final type = map['type'] as String?;
      if (type == 'audio_event') continue; // skip (laughter) etc. or include — we include for now
      final start = (map['start'] as num?)?.toDouble();
      final end = (map['end'] as num?)?.toDouble();

      if (speakerId != currentSpeakerId && currentWords.isNotEmpty) {
        segments.add(TranscriptSegment(
          speakerLabel: 'Speaker ${segments.length + 1}',
          text: currentWords.join(' ').trim(),
          startTimeSeconds: segmentStart,
          endTimeSeconds: segmentEnd,
        ));
        currentWords.clear();
        segmentStart = null;
        segmentEnd = null;
      }
      currentSpeakerId = speakerId;
      if (wordText.isNotEmpty) currentWords.add(wordText);
      if (start != null) segmentStart ??= start;
      if (end != null) segmentEnd = end;
    }

    if (currentWords.isNotEmpty) {
      segments.add(TranscriptSegment(
        speakerLabel: 'Speaker ${segments.length + 1}',
        text: currentWords.join(' ').trim(),
        startTimeSeconds: segmentStart,
        endTimeSeconds: segmentEnd,
      ));
    }

    return segments;
  }

  Never _throwError(int statusCode, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final detail = json['detail'];
      String msg = 'ElevenLabs API error ($statusCode).';
      if (detail is Map && detail['message'] != null) {
        msg = detail['message'] as String;
      } else if (detail is String) {
        msg = detail;
      }
      if (statusCode == 401) {
        throw ElevenLabsTranscriptionException(
            'Invalid ElevenLabs API key. Check Settings.');
      }
      if (statusCode == 429) {
        throw ElevenLabsTranscriptionException(
            'ElevenLabs rate limit reached. Please wait and try again.');
      }
      throw ElevenLabsTranscriptionException(msg);
    } catch (e) {
      if (e is ElevenLabsTranscriptionException) rethrow;
      throw ElevenLabsTranscriptionException(
          'ElevenLabs API error ($statusCode).');
    }
  }
}

class ElevenLabsTranscriptionException implements Exception {
  final String message;
  ElevenLabsTranscriptionException(this.message);
  @override
  String toString() => message;
}
