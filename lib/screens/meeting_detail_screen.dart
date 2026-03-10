import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/meeting.dart';
import '../services/api_keys_service.dart';
import '../services/storage_service.dart';
import '../services/summary_service.dart';
import '../services/transcription_service.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';

class MeetingDetailScreen extends StatefulWidget {
  final Meeting meeting;
  const MeetingDetailScreen({super.key, required this.meeting});

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  late Meeting _meeting;
  bool _showFullTranscript = false;

  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _audioExists = false;

  // AI states
  bool _isTranscribing = false;
  bool _isSummarizing = false;
  String _aiStatus = '';

  @override
  void initState() {
    super.initState();
    _meeting = widget.meeting;
    _initAudio();
  }

  Future<void> _initAudio() async {
    final path = _meeting.audioFilePath;
    if (path == null || path.isEmpty) return;

    final file = File(path);
    if (!await file.exists()) return;

    final size = await file.length();
    if (!mounted) return;
    if (size <= 1024) return;

    setState(() => _audioExists = true);

    // Fix: removed defaultToSpeaker (only valid with playAndRecord category)
    await _audioPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {},
        ),
      ),
    );

    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _audioPlayer.onPlayerStateChanged
        .listen((s) { if (mounted) setState(() => _playerState = s); });
    _audioPlayer.onPositionChanged
        .listen((p) { if (mounted) setState(() => _position = p); });
    _audioPlayer.onDurationChanged
        .listen((d) { if (mounted) setState(() => _duration = d); });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        _playerState = PlayerState.stopped;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Transcription ───────────────────────────────────────────
  Future<void> _transcribe() async {
    final creds = await ApiKeysService.instance.getBestTranscriptionKey();
    if (!mounted) return;

    if (creds == null) {
      _showNoKeyDialog();
      return;
    }

    final providerLabel = creds.provider == 'groq' ? 'Groq Whisper' : 'OpenAI Whisper';
    setState(() { _isTranscribing = true; _aiStatus = 'Sending audio to $providerLabel...'; });

    try {
      setState(() => _aiStatus = 'Transcribing speech to text...');
      final result = await TranscriptionService.instance
          .transcribe(_meeting.audioFilePath!, creds.key, creds.provider);

      if (!mounted) return;
      final updated = _meeting.copyWith(transcript: result.text);
      await StorageService.instance.updateMeeting(updated);
      setState(() {
        _meeting = updated;
        _isTranscribing = false;
        _aiStatus = '';
      });

      // Auto-trigger summary right after transcription
      if (mounted) _summarize();
    } on TranscriptionException catch (e) {
      if (!mounted) return;
      setState(() { _isTranscribing = false; _aiStatus = ''; });
      _showError('Transcription failed', e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() { _isTranscribing = false; _aiStatus = ''; });
      _showError('Transcription failed', 'Unexpected error: $e');
    }
  }

  // ─── Summary ─────────────────────────────────────────────────
  Future<void> _summarize() async {
    if (_meeting.transcript.isEmpty) return;

    final creds = await ApiKeysService.instance.getBestSummaryKey();
    if (!mounted) return;

    if (creds == null) {
      _showNoKeyDialog();
      return;
    }

    setState(() { _isSummarizing = true; _aiStatus = 'Generating AI summary...'; });

    try {
      SummaryResult result;
      if (creds.provider == 'groq') {
        setState(() => _aiStatus = 'Summarizing with Llama 3 (Groq)...');
        result = await SummaryService.instance
            .summarizeWithGroq(_meeting.transcript, creds.key);
      } else if (creds.provider == 'claude') {
        setState(() => _aiStatus = 'Summarizing with Claude...');
        result = await SummaryService.instance
            .summarizeWithClaude(_meeting.transcript, creds.key);
      } else {
        setState(() => _aiStatus = 'Summarizing with GPT-4o...');
        result = await SummaryService.instance
            .summarizeWithOpenAI(_meeting.transcript, creds.key);
      }

      if (!mounted) return;
      final updated = _meeting.copyWith(
        summary: result.summary,
        actionItems: [
          ...result.actionItems,
          if (result.keyDecisions.isNotEmpty)
            ...result.keyDecisions
                .map((d) => '📌 Decision: $d'),
        ],
      );
      await StorageService.instance.updateMeeting(updated);
      setState(() {
        _meeting = updated;
        _isSummarizing = false;
        _aiStatus = '';
      });
    } on SummaryException catch (e) {
      if (!mounted) return;
      setState(() { _isSummarizing = false; _aiStatus = ''; });
      _showError('Summary failed', e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() { _isSummarizing = false; _aiStatus = ''; });
      _showError('Summary failed', 'Unexpected error: $e');
    }
  }

  void _showNoKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('API Key Required',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'You need an OpenAI API key to use transcription and summaries.\n\nGo to Settings → add your key → Save.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            child: const Text('Open Settings',
                style: TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.errorColor, size: 20),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(message,
            style: const TextStyle(
                color: AppTheme.textSecondary, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK',
                  style: TextStyle(color: AppTheme.accent))),
        ],
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMetaRow(),
                    const SizedBox(height: 16),
                    if (_audioExists) ...[
                      _buildAudioPlayer(),
                      const SizedBox(height: 14),
                    ],
                    if (_meeting.participants.isNotEmpty) ...[
                      _buildParticipantsSection(),
                      const SizedBox(height: 14),
                    ],
                    _buildTranscriptSection(),
                    const SizedBox(height: 14),
                    _buildSummarySection(),
                    const SizedBox(height: 14),
                    if (_meeting.actionItems.isNotEmpty) ...[
                      _buildActionItemsSection(),
                      const SizedBox(height: 14),
                    ],
                  ]),
                ),
              ),
            ],
          ),
          // AI loading overlay
          if (_isTranscribing || _isSummarizing) _buildAiOverlay(),
        ],
      ),
    );
  }

  Widget _buildAiOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              AppTheme.background,
              AppTheme.background.withValues(alpha: 0.95),
              Colors.transparent,
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: _isTranscribing
                      ? AppTheme.accentSecondary
                      : AppTheme.accent,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isTranscribing ? 'Transcribing...' : 'Summarizing...',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    if (_aiStatus.isNotEmpty)
                      Text(_aiStatus,
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isTranscribing ? 'Whisper' : 'Llama 3',
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: AppTheme.background,
      pinned: true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        _meeting.title,
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 17),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_rounded,
              color: AppTheme.textSecondary),
          onPressed: _shareAsText,
          tooltip: 'Copy to clipboard',
        ),
      ],
    );
  }

  Widget _buildMetaRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildBadge(Icons.calendar_today_rounded,
            _meeting.formattedFullDate, AppTheme.textSecondary),
        _buildBadge(Icons.timer_outlined,
            _meeting.formattedDuration, AppTheme.accent),
        if (_meeting.transcript.isNotEmpty)
          _buildBadge(Icons.text_snippet_outlined, 'Transcribed',
              AppTheme.accentSecondary),
        if (_meeting.summary.isNotEmpty)
          _buildBadge(Icons.auto_awesome_rounded, 'AI Summary',
              AppTheme.success),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer() {
    final isPlaying = _playerState == PlayerState.playing;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying
              ? AppTheme.accent.withValues(alpha: 0.4)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.headphones_rounded,
                    size: 15, color: AppTheme.accent),
              ),
              const SizedBox(width: 10),
              const Text('Recording',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '${_fmt(_position)} / ${_fmt(_duration)}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.border,
              thumbColor: AppTheme.accent,
              overlayColor: AppTheme.accent.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (v) async {
                final pos = Duration(
                    milliseconds:
                        (v * _duration.inMilliseconds).round());
                await _audioPlayer.seek(pos);
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10_rounded,
                    color: AppTheme.textSecondary, size: 28),
                onPressed: () async {
                  final p = Duration(
                      seconds: (_position.inSeconds - 10)
                          .clamp(0, _duration.inSeconds));
                  await _audioPlayer.seek(p);
                },
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  try {
                    if (isPlaying) {
                      await _audioPlayer.pause();
                    } else {
                      await _audioPlayer
                          .play(DeviceFileSource(_meeting.audioFilePath!));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Playback error: $e')));
                    }
                  }
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: [AppTheme.accent, Color(0xFF9C63FF)]),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.forward_10_rounded,
                    color: AppTheme.textSecondary, size: 28),
                onPressed: () async {
                  final p = Duration(
                      seconds: (_position.inSeconds + 10)
                          .clamp(0, _duration.inSeconds));
                  await _audioPlayer.seek(p);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return _buildSection(
      icon: Icons.people_alt_rounded,
      iconColor: AppTheme.accentSecondary,
      title: 'Participants',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _meeting.participants.map((name) {
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color:
                      AppTheme.accentSecondary.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(name[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 7),
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTranscriptSection() {
    final hasTranscript = _meeting.transcript.isNotEmpty;
    final canTranscribe =
        _audioExists && !_isTranscribing && !_isSummarizing;

    return _buildSection(
      icon: Icons.text_snippet_outlined,
      iconColor: AppTheme.accentSecondary,
      title: 'Transcript',
      trailing: hasTranscript
          ? GestureDetector(
              onTap: () => setState(
                  () => _showFullTranscript = !_showFullTranscript),
              child: Text(
                _showFullTranscript ? 'Collapse' : 'Expand',
                style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            )
          : null,
      child: hasTranscript
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _meeting.transcript,
                  maxLines: _showFullTranscript ? null : 5,
                  overflow: _showFullTranscript
                      ? TextOverflow.visible
                      : TextOverflow.fade,
                  style: const TextStyle(
                      color: Color(0xFF8892A4),
                      fontSize: 14,
                      height: 1.65),
                ),
                if (!_showFullTranscript &&
                    _meeting.transcript.length > 250)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _showFullTranscript = true),
                      child: const Text('Show full transcript',
                          style: TextStyle(
                              color: AppTheme.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                const SizedBox(height: 12),
                // Re-transcribe option
                GestureDetector(
                  onTap: canTranscribe ? _transcribe : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded,
                          color: AppTheme.textSecondary, size: 14),
                      const SizedBox(width: 5),
                      const Text('Re-transcribe',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSecondary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.accentSecondary
                            .withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.accentSecondary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.mic_none_rounded,
                            color: AppTheme.accentSecondary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('No transcript yet',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(height: 2),
                            Text(
                              'Tap the button below to convert your recording to text using Whisper AI.',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (canTranscribe) ...[
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: Icons.transcribe_rounded,
                    label: 'Transcribe with Whisper',
                    sublabel: 'Converts audio to text · OpenAI Whisper',
                    color: AppTheme.accentSecondary,
                    onTap: _transcribe,
                  ),
                ] else if (!_audioExists) ...[
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 13, color: AppTheme.textSecondary),
                      SizedBox(width: 6),
                      Text('No audio recording found for this meeting',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildSummarySection() {
    final hasSummary = _meeting.summary.isNotEmpty;
    final hasTranscript = _meeting.transcript.isNotEmpty;
    final canSummarize =
        hasTranscript && !_isTranscribing && !_isSummarizing;

    return _buildSection(
      icon: Icons.auto_awesome_rounded,
      iconColor: AppTheme.accent,
      title: 'AI Summary',
      child: hasSummary
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _meeting.summary,
                  style: const TextStyle(
                      color: Color(0xFFCDD5E0),
                      fontSize: 14,
                      height: 1.65),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: canSummarize ? _summarize : null,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          color: AppTheme.textSecondary, size: 14),
                      SizedBox(width: 5),
                      Text('Regenerate summary',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: AppTheme.accent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('No summary yet',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              hasTranscript
                                  ? 'Tap below to generate a summary with action items.'
                                  : 'Transcribe the audio first, then generate a summary.',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (canSummarize) ...[
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Generate AI Summary',
                    sublabel: 'Summary + action items · GPT-4o / Claude',
                    color: AppTheme.accent,
                    onTap: _summarize,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildActionItemsSection() {
    return _buildSection(
      icon: Icons.check_circle_outline_rounded,
      iconColor: AppTheme.success,
      title: 'Action Items',
      child: Column(
        children: _meeting.actionItems.asMap().entries.map((entry) {
          final isDecision = entry.value.startsWith('📌');
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: isDecision
                        ? AppTheme.accentSecondary.withValues(alpha: 0.1)
                        : null,
                    border: Border.all(
                        color: isDecision
                            ? AppTheme.accentSecondary
                                .withValues(alpha: 0.4)
                            : AppTheme.success.withValues(alpha: 0.4),
                        width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: isDecision
                        ? Icon(Icons.push_pin_rounded,
                            size: 11,
                            color: AppTheme.accentSecondary
                                .withValues(alpha: 0.8))
                        : Text('${entry.key + 1}',
                            style: const TextStyle(
                                color: AppTheme.success,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isDecision
                        ? entry.value.replaceFirst('📌 Decision: ', '')
                        : entry.value,
                    style: TextStyle(
                        color: isDecision
                            ? AppTheme.accentSecondary
                                .withValues(alpha: 0.9)
                            : Colors.white,
                        fontSize: 14,
                        height: 1.45),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text(sublabel,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.6), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _shareAsText() {
    final actionsList = _meeting.actionItems.isEmpty
        ? 'None'
        : _meeting.actionItems
            .asMap()
            .entries
            .map((e) => '${e.key + 1}. ${e.value}')
            .join('\n');

    final text = '''${_meeting.title}
${_meeting.formattedFullDate} · ${_meeting.formattedDuration}

SUMMARY
${_meeting.summary.isEmpty ? 'No summary.' : _meeting.summary}

ACTION ITEMS
$actionsList

TRANSCRIPT
${_meeting.transcript.isEmpty ? 'No transcript.' : _meeting.transcript}
''';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meeting copied to clipboard')),
    );
  }
}
