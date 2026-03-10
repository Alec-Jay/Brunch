class Meeting {
  final String id;
  final String title;
  final DateTime date;
  final int durationSeconds;
  final String transcript;
  final String summary;
  final List<String> actionItems;
  final String? audioFilePath;
  final List<String> participants;

  const Meeting({
    required this.id,
    required this.title,
    required this.date,
    required this.durationSeconds,
    this.transcript = '',
    this.summary = '',
    this.actionItems = const [],
    this.audioFilePath,
    this.participants = const [],
  });

  Meeting copyWith({
    String? id,
    String? title,
    DateTime? date,
    int? durationSeconds,
    String? transcript,
    String? summary,
    List<String>? actionItems,
    String? audioFilePath,
    List<String>? participants,
  }) {
    return Meeting(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      transcript: transcript ?? this.transcript,
      summary: summary ?? this.summary,
      actionItems: actionItems ?? this.actionItems,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      participants: participants ?? this.participants,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'durationSeconds': durationSeconds,
        'transcript': transcript,
        'summary': summary,
        'actionItems': actionItems,
        'audioFilePath': audioFilePath,
        'participants': participants,
      };

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
        id: json['id'] as String,
        title: json['title'] as String,
        date: DateTime.parse(json['date'] as String),
        durationSeconds: json['durationSeconds'] as int,
        transcript: (json['transcript'] as String?) ?? '',
        summary: (json['summary'] as String?) ?? '',
        actionItems: (json['actionItems'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        audioFilePath: json['audioFilePath'] as String?,
        participants: (json['participants'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
    final seconds = durationSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  String get formattedFullDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
