class PlaybackAnchor {
  final String fileId;
  final int lineIndex;
  final int lineRepeatIndex;
  final DateTime savedAt;

  const PlaybackAnchor({
    required this.fileId,
    required this.lineIndex,
    required this.lineRepeatIndex,
    required this.savedAt,
  });

  String get displayText {
    final age = DateTime.now().difference(savedAt);
    final t = age.inMinutes < 60
        ? '${age.inMinutes}p trước'
        : '${age.inHours}g trước';
    return 'Câu ${lineIndex + 1}  •  $t';
  }

  Map<String, dynamic> toJson() => {
    'fileId':     fileId,
    'line':       lineIndex,
    'lineRepeat': lineRepeatIndex,
    'savedAt':    savedAt.toIso8601String(),
  };

  factory PlaybackAnchor.fromJson(Map<String, dynamic> j) => PlaybackAnchor(
    fileId:          j['fileId'] as String,
    lineIndex:       j['line'] as int,
    lineRepeatIndex: j['lineRepeat'] as int? ?? 0,
    savedAt:         DateTime.parse(j['savedAt'] as String),
  );
}
