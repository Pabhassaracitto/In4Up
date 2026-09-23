// ignore_for_file: unnecessary_brace_in_string_interps
/// Nguồn gốc của một video trong thư viện — quyết định cách "quét lại" và
/// việc có giữ entry khi file biến mất khỏi máy hay không.
///
/// Cùng triết lý `AudioSource` (thư viện nhạc): entry do QUÉT được (media)
/// mất khỏi lần quét sau ⇒ hiểu là file đã xóa; entry do người dùng CHỌN
/// (picked/folder) luôn giữ.
enum VideoSource {
  /// Quét MediaStore (toàn máy, Android).
  media,

  /// Quét thư mục đã chọn (SAF tree, Android).
  folder,

  /// Người dùng chọn file thủ công (file_picker, mọi nền tảng).
  picked;

  static VideoSource fromName(String? name) {
    switch (name) {
      case 'folder':
        return VideoSource.folder;
      case 'picked':
        return VideoSource.picked;
      case 'media':
      default:
        return VideoSource.media;
    }
  }

  String get name => switch (this) {
        VideoSource.media => 'media',
        VideoSource.folder => 'folder',
        VideoSource.picked => 'picked',
      };
}

/// Model cho video trong thư viện
class VideoInfo {
  final String id;
  final String title;

  /// Đường dẫn phát ĐƯỢC: file thật (đã copy vào bộ nhớ app) hoặc
  /// content:// URI (MediaStore/SAF — resolve sang cache khi phát).
  final String filePath;
  final String? thumbnailPath;
  final Duration duration;
  final DateTime addedAt;

  /// Nguồn gốc entry (quét máy / thư mục / chọn tay).
  final VideoSource source;

  /// content:// URI gốc (nếu có) — dùng để nhận diện lại khi quét máy.
  final String? sourceUri;

  final int sizeBytes;
  final DateTime? lastPlayedAt;

  const VideoInfo({
    required this.id,
    required this.title,
    required this.filePath,
    this.thumbnailPath,
    required this.duration,
    required this.addedAt,
    this.source = VideoSource.picked,
    this.sourceUri,
    this.sizeBytes = 0,
    this.lastPlayedAt,
  });

  String get durationText {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  /// Dung lượng dạng gọn (vd "128 MB").
  String get sizeText {
    if (sizeBytes <= 0) return '';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).round()} KB';
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  VideoInfo copyWith({
    String? title,
    String? filePath,
    String? thumbnailPath,
    Duration? duration,
    DateTime? lastPlayedAt,
    int? sizeBytes,
    VideoSource? source,
    String? sourceUri,
  }) =>
      VideoInfo(
        id: id,
        title: title ?? this.title,
        filePath: filePath ?? this.filePath,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        duration: duration ?? this.duration,
        addedAt: addedAt,
        lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        source: source ?? this.source,
        sourceUri: sourceUri ?? this.sourceUri,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'file_path': filePath,
        'thumbnail_path': thumbnailPath,
        'duration_ms': duration.inMilliseconds,
        'added_at': addedAt.toIso8601String(),
        'source': source.name,
        'source_uri': sourceUri,
        'size_bytes': sizeBytes,
        if (lastPlayedAt != null)
          'last_played_at': lastPlayedAt!.toIso8601String(),
      };

  factory VideoInfo.fromJson(Map<String, dynamic> json) => VideoInfo(
        id: json['id'] as String,
        title: json['title'] as String,
        filePath: json['file_path'] as String,
        thumbnailPath: json['thumbnail_path'] as String?,
        duration: Duration(milliseconds: (json['duration_ms'] as int?) ?? 0),
        addedAt: DateTime.tryParse(json['added_at'] as String? ?? '') ??
            DateTime.now(),
        source: VideoSource.fromName(json['source'] as String?),
        sourceUri: json['source_uri'] as String?,
        sizeBytes: (json['size_bytes'] as int?) ?? 0,
        lastPlayedAt: json['last_played_at'] == null
            ? null
            : DateTime.tryParse(json['last_played_at'] as String),
      );
}
