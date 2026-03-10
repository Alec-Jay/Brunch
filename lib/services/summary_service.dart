import 'dart:convert';
import 'package:http/http.dart' as http;

class SummaryResult {
  final String summary;
  final List<String> actionItems;
  final List<String> keyDecisions;

  const SummaryResult({
    required this.summary,
    required this.actionItems,
    required this.keyDecisions,
  });
}

class SummaryService {
  static const _openAiUrl =
      'https://api.openai.com/v1/chat/completions';
  static const _claudeUrl =
      'https://api.anthropic.com/v1/messages';

  static SummaryService? _instance;
  SummaryService._();
  static SummaryService get instance {
    _instance ??= SummaryService._();
    return _instance!;
  }

  static const _systemPrompt = '''
You are an expert meeting notes assistant. Analyze the meeting transcript and respond ONLY with a valid JSON object — no extra text, no markdown, no code fences.

Use exactly this structure:
{
  "summary": "2-4 sentence overview of what was discussed and decided",
  "action_items": ["Person A will do X by date", "..."],
  "key_decisions": ["Decision 1", "..."]
}

Guidelines:
- Summary: be concise and professional, mention who was involved if clear
- Action items: be specific, include owner and deadline if mentioned
- Key decisions: list concrete decisions made (empty array if none)
- If speech is unclear or incomplete, do your best with available context
''';

  /// Generates a summary using OpenAI GPT-4o.
  Future<SummaryResult> summarizeWithOpenAI(
      String transcript, String apiKey) async {
    final response = await http
        .post(
          Uri.parse(_openAiUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'gpt-4o',
            'messages': [
              {'role': 'system', 'content': _systemPrompt},
              {
                'role': 'user',
                'content':
                    'Please summarize this meeting transcript:\n\n$transcript'
              },
            ],
            'temperature': 0.3,
            'max_tokens': 1000,
          }),
        )
        .timeout(const Duration(minutes: 2),
            onTimeout: () =>
                throw SummaryException('Request timed out.'));

    if (response.statusCode == 200) {
      return _parseOpenAiResponse(response.body);
    }
    _throwOpenAiError(response.statusCode, response.body);
  }

  /// Generates a summary using Anthropic Claude.
  Future<SummaryResult> summarizeWithClaude(
      String transcript, String apiKey) async {
    final response = await http
        .post(
          Uri.parse(_claudeUrl),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'claude-3-5-haiku-20241022',
            'max_tokens': 1000,
            'system': _systemPrompt,
            'messages': [
              {
                'role': 'user',
                'content':
                    'Please summarize this meeting transcript:\n\n$transcript'
              },
            ],
          }),
        )
        .timeout(const Duration(minutes: 2),
            onTimeout: () =>
                throw SummaryException('Request timed out.'));

    if (response.statusCode == 200) {
      return _parseClaudeResponse(response.body);
    }
    _throwClaudeError(response.statusCode, response.body);
  }

  SummaryResult _parseOpenAiResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final content =
          json['choices'][0]['message']['content'] as String;
      return _parseJson(content);
    } catch (e) {
      throw SummaryException('Could not parse summary response.');
    }
  }

  SummaryResult _parseClaudeResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final content =
          (json['content'] as List).first['text'] as String;
      return _parseJson(content);
    } catch (e) {
      throw SummaryException('Could not parse summary response.');
    }
  }

  SummaryResult _parseJson(String raw) {
    // Strip any accidental markdown code fences
    String cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```[a-z]*\n?'), '')
          .replaceFirst(RegExp(r'\n?```$'), '')
          .trim();
    }
    final json = jsonDecode(cleaned) as Map<String, dynamic>;
    return SummaryResult(
      summary: (json['summary'] as String?) ?? '',
      actionItems: (json['action_items'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      keyDecisions: (json['key_decisions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Never _throwOpenAiError(int statusCode, String body) {
    try {
      final err = (jsonDecode(body)['error']
          as Map<String, dynamic>?)?['message'] as String?;
      if (statusCode == 401) {
        throw SummaryException(
            'Invalid OpenAI API key. Please check your key in Settings.');
      }
      if (statusCode == 429) {
        throw SummaryException(
            'OpenAI rate limit reached. Please wait and try again.');
      }
      throw SummaryException(
          err ?? 'OpenAI API error ($statusCode).');
    } catch (e) {
      if (e is SummaryException) rethrow;
      throw SummaryException('OpenAI API error ($statusCode).');
    }
  }

  Never _throwClaudeError(int statusCode, String body) {
    if (statusCode == 401) {
      throw SummaryException(
          'Invalid Claude API key. Please check your key in Settings.');
    }
    if (statusCode == 429) {
      throw SummaryException(
          'Claude rate limit reached. Please wait and try again.');
    }
    throw SummaryException('Claude API error ($statusCode).');
  }
}

class SummaryException implements Exception {
  final String message;
  SummaryException(this.message);

  @override
  String toString() => message;
}
