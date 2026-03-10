import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class TranscriptionResult {
  final String text;
  final String? language;
  final String provider;
  TranscriptionResult({required this.text, this.language, required this.provider});
}

class TranscriptionService {
  // Groq uses the exact same API format as OpenAI — just a different base URL
  static const _groqUrl =
      'https://api.groq.com/openai/v1/audio/transcriptions';
  static const _openAiUrl =
      'https://api.openai.com/v1/audio/transcriptions';

  static const _maxFileSizeBytes = 25 * 1024 * 1024; // 25 MB limit

  static TranscriptionService? _instance;
  TranscriptionService._();
  static TranscriptionService get instance {
    _instance ??= TranscriptionService._();
    return _instance!;
  }

  /// Transcribes audio. Provider: 'groq' (free) or 'openai'.
  Future<TranscriptionResult> transcribe(
      String audioFilePath, String apiKey, String provider) async {
    final file = File(audioFilePath);

    if (!await file.exists()) {
      throw TranscriptionException('Audio file not found.');
    }

    final fileSize = await file.length();
    if (fileSize > _maxFileSizeBytes) {
      throw TranscriptionException(
          'File too large (max 25 MB). Current: ${(fileSize / 1048576).toStringAsFixed(1)} MB');
    }
    if (fileSize < 500) {
      throw TranscriptionException(
          'Audio file is empty. Check that your microphone was working.');
    }

    final url = provider == 'groq' ? _groqUrl : _openAiUrl;
    // Groq uses whisper-large-v3 (more accurate), OpenAI uses whisper-1
    final model = provider == 'groq' ? 'whisper-large-v3' : 'whisper-1';

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.fields['model'] = model;
    request.fields['response_format'] = 'verbose_json';

    final fileName = audioFilePath.split(Platform.pathSeparator).last;
    request.files.add(
      await http.MultipartFile.fromPath('file', audioFilePath,
          filename: fileName),
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
              'No speech detected. Make sure the microphone was working during recording.');
        }
        return TranscriptionResult(
            text: text.trim(),
            language: language,
            provider: provider);
      } catch (e) {
        if (e is TranscriptionException) rethrow;
        throw TranscriptionException('Unexpected response from API.');
      }
    }

    _throwApiError(streamedResponse.statusCode, body, provider);
  }

  Never _throwApiError(int statusCode, String body, String provider) {
    try {
      final errMsg = (jsonDecode(body)['error']
          as Map<String, dynamic>?)?['message'] as String?;
      if (statusCode == 401) {
        throw TranscriptionException(
            'Invalid ${provider == 'groq' ? 'Groq' : 'OpenAI'} API key. Check Settings.');
      }
      if (statusCode == 429) {
        throw TranscriptionException(
            'Rate limit reached. Please wait a moment and try again.');
      }
      throw TranscriptionException(
          errMsg ?? 'API error ($statusCode). Try again.');
    } catch (e) {
      if (e is TranscriptionException) rethrow;
      throw TranscriptionException('API error ($statusCode).');
    }
  }
}

class TranscriptionException implements Exception {
  final String message;
  TranscriptionException(this.message);
  @override
  String toString() => message;
}
