// ignore_for_file: unnecessary_brace_in_string_interps
// Model cho video trong thư viện.
//
// I4U18-VIDEO-LIB-001: mở rộng model để hỗ trợ
//  - Quét thư mục (SAF) đệ quy → `source`, `folder`, `sizeBytes`, `dateModified`.
//  - Ghép phụ đề cùng tên/thư mục → `subtitlePath`.
//  - Giữ vị trí phát gần nhất (reopen đúng chỗ) → `lastPositionMs`.
//  - Yêu thích / gần đây → `favorite`, `lastPlayed`.
//
// JSON tương thích ngược: các trường mới đều nullable/có default, đọc bản
// manifest cũ (chỉ 6 trường) vẫn chạy.

/// Nguồn của một video trong thư viện.
enum VideoSource {
  /// Import từng file thủ công (FilePicker) — hành vi cũ.
  picked,

  /// Quét từ thư mục người dùng chọn (SAF tree, đệ quy).
  folder,
}

extension VideoSourceX on VideoSource {
  String get name2 => this == VideoSource.folder ? 'folder' : 'picked';

  static VideoSource parse(String? v) =>
      v == 'folder' ? VideoSource.folder : VideoSource.picked;
}

class VideoInfo {
  final String id;
  final String title;

  /// Đường dẫn/URI phát: file path chuẩn hoá (\\ → /) hoặc content:// (SAF).
  final String filePath;

  final String? thumbnailPath;
  final Duration duration;
  final DateTime addedAt;

  // ── I4U18 (thêm mới, tương thích ngược) ──────────────────────
  /// Kích thước file (byte); 0 nếu không rõ.
  final int sizeBytes;

  /// Thời điểm sửa file (từ SAF); null nếu không rõ.
  final DateTime? dateModified;

  /// Tên thư mục cha (để nhóm/lọc theo thư mục). Rỗng nếu không rõ.
  final String folder;

  /// Nguồn video.
  final VideoSource source;

  /// Đánh dấu yêu thích.
  final bool favorite;

  /// Vị trí phát gần nhất (ms) — reopen đúng vị trí.
  final int lastPositionMs;

  /// Lần phát gần nhất (để tab "Gần đây"); null nếu chưa phát.
  final DateTime? lastPlayed;

  /// Đường dẫn/URI phụ đề đã ghép (cùng tên/thư mục) — .srt/.vtt/.ass...
  final String? subtitlePath;

  const VideoInfo({
    required this.id,
    required this.title,
    required this.filePath,
    this.thumbnailPath,
    required this.duration,
    required this.addedAt,
    this.sizeBytes = 0,
    this.dateModified,
    this.folder = '',
    this.source = VideoSource.picked,
    this.favorite = false,
    this.lastPositionMs = 0,
    this.lastPlayed,
    this.subtitlePath,
  });

  bool get hasSubtitle => (subtitlePath ?? '').isNotEmpty;

  Duration get lastPosition => Duration(milliseconds: lastPositionMs);

  /// Đã xem xong (còn ≤ 15s là coi như xong) — để phân nhóm.
  bool get isCompleted =>
      duration.inSeconds > 0 &&
      lastPositionMs >= (duration.inMilliseconds - 15000);

  bool get isInProgress => lastPositionMs > 5000 && !isCompleted;

  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (lastPositionMs / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  String get durationText {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  String get sizeLabel {
    if (sizeBytes <= 0) return '';
    if (sizeBytes >= 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / 1024).round()} KB';
  }

  VideoInfo copyWith({
    String? title,
    String? thumbnailPath,
    Duration? duration,
    int? sizeBytes,
    DateTime? dateModified,
    String? folder,
    VideoSource? source,
    bool? favorite,
    int? lastPositionMs,
    DateTime? lastPlayed,
    String? subtitlePath,
    bool clearSubtitle = false,
  }) {
    return VideoInfo(
      id: id,
      title: title ?? this.title,
      filePath: filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      duration: duration ?? this.duration,
      addedAt: addedAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      dateModified: dateModified ?? this.dateModified,
      folder: folder ?? this.folder,
      source: source ?? this.source,
      favorite: favorite ?? this.favorite,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      subtitlePath:
          clearSubtitle ? null : (subtitlePath ?? this.subtitlePath),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'file_path': filePath,
        'thumbnail_path': thumbnailPath,
        'duration_ms': duration.inMilliseconds,
        'added_at': addedAt.toIso8601String(),
        'size_bytes': sizeBytes,
        'date_modified': dateModified?.toIso8601String(),
        'folder': folder,
        'source': source.name2,
        'favorite': favorite,
        'last_position_ms': lastPositionMs,
        'last_played': lastPlayed?.toIso8601String(),
        'subtitle_path': subtitlePath,
      };

  factory VideoInfo.fromJson(Map<String, dynamic> json) => VideoInfo(
        id: json['id'] as String,
        title: json['title'] as String,
        filePath: json['file_path'] as String,
        thumbnailPath: json['thumbnail_path'] as String?,
        duration: Duration(milliseconds: (json['duration_ms'] as num?)?.toInt() ?? 0),
        addedAt: DateTime.tryParse(json['added_at'] as String? ?? '') ??
            DateTime.now(),
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
        dateModified: json['date_modified'] == null
            ? null
            : DateTime.tryParse(json['date_modified'] as String),
        folder: (json['folder'] as String?) ?? '',
        source: VideoSourceX.parse(json['source'] as String?),
        favorite: (json['favorite'] as bool?) ?? false,
        lastPositionMs: (json['last_position_ms'] as num?)?.toInt() ?? 0,
        lastPlayed: json['last_played'] == null
            ? null
            : DateTime.tryParse(json['last_played'] as String),
        subtitlePath: json['subtitle_path'] as String?,
      );
}
