enum RecentAudioType { local, youtube }

class RecentAudio {
  final String id;
  final String title;
  final String? artist;
  final RecentAudioType type;
  final String? localPath;
  final String? youtubeUrl;
  final DateTime lastOpened;
  final Duration totalDuration;
  final Duration lastPosition;
  final String? thumbnailEmoji;

  const RecentAudio({
    required this.id,
    required this.title,
    this.artist,
    required this.type,
    this.localPath,
    this.youtubeUrl,
    required this.lastOpened,
    this.totalDuration = Duration.zero,
    this.lastPosition = Duration.zero,
    this.thumbnailEmoji,
  });

  // ── Computed ────────────────────────────────────────────────
  double get listenProgress {
    if (totalDuration.inSeconds == 0) return 0.0;
    return (lastPosition.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0);
  }

  bool get isNew => lastPosition == Duration.zero;
  bool get isCompleted =>
      totalDuration.inSeconds > 0 &&
      lastPosition.inSeconds >= totalDuration.inSeconds - 10;
  bool get isInProgress => !isNew && !isCompleted;

  String get progressText {
    if (totalDuration == Duration.zero) return 'Chưa nghe';
    if (lastPosition == Duration.zero) return 'Mới thêm';
    if (isCompleted) return 'Đã nghe xong ✓';
    return '${_fmt(lastPosition)} / ${_fmt(totalDuration)}';
  }

  String get typeLabel {
    switch (type) {
      case RecentAudioType.youtube:
        return 'YouTube';
      case RecentAudioType.local:
        return 'Local';
    }
  }

  String get typeEmoji {
    switch (type) {
      case RecentAudioType.youtube:
        return '▶️';
      case RecentAudioType.local:
        return '🎵';
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  // ── Serialization ────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'type': type.name,
        'localPath': localPath,
        'youtubeUrl': youtubeUrl,
        'lastOpened': lastOpened.toIso8601String(),
        'totalDuration': totalDuration.inMilliseconds,
        'lastPosition': lastPosition.inMilliseconds,
        'thumbnailEmoji': thumbnailEmoji,
      };

  factory RecentAudio.fromJson(Map<String, dynamic> json) {
    return RecentAudio(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown',
      artist: json['artist'] as String?,
      type: RecentAudioType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? ''),
        orElse: () => RecentAudioType.local,
      ),
      localPath: json['localPath'] as String?,
      youtubeUrl: json['youtubeUrl'] as String?,
      lastOpened: DateTime.tryParse(json['lastOpened'] as String? ?? '') ??
          DateTime.now(),
      totalDuration: Duration(
        milliseconds: json['totalDuration'] as int? ?? 0,
      ),
      lastPosition: Duration(
        milliseconds: json['lastPosition'] as int? ?? 0,
      ),
      thumbnailEmoji: json['thumbnailEmoji'] as String?,
    );
  }

  // ── CopyWith ─────────────────────────────────────────────────
  RecentAudio copyWith({
    Duration? lastPosition,
    Duration? totalDuration,
    DateTime? lastOpened,
    String? thumbnailEmoji,
  }) =>
      RecentAudio(
        id: id,
        title: title,
        artist: artist,
        type: type,
        localPath: localPath,
        youtubeUrl: youtubeUrl,
        lastOpened: lastOpened ?? this.lastOpened,
        totalDuration: totalDuration ?? this.totalDuration,
        lastPosition: lastPosition ?? this.lastPosition,
        thumbnailEmoji: thumbnailEmoji ?? this.thumbnailEmoji,
      );

  // ── Factory helpers ──────────────────────────────────────────
  factory RecentAudio.fromLocalFile({
    required String path,
    String? title,
    Duration totalDuration = Duration.zero,
  }) {
    final normalizedPath = path.replaceAll("\\", "/");
    final name = normalizedPath.split('/').last;
    final nameNoExt =
        name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    return RecentAudio(
      id: 'local_${normalizedPath.toLowerCase().hashCode}',
      title: title ?? nameNoExt,
      type: RecentAudioType.local,
      localPath: normalizedPath,
      lastOpened: DateTime.now(),
      totalDuration: totalDuration,
      thumbnailEmoji: '🎵',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RecentAudio && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'RecentAudio($id, $title, ${type.name})';
}
