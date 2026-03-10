import 'package:shared_preferences/shared_preferences.dart';

class ApiKeysService {
  static const _openAiKey = 'api_key_openai';
  static const _claudeKey = 'api_key_claude';

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

  Future<void> saveOpenAiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_openAiKey, key.trim());
  }

  Future<void> saveClaudeKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claudeKey, key.trim());
  }

  Future<bool> hasOpenAiKey() async => (await getOpenAiKey()) != null;
  Future<bool> hasClaudeKey() async => (await getClaudeKey()) != null;
}
