import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/meeting.dart';
import '../theme/app_theme.dart';

class MeetingDetailScreen extends StatefulWidget {
  final Meeting meeting;

  const MeetingDetailScreen({super.key, required this.meeting});

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  bool _showFullTranscript = false;

  // Audio playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _audioExists = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    final path = widget.meeting.audioFilePath;
    if (path == null || path.isEmpty) return;

    final file = File(path);
    final exists = await file.exists();
    if (!mounted) return;

    if (!exists) {
      setState(() => _audioExists = false);
      return;
    }

    // Verify the file has actual content
    final size = await file.length();
    if (!mounted) return;
    setState(() => _audioExists = size > 1024);
    if (size <= 1024) return;

    // Configure audio context for Android
    await _audioPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.defaultToSpeaker},
        ),
      ),
    );

    await _audioPlayer.setReleaseMode(ReleaseMode.stop);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _togglePlayback() async {
    try {
      if (_playerState == PlayerState.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(
          DeviceFileSource(widget.meeting.audioFilePath!),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildMetaRow(),
                const SizedBox(height: 16),
                if (_audioExists) ...[
                  _buildAudioPlayer(),
                  const SizedBox(height: 14),
                ],
                if (widget.meeting.participants.isNotEmpty) ...[
                  _buildParticipantsSection(),
                  const SizedBox(height: 14),
                ],
                _buildSummarySection(),
                const SizedBox(height: 14),
                if (widget.meeting.actionItems.isNotEmpty) ...[
                  _buildActionItemsSection(),
                  const SizedBox(height: 14),
                ],
                _buildTranscriptSection(),
              ]),
            ),
          ),
        ],
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
        widget.meeting.title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_rounded, color: AppTheme.textSecondary),
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
        _buildBadge(Icons.calendar_today_rounded, widget.meeting.formattedFullDate, AppTheme.textSecondary),
        _buildBadge(Icons.timer_outlined, widget.meeting.formattedDuration, AppTheme.accent),
        if (widget.meeting.summary.isNotEmpty)
          _buildBadge(Icons.auto_awesome_rounded, 'AI Summary', AppTheme.accentSecondary),
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
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
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
                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
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
              // Rewind 10s
              IconButton(
                icon: const Icon(Icons.replay_10_rounded,
                    color: AppTheme.textSecondary, size: 28),
                onPressed: () async {
                  final newPos = Duration(
                      seconds:
                          (_position.inSeconds - 10).clamp(0, _duration.inSeconds));
                  await _audioPlayer.seek(newPos);
                },
              ),
              const SizedBox(width: 12),
              // Play / Pause
              GestureDetector(
                onTap: _togglePlayback,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppTheme.accent, Color(0xFF9C63FF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
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
              // Forward 10s
              IconButton(
                icon: const Icon(Icons.forward_10_rounded,
                    color: AppTheme.textSecondary, size: 28),
                onPressed: () async {
                  final newPos = Duration(
                      seconds:
                          (_position.inSeconds + 10).clamp(0, _duration.inSeconds));
                  await _audioPlayer.seek(newPos);
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
        children: widget.meeting.participants.map((name) {
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accentSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppTheme.accentSecondary.withValues(alpha: 0.25)),
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
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
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

  Widget _buildSummarySection() {
    final hasSummary = widget.meeting.summary.isNotEmpty;
    return _buildSection(
      icon: Icons.auto_awesome_rounded,
      iconColor: AppTheme.accentSecondary,
      title: 'AI Summary',
      child: hasSummary
          ? Text(
              widget.meeting.summary,
              style: const TextStyle(
                  color: Color(0xFFCDD5E0), fontSize: 14, height: 1.65),
            )
          : Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accentSecondary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color:
                        AppTheme.accentSecondary.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accentSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.hourglass_top_rounded,
                        color: AppTheme.accentSecondary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coming in Phase 4',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Claude AI will generate a smart summary with action items after transcription.',
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
    );
  }

  Widget _buildActionItemsSection() {
    return _buildSection(
      icon: Icons.check_circle_outline_rounded,
      iconColor: AppTheme.success,
      title: 'Action Items',
      child: Column(
        children: widget.meeting.actionItems.asMap().entries.map((entry) {
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
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.4), width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: AppTheme.success,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTranscriptSection() {
    final hasTranscript = widget.meeting.transcript.isNotEmpty;

    return _buildSection(
      icon: Icons.text_snippet_outlined,
      iconColor: AppTheme.textSecondary,
      title: 'Transcript',
      trailing: hasTranscript
          ? GestureDetector(
              onTap: () =>
                  setState(() => _showFullTranscript = !_showFullTranscript),
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
                  widget.meeting.transcript,
                  maxLines: _showFullTranscript ? null : 4,
                  overflow: _showFullTranscript
                      ? TextOverflow.visible
                      : TextOverflow.fade,
                  style: const TextStyle(
                      color: Color(0xFF8892A4), fontSize: 14, height: 1.65),
                ),
                if (!_showFullTranscript &&
                    widget.meeting.transcript.length > 200)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _showFullTranscript = true),
                      child: const Text(
                        'Show full transcript',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
              ],
            )
          : Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
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
                    child: const Icon(Icons.hourglass_top_rounded,
                        color: AppTheme.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coming in Phase 3',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Whisper AI will automatically transcribe your recording when you save.',
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
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  void _shareAsText() {
    final actionsList = widget.meeting.actionItems.isEmpty
        ? 'None'
        : widget.meeting.actionItems.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n');

    final text = '''${widget.meeting.title}
${widget.meeting.formattedFullDate} · ${widget.meeting.formattedDuration}

SUMMARY
${widget.meeting.summary.isEmpty ? 'No summary.' : widget.meeting.summary}

ACTION ITEMS
$actionsList

TRANSCRIPT
${widget.meeting.transcript.isEmpty ? 'No transcript.' : widget.meeting.transcript}
''';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meeting copied to clipboard')),
    );
  }
}
