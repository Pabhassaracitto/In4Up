// PLAN-043 mục 2 (WORDLIST-TTS-001 mở rộng) — THỨ TỰ đọc "từ + nghĩa"
// của Worklist, tách THUẦN khỏi `wordlist_playback_service.dart` (file đó
// kéo TtsService/flutter) để phần logic dễ sai nhất (thứ tự, số lần lặp
// từng phía, khoảng lặng gợi nhớ, từ thiếu nghĩa) test được không plugin.
//
// Khuôn theo `yt_read_aloud_sequence.dart` (YT-TTS-READ-001): service phát
// đúng danh sách bước hàm này dựng, nên test ở đây là test hành vi thật.

/// Chế độ đọc một mục từ vựng.
enum WordlistReadMode {
  /// Chỉ đọc TỪ (hành vi cũ trước PLAN-043).
  wordOnly,

  /// Chỉ đọc NGHĨA; mục nào không có nghĩa thì đọc từ thay (không im lặng).
  meaningOnly,

  /// Từ (×wordRepeats) rồi nghĩa (×meaningRepeats) — mặc định owner chốt.
  wordThenMeaning,

  /// Nghĩa rồi từ.
  meaningThenWord,

  /// Gợi nhớ chủ động: nghĩa → KHOẢNG LẶNG (tự bật ra từ trong đầu) → từ.
  /// Về chuỗi bước thì như [meaningThenWord], nhưng bước từ đầu tiên mang
  /// `pauseBeforeMs` lớn (khoảng lặng gợi nhớ thay vì khoảng nghỉ thường).
  recall,
}

/// Cài đặt đọc Worklist (persist bởi [WordlistPlaybackService]).
///
/// Mặc định theo chốt của owner 2026-11-02 (PLAN-043 Q2): Từ ×2 → Nghĩa ×1.
class WordlistReadSettings {
  final WordlistReadMode mode;

  /// Số lần đọc phía TỪ cho mỗi mục (0–5; 0 = bỏ phía từ khi mode cho phép).
  final int wordRepeats;

  /// Số lần đọc phía NGHĨA cho mỗi mục (0–5).
  final int meaningRepeats;

  /// Nghỉ giữa hai phía (từ ↔ nghĩa) trong cùng một mục, ms.
  /// Ở chế độ [WordlistReadMode.recall] đây là thời gian TỰ NHỚ.
  final int gapBetweenSidesMs;

  /// Nghỉ giữa hai lần đọc LIÊN TIẾP của cùng một phía, ms.
  final int gapBetweenRepeatsMs;

  /// Nghỉ giữa hai mục từ vựng, ms (service áp dụng, không nằm trong bước).
  final int gapBetweenWordsMs;

  /// Ngôn ngữ đọc phía NGHĨA: mã như 'vi'/'en', hoặc 'auto' (để TTS tự dò
  /// theo nội dung nghĩa — nghĩa là chuỗi tự do do người dùng viết).
  final String meaningLanguage;

  const WordlistReadSettings({
    this.mode = WordlistReadMode.wordThenMeaning,
    this.wordRepeats = 2,
    this.meaningRepeats = 1,
    this.gapBetweenSidesMs = 700,
    this.gapBetweenRepeatsMs = 350,
    this.gapBetweenWordsMs = 500,
    this.meaningLanguage = 'auto',
  });

  WordlistReadSettings copyWith({
    WordlistReadMode? mode,
    int? wordRepeats,
    int? meaningRepeats,
    int? gapBetweenSidesMs,
    int? gapBetweenRepeatsMs,
    int? gapBetweenWordsMs,
    String? meaningLanguage,
  }) {
    return WordlistReadSettings(
      mode: mode ?? this.mode,
      wordRepeats: wordRepeats ?? this.wordRepeats,
      meaningRepeats: meaningRepeats ?? this.meaningRepeats,
      gapBetweenSidesMs: gapBetweenSidesMs ?? this.gapBetweenSidesMs,
      gapBetweenRepeatsMs: gapBetweenRepeatsMs ?? this.gapBetweenRepeatsMs,
      gapBetweenWordsMs: gapBetweenWordsMs ?? this.gapBetweenWordsMs,
      meaningLanguage: meaningLanguage ?? this.meaningLanguage,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': mode.name,
        'wordRepeats': wordRepeats,
        'meaningRepeats': meaningRepeats,
        'gapBetweenSidesMs': gapBetweenSidesMs,
        'gapBetweenRepeatsMs': gapBetweenRepeatsMs,
        'gapBetweenWordsMs': gapBetweenWordsMs,
        'meaningLanguage': meaningLanguage,
      };

  /// Đọc cài đặt đã lưu — chịu được JSON thiếu/lạ (bản app cũ hơn ghi dở):
  /// trường nào sai thì rơi về mặc định của trường đó, không ném.
  factory WordlistReadSettings.fromJson(Map<String, dynamic> json) {
    const d = WordlistReadSettings();
    WordlistReadMode mode = d.mode;
    for (final m in WordlistReadMode.values) {
      if (m.name == json['mode']) mode = m;
    }
    int pickInt(String key, int fallback, int min, int max) {
      final v = json[key];
      if (v is int) return v.clamp(min, max);
      if (v is num) return v.toInt().clamp(min, max);
      return fallback;
    }

    final lang = json['meaningLanguage'];
    return WordlistReadSettings(
      mode: mode,
      wordRepeats: pickInt('wordRepeats', d.wordRepeats, 0, 5),
      meaningRepeats: pickInt('meaningRepeats', d.meaningRepeats, 0, 5),
      gapBetweenSidesMs:
          pickInt('gapBetweenSidesMs', d.gapBetweenSidesMs, 0, 10000),
      gapBetweenRepeatsMs:
          pickInt('gapBetweenRepeatsMs', d.gapBetweenRepeatsMs, 0, 5000),
      gapBetweenWordsMs:
          pickInt('gapBetweenWordsMs', d.gapBetweenWordsMs, 0, 5000),
      meaningLanguage:
          (lang is String && lang.trim().isNotEmpty) ? lang.trim() : 'auto',
    );
  }
}

/// Một mục sẵn sàng để dựng chuỗi (tách khỏi WordEntry để test thuần).
class WordlistReadLine {
  const WordlistReadLine({required this.word, this.meaning});

  final String word;
  final String? meaning;

  bool get hasMeaning => meaning != null && meaning!.trim().isNotEmpty;
}

/// Một bước đọc.
class WordlistReadStep {
  const WordlistReadStep({
    required this.line,
    required this.isMeaning,
    required this.text,
    required this.repeatNumber,
    required this.pauseBeforeMs,
  });

  /// Chỉ số mục trong danh sách đầu vào (0-based).
  final int line;

  /// `true` = đang đọc phía NGHĨA, `false` = phía TỪ.
  final bool isMeaning;

  /// Nội dung thật đưa cho TTS.
  final String text;

  /// Lần thứ mấy của phía này (1-based) — UI hiện "lần 2".
  final int repeatNumber;

  /// Nghỉ TRƯỚC bước này (ms). Bước đầu tiên của mục luôn 0 (nghỉ giữa
  /// các mục do service lo bằng `gapBetweenWordsMs`).
  final int pauseBeforeMs;

  @override
  String toString() =>
      'step(line=$line, ${isMeaning ? 'M' : 'W'}#$repeatNumber, pause=$pauseBeforeMs: $text)';
}

int _clampRepeats(int v) => v < 0 ? 0 : (v > 5 ? 5 : v);

/// Dựng chuỗi bước đọc cho MỘT mục (service ghép các mục + vòng lặp list).
///
/// Quy tắc (khớp cách service phát — test ở đây là hành vi thật):
///  * `wordOnly`     → chỉ phía từ (wordRepeats, tối thiểu 1 nếu đặt 0).
///  * `meaningOnly`  → chỉ phía nghĩa; thiếu nghĩa ⇒ đọc từ 1 lần thay thế.
///  * `wordThenMeaning` / `meaningThenWord` → hai phía theo thứ tự; phía
///    nghĩa bị bỏ khi mục không có nghĩa; phía nào đặt 0 lần thì bỏ phía đó.
///  * `recall` → nghĩa trước, bước từ đầu tiên mang `pauseBeforeMs` =
///    `gapBetweenSidesMs` (khoảng lặng tự nhớ); thiếu nghĩa ⇒ như wordOnly.
///  * Mục có `word` rỗng → không có bước nào.
List<WordlistReadStep> buildWordlistReadStepsForLine({
  required int lineIndex,
  required WordlistReadLine line,
  required WordlistReadSettings settings,
}) {
  final steps = <WordlistReadStep>[];
  final word = line.word.trim();
  if (word.isEmpty) return steps;
  final meaning = (line.meaning ?? '').trim();

  var wordRepeats = _clampRepeats(settings.wordRepeats);
  var meaningRepeats = _clampRepeats(settings.meaningRepeats);
  switch (settings.mode) {
    case WordlistReadMode.wordOnly:
      meaningRepeats = 0;
      if (wordRepeats == 0) wordRepeats = 1;
      break;
    case WordlistReadMode.meaningOnly:
      wordRepeats = 0;
      if (meaningRepeats == 0) meaningRepeats = 1;
      break;
    case WordlistReadMode.wordThenMeaning:
    case WordlistReadMode.meaningThenWord:
    case WordlistReadMode.recall:
      // Cả hai phía đều 0 ⇒ không có gì để đọc; ép phía từ 1 lần để
      // không im lặng khó hiểu (cài đặt cực đoan vẫn nghe được mục đó).
      if (wordRepeats == 0 && meaningRepeats == 0) wordRepeats = 1;
      break;
  }

  void addSide({required bool isMeaning, required int repeats}) {
    final text = isMeaning ? meaning : word;
    if (text.isEmpty) return;
    for (var r = 0; r < repeats; r++) {
      final pause = steps.isEmpty
          ? 0
          : (r == 0
              ? settings.gapBetweenSidesMs
              : settings.gapBetweenRepeatsMs);
      steps.add(WordlistReadStep(
        line: lineIndex,
        isMeaning: isMeaning,
        text: text,
        repeatNumber: r + 1,
        pauseBeforeMs: pause < 0 ? 0 : pause,
      ));
    }
  }

  switch (settings.mode) {
    case WordlistReadMode.wordOnly:
    case WordlistReadMode.wordThenMeaning:
      addSide(isMeaning: false, repeats: wordRepeats);
      addSide(isMeaning: true, repeats: meaningRepeats);
      break;
    case WordlistReadMode.meaningOnly:
    case WordlistReadMode.meaningThenWord:
    case WordlistReadMode.recall:
      addSide(isMeaning: true, repeats: meaningRepeats);
      addSide(isMeaning: false, repeats: wordRepeats);
      break;
  }

  // Chế độ cậy vào nghĩa nhưng mục KHÔNG có nghĩa ⇒ steps có thể rỗng
  // (meaningOnly) — đọc từ 1 lần thay vì bỏ qua lặng lẽ.
  if (steps.isEmpty) {
    steps.add(WordlistReadStep(
      line: lineIndex,
      isMeaning: false,
      text: word,
      repeatNumber: 1,
      pauseBeforeMs: 0,
    ));
  }
  return steps;
}

/// Dựng chuỗi cho CẢ danh sách (một lượt — vòng lặp cả list do service lo).
List<WordlistReadStep> buildWordlistReadSequence({
  required List<WordlistReadLine> lines,
  required WordlistReadSettings settings,
}) {
  final steps = <WordlistReadStep>[];
  for (var i = 0; i < lines.length; i++) {
    steps.addAll(buildWordlistReadStepsForLine(
      lineIndex: i,
      line: lines[i],
      settings: settings,
    ));
  }
  return steps;
}
