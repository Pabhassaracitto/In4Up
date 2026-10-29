/// Lộ trình phủ ngôn ngữ của dự án — ADR-0002 (máy bắt bằng test).
///
/// Lộ trình: **vi → en → hi + zh (+zh_TW) + si → …**
///
/// - T0 `vi` — ngôn ngữ nguồn: chuỗi gốc của app viết bằng tiếng Việt.
/// - T1 `en` — chuẩn fallback toàn cục: locale ≠ vi mà thiếu bản dịch thì
///   hiển thị English, KHÔNG BAO GIỜ fallback về tiếng Việt (rule #5,
///   AGENTS.md). ARB template cũng là `app_en.arb`.
/// - T2 rollout ưu tiên — Hindi, Chinese (giản + phồn), Sinhala: phủ dần
///   thay cho English theo từng wave; sau wave 1 (2026-08-22) đã phủ
///   100% thông điệp chrome (trừ key giữ nguyên English theo chính sách
///   `tool/lang_keep_english.json`).
/// - T3 kế tiếp — các locale còn lại; sàn độ phủ = độ phủ hiện tại
///   (chỉ được tăng — ratchet). Locale lên T2 khi owner duyệt ADR mới.
///
/// Sàn độ phủ (floor) lấy từ `tool/lang_rollout_floors.json`;
/// [LanguageRollout.coverageFloors] là bản sao bắt buộc đồng bộ — test
/// group ADR-0002 trong `test/locale_chrome_no_vietnamese_test.dart`
/// fail nếu hai nơi lệch nhau.
library;

/// Một bậc trong lộ trình phủ ngôn ngữ.
class LanguageRolloutTier {
  /// Id bậc (T0..T3) — hiển thị trong báo cáo.
  final String id;

  /// Mô tả ngắn (tiếng Việt, dành cho người sở hữu dự án).
  final String label;

  /// Locale codes thuộc bậc này (không gồm `vi`/`en` ở T0/T1).
  final List<String> locales;

  const LanguageRolloutTier({
    required this.id,
    required this.label,
    required this.locales,
  });
}

class LanguageRollout {
  LanguageRollout._();

  /// Lộ trình chuẩn — thứ tự phủ: vi → en → hi/zh/si → còn lại.
  static const List<LanguageRolloutTier> tiers = [
    LanguageRolloutTier(
      id: 'T0',
      label: 'Tiếng Việt — ngôn ngữ nguồn của chuỗi UI gốc',
      locales: ['vi'],
    ),
    LanguageRolloutTier(
      id: 'T1',
      label: 'English — chuẩn fallback cho mọi locale ≠ vi (rule #5)',
      locales: ['en'],
    ),
    LanguageRolloutTier(
      id: 'T2',
      label: 'Rollout ưu tiên: Hindi + Chinese (zh, zh_TW) + Sinhala — '
          'phủ dần thay English, wave 1 đã đạt 100%',
      locales: ['hi', 'zh', 'zh_TW', 'si'],
    ),
    LanguageRolloutTier(
      id: 'T3',
      label: 'Kế tiếp — sàn ratchet theo độ phủ hiện tại, chờ duyệt lên T2',
      locales: [
        'ar', 'bn', 'bo', 'de', 'es', 'fr', 'id', 'it', 'ja', 'km', //
        'ko', 'lo', 'mn', 'mr', 'my', 'pt', 'ru', 'ta', 'te', 'th',
      ],
    ),
  ];

  /// Locale thuộc bậc rollout ưu tiên (T2) — phủ để thay English.
  static const List<String> priorityLocales = ['hi', 'zh', 'zh_TW', 'si'];

  /// Bản sao sàn độ phủ của `tool/lang_rollout_floors.json`.
  ///
  /// CHỈ ĐƯỢC RA LÊN khi độ phủ tăng (ratchet); không được hạ.
  /// Group ADR-0002 trong `test/locale_chrome_no_vietnamese_test.dart`
  /// fail nếu lệch JSON.
  static const Map<String, double> coverageFloors = {
    'ar': 0.41,
    'bn': 0.14,
    'bo': 0.14,
    'de': 0.39,
    'es': 0.40,
    'fr': 0.39,
    'hi': 1.0,
    'id': 0.40,
    'it': 0.40,
    'ja': 0.41,
    'km': 0.14,
    'ko': 0.41,
    'lo': 0.14,
    'mn': 0.14,
    'mr': 0.14,
    'my': 0.14,
    'pt': 0.41,
    'ru': 0.41,
    'si': 1.0,
    'ta': 0.14,
    'te': 0.14,
    'th': 0.41,
    'zh': 1.0,
    'zh_TW': 1.0,
  };

  /// Chuẩn hóa code về dạng ARB stem (`vi`, `en`, `hi`, `zh`, `zh_TW`, `si`…).
  ///
  /// Chấp nhận cả language-tag (`zh-TW`, `zh-Hant`) — mirror ngữ nghĩa của
  /// `AppUITranslations.canonicalLocaleCode` để hai nơi không lệch nhau.
  static String canonicalize(String localeCode) {
    final parts =
        localeCode.trim().replaceAll('_', '-').split('-');
    if (parts.first.isEmpty) return '';
    final language = parts.first.toLowerCase();
    if (language == 'zh' && parts.length > 1) {
      final subtags = parts.skip(1).map((p) => p.toLowerCase()).toSet();
      if (subtags.contains('tw') ||
          subtags.contains('hant') ||
          subtags.contains('hk') ||
          subtags.contains('mo')) {
        return 'zh_TW';
      }
      return 'zh';
    }
    return language;
  }

  /// Bậc của [localeCode] (`vi`, `en`, `hi`, `zh_TW`, …). Null nếu lạ.
  static LanguageRolloutTier? tierOf(String localeCode) {
    final canonical = canonicalize(localeCode);
    for (final tier in tiers) {
      if (tier.locales.contains(canonical)) return tier;
    }
    return null;
  }

  static bool isPriority(String localeCode) =>
      priorityLocales.contains(canonicalize(localeCode));

  static double floorFor(String localeCode) =>
      coverageFloors[canonicalize(localeCode)] ?? 0.0;
}
