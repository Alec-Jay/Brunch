import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../models/meeting.dart';
import '../services/audio_recorder_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/waveform_widget.dart';

class NewMeetingScreen extends StatefulWidget {
  const NewMeetingScreen({super.key});

  @override
  State<NewMeetingScreen> createState() => _NewMeetingScreenState();
}

class _NewMeetingScreenState extends State<NewMeetingScreen>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController(
    text:
        'Meeting ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
  );
  final _participantController = TextEditingController();
  final _recorder = AudioRecorderService();

  bool _isRecording = false;
  bool _isSaving = false;
  bool _permissionDenied = false;
  int _seconds = 0;
  Timer? _timer;
  String? _audioFilePath;
  final List<String> _participants = [];

  // Waveform bars driven by amplitude
  final List<double> _waveformBars = List.filled(30, 0.1);
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _participantController.dispose();
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    _recorder.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final filePath = await _recorder.startRecording();
    if (filePath == null) {
      setState(() => _permissionDenied = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied. Please enable it in Settings.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _permissionDenied = false;
      _audioFilePath = filePath;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });

    _pulseController.repeat(reverse: true);

    _amplitudeSubscription = _recorder.amplitudeStream.listen((amp) {
      if (!mounted) return;
      final normalised = ((amp.current + 60) / 60).clamp(0.05, 1.0);
      setState(() {
        _waveformBars.removeAt(0);
        _waveformBars.add(normalised);
      });
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    final (path, fileSize) = await _recorder.stopRecording();
    setState(() {
      _isRecording = false;
      _audioFilePath = path;
    });

    if (!mounted) return;

    if (path != null && fileSize > 500) {
      final kb = (fileSize / 1024).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 18),
              const SizedBox(width: 10),
              Text('Audio captured — ${kb}KB · ${_seconds}s'),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Text('Microphone not captured',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                fileSize == 0
                    ? 'File was empty (${fileSize}B). Check Windows Privacy → Microphone → allow desktop apps.'
                    : 'File too small (${fileSize}B). Microphone may be blocked.',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _saveAndClose() async {
    if (_seconds == 0) return;

    setState(() => _isSaving = true);

    if (_isRecording) await _stopRecording();

    final meeting = Meeting(
      id: const Uuid().v4(),
      title: _titleController.text.trim().isEmpty
          ? 'Untitled Meeting'
          : _titleController.text.trim(),
      date: DateTime.now(),
      durationSeconds: _seconds,
      audioFilePath: _audioFilePath,
      transcript: '',
      summary: '',
      actionItems: const [],
      participants: List.from(_participants),
    );

    await StorageService.instance.saveMeeting(meeting);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _discard() async {
    if (_seconds == 0) {
      Navigator.pop(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discard recording?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This recording will be permanently deleted.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (_isRecording) await _recorder.cancelRecording();
      if (mounted) Navigator.pop(context);
    }
  }

  String get _formattedTime {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: _discard,
        ),
        title: const Text('New Meeting'),
        actions: [
          if (_seconds > 0 && !_isRecording && !_isSaving)
            TextButton(
              onPressed: _saveAndClose,
              child: const Text(
                'Save',
                style: TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
            ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTitleField(),
            _buildParticipantsField(),
            Expanded(child: _buildRecordingArea()),
            _buildTranscriptPreview(),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: TextField(
          controller: _titleController,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: const InputDecoration(
            hintText: 'Meeting title',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            prefixIcon: Icon(Icons.edit_outlined,
                color: AppTheme.textSecondary, size: 18),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantsField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_outline_rounded,
                    color: AppTheme.textSecondary, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'Participants',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                Text(
                  '(helps AI identify speakers)',
                  style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.6),
                      fontSize: 11),
                ),
              ],
            ),
            if (_participants.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _participants.map((name) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _participants.remove(name)),
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _participantController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onSubmitted: _addParticipant,
                    decoration: const InputDecoration(
                      hintText: 'Add a name and press Enter...',
                      hintStyle: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _addParticipant(_participantController.text),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: AppTheme.accent, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addParticipant(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _participants.contains(trimmed)) return;
    setState(() => _participants.add(trimmed));
    _participantController.clear();
  }

  Widget _buildRecordingArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Timer
        Text(
          _formattedTime,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.w200,
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            key: ValueKey('$_isRecording-$_seconds-$_permissionDenied'),
            _permissionDenied
                ? 'Microphone access denied'
                : _isRecording
                    ? 'Recording...'
                    : _seconds > 0
                        ? 'Paused — tap to resume'
                        : 'Tap the button to start',
            style: TextStyle(
              color: _permissionDenied
                  ? AppTheme.errorColor
                  : AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ),

        // Waveform display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isRecording
                    ? AppTheme.accent.withValues(alpha: 0.3)
                    : AppTheme.border,
              ),
            ),
            child: WaveformWidget(
              amplitudes: _waveformBars,
              isRecording: _isRecording,
              height: 72,
            ),
          ),
        ),

        // Record button
        ScaleTransition(
          scale: _isRecording
              ? _pulseAnimation
              : const AlwaysStoppedAnimation(1.0),
          child: GestureDetector(
            onTap: _toggleRecording,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isRecording
                      ? [const Color(0xFFFF5252), const Color(0xFFFF1744)]
                      : [AppTheme.accent, const Color(0xFF9C63FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : AppTheme.accent)
                        .withValues(alpha: 0.5),
                    blurRadius: 28,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isRecording ? 'Tap to stop' : 'Tap to start recording',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTranscriptPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_snippet_outlined,
                  color: AppTheme.textSecondary, size: 15),
              const SizedBox(width: 6),
              const Text(
                'Live Transcript',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _isRecording
                      ? const Color(0xFFFF5252)
                      : AppTheme.textSecondary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isRecording ? 'LIVE' : 'IDLE',
                style: TextStyle(
                  color: _isRecording
                      ? const Color(0xFFFF5252)
                      : AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _isRecording
                ? 'Recording audio... Whisper AI transcription will be added in Phase 3.'
                : _seconds > 0
                    ? 'Recording paused. Resume or save your meeting.'
                    : 'Start recording and your words will appear here automatically.',
            style: TextStyle(
              color: _isRecording
                  ? Colors.white.withValues(alpha: 0.6)
                  : AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
              fontStyle:
                  _isRecording ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    if (_seconds == 0 || _isRecording) {
      return const SizedBox(height: 24);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              label: 'Discard',
              icon: Icons.delete_outline_rounded,
              color: AppTheme.errorColor,
              onTap: _discard,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _buildActionButton(
              label: 'Save & Summarize',
              icon: Icons.auto_awesome_rounded,
              color: AppTheme.accent,
              filled: true,
              onTap: _saveAndClose,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: filled
              ? null
              : Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: filled
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5))
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: filled ? Colors.white : color, size: 17),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
