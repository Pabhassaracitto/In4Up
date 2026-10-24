// YT-LR-002 / IN4-88 — Cài đặt học tập cho chế độ YouTube.
//
// File này nằm trong `models/` (KHÔNG phải presentation file theo quy ước của
// `tool/generate_legacy_ui_fallbacks.py`). Vì vậy:
//   • KHÔNG đặt literal tiếng Việt ở đây — gate i18n quét toàn bộ string trong
//     file presentation và bắt mọi literal có dấu phải được phân loại.
//   • Mọi nhãn hiển thị nằm ở call-site trong widget, gọi qua `context.uiText()`
//     và có English fallback trong `tool/legacy_ui_english_overrides.json`.

/// Cách hiển thị phần dịch trong ô phụ đề của màn học YouTube.
///
/// Giống menu `Single Subtitle` của Language Reactor: người dùng chọn mức "độ
/// khó" khi luyện nghe.
enum YtTranslationMode {
  /// Phụ đề gốc + bản dịch bên dưới (mặc định, hành vi cũ).
  withTranslation,

  /// Chỉ hiện phụ đề gốc — luyện đọc/nghe bản gốc.
  hideTranslation,

  /// Bản dịch bị làm mờ; bấm vào để hiện tạm rồi mờ lại.
  blurTranslation,

  /// Ẩn cả gốc lẫn dịch — luyện nghe nâng cao. Vẫn giữ ô trống để không
  /// giật layout (player không bị dịch chuyển khi đổi chế độ).
  hideSubtitle,
}

/// Bố cục danh sách phụ đề (tab VĂN BẢN).
enum YtSubtitleLayout {
  /// Danh sách đơn giản: chỉ phụ đề gốc, cuộn theo thời gian.
  simple,

  /// Song song: phụ đề gốc và bản dịch nằm cạnh nhau (2 cột).
  sideBySide,

  /// Trên và dưới: gốc ở trên, bản dịch tiếng Việt ở dưới.
  stacked,
}

/// YT-TTS-READ-001: đọc thành tiếng phần **bản dịch** của phụ đề.
///
/// Cùng ý tưởng với "đọc song ngữ" ở tab Đọc, nhưng ở đây nguồn chữ là phụ đề
/// YouTube chứ không phải file văn bản.
enum YtReadAloudMode {
  /// Chỉ đọc phụ đề **gốc** (luyện nghe/đọc bản gốc).
  sourceOnly,

  /// Chỉ đọc **bản dịch** — đúng yêu cầu "nghe âm thanh đã dịch".
  targetOnly,

  /// Xen kẽ: gốc → dịch (số lần mỗi bên theo [YtLearningSettings]).
  interleaved,
}

/// YT-MEDIA-STORE-001: nơi lưu phụ đề `.lrc` và file âm thanh đã tải.
enum YtSaveLocation {
  /// Bộ nhớ riêng của app (`.../app_flutter/youtube_media`) — luôn ghi được,
  /// không cần quyền, nhưng người dùng không thấy trong trình quản lý file.
  appPrivate,

  /// Thư mục công khai của máy (Android: `Download/In4Up`). Tiện tìm lại và
  /// sao chép ra ngoài, nhưng Android 11+ có thể từ chối ghi ⇒ phải có
  /// đường lùi về [appPrivate] và **báo thật** cho người dùng biết.
  externalDownloads,
}

/// Cài đặt học tập của chế độ YouTube.
///
/// Lưu **toàn cục** (không theo từng video) — người dùng chọn một lần, áp dụng
/// cho mọi video mở sau đó.
class YtLearningSettings {
  final YtTranslationMode translationMode;
  final YtSubtitleLayout subtitleLayout;

  /// Ngưỡng rank tần suất: từ có `langRank` <= ngưỡng bị coi là "dễ / đã quen".
  /// Thanh trượt trong bảng tra từ cho phép người dùng kéo đổi ngưỡng này.
  final double frequencyRankThreshold;

  /// YT-AUDIT-10 (IN4-102): tab VĂN BẢN tự cuộn theo dòng phụ đề đang phát.
  /// Mặc định BẬT; tắt đi để người dùng tự do đọc/kéo (auto cuộn sẽ không
  /// giật lại vị trí đang đọc).
  final bool transcriptAutoFollow;

  /// YT-AUDIT-04 (IN4-103): ngôn ngữ của **phụ đề gốc** lấy từ YouTube
  /// (vd `en`, `ja`, `a.en` cho auto-generated). Mặc định `en`.
  ///
  /// Khác với [targetLang]: đây là thứ đang được NÓI trong video, còn
  /// [targetLang] là thứ người dùng muốn ĐỌC.
  final String subtitleLang;

  /// YT-AUDIT-04 (IN4-103): ngôn ngữ dịch.
  ///
  /// `null` (mặc định) ⇒ **theo Cài đặt Home** (`TranslationService.targetLang`).
  /// Khác `null` ⇒ người dùng đã chọn riêng cho YouTube, không bám Home nữa.
  ///
  /// English nằm trong danh sách CHỌN, không phải mặc định — học tiếng Anh
  /// mà dịch Anh→Anh là vô nghĩa.
  final String? targetLang;

  /// YT-AUDIT-11 (IN4-106): bù trễ **THỦ CÔNG** giữa âm thanh và chữ (ms).
  ///
  /// Chiều dương được định nghĩa theo đúng cách owner mô tả triệu chứng:
  ///   * `> 0` ⇒ **âm thanh nhanh hơn chữ** ⇒ chữ phải đổi SỚM hơn
  ///     (cộng thêm vào vị trí phát khi chọn dòng phụ đề).
  ///   * `< 0` ⇒ chữ nhanh hơn âm thanh ⇒ chữ đổi muộn hơn.
  ///
  /// Lý do phải có tay: phần lệch do **track phụ đề** (YouTube caption lệch so
  /// với audio) là KHÔNG ĐO ĐƯỢC nếu không có tín hiệu PCM (VAD đã bị bác vì
  /// iframe WebView không lấy được PCM). Phần lệch do **kênh WebView→Flutter**
  /// thì đo được và được bù TỰ ĐỘNG ở `AiConnectivity…` của player — hai phần
  /// này cộng lại, không thay thế nhau.
  final double audioLeadMs;

  // ─── YT-TTS-READ-001: đọc phần bản dịch thành tiếng ───────────────
  /// Chế độ đọc (gốc / dịch / xen kẽ).
  final YtReadAloudMode readAloudMode;

  /// Số lần đọc **mỗi dòng gốc** trong một lượt (0 = bỏ qua bên gốc).
  final int readAloudSourceRepeats;

  /// Số lần đọc **mỗi dòng dịch** trong một lượt (0 = bỏ qua bên dịch).
  ///
  /// `sourceRepeats = 2, targetRepeats = 1` chính là kiểu "bên nhiều bên ít"
  /// owner yêu cầu; `1/1` là xen kẽ đều.
  final int readAloudTargetRepeats;

  /// Khoảng nghỉ giữa hai lượt đọc (ms) — để kịp ngẫm nghĩa.
  final int readAloudGapMs;

  /// Tốc độ đọc 0.5–2.0.
  final double readAloudSpeed;

  // ─── YT-MEDIA-STORE-001: nơi lưu ──────────────────────────────────
  /// Nơi lưu phụ đề `.lrc` + file âm thanh đã tải.
  final YtSaveLocation saveLocation;

  const YtLearningSettings({
    this.translationMode = YtTranslationMode.withTranslation,
    this.subtitleLayout = YtSubtitleLayout.stacked,
    this.frequencyRankThreshold = 300,
    this.transcriptAutoFollow = true,
    this.subtitleLang = 'en',
    this.targetLang,
    this.audioLeadMs = 0,
    this.readAloudMode = YtReadAloudMode.interleaved,
    this.readAloudSourceRepeats = 1,
    this.readAloudTargetRepeats = 1,
    this.readAloudGapMs = 500,
    this.readAloudSpeed = 1.0,
    this.saveLocation = YtSaveLocation.appPrivate,
  });

  /// YT-AUDIT-04 (IN4-103) — ngôn ngữ dịch THỰC TẾ + có đang phải "rớt về
  /// tiếng Việt" hay không.
  ///
  /// Trước đây code tự đoán trong im lặng:
  /// ```dart
  /// final target = TranslationService().targetLang.toLowerCase();
  /// final lang2 = target.isEmpty || target == 'en' ? 'vi' : target;
  /// ```
  /// ⇒ Home đang để EN thì **lén** đổi sang VI mà người dùng không hay. Giờ
  /// vẫn giữ hành vi rớt về `vi` (đừng làm mất bản dịch) nhưng trả kèm
  /// `fellBack: true` để UI **nói rõ lý do** thay vì im lặng.
  static ({String lang, bool fellBack}) resolveTargetLang({
    required String subtitleLang,
    String? overrideTargetLang,
    required String homeTargetLang,
  }) {
    var sub = subtitleLang.trim().toLowerCase();
    // `a.en` = phụ đề auto-generated TIẾNG ANH của YouTube. Bỏ tiền tố để so
    // sánh cho đúng: dịch en (gốc) → en (đích) cũng vô nghĩa như a.en → en.
    if (sub.startsWith('a.')) sub = sub.substring(2);
    final chosen = (overrideTargetLang ?? '').trim().toLowerCase();
    final home = homeTargetLang.trim().toLowerCase();

    var lang = chosen.isNotEmpty ? chosen : home;
    if (lang.isEmpty) lang = 'vi';

    if (lang == sub) {
      // Ngôn ngữ đích trùng với phụ đề gốc ⇒ dịch là vô nghĩa.
      // Rớt về tiếng Việt nhưng BÁO cho UI biết.
      return (lang: 'vi', fellBack: true);
    }
    return (lang: lang, fellBack: false);
  }

  /// Biên dưới của thanh trượt bù trễ (ms) — chữ đổi muộn hơn 3 giây.
  static const double kAudioLeadMin = -3000;

  /// Biên trên của thanh trượt bù trễ (ms) — chữ đổi sớm hơn 3 giây.
  static const double kAudioLeadMax = 3000;

  /// Bước của thanh trượt / nút +− (ms) = 0,1 giây.
  static const double kAudioLeadStep = 100;

  /// Kẹp giá trị bù trễ vào biên cho phép.
  ///
  /// `double.clamp` trả `num` ⇒ viết tay để giữ kiểu `double` cho Slider.
  static double clampAudioLead(double v) {
    if (v.isNaN) return 0;
    if (v < kAudioLeadMin) return kAudioLeadMin;
    if (v > kAudioLeadMax) return kAudioLeadMax;
    return v;
  }

  /// Chốt giá trị bù trễ về đúng BƯỚC 100 ms.
  ///
  /// Slider có `divisions` vẫn có thể trả `-1.4e-14` hoặc `100.00000000000001`
  /// (chia cho 60 rồi nhân 6000). Những giá trị đó làm UI hiện "-0.0s" và làm
  /// `lead == 0` sai ⇒ phải chốt lại. `-0.0` được ép thành `0.0`.
  static double snapAudioLead(double v) {
    final clamped = clampAudioLead(v);
    final snapped = (clamped / kAudioLeadStep).round() * kAudioLeadStep;
    // `-0.0 == 0.0` là true ⇒ ghi đè cả hai về `0.0` (UI so sánh `== 0`).
    return snapped == 0 ? 0.0 : snapped.toDouble();
  }

  /// Bù trễ đang đặt, tính theo GIÂY (UI đọc số này).
  double get audioLeadSeconds => audioLeadMs / 1000.0;

  /// Biên dưới của thanh trượt tần suất (`LrWord.langRank` bắt đầu từ 100).
  static const double kMinRank = 100;

  /// Biên trên của thanh trượt tần suất (từ hiếm / khó).
  static const double kMaxRank = 2000;

  /// Chia thanh trượt theo bước 50 để giá trị dễ đọc.
  static const double kRankStep = 50;

  /// Có render phần dịch hay không.
  bool get showsTranslation =>
      translationMode == YtTranslationMode.withTranslation ||
      translationMode == YtTranslationMode.blurTranslation;

  /// Ẩn hoàn toàn cả phụ đề gốc lẫn bản dịch.
  bool get hidesSubtitle =>
      translationMode == YtTranslationMode.hideSubtitle;

  /// Phần dịch bị làm mờ (bấm để hiện tạm).
  bool get blursTranslation =>
      translationMode == YtTranslationMode.blurTranslation;

  /// Từ có rank <= ngưỡng được coi là dễ (đã quen).
  bool isEasy(int langRank) => langRank <= frequencyRankThreshold;

  YtLearningSettings copyWith({
    YtTranslationMode? translationMode,
    YtSubtitleLayout? subtitleLayout,
    double? frequencyRankThreshold,
    bool? transcriptAutoFollow,
    String? subtitleLang,
    Object? targetLang = _kNoChange,
    double? audioLeadMs,
    YtReadAloudMode? readAloudMode,
    int? readAloudSourceRepeats,
    int? readAloudTargetRepeats,
    int? readAloudGapMs,
    double? readAloudSpeed,
    YtSaveLocation? saveLocation,
  }) {
    return YtLearningSettings(
      translationMode: translationMode ?? this.translationMode,
      subtitleLayout: subtitleLayout ?? this.subtitleLayout,
      frequencyRankThreshold:
          frequencyRankThreshold ?? this.frequencyRankThreshold,
      transcriptAutoFollow:
          transcriptAutoFollow ?? this.transcriptAutoFollow,
      subtitleLang: subtitleLang ?? this.subtitleLang,
      // `Object?` sentinel để phân biệt "không đổi" với "đặt về null"
      // (= quay lại theo Cài đặt Home).
      targetLang: identical(targetLang, _kNoChange)
          ? this.targetLang
          : targetLang as String?,
      audioLeadMs: audioLeadMs == null
          ? this.audioLeadMs
          : clampAudioLead(audioLeadMs),
      readAloudMode: readAloudMode ?? this.readAloudMode,
      // `.clamp()` trả `num` ⇒ phải `.toInt()` / `.toDouble()` trước khi gán
      // vào field có kiểu cụ thể (analyzer báo lỗi nếu bỏ qua).
      readAloudSourceRepeats: readAloudSourceRepeats == null
          ? this.readAloudSourceRepeats
          : readAloudSourceRepeats.clamp(0, 5).toInt(),
      readAloudTargetRepeats: readAloudTargetRepeats == null
          ? this.readAloudTargetRepeats
          : readAloudTargetRepeats.clamp(0, 5).toInt(),
      readAloudGapMs: readAloudGapMs == null
          ? this.readAloudGapMs
          : readAloudGapMs.clamp(0, 5000).toInt(),
      readAloudSpeed: readAloudSpeed == null
          ? this.readAloudSpeed
          : readAloudSpeed.clamp(0.5, 2.0).toDouble(),
      saveLocation: saveLocation ?? this.saveLocation,
    );
  }

  /// Sentinel cho [copyWith] — phân biệt "giữ nguyên" và "xoá override".
  static const Object _kNoChange = Object();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'translationMode': translationMode.name,
        'subtitleLayout': subtitleLayout.name,
        'frequencyRankThreshold': frequencyRankThreshold,
        'transcriptAutoFollow': transcriptAutoFollow,
        'subtitleLang': subtitleLang,
        'targetLang': targetLang,
        'audioLeadMs': audioLeadMs,
        'readAloudMode': readAloudMode.name,
        'readAloudSourceRepeats': readAloudSourceRepeats,
        'readAloudTargetRepeats': readAloudTargetRepeats,
        'readAloudGapMs': readAloudGapMs,
        'readAloudSpeed': readAloudSpeed,
        'saveLocation': saveLocation.name,
      };

  factory YtLearningSettings.fromJson(Map<String, dynamic> json) {
    return YtLearningSettings(
      translationMode: YtTranslationMode.values.firstWhere(
        (e) => e.name == json['translationMode'],
        orElse: () => YtTranslationMode.withTranslation,
      ),
      subtitleLayout: YtSubtitleLayout.values.firstWhere(
        (e) => e.name == json['subtitleLayout'],
        orElse: () => YtSubtitleLayout.stacked,
      ),
      frequencyRankThreshold:
          (json['frequencyRankThreshold'] as num?)?.toDouble() ?? 300,
      // Dữ liệu cũ không có khoá này ⇒ mặc định BẬT (đúng yêu cầu owner:
      // "auto là mặc định").
      transcriptAutoFollow: json['transcriptAutoFollow'] as bool? ?? true,
      // Dữ liệu cũ ⇒ ngôn ngữ gốc `en`, ngôn ngữ dịch theo Cài đặt Home.
      subtitleLang: (json['subtitleLang'] as String?) ?? 'en',
      targetLang: json['targetLang'] as String?,
      // Dữ liệu cũ không có khoá này ⇒ 0 (không bù).
      audioLeadMs: (json['audioLeadMs'] as num?)?.toDouble() ?? 0,
      // Dữ liệu cũ không có các khoá dưới ⇒ mặc định = hành vi mới an toàn
      // (xen kẽ 1/1, nghỉ 500ms, tốc độ 1.0, lưu trong bộ nhớ riêng của app).
      readAloudMode: YtReadAloudMode.values.firstWhere(
        (e) => e.name == json['readAloudMode'],
        orElse: () => YtReadAloudMode.interleaved,
      ),
      readAloudSourceRepeats:
          (json['readAloudSourceRepeats'] as num?)?.toInt() ?? 1,
      readAloudTargetRepeats:
          (json['readAloudTargetRepeats'] as num?)?.toInt() ?? 1,
      readAloudGapMs: (json['readAloudGapMs'] as num?)?.toInt() ?? 500,
      readAloudSpeed: (json['readAloudSpeed'] as num?)?.toDouble() ?? 1.0,
      saveLocation: YtSaveLocation.values.firstWhere(
        (e) => e.name == json['saveLocation'],
        orElse: () => YtSaveLocation.appPrivate,
      ),
    );
  }
}
