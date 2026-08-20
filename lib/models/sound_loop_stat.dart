// lib/models/sound_loop_stat.dart
// Soundlist – Thống kê thói quen lặp A–B (nguồn cho "Gợi ý thông minh").
//
// Mỗi khi người dùng lặp một vùng (start–end) trong file, bộ theo dõi
// ghi nhận +1. Đoạn nào bị lặp nhiều lần và gần đây → app gợi ý
// "Đây có vẻ là đoạn khó — đánh dấu 💪 Khó?".

class SoundLoopStat {
  /// id = audioPath|startMs|endMs
  final String id;
  final String audioPath;
  final Duration start;
  final Duration end;

  int count;
  DateTime lastUsed;

  /// Người dùng đã "Bỏ qua" gợi ý cho vùng này.
  bool dismissed;

  SoundLoopStat({
    required this.id,
    required this.audioPath,
    required this.start,
    required this.end,
    required this.count,
    required this.lastUsed,
    this.dismissed = false,
  });

  String get timeLabel => '${_fmt(start)} – ${_fmt(end)}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'audioPath': audioPath,
        'start': start.inMilliseconds,
        'end': end.inMilliseconds,
        'count': count,
        'lastUsed': lastUsed.toIso8601String(),
        'dismissed': dismissed,
      };

  factory SoundLoopStat.fromJson(Map<String, dynamic> j) => SoundLoopStat(
        id: j['id'] as String,
        audioPath: j['audioPath'] as String,
        start: Duration(milliseconds: (j['start'] as num).toInt()),
        end: Duration(milliseconds: (j['end'] as num).toInt()),
        count: (j['count'] as num?)?.toInt() ?? 1,
        lastUsed: DateTime.tryParse(j['lastUsed'] as String? ?? '') ??
            DateTime.now(),
        dismissed: j['dismissed'] as bool? ?? false,
      );

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
