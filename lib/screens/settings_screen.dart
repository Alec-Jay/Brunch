import 'package:flutter/material.dart';
import '../services/api_keys_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _openAIController = TextEditingController();
  final _claudeController = TextEditingController();
  bool _showOpenAI = false;
  bool _showClaude = false;
  bool _openAISaved = false;
  bool _claudeSaved = false;
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final openAi = await ApiKeysService.instance.getOpenAiKey();
    final claude = await ApiKeysService.instance.getClaudeKey();
    if (mounted) {
      setState(() {
        if (openAi != null) {
          _openAIController.text = openAi;
          _openAISaved = true;
        }
        if (claude != null) {
          _claudeController.text = claude;
          _claudeSaved = true;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await ApiKeysService.instance.saveOpenAiKey(_openAIController.text);
    await ApiKeysService.instance.saveClaudeKey(_claudeController.text);
    if (mounted) {
      setState(() {
        _isSaving = false;
        _openAISaved = _openAIController.text.trim().isNotEmpty;
        _claudeSaved = _claudeController.text.trim().isNotEmpty;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 18),
              const SizedBox(width: 8),
              Text(_openAISaved || _claudeSaved
                  ? 'API keys saved successfully'
                  : 'Settings saved (no keys entered)'),
            ],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _openAIController.dispose();
    _claudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0D18), Color(0xFF0D1525), Color(0xFF080C14)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.accent, strokeWidth: 2))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildInfoBanner(),
                    const SizedBox(height: 24),
                    _buildSectionLabel('TRANSCRIPTION — WHISPER'),
                    const SizedBox(height: 10),
                    _buildApiKeyCard(
                      label: 'OpenAI API Key',
                      subtitle: 'Used for Whisper transcription AND GPT-4o summaries',
                      icon: Icons.mic_rounded,
                      iconColor: AppTheme.accentSecondary,
                      controller: _openAIController,
                      isVisible: _showOpenAI,
                      isSaved: _openAISaved,
                      onToggle: () =>
                          setState(() => _showOpenAI = !_showOpenAI),
                      placeholder: 'sk-...',
                      learnMoreUrl: 'platform.openai.com/api-keys',
                    ),
                    const SizedBox(height: 20),
                    _buildSectionLabel('SUMMARIES — CLAUDE (OPTIONAL)'),
                    const SizedBox(height: 10),
                    _buildApiKeyCard(
                      label: 'Anthropic Claude API Key',
                      subtitle:
                          'Optional: Uses Claude instead of GPT-4o for summaries',
                      icon: Icons.auto_awesome_rounded,
                      iconColor: AppTheme.accent,
                      controller: _claudeController,
                      isVisible: _showClaude,
                      isSaved: _claudeSaved,
                      onToggle: () =>
                          setState(() => _showClaude = !_showClaude),
                      placeholder: 'sk-ant-...',
                      learnMoreUrl: 'console.anthropic.com',
                    ),
                    const SizedBox(height: 28),
                    _buildSaveButton(),
                    const SizedBox(height: 32),
                    _buildSectionLabel('ABOUT'),
                    const SizedBox(height: 10),
                    _buildAboutCard(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              Text('Configure your AI integrations',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppTheme.accent, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How it works',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(
                  '1. Enter your OpenAI key (required for transcription + summaries)\n'
                  '2. Record a meeting\n'
                  '3. Tap "Transcribe" in the meeting — Whisper converts speech to text\n'
                  '4. Tap "Summarize" — GPT-4o generates summary + action items',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildApiKeyCard({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required bool isVisible,
    required bool isSaved,
    required VoidCallback onToggle,
    required String placeholder,
    required String learnMoreUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSaved
              ? AppTheme.success.withValues(alpha: 0.4)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            height: 1.3)),
                  ],
                ),
              ),
              if (isSaved)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: AppTheme.success, size: 11),
                      SizedBox(width: 4),
                      Text('Saved',
                          style: TextStyle(
                              color: AppTheme.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            obscureText: !isVisible,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: placeholder,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: IconButton(
                icon: Icon(
                  isVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
                onPressed: onToggle,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.open_in_new_rounded,
                  size: 12, color: AppTheme.textSecondary),
              const SizedBox(width: 5),
              Text(
                'Get your key at $learnMoreUrl',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _save,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppTheme.accent, Color(0xFF9C63FF)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text(
                  'Save Settings',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _buildAboutRow(
              Icons.mic_rounded, 'Transcription', 'OpenAI Whisper'),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1)),
          _buildAboutRow(
              Icons.auto_awesome_rounded, 'Summaries', 'GPT-4o / Claude'),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1)),
          _buildAboutRow(
              Icons.smartphone_rounded, 'Platform', 'Android & iOS'),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1)),
          _buildAboutRow(
              Icons.storage_rounded, 'Storage', 'Local (on device)'),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1)),
          _buildAboutRow(
              Icons.info_outline_rounded, 'Version', '1.0.0 · Phase 3+4'),
        ],
      ),
    );
  }

  Widget _buildAboutRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 17),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 14)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
