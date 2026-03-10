import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/meeting.dart';
import '../models/note.dart';
import '../services/notes_storage_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

enum _Filter { all, recordings, notes }

class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  _Filter _filter = _Filter.all;
  List<Meeting> _meetings = [];
  List<Note> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      StorageService.instance.loadMeetings(),
      NotesStorageService.instance.loadNotes(),
    ]);
    if (mounted) {
      setState(() {
        _meetings = results[0] as List<Meeting>;
        _notes = results[1] as List<Note>;
        _isLoading = false;
      });
    }
  }

  List<_FolderItem> get _items {
    final items = <_FolderItem>[];
    if (_filter != _Filter.notes) {
      for (final m in _meetings) {
        if (m.audioFilePath != null && m.audioFilePath!.isNotEmpty) {
          items.add(_FolderItem.fromMeeting(m));
        }
      }
    }
    if (_filter != _Filter.recordings) {
      for (final n in _notes) {
        if (n.type == NoteType.voice && n.audioFilePath != null) {
          items.add(_FolderItem.fromVoiceNote(n));
        }
        if (n.type == NoteType.text) {
          items.add(_FolderItem.fromTextNote(n));
        }
      }
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  int get _totalAudioCount {
    int count = 0;
    for (final m in _meetings) {
      if (m.audioFilePath != null && m.audioFilePath!.isNotEmpty) count++;
    }
    for (final n in _notes) {
      if (n.type == NoteType.voice && n.audioFilePath != null) count++;
    }
    return count;
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
            colors: [Color(0xFF080E18), Color(0xFF0C1220), Color(0xFF080C14)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildStats(),
              _buildFilter(),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                Text('Folder',
                    style: TextStyle(color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.bold)),
                Text('All recordings & notes',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppTheme.textSecondary, size: 20),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.mic_rounded,
            label: '$_totalAudioCount recordings',
            color: AppTheme.accent,
          ),
          const SizedBox(width: 10),
          _StatChip(
            icon: Icons.note_alt_rounded,
            label: '${_notes.length} notes',
            color: const Color(0xFF00B09B),
          ),
          const SizedBox(width: 10),
          _StatChip(
            icon: Icons.folder_rounded,
            label: '${_meetings.length} meetings',
            color: const Color(0xFF4776E6),
          ),
        ],
      ),
    );
  }

  Widget _buildFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: _Filter.values.map((f) {
            final selected = _filter == f;
            final label = f.name[0].toUpperCase() + f.name.substring(1);
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(label,
                        style: TextStyle(
                          color: selected ? Colors.white : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        )),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppTheme.accent, strokeWidth: 2));
    }
    final items = _items;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF4776E6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: const Color(0xFF4776E6).withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.folder_open_rounded,
                  color: Color(0xFF4776E6), size: 34),
            ),
            const SizedBox(height: 16),
            const Text('Folder is empty',
                style: TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Your recordings and notes will appear here',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _FolderItemCard(item: items[i]),
    );
  }
}

// ─── Data model for display ─────────────────────────────────────
class _FolderItem {
  final String id;
  final String name;
  final String subtitle;
  final _ItemType type;
  final DateTime date;
  final String? audioPath;
  final int durationSeconds;
  int fileSizeBytes;

  _FolderItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.type,
    required this.date,
    this.audioPath,
    this.durationSeconds = 0,
    this.fileSizeBytes = 0,
  });

  factory _FolderItem.fromMeeting(Meeting m) => _FolderItem(
        id: m.id,
        name: m.title,
        subtitle: 'Meeting recording',
        type: _ItemType.meetingAudio,
        date: m.date,
        audioPath: m.audioFilePath,
        durationSeconds: m.durationSeconds,
      );

  factory _FolderItem.fromVoiceNote(Note n) => _FolderItem(
        id: n.id,
        name: n.title,
        subtitle: 'Voice note',
        type: _ItemType.voiceNote,
        date: n.date,
        audioPath: n.audioFilePath,
        durationSeconds: n.durationSeconds,
      );

  factory _FolderItem.fromTextNote(Note n) => _FolderItem(
        id: n.id,
        name: n.title,
        subtitle: n.content.isEmpty ? 'Empty note' : n.content,
        type: _ItemType.textNote,
        date: n.date,
      );
}

enum _ItemType { meetingAudio, voiceNote, textNote }

// ─── Folder Item Card ────────────────────────────────────────────
class _FolderItemCard extends StatefulWidget {
  final _FolderItem item;
  const _FolderItemCard({required this.item});

  @override
  State<_FolderItemCard> createState() => _FolderItemCardState();
}

class _FolderItemCardState extends State<_FolderItemCard> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  bool _playerReady = false;
  int _fileSizeKB = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Load file size
    final path = widget.item.audioPath;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) {
        final size = await f.length();
        if (mounted) setState(() => _fileSizeKB = (size / 1024).round());
      }
    }
    // Init player for audio types
    if (widget.item.type != _ItemType.textNote && path != null) {
      if (!await File(path).exists()) return;
      _player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _state = s);
      });
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _state = PlayerState.stopped);
      });
      if (mounted) setState(() => _playerReady = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Color get _typeColor {
    switch (widget.item.type) {
      case _ItemType.meetingAudio: return AppTheme.accent;
      case _ItemType.voiceNote: return const Color(0xFF00B09B);
      case _ItemType.textNote: return const Color(0xFF4776E6);
    }
  }

  IconData get _typeIcon {
    switch (widget.item.type) {
      case _ItemType.meetingAudio: return Icons.mic_rounded;
      case _ItemType.voiceNote: return Icons.record_voice_over_rounded;
      case _ItemType.textNote: return Icons.notes_rounded;
    }
  }

  String get _typeLabel {
    switch (widget.item.type) {
      case _ItemType.meetingAudio: return 'Meeting';
      case _ItemType.voiceNote: return 'Voice';
      case _ItemType.textNote: return 'Note';
    }
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatDuration(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    if (m == 0) return '${sec}s';
    return '${m}m ${sec}s';
  }

  @override
  Widget build(BuildContext context) {
    final isAudio = widget.item.type != _ItemType.textNote;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_typeColor, _typeColor.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(_typeIcon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _Chip(label: _typeLabel, color: _typeColor),
                      const SizedBox(width: 6),
                      if (isAudio && widget.item.durationSeconds > 0)
                        _Chip(
                          label: _formatDuration(widget.item.durationSeconds),
                          color: Colors.white54,
                        ),
                      if (isAudio && widget.item.durationSeconds > 0)
                        const SizedBox(width: 6),
                      if (_fileSizeKB > 0)
                        _Chip(
                          label: '${_fileSizeKB}KB',
                          color: Colors.white38,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(_formatDate(widget.item.date),
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            if (isAudio && _playerReady)
              GestureDetector(
                onTap: () async {
                  if (_state == PlayerState.playing) {
                    await _player.pause();
                  } else {
                    await _player.play(
                        DeviceFileSource(widget.item.audioPath!));
                  }
                },
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _typeColor.withValues(alpha: 0.15),
                    border:
                        Border.all(color: _typeColor.withValues(alpha: 0.4)),
                  ),
                  child: Icon(
                      _state == PlayerState.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: _typeColor,
                      size: 20),
                ),
              )
            else if (isAudio && !_playerReady)
              const Icon(Icons.broken_image_outlined,
                  color: AppTheme.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
