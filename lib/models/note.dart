enum NoteType { text, voice }

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final NoteType type;
  final String? audioFilePath;
  final int durationSeconds;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.type,
    this.audioFilePath,
    this.durationSeconds = 0,
  });

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? date,
    NoteType? type,
    String? audioFilePath,
    int? durationSeconds,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      date: date ?? this.date,
      type: type ?? this.type,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'date': date.toIso8601String(),
        'type': type.name,
        'audioFilePath': audioFilePath,
        'durationSeconds': durationSeconds,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String,
        content: (json['content'] as String?) ?? '',
        date: DateTime.parse(json['date'] as String),
        type: NoteType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => NoteType.text,
        ),
        audioFilePath: json['audioFilePath'] as String?,
        durationSeconds: (json['durationSeconds'] as int?) ?? 0,
      );

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays == 0) return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m}m ${s}s';
  }
}
