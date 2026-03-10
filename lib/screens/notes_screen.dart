import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/audio_recorder_service.dart';
import '../services/notes_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/waveform_widget.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final notes = await NotesStorageService.instance.loadNotes();
    if (mounted) setState(() { _notes = notes; _isLoading = false; });
  }

  void _showNewNoteOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2))),
              const Text('New Note',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _OptionButton(
                      icon: Icons.keyboard_rounded,
                      label: 'Text Note',
                      color: const Color(0xFF00B09B),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openTextNoteEditor();
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _OptionButton(
                      icon: Icons.mic_rounded,
                      label: 'Voice Note',
                      color: AppTheme.accent,
                      onTap: () {
                        Navigator.pop(ctx);
                        _openVoiceNoteRecorder();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTextNoteEditor({Note? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _TextNoteEditor(
        existing: existing,
        onSave: (note) async {
          await NotesStorageService.instance.saveNote(note);
          _load();
        },
      ),
    );
  }

  void _openVoiceNoteRecorder() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _VoiceNoteRecorder(
        onSave: (note) async {
          await NotesStorageService.instance.saveNote(note);
          _load();
        },
      ),
    );
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete note?',
            style: TextStyle(color: Colors.white)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.errorColor))),
        ],
      ),
    );
    if (confirmed == true) {
      await NotesStorageService.instance.deleteNote(note.id);
      if (note.audioFilePath != null) {
        await File(note.audioFilePath!).delete().catchError((_) {});
      }
      _load();
    }
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
            colors: [Color(0xFF0A1812), Color(0xFF0D1A14), Color(0xFF080C10)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewNoteOptions,
        backgroundColor: const Color(0xFF00B09B),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Note',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notes',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                Text('Text & voice notes',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(
              color: Color(0xFF00B09B), strokeWidth: 2));
    }
    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF00B09B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color:
                        const Color(0xFF00B09B).withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.note_alt_outlined,
                  color: Color(0xFF00B09B), size: 34),
            ),
            const SizedBox(height: 16),
            const Text('No notes yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Tap "New Note" to create a text or voice note',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: _notes.length,
      itemBuilder: (ctx, i) => _NoteCard(
        note: _notes[i],
        onTap: () => _notes[i].type == NoteType.text
            ? _openTextNoteEditor(existing: _notes[i])
            : null,
        onDelete: () => _deleteNote(_notes[i]),
      ),
    );
  }
}

// ─── Option Button ───────────────────────────────────────────────
class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Text Note Editor ────────────────────────────────────────────
class _TextNoteEditor extends StatefulWidget {
  final Note? existing;
  final Future<void> Function(Note) onSave;

  const _TextNoteEditor({this.existing, required this.onSave});

  @override
  State<_TextNoteEditor> createState() => _TextNoteEditorState();
}

class _TextNoteEditorState extends State<_TextNoteEditor> {
  late TextEditingController _title;
  late TextEditingController _content;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _content = TextEditingController(text: widget.existing?.content ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty && _content.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    final note = Note(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: _title.text.trim().isEmpty ? 'Untitled Note' : _title.text.trim(),
      content: _content.text.trim(),
      date: DateTime.now(),
      type: NoteType.text,
    );
    await widget.onSave(note);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2))),
            Row(
              children: [
                const Icon(Icons.keyboard_rounded,
                    color: Color(0xFF00B09B), size: 20),
                const SizedBox(width: 8),
                const Text('Text Note',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_saving)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF00B09B)))
                else
                  TextButton(
                    onPressed: _save,
                    child: const Text('Save',
                        style: TextStyle(
                            color: Color(0xFF00B09B),
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const Divider(color: AppTheme.border),
            Expanded(
              child: TextField(
                controller: _content,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 15, height: 1.6),
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'Start typing your note...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Voice Note Recorder ─────────────────────────────────────────
class _VoiceNoteRecorder extends StatefulWidget {
  final Future<void> Function(Note) onSave;
  const _VoiceNoteRecorder({required this.onSave});

  @override
  State<_VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

class _VoiceNoteRecorderState extends State<_VoiceNoteRecorder>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorderService();
  final _titleController = TextEditingController();
  bool _isRecording = false;
  bool _saving = false;
  int _seconds = 0;
  Timer? _timer;
  String? _filePath;
  final List<double> _bars = List.filled(30, 0.05);
  StreamSubscription? _ampSub;

  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    _pulse.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isRecording) {
      _timer?.cancel();
      _ampSub?.cancel();
      _pulse.stop();
      _pulse.reset();
      final (path, _) = await _recorder.stopRecording();
      setState(() { _isRecording = false; _filePath = path; });
    } else {
      final path = await _recorder.startRecording();
      if (path == null) return;
      setState(() { _isRecording = true; _filePath = path; });
      _timer = Timer.periodic(const Duration(seconds: 1),
          (_) => setState(() => _seconds++));
      _pulse.repeat(reverse: true);
      _ampSub = _recorder.amplitudeStream.listen((amp) {
        if (!mounted) return;
        final v = ((amp.current + 60) / 60).clamp(0.05, 1.0);
        setState(() { _bars.removeAt(0); _bars.add(v); });
      });
    }
  }

  Future<void> _save() async {
    if (_seconds == 0 || _filePath == null) {
      Navigator.pop(context);
      return;
    }
    if (_isRecording) await _toggle();
    setState(() => _saving = true);
    final note = Note(
      id: const Uuid().v4(),
      title: _titleController.text.trim().isEmpty
          ? 'Voice note ${DateTime.now().day}/${DateTime.now().month}'
          : _titleController.text.trim(),
      content: '',
      date: DateTime.now(),
      type: NoteType.voice,
      audioFilePath: _filePath,
      durationSeconds: _seconds,
    );
    await widget.onSave(note);
    if (mounted) Navigator.pop(context);
  }

  String get _time {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        children: [
          Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2))),
          Row(
            children: [
              const Icon(Icons.mic_rounded, color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              const Text('Voice Note',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_seconds > 0 && !_isRecording)
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2,
                              color: AppTheme.accent))
                      : const Text('Save',
                          style: TextStyle(color: AppTheme.accent,
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Voice note title (optional)',
              hintStyle: TextStyle(color: AppTheme.textSecondary),
              border: InputBorder.none, contentPadding: EdgeInsets.zero,
            ),
          ),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 12),
          Text(_time,
              style: const TextStyle(color: Colors.white, fontSize: 42,
                  fontWeight: FontWeight.w200, letterSpacing: 4)),
          const SizedBox(height: 8),
          WaveformWidget(amplitudes: _bars, isRecording: _isRecording,
              height: 56),
          const SizedBox(height: 16),
          ScaleTransition(
            scale: _isRecording ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
            child: GestureDetector(
              onTap: _toggle,
              child: Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _isRecording
                        ? [const Color(0xFFFF5252), const Color(0xFFFF1744)]
                        : [AppTheme.accent, const Color(0xFF9C63FF)],
                  ),
                  boxShadow: [BoxShadow(
                    color: (_isRecording ? Colors.red : AppTheme.accent)
                        .withValues(alpha: 0.45),
                    blurRadius: 24, spreadRadius: 2,
                  )],
                ),
                child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white, size: 30),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(_isRecording ? 'Tap to stop' : 'Tap to record',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Note Card ───────────────────────────────────────────────────
class _NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  const _NoteCard(
      {required this.note, this.onTap, required this.onDelete});

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _playerReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.note.type == NoteType.voice) _initPlayer();
  }

  Future<void> _initPlayer() async {
    final path = widget.note.audioFilePath;
    if (path == null) return;
    if (!await File(path).exists()) return;
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _state = PlayerState.stopped; _pos = Duration.zero; });
    });
    setState(() => _playerReady = true);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isVoice = widget.note.type == NoteType.voice;
    const tealColor = Color(0xFF00B09B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onDelete,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: (isVoice ? AppTheme.accent : tealColor)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                        isVoice ? Icons.mic_rounded : Icons.notes_rounded,
                        color: isVoice ? AppTheme.accent : tealColor,
                        size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.note.title,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  if (isVoice)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(widget.note.formattedDuration,
                          style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              if (!isVoice && widget.note.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(widget.note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.4)),
              ],
              if (isVoice && _playerReady) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        if (_state == PlayerState.playing) {
                          await _player.pause();
                        } else {
                          await _player.play(DeviceFileSource(
                              widget.note.audioFilePath!));
                        }
                      },
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                              colors: [AppTheme.accent, Color(0xFF9C63FF)]),
                        ),
                        child: Icon(
                            _state == PlayerState.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 10),
                          activeTrackColor: AppTheme.accent,
                          inactiveTrackColor: AppTheme.border,
                          thumbColor: AppTheme.accent,
                          overlayColor:
                              AppTheme.accent.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: (_dur.inMilliseconds > 0
                              ? _pos.inMilliseconds / _dur.inMilliseconds
                              : 0.0).clamp(0.0, 1.0),
                          onChanged: (v) async {
                            final pos = Duration(
                                milliseconds:
                                    (v * _dur.inMilliseconds).round());
                            await _player.seek(pos);
                          },
                        ),
                      ),
                    ),
                    Text(_fmt(_pos),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(widget.note.formattedDate,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                  const Spacer(),
                  const Text('Hold to delete',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
