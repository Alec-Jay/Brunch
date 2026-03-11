/// A single segment of the transcript with optional speaker label (e.g. Speaker 1).
/// Used for ElevenLabs Scribe diarization — "who said what".
class TranscriptSegment {
  final String speakerLabel;
  final String text;
  final double? startTimeSeconds;
  final double? endTimeSeconds;

  const TranscriptSegment({
    required this.speakerLabel,
    required this.text,
    this.startTimeSeconds,
    this.endTimeSeconds,
  });

  Map<String, dynamic> toJson() => {
        'speakerLabel': speakerLabel,
        'text': text,
        if (startTimeSeconds != null) 'startTimeSeconds': startTimeSeconds,
        if (endTimeSeconds != null) 'endTimeSeconds': endTimeSeconds,
      };

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) =>
      TranscriptSegment(
        speakerLabel: (json['speakerLabel'] as String?) ?? 'Speaker',
        text: (json['text'] as String?) ?? '',
        startTimeSeconds: (json['startTimeSeconds'] as num?)?.toDouble(),
        endTimeSeconds: (json['endTimeSeconds'] as num?)?.toDouble(),
      );
}
