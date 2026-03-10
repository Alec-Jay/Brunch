import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class TranscriptionResult {
  final String text;
  final String? language;
  TranscriptionResult({required this.text, this.language});
}

class TranscriptionService {
  static const _whisperUrl =
      'https://api.openai.com/v1/audio/transcriptions';
  static const _maxFileSizeBytes = 25 * 1024 * 1024; // 25 MB Whisper limit

  static TranscriptionService? _instance;
  TranscriptionService._();
  static TranscriptionService get instance {
    _instance ??= TranscriptionService._();
    return _instance!;
  }

  /// Transcribes an audio file using OpenAI Whisper.
  /// Throws a [TranscriptionException] with a user-friendly message on failure.
  Future<TranscriptionResult> transcribe(
      String audioFilePath, String apiKey) async {
    final file = File(audioFilePath);

    if (!await file.exists()) {
      throw TranscriptionException('Audio file not found.');
    }

    final fileSize = await file.length();
    if (fileSize > _maxFileSizeBytes) {
      throw TranscriptionException(
          'Audio file is too large (max 25 MB). Current: ${(fileSize / 1048576).toStringAsFixed(1)} MB');
    }
    if (fileSize < 500) {
      throw TranscriptionException(
          'Audio file is empty or too small to transcribe.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(_whisperUrl),
    );

    request.headers['Authorization'] = 'Bearer $apiKey';
    request.fields['model'] = 'whisper-1';
    request.fields['response_format'] = 'verbose_json';

    final fileName = audioFilePath.split(Platform.pathSeparator).last;
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        audioFilePath,
        filename: fileName,
      ),
    );

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send().timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TranscriptionException(
            'Request timed out. Check your internet connection.'),
      );
    } catch (e) {
      if (e is TranscriptionException) rethrow;
      throw TranscriptionException(
          'Network error. Check your internet connection.');
    }

    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode == 200) {
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final text = json['text'] as String? ?? '';
        final language = json['language'] as String?;
        if (text.trim().isEmpty) {
          throw TranscriptionException(
              'No speech detected in the recording. Make sure the microphone was working during the meeting.');
        }
        return TranscriptionResult(text: text.trim(), language: language);
      } catch (e) {
        if (e is TranscriptionException) rethrow;
        throw TranscriptionException('Unexpected response from Whisper API.');
      }
    }

    // Handle API errors
    try {
      final errJson = jsonDecode(body) as Map<String, dynamic>;
      final errMsg =
          (errJson['error'] as Map<String, dynamic>?)?['message'] as String?;
      if (streamedResponse.statusCode == 401) {
        throw TranscriptionException(
            'Invalid OpenAI API key. Please check your key in Settings.');
      }
      if (streamedResponse.statusCode == 429) {
        throw TranscriptionException(
            'OpenAI rate limit reached. Please wait a moment and try again.');
      }
      throw TranscriptionException(
          errMsg ?? 'Whisper API error (${streamedResponse.statusCode}).');
    } catch (e) {
      if (e is TranscriptionException) rethrow;
      throw TranscriptionException(
          'Whisper API error (${streamedResponse.statusCode}).');
    }
  }
}

class TranscriptionException implements Exception {
  final String message;
  TranscriptionException(this.message);

  @override
  String toString() => message;
}
