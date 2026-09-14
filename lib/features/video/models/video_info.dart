/// Model cho video trong thư viện
class VideoInfo {
  final String id;
  final String title;
  final String filePath;
  final String? thumbnailPath;
  final Duration duration;
  final DateTime addedAt;

  const VideoInfo({
    required this.id,
    required this.title,
    required this.filePath,
    this.thumbnailPath,
    required this.duration,
    required this.addedAt,
  });

  String get durationText {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'file_path': filePath,
        'thumbnail_path': thumbnailPath,
        'duration_ms': duration.inMilliseconds,
        'added_at': addedAt.toIso8601String(),
      };

  factory VideoInfo.fromJson(Map<String, dynamic> json) => VideoInfo(
        id: json['id'] as String,
        title: json['title'] as String,
        filePath: json['file_path'] as String,
        thumbnailPath: json['thumbnail_path'] as String?,
        duration: Duration(milliseconds: json['duration_ms'] as int),
        addedAt: DateTime.parse(json['added_at'] as String),
      );
}
