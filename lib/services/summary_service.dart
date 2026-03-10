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
  // Groq uses the same format as OpenAI
  static const _groqChatUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const _openAiChatUrl =
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
- Summary: concise and professional, mention participants if clear
- Action items: specific, include owner and deadline if mentioned (empty array if none)
- Key decisions: concrete decisions made (empty array if none)
- If speech is unclear, do your best with available context
''';

  /// Summarize with Groq (free — Llama 3.3 70B).
  Future<SummaryResult> summarizeWithGroq(
      String transcript, String apiKey) async {
    return _summarizeOpenAiCompat(
      transcript: transcript,
      apiKey: apiKey,
      url: _groqChatUrl,
      model: 'llama-3.3-70b-versatile',
      providerName: 'Groq',
    );
  }

  /// Summarize with OpenAI GPT-4o.
  Future<SummaryResult> summarizeWithOpenAI(
      String transcript, String apiKey) async {
    return _summarizeOpenAiCompat(
      transcript: transcript,
      apiKey: apiKey,
      url: _openAiChatUrl,
      model: 'gpt-4o',
      providerName: 'OpenAI',
    );
  }

  /// Summarize with Anthropic Claude.
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
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final content =
            (json['content'] as List).first['text'] as String;
        return _parseJson(content);
      } catch (_) {
        throw SummaryException('Could not parse summary response.');
      }
    }
    if (response.statusCode == 401) {
      throw SummaryException(
          'Invalid Claude API key. Check Settings.');
    }
    throw SummaryException('Claude API error (${response.statusCode}).');
  }

  Future<SummaryResult> _summarizeOpenAiCompat({
    required String transcript,
    required String apiKey,
    required String url,
    required String model,
    required String providerName,
  }) async {
    final response = await http
        .post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
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
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final content =
            json['choices'][0]['message']['content'] as String;
        return _parseJson(content);
      } catch (_) {
        throw SummaryException('Could not parse summary response.');
      }
    }
    if (response.statusCode == 401) {
      throw SummaryException(
          'Invalid $providerName API key. Check Settings.');
    }
    if (response.statusCode == 429) {
      throw SummaryException(
          '$providerName rate limit reached. Wait a moment and try again.');
    }
    throw SummaryException(
        '$providerName API error (${response.statusCode}).');
  }

  SummaryResult _parseJson(String raw) {
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
}

class SummaryException implements Exception {
  final String message;
  SummaryException(this.message);
  @override
  String toString() => message;
}
