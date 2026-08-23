// lib/models/audio_library_entry.dart
// Thư viện âm thanh (Phụ lục A, P1) — một mục trong bảng chỉ mục audio.
//
// Nguồn (source):
//  - media  : quét MediaStore (Android) — toàn bộ audio máy
//  - folder : thư mục người dùng chọn (SAF) — P2
//  - picked : file import thủ công qua FilePicker
//  - recent : phục hồi từ RecentAudioService cũ
//
// fingerprint (SHA-256 8 bytes của 64KB đầu file) — P3 cho re-link, P1 để null.

enum AudioSource { media, folder, picked, recent }

extension AudioSourceX on AudioSource {
  String get label {
    switch (this) {
      case AudioSource.media:
        return 'Thư viện máy';
      case AudioSource.folder:
        return 'Thư mục';
      case AudioSource.picked:
        return 'Đã import';
      case AudioSource.recent:
        return 'Gần đây';
    }
  }
}

class AudioLibraryEntry {
  /// Khóa ổn định: 'media_<id>' | 'folder_<uri>_<docId>' | 'picked_<hash>' | 'recent_<id>'
  final String libraryId;

  /// Địa chỉ phát: content:// hoặc file path chuẩn hóa (\\ → /)
  final String uri;

  final String title;
  final String? artist;
  final int durationMs;
  final int sizeBytes;
  final AudioSource source;

  /// Unix seconds (MediaStore DATE_ADDED); fallback = thời điểm thêm vào chỉ mục.
  final DateTime addedAt;

  DateTime? lastPlayed;

  /// SHA-256 8 bytes của 64KB đầu file (hex 16) — P3 (re-link). P1 = null.
  final String? fingerprint;

  AudioLibraryEntry({
    required this.libraryId,
    required this.uri,
    required this.title,
    this.artist,
    this.durationMs = 0,
    this.sizeBytes = 0,
    this.source = AudioSource.media,
    required this.addedAt,
    this.lastPlayed,
    this.fingerprint,
  });

  String get durationLabel {
    if (durationMs <= 0) return '';
    final d = Duration(milliseconds: durationMs);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String get sizeLabel {
    if (sizeBytes <= 0) return '';
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / 1024).round()} KB';
  }

  /// Từ bản ghi MediaStore (native trả map).
  factory AudioLibraryEntry.fromMediaMap(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString();
    final titleRaw = (m['title'] ?? '').toString().trim();
    final name = (m['displayName'] ?? '').toString().trim();
    final dur = (m['durationMs'] as num?)?.toInt() ?? 0;
    final size = (m['sizeBytes'] as num?)?.toInt() ?? 0;
    final dateSec = (m['dateAddedSec'] as num?)?.toInt() ?? 0;
    final artist = (m['artist'] ?? '').toString().trim();

    return AudioLibraryEntry(
      libraryId: 'media_$id',
      uri: (m['uri'] ?? '').toString(),
      title: titleRaw.isNotEmpty ? titleRaw : (name.isNotEmpty ? name : 'Unknown'),
      artist: artist.isEmpty ? null : artist,
      durationMs: dur,
      sizeBytes: size,
      source: AudioSource.media,
      addedAt: dateSec > 0
          ? DateTime.fromMillisecondsSinceEpoch(dateSec * 1000)
          : DateTime.now(),
    );
  }

  AudioLibraryEntry copyWith({
    DateTime? lastPlayed,
    String? fingerprint,
    bool clearLastPlayed = false,
  }) {
    return AudioLibraryEntry(
      libraryId: libraryId,
      uri: uri,
      title: title,
      artist: artist,
      durationMs: durationMs,
      sizeBytes: sizeBytes,
      source: source,
      addedAt: addedAt,
      lastPlayed: clearLastPlayed ? null : (lastPlayed ?? this.lastPlayed),
      fingerprint: fingerprint ?? this.fingerprint,
    );
  }

  Map<String, dynamic> toJson() => {
        'libraryId': libraryId,
        'uri': uri,
        'title': title,
        'artist': artist,
        'durationMs': durationMs,
        'sizeBytes': sizeBytes,
        'source': source.name,
        'addedAt': addedAt.toIso8601String(),
        'lastPlayed': lastPlayed?.toIso8601String(),
        'fingerprint': fingerprint,
      };

  factory AudioLibraryEntry.fromJson(Map<String, dynamic> j) {
    return AudioLibraryEntry(
      libraryId: (j['libraryId'] as String?) ?? '',
      uri: (j['uri'] as String?) ?? '',
      title: (j['title'] as String?) ?? 'Unknown',
      artist: j['artist'] as String?,
      durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
      sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
      source: AudioSource.values.firstWhere(
        (e) => e.name == (j['source'] as String? ?? ''),
        orElse: () => AudioSource.media,
      ),
      addedAt: DateTime.tryParse(j['addedAt'] as String? ?? '') ??
          DateTime.now(),
      lastPlayed: j['lastPlayed'] == null
          ? null
          : DateTime.tryParse(j['lastPlayed'] as String),
      fingerprint: j['fingerprint'] as String?,
    );
  }
}
