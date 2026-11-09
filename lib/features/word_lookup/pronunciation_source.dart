// lib/features/word_lookup/pronunciation_source.dart
//
// PRON-002 (ADR-0015 D1) — "Nguồn phát âm" là MỘT khái niệm, YouGlish chỉ là
// một nguồn trong đó. File này THUẦN DART (không import flutter/plugin) vì nó
// là CỔNG CI: bài học `4b4965f` (run 40229976121) là test widget + plugin/Hive
// TREO >8 phút trên runner ⇒ mọi machine-check của PRON chỉ được dựa trên logic
// thuần. Xem `test/youglish/pronunciation_source_test.dart`.

/// Ba nguồn phát âm cho MỘT từ trong In4Up.
enum PronunciationSource {
  /// Giọng máy — `TextProvider.speak` → `TtsService` (offline được, tức thì).
  tts('Giọng máy', 'tts'),

  /// Nhiều giọng người thật trong ngữ cảnh (YouTube qua YouGlish) — cần mạng.
  youglish('YouGlish', 'youglish'),

  /// File audio đi kèm bộ từ điển (`DictEntry.audioPath`).
  /// PRON-002 CHƯA bật nguồn này — `DictEntry.audioPath` vẫn chưa chỗ nào phát;
  /// nối nó là việc của PRON-005 (nay khả thi vì DICT-PACK-001 cho phép
  /// `wav/mp3/ogg/m4a` trong pack).
  dictionary('Âm thanh từ điển', 'dictionary');

  const PronunciationSource(this.labelVi, this.prefCode);

  /// Nhãn chrome — nơi dùng phải bọc `context.uiText(...)` (rule #5).
  final String labelVi;

  /// Mã lưu trong SharedPreferences (key `pronunciation.source`).
  final String prefCode;

  static PronunciationSource? fromPrefCode(String? code) {
    if (code == null) return null;
    for (final s in values) {
      if (s.prefCode == code) return s;
    }
    return null;
  }
}

/// Những gì đang sẵn sàng trên máy, tại thời điểm người dùng bấm nút loa.
class PronunciationAvailability {
  const PronunciationAvailability({
    this.youglishEnabled = true,
    this.networkAvailable = true,
    this.dictionaryHasAudio = false,
  });

  /// Kill-switch `youglish.enabled` (ADR-0015 D2) — owner tắt khi YouGlish
  /// không cấp quyền, KHÔNG phải sửa code.
  final bool youglishEnabled;

  /// `null` = chưa kiểm tra được (connectivity lỗi) ⇒ coi như CÓ mạng để không
  /// chặn tính năng chỉ vì một plugin trả lỗi.
  final bool networkAvailable;

  /// Chỉ `true` khi `DictEntry.hasAudio` và file thật sự mở được (PRON-005).
  final bool dictionaryHasAudio;

  bool isAvailable(PronunciationSource source) => switch (source) {
        PronunciationSource.tts => true, // luôn luôn dùng được
        PronunciationSource.youglish => youglishEnabled && networkAvailable,
        PronunciationSource.dictionary => dictionaryHasAudio,
      };

  List<PronunciationSource> get available => PronunciationSource.values
      .where(isAvailable)
      .toList(growable: false);
}

class PronunciationSourcePolicy {
  PronunciationSourcePolicy._();

  /// Thứ tự ưu tiên khi người dùng chưa chọn gì. TTS cuối vì luôn còn đó.
  static const List<PronunciationSource> preferredOrder = [
    PronunciationSource.youglish,
    PronunciationSource.dictionary,
    PronunciationSource.tts,
  ];

  /// Nguồn dùng cho nút ▶.
  ///
  /// [remembered] = lựa chọn gần nhất của người dùng (key
  /// `pronunciation.source`). Nó THẮNG, nhưng chỉ khi còn khả dụng — nghĩa là
  /// mất mạng / owner tắt kill-switch thì tự rớt về bậc kế tiếp còn khả dụng chứ
  /// không im lặng chết.
  static PronunciationSource resolve({
    PronunciationSource? remembered,
    required PronunciationAvailability availability,
  }) {
    if (remembered != null && availability.isAvailable(remembered)) {
      return remembered;
    }
    for (final s in preferredOrder) {
      if (availability.isAvailable(s)) return s;
    }
    return PronunciationSource.tts;
  }

  /// Bậc thoái lui khi một nguồn THẤT BẠI lúc đang chạy (WebView lỗi, file âm
  /// thanh thiếu). Trả `null` khi không còn nguồn nào phía sau. Nguồn TTS luôn
  /// còn nên thực tế chỉ `tts` mới trả `null`.
  static PronunciationSource? nextFallback(
    PronunciationSource failed,
    PronunciationAvailability availability,
  ) {
    // CHỈ đi tới — không vòng lại phía trước: quay ngược sẽ tạo vòng lặp
    // youglish → tts → youglish khi mạng chập chờn.
    final start = preferredOrder.indexOf(failed);
    for (var i = start + 1; i < preferredOrder.length; i++) {
      final s = preferredOrder[i];
      if (availability.isAvailable(s)) return s;
    }
    return null;
  }
}
