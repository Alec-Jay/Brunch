import 'package:flutter/material.dart';
import '../services/api_keys_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _groqController = TextEditingController();
  final _openAIController = TextEditingController();
  final _claudeController = TextEditingController();
  bool _showGroq = false;
  bool _showOpenAI = false;
  bool _showClaude = false;
  bool _groqSaved = false;
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
    final groq = await ApiKeysService.instance.getGroqKey();
    final openAi = await ApiKeysService.instance.getOpenAiKey();
    final claude = await ApiKeysService.instance.getClaudeKey();
    if (mounted) {
      setState(() {
        if (groq != null) { _groqController.text = groq; _groqSaved = true; }
        if (openAi != null) { _openAIController.text = openAi; _openAISaved = true; }
        if (claude != null) { _claudeController.text = claude; _claudeSaved = true; }
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await ApiKeysService.instance.saveGroqKey(_groqController.text);
    await ApiKeysService.instance.saveOpenAiKey(_openAIController.text);
    await ApiKeysService.instance.saveClaudeKey(_claudeController.text);
    if (mounted) {
      setState(() {
        _isSaving = false;
        _groqSaved = _groqController.text.trim().isNotEmpty;
        _openAISaved = _openAIController.text.trim().isNotEmpty;
        _claudeSaved = _claudeController.text.trim().isNotEmpty;
      });
      final anyKey = _groqSaved || _openAISaved || _claudeSaved;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(anyKey ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: anyKey ? AppTheme.success : AppTheme.textSecondary,
                  size: 18),
              const SizedBox(width: 8),
              Text(anyKey ? 'API key saved — ready to transcribe!' : 'Saved (no key entered yet)'),
            ],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _groqController.dispose();
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
              ? const Center(child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildFreeOptionBanner(),
                    const SizedBox(height: 24),

                    // ── GROQ (FREE — RECOMMENDED) ──
                    _buildSectionLabel('GROQ — FREE  ✦  RECOMMENDED'),
                    const SizedBox(height: 10),
                    _buildApiKeyCard(
                      label: 'Groq API Key',
                      subtitle: 'Free · Whisper-large-v3 transcription + Llama 3 summaries',
                      icon: Icons.bolt_rounded,
                      iconColor: const Color(0xFFF97316),
                      controller: _groqController,
                      isVisible: _showGroq,
                      isSaved: _groqSaved,
                      onToggle: () => setState(() => _showGroq = !_showGroq),
                      placeholder: 'gsk_...',
                      learnMoreUrl: 'console.groq.com',
                      isFree: true,
                    ),

                    const SizedBox(height: 28),
                    _buildSectionLabel('OPENAI — OPTIONAL (PAID)'),
                    const SizedBox(height: 10),
                    _buildApiKeyCard(
                      label: 'OpenAI API Key',
                      subtitle: 'Whisper-1 transcription + GPT-4o summaries',
                      icon: Icons.psychology_rounded,
                      iconColor: AppTheme.accentSecondary,
                      controller: _openAIController,
                      isVisible: _showOpenAI,
                      isSaved: _openAISaved,
                      onToggle: () => setState(() => _showOpenAI = !_showOpenAI),
                      placeholder: 'sk-...',
                      learnMoreUrl: 'platform.openai.com/api-keys',
                    ),

                    const SizedBox(height: 20),
                    _buildSectionLabel('ANTHROPIC CLAUDE — OPTIONAL (PAID)'),
                    const SizedBox(height: 10),
                    _buildApiKeyCard(
                      label: 'Claude API Key',
                      subtitle: 'Claude Haiku for summaries (used instead of Groq/GPT-4o)',
                      icon: Icons.auto_awesome_rounded,
                      iconColor: AppTheme.accent,
                      controller: _claudeController,
                      isVisible: _showClaude,
                      isSaved: _claudeSaved,
                      onToggle: () => setState(() => _showClaude = !_showClaude),
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
                  style: TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold)),
              Text('Configure AI integrations',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFreeOptionBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF97316).withValues(alpha: 0.12),
            const Color(0xFFF97316).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFFF97316), size: 18),
              SizedBox(width: 8),
              Text('Start for FREE with Groq',
                  style: TextStyle(color: Colors.white, fontSize: 14,
                      fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              _FreeBadge(),
            ],
          ),
          const SizedBox(height: 10),
          _buildStep('1', 'Go to console.groq.com → sign up (free, no credit card)'),
          _buildStep('2', 'Click "API Keys" → "Create API key" → copy it'),
          _buildStep('3', 'Paste it in the Groq field below → tap Save'),
          _buildStep('4', 'Record a meeting → open it → tap Transcribe'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 13),
                SizedBox(width: 6),
                Text('Free tier: 28,800 sec/day transcription + unlimited summaries',
                    style: TextStyle(color: AppTheme.success, fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18, height: 18,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(num,
                  style: const TextStyle(color: Color(0xFFF97316),
                      fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppTheme.textSecondary,
                    fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 1.1));
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
    bool isFree = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSaved
              ? AppTheme.success.withValues(alpha: 0.4)
              : isFree
                  ? const Color(0xFFF97316).withValues(alpha: 0.3)
                  : AppTheme.border,
          width: isFree && !isSaved ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(label,
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        if (isFree) const SizedBox(width: 6),
                        if (isFree) const _FreeBadge(),
                      ],
                    ),
                    Text(subtitle,
                        style: const TextStyle(color: AppTheme.textSecondary,
                            fontSize: 11, height: 1.3)),
                  ],
                ),
              ),
              if (isSaved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: AppTheme.success, size: 11),
                      SizedBox(width: 4),
                      Text('Saved',
                          style: TextStyle(color: AppTheme.success,
                              fontSize: 11, fontWeight: FontWeight.w600)),
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
                  isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.textSecondary, size: 18,
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
              Text('Get your key at $learnMoreUrl',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
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
            BoxShadow(color: AppTheme.accent.withValues(alpha: 0.35),
                blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Save Settings',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 15)),
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
          _buildAboutRow(Icons.bolt_rounded, 'Transcription', 'Groq Whisper-large-v3'),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1)),
          _buildAboutRow(Icons.smart_toy_rounded, 'Summaries', 'Groq Llama 3 / Claude / GPT-4o'),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1)),
          _buildAboutRow(Icons.smartphone_rounded, 'Platform', 'Android & iOS'),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1)),
          _buildAboutRow(Icons.storage_rounded, 'Storage', 'Local (on device)'),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1)),
          _buildAboutRow(Icons.info_outline_rounded, 'Version', '1.0.0 · Phase 3+4'),
        ],
      ),
    );
  }

  Widget _buildAboutRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 17),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _FreeBadge extends StatelessWidget {
  const _FreeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
      ),
      child: const Text('FREE',
          style: TextStyle(color: AppTheme.success, fontSize: 10,
              fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }
}
