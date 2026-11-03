// lib/features/dharma/models/dharma_talk.dart
//
// PLAN-042 / DHRM-001 (sóng P1) — model pháp thoại.
//
// QUYẾT ĐỊNH (ADR-0022) — đọc trước khi sửa:
//  1. `episodeKey` là DANH TÍNH NỘI DUNG, không phải đường dẫn:
//       'drive:<fileId>'   — file còn trên Drive (hoặc đã tải từ Drive)
//       'local:<audioIdentity>' — file trên máy (md5 của path chuẩn hoá)
//     Nhờ vậy tiến độ nghe sống sót khi đổi nguồn phát (stream ⇄ file đã tải),
//     khi cache tạm bị Android dọn, hoặc khi thư mục bị đổi tên.
//  2. TIẾN ĐỘ TÁCH KHỎI CATALOG. `DharmaSeries` (metadata) được ghi đè mỗi lần
//     quét; `DharmaProgress` nằm ở box riêng và KHÔNG BAO GIỜ bị quét ghi đè.
//  3. `isCompleted` là giá trị SUY RA — không phải trường được lưu/sync.
//  4. Additive: không đổi schema box cũ (`saved_positions`, `sound_marks`, …).

enum DharmaCollection {
  /// Kinh tụng (Pāḷi) — nghe để tụng theo, không resume tự động.
  chanting,

  /// Sách nói (audiobook) — nghe liên tục theo chương.
  audiobook,

  /// Bài giảng/pháp thoại đã giảng xong (kho tĩnh).
  talkArchive,

  /// Pháp thoại đang giảng (có bài mới theo thời gian).
  talkOngoing,

  /// Khác (biểu đồ, tài liệu, ebook…) — chỉ hiện lối tắt, không phân tích.
  other,
}

enum DharmaLanguage { vi, pali, bilingual, my, en, unknown }

/// Loại nguồn phát của một buổi.
enum DharmaSourceKind {
  /// File đã có trên máy (import thủ công hoặc đã tải) — P1.
  local,

  /// Đã tải từ Drive về thư mục bền vững — P2.
  downloaded,

  /// Stream trực tiếp từ Drive — P3 (chưa bật trong P1).
  stream,
}

/// Một "buổi" — đơn vị nhỏ nhất có thể phát.
class DharmaEpisode {
  /// Khoá ổn định — xem quyết định #1 ở đầu file.
  final String episodeKey;

  /// Địa chỉ phát hiện tại (path bền vững hoặc URL). Không phải danh tính.
  final String source;

  final DharmaSourceKind sourceKind;

  /// Tiêu đề đã làm sạch để hiển thị (bỏ số thứ tự/ngày/đuôi file).
  final String title;

  /// Tên gốc — KHÔNG BAO GIỜ bị mất (UI có "xem tên gốc", debug, gửi lỗi).
  final String rawName;

  /// Số buổi đầu/cuối trong series. `05-06. …` ⇒ start=5, end=6.
  final int? episodeStart;
  final int? episodeEnd;

  /// Ngày giảng đọc được từ tên file (`ddMMyy`/`yyyyMMdd`).
  final DateTime? talkDate;

  /// `false` = đoán được nhưng chưa chắc ⇒ UI không hiển thị ngày.
  final bool dateConfident;

  /// Thời lượng GỢI Ý trong tên file (`(54 phút)`). Chỉ để xếp hạng/hiển thị
  /// mờ — số thật lấy từ player. Cấm dùng làm dữ liệu tin cậy.
  final int? durationHintMin;

  /// Mã "Phần N" nếu tên file có (`Phần 3`, `P9`). Lấy mốc CUỐI cùng.
  final int? part;

  /// `true` = tên có hậu tố nhà sản xuất (`- end sound`) — chỉ là cờ, không
  /// ghi đè tên gốc.
  final bool housekeeping;

  /// Mã thư viện máy (`AudioLibraryEntry.libraryId`) nếu đã đăng ký — P1 để
  /// null vì audio import thủ công không nằm trong chỉ mục MediaStore.
  final String? libraryId;

  /// Drive: id file. null khi buổi chỉ còn trên máy (đã tải/đã import).
  final String? driveFileId;

  final int sizeBytes;
  final DateTime? driveModifiedTime;
  final String? contentMd5;

  const DharmaEpisode({
    required this.episodeKey,
    required this.source,
    this.sourceKind = DharmaSourceKind.local,
    required this.title,
    required this.rawName,
    this.episodeStart,
    this.episodeEnd,
    this.talkDate,
    this.dateConfident = true,
    this.durationHintMin,
    this.part,
    this.housekeeping = false,
    this.libraryId,
    this.driveFileId,
    this.sizeBytes = 0,
    this.driveModifiedTime,
    this.contentMd5,
  });

  /// Số buổi hiển thị: '05' / '05-06' / ''.
  String get episodeLabel {
    final start = episodeStart;
    if (start == null) return '';
    final end = episodeEnd;
    final s = start.toString().padLeft(2, '0');
    if (end == null || end == start) return s;
    return '$s-${end.toString().padLeft(2, '0')}';
  }

  /// Ngày hiển thị — CHỈ khi đã chắc (quy tắc "đoán an toàn" PLAN-042 §5.2).
  DateTime? get confidentDate => dateConfident ? talkDate : null;

  DharmaEpisode copyWith({
    String? episodeKey,
    String? source,
    DharmaSourceKind? sourceKind,
    String? title,
    String? libraryId,
    String? driveFileId,
  }) {
    return DharmaEpisode(
      episodeKey: episodeKey ?? this.episodeKey,
      source: source ?? this.source,
      sourceKind: sourceKind ?? this.sourceKind,
      title: title ?? this.title,
      rawName: rawName,
      episodeStart: episodeStart,
      episodeEnd: episodeEnd,
      talkDate: talkDate,
      dateConfident: dateConfident,
      durationHintMin: durationHintMin,
      part: part,
      housekeeping: housekeeping,
      libraryId: libraryId ?? this.libraryId,
      driveFileId: driveFileId ?? this.driveFileId,
      sizeBytes: sizeBytes,
      driveModifiedTime: driveModifiedTime,
      contentMd5: contentMd5,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'episode_key': episodeKey,
        'source': source,
        'source_kind': sourceKind.name,
        'title': title,
        'raw_name': rawName,
        'episode_start': episodeStart,
        'episode_end': episodeEnd,
        'talk_date': talkDate?.toIso8601String(),
        'date_confident': dateConfident,
        'duration_hint_min': durationHintMin,
        'part': part,
        'housekeeping': housekeeping,
        'library_id': libraryId,
        'drive_file_id': driveFileId,
        'size_bytes': sizeBytes,
        'drive_modified_time': driveModifiedTime?.toIso8601String(),
        'content_md5': contentMd5,
      };

  factory DharmaEpisode.fromJson(Map<String, dynamic> json) {
    return DharmaEpisode(
      episodeKey: json['episode_key'] as String? ?? '',
      source: json['source'] as String? ?? '',
      sourceKind: DharmaSourceKind.values.firstWhere(
        (e) => e.name == (json['source_kind'] as String? ?? ''),
        orElse: () => DharmaSourceKind.local,
      ),
      title: json['title'] as String? ?? '',
      rawName: json['raw_name'] as String? ?? '',
      episodeStart: json['episode_start'] as int?,
      episodeEnd: json['episode_end'] as int?,
      talkDate: DateTime.tryParse(json['talk_date'] as String? ?? ''),
      dateConfident: json['date_confident'] as bool? ?? true,
      durationHintMin: json['duration_hint_min'] as int?,
      part: json['part'] as int?,
      housekeeping: json['housekeeping'] as bool? ?? false,
      libraryId: json['library_id'] as String?,
      driveFileId: json['drive_file_id'] as String?,
      sizeBytes: json['size_bytes'] as int? ?? 0,
      driveModifiedTime:
          DateTime.tryParse(json['drive_modified_time'] as String? ?? ''),
      contentMd5: json['content_md5'] as String?,
    );
  }
}

/// Một series (một thư mục) — cấp người dùng thực sự "học".
class DharmaSeries {
  /// `local:<md5(relativeFolder)>` hoặc `drive:<folderId>`.
  final String seriesKey;

  final String title;
  final String rawName;

  /// Số thứ tự trong collection (`34. …` ⇒ 34) — dùng để sắp xếp.
  final int? orderIndex;

  /// Khoá vị Thầy đã chuẩn hoá (không dấu, lowercase, gạch dưới).
  /// Cùng một vị Thầy nhiều cách viết phải ra CÙNG khoá (PLAN-042 F5).
  final String? speakerKey;

  /// Tên hiển thị: ưu tiên bản sửa tay của người dùng, rồi alias đã biết.
  final String? speakerDisplay;

  final DharmaCollection collection;
  final DharmaLanguage language;

  final int? year;
  final String? venue;
  final String? topic;

  /// Thư mục chứa (đường dẫn tương đối so với thư mục gốc đã chọn).
  final String relativeFolder;

  final List<DharmaEpisode> episodes;
  final DateTime? lastScannedAt;

  const DharmaSeries({
    required this.seriesKey,
    required this.title,
    required this.rawName,
    this.orderIndex,
    this.speakerKey,
    this.speakerDisplay,
    this.collection = DharmaCollection.talkArchive,
    this.language = DharmaLanguage.vi,
    this.year,
    this.venue,
    this.topic,
    this.relativeFolder = '',
    this.episodes = const <DharmaEpisode>[],
    this.lastScannedAt,
  });

  int get episodeCount => episodes.length;

  /// Tổng thời lượng GỢI Ý (chỉ từ tên file) — không phải số liệu thật.
  int? get durationHintTotalMin {
    var total = 0;
    var any = false;
    for (final e in episodes) {
      final hint = e.durationHintMin;
      if (hint != null) {
        total += hint;
        any = true;
      }
    }
    return any ? total : null;
  }

  /// Nhóm hiển thị "Theo Thầy" — series không rõ vị Thầy gom vào một nhóm riêng
  /// thay vì rải rác.
  String get speakerGroupKey => speakerKey ?? '__unknown__';

  String get speakerGroupLabel => speakerDisplay ?? '';

  DharmaSeries copyWith({
    String? title,
    String? speakerKey,
    String? speakerDisplay,
    DharmaCollection? collection,
    DharmaLanguage? language,
    int? year,
    String? venue,
    String? topic,
    List<DharmaEpisode>? episodes,
    DateTime? lastScannedAt,
  }) {
    return DharmaSeries(
      seriesKey: seriesKey,
      title: title ?? this.title,
      rawName: rawName,
      orderIndex: orderIndex,
      speakerKey: speakerKey ?? this.speakerKey,
      speakerDisplay: speakerDisplay ?? this.speakerDisplay,
      collection: collection ?? this.collection,
      language: language ?? this.language,
      year: year ?? this.year,
      venue: venue ?? this.venue,
      topic: topic ?? this.topic,
      relativeFolder: relativeFolder,
      episodes: episodes ?? this.episodes,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'series_key': seriesKey,
        'title': title,
        'raw_name': rawName,
        'order_index': orderIndex,
        'speaker_key': speakerKey,
        'speaker_display': speakerDisplay,
        'collection': collection.name,
        'language': language.name,
        'year': year,
        'venue': venue,
        'topic': topic,
        'relative_folder': relativeFolder,
        'episodes': episodes.map((e) => e.toJson()).toList(),
        'last_scanned_at': lastScannedAt?.toIso8601String(),
      };

  factory DharmaSeries.fromJson(Map<String, dynamic> json) {
    final rawEpisodes = json['episodes'];
    return DharmaSeries(
      seriesKey: json['series_key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      rawName: json['raw_name'] as String? ?? '',
      orderIndex: json['order_index'] as int?,
      speakerKey: json['speaker_key'] as String?,
      speakerDisplay: json['speaker_display'] as String?,
      collection: DharmaCollection.values.firstWhere(
        (e) => e.name == (json['collection'] as String? ?? ''),
        orElse: () => DharmaCollection.talkArchive,
      ),
      language: DharmaLanguage.values.firstWhere(
        (e) => e.name == (json['language'] as String? ?? ''),
        orElse: () => DharmaLanguage.unknown,
      ),
      year: json['year'] as int?,
      venue: json['venue'] as String?,
      topic: json['topic'] as String?,
      relativeFolder: json['relative_folder'] as String? ?? '',
      episodes: rawEpisodes is List
          ? rawEpisodes
              .whereType<Map>()
              .map((e) => DharmaEpisode.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const <DharmaEpisode>[],
      lastScannedAt: DateTime.tryParse(json['last_scanned_at'] as String? ?? ''),
    );
  }
}

/// Tiến độ nghe — store RIÊNG, không bao giờ bị quét/sync ghi đè.
class DharmaProgress {
  final String episodeKey;
  final Duration lastPosition;

  /// 0 = chưa biết (player chưa trả duration).
  final Duration duration;

  /// Người dùng bấm "Đã nghe xong" — thắng mọi suy luận tự động.
  final bool completedManually;

  final DateTime lastPlayedAt;

  /// Cho phép `const` trong test/preview: mốc "chưa từng phát" thay vì
  /// `DateTime.now()` (không phải hằng).
  const DharmaProgress({
    required this.episodeKey,
    this.lastPosition = Duration.zero,
    this.duration = Duration.zero,
    this.completedManually = false,
    this.lastPlayedAt = kNeverPlayed,
  });

  static final DateTime kNeverPlayed = DateTime.fromMillisecondsSinceEpoch(0);

  /// Ngưỡng hoàn thành: ≥95% hoặc còn ≤ 30 s.
  static bool isFinished({
    required Duration position,
    required Duration duration,
  }) {
    if (duration <= Duration.zero) return false;
    final tail = duration <= const Duration(seconds: 60)
        ? duration * 0.2
        : const Duration(seconds: 30);
    return position >= duration - tail;
  }

  bool get isCompleted =>
      completedManually ||
      isFinished(position: lastPosition, duration: duration);

  bool get isNew => !completedManually && lastPosition <= Duration.zero;

  bool get isInProgress => !isNew && !isCompleted;

  double get listenProgress {
    if (duration.inSeconds <= 0) return 0;
    return (lastPosition.inSeconds / duration.inSeconds).clamp(0.0, 1.0);
  }

  Duration get remaining {
    if (duration <= Duration.zero) return Duration.zero;
    final left = duration - lastPosition;
    return left.isNegative ? Duration.zero : left;
  }

  DharmaProgress copyWith({
    Duration? lastPosition,
    Duration? duration,
    bool? completedManually,
    DateTime? lastPlayedAt,
  }) {
    return DharmaProgress(
      episodeKey: episodeKey,
      lastPosition: lastPosition ?? this.lastPosition,
      duration: duration ?? this.duration,
      completedManually: completedManually ?? this.completedManually,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'episode_key': episodeKey,
        'last_position_ms': lastPosition.inMilliseconds,
        'duration_ms': duration.inMilliseconds,
        'completed_manually': completedManually,
        'last_played_at': lastPlayedAt.toIso8601String(),
      };

  factory DharmaProgress.fromJson(Map<String, dynamic> json) {
    return DharmaProgress(
      episodeKey: json['episode_key'] as String? ?? '',
      lastPosition: Duration(milliseconds: json['last_position_ms'] as int? ?? 0),
      duration: Duration(milliseconds: json['duration_ms'] as int? ?? 0),
      completedManually: json['completed_manually'] as bool? ?? false,
      lastPlayedAt: DateTime.tryParse(json['last_played_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
