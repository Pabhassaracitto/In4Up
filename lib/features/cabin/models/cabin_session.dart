import 'package:flutter/foundation.dart';

/// CABIN-SAVE-001 (PLAN-030) — một câu đã chốt trong phiên Cabin, kèm mốc
/// thời gian tính từ lúc bắt đầu phiên (khớp vị trí trong file ghi âm).
@immutable
class CabinTranscriptEntry {
  /// Mốc bắt đầu câu, tính từ đầu phiên (không tính thời gian tạm dừng).
  final Duration offset;
  final String sourceText;
  final String translatedText;

  const CabinTranscriptEntry({
    required this.offset,
    required this.sourceText,
    this.translatedText = '',
  });

  Map<String, dynamic> toJson() => {
        'ms': offset.inMilliseconds,
        'src': sourceText,
        'tgt': translatedText,
      };

  factory CabinTranscriptEntry.fromJson(Map<String, dynamic> json) =>
      CabinTranscriptEntry(
        offset: Duration(milliseconds: (json['ms'] as num?)?.toInt() ?? 0),
        sourceText: (json['src'] as String?) ?? '',
        translatedText: (json['tgt'] as String?) ?? '',
      );
}

/// Nội dung text xuất ra khi lưu phiên.
enum CabinTextMode { bilingual, source, target }

/// Định dạng ghi âm. `compressed` hiện CHƯA khả dụng (repo chưa có thư viện
/// nén — xem PLAN-030 rủi ro R2); giữ trong enum để Settings hiện "sắp có".
enum CabinAudioFormat { wav, compressed }

/// Trạng thái vòng đời của phiên trên đĩa.
enum CabinSessionStatus {
  /// Đang ghi (nếu thấy trạng thái này lúc mở app ⇒ phiên bị ngắt ngang).
  recording,

  /// Đã dừng nhưng user chưa quyết định lưu / bỏ.
  unsaved,

  /// User đã lưu.
  saved,
}

/// Metadata một phiên Cabin (tệp `session.json` trong thư mục phiên).
@immutable
class CabinSession {
  final String id;
  final String dirPath;
  final String title;
  final DateTime createdAt;
  final Duration duration;
  final String sourceLang;
  final String targetLang;
  final String engine;
  final CabinSessionStatus status;
  final bool hasAudio;
  final int entryCount;
  final CabinTextMode textMode;

  /// Phiên được khôi phục sau khi app bị tắt ngang.
  final bool recovered;

  const CabinSession({
    required this.id,
    required this.dirPath,
    required this.title,
    required this.createdAt,
    this.duration = Duration.zero,
    required this.sourceLang,
    required this.targetLang,
    this.engine = '',
    this.status = CabinSessionStatus.recording,
    this.hasAudio = false,
    this.entryCount = 0,
    this.textMode = CabinTextMode.bilingual,
    this.recovered = false,
  });

  /// Tên gốc chung của `.wav` và `.lrc` — cùng tên để tab Nghe tự tìm được
  /// LRC sidecar cạnh file audio (SourceArtifactStore.sidecarLrcPath).
  String get baseName => 'cabin_$id';
  String get audioPath => '$dirPath/$baseName.wav';
  String get lrcPath => '$dirPath/$baseName.lrc';
  String get txtPath => '$dirPath/$baseName.txt';
  String get journalPath => '$dirPath/captions.jsonl';
  String get metaPath => '$dirPath/session.json';

  bool get isEmpty => entryCount == 0 && (!hasAudio || duration.inSeconds < 1);

  CabinSession copyWith({
    String? title,
    Duration? duration,
    CabinSessionStatus? status,
    bool? hasAudio,
    int? entryCount,
    CabinTextMode? textMode,
    bool? recovered,
  }) {
    return CabinSession(
      id: id,
      dirPath: dirPath,
      title: title ?? this.title,
      createdAt: createdAt,
      duration: duration ?? this.duration,
      sourceLang: sourceLang,
      targetLang: targetLang,
      engine: engine,
      status: status ?? this.status,
      hasAudio: hasAudio ?? this.hasAudio,
      entryCount: entryCount ?? this.entryCount,
      textMode: textMode ?? this.textMode,
      recovered: recovered ?? this.recovered,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
        'engine': engine,
        'status': status.name,
        'hasAudio': hasAudio,
        'entryCount': entryCount,
        'textMode': textMode.name,
        'recovered': recovered,
      };

  factory CabinSession.fromJson(Map<String, dynamic> json, String dirPath) {
    T byName<T extends Enum>(List<T> values, Object? raw, T fallback) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
      return fallback;
    }

    return CabinSession(
      id: (json['id'] as String?) ?? dirPath.split('/').last,
      dirPath: dirPath,
      title: (json['title'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      duration: Duration(
          milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
      sourceLang: (json['sourceLang'] as String?) ?? '',
      targetLang: (json['targetLang'] as String?) ?? '',
      engine: (json['engine'] as String?) ?? '',
      status: byName(CabinSessionStatus.values, json['status'],
          CabinSessionStatus.unsaved),
      hasAudio: json['hasAudio'] == true,
      entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
      textMode: byName(
          CabinTextMode.values, json['textMode'], CabinTextMode.bilingual),
      recovered: json['recovered'] == true,
    );
  }
}
