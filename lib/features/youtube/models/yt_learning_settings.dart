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

  const YtLearningSettings({
    this.translationMode = YtTranslationMode.withTranslation,
    this.subtitleLayout = YtSubtitleLayout.stacked,
    this.frequencyRankThreshold = 300,
  });

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
  }) {
    return YtLearningSettings(
      translationMode: translationMode ?? this.translationMode,
      subtitleLayout: subtitleLayout ?? this.subtitleLayout,
      frequencyRankThreshold:
          frequencyRankThreshold ?? this.frequencyRankThreshold,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'translationMode': translationMode.name,
        'subtitleLayout': subtitleLayout.name,
        'frequencyRankThreshold': frequencyRankThreshold,
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
    );
  }
}
