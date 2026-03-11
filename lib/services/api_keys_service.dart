import 'package:shared_preferences/shared_preferences.dart';

class ApiKeysService {
  static const _openAiKey = 'api_key_openai';
  static const _claudeKey = 'api_key_claude';
  static const _groqKey = 'api_key_groq';
  static const _elevenLabsKey = 'api_key_elevenlabs';

  static ApiKeysService? _instance;
  ApiKeysService._();
  static ApiKeysService get instance {
    _instance ??= ApiKeysService._();
    return _instance!;
  }

  Future<String?> getOpenAiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_openAiKey);
    return (key != null && key.trim().isNotEmpty) ? key.trim() : null;
  }

  Future<String?> getClaudeKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_claudeKey);
    return (key != null && key.trim().isNotEmpty) ? key.trim() : null;
  }

  Future<String?> getGroqKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_groqKey);
    return (key != null && key.trim().isNotEmpty) ? key.trim() : null;
  }

  Future<String?> getElevenLabsKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_elevenLabsKey);
    return (key != null && key.trim().isNotEmpty) ? key.trim() : null;
  }

  Future<void> saveOpenAiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_openAiKey, key.trim());
  }

  Future<void> saveClaudeKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claudeKey, key.trim());
  }

  Future<void> saveGroqKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_groqKey, key.trim());
  }

  Future<void> saveElevenLabsKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_elevenLabsKey, key.trim());
  }

  Future<bool> hasOpenAiKey() async => (await getOpenAiKey()) != null;
  Future<bool> hasClaudeKey() async => (await getClaudeKey()) != null;
  Future<bool> hasGroqKey() async => (await getGroqKey()) != null;
  Future<bool> hasElevenLabsKey() async => (await getElevenLabsKey()) != null;

  /// Best transcription: ElevenLabs (Afrikaans + diarization) → Groq → OpenAI
  Future<({String key, String provider})?> getBestTranscriptionKey() async {
    final elevenLabs = await getElevenLabsKey();
    if (elevenLabs != null) return (key: elevenLabs, provider: 'elevenlabs');
    final groq = await getGroqKey();
    if (groq != null) return (key: groq, provider: 'groq');
    final openAi = await getOpenAiKey();
    if (openAi != null) return (key: openAi, provider: 'openai');
    return null;
  }

  /// Fallback when ElevenLabs fails: Groq → OpenAI (no ElevenLabs)
  Future<({String key, String provider})?> getFallbackTranscriptionKey() async {
    final groq = await getGroqKey();
    if (groq != null) return (key: groq, provider: 'groq');
    final openAi = await getOpenAiKey();
    if (openAi != null) return (key: openAi, provider: 'openai');
    return null;
  }

  /// Returns the best available summary key.
  /// Priority: Groq (free) → Claude → OpenAI
  Future<({String key, String provider})?> getBestSummaryKey() async {
    final groq = await getGroqKey();
    if (groq != null) return (key: groq, provider: 'groq');
    final claude = await getClaudeKey();
    if (claude != null) return (key: claude, provider: 'claude');
    final openAi = await getOpenAiKey();
    if (openAi != null) return (key: openAi, provider: 'openai');
    return null;
  }
}
