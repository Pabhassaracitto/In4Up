// lib/features/translation/mlkit_pack_catalog.dart
//
// PSRC-28 · XLAT-OFFLINE-LANG-001 (owner 2026-11-11) — *"chỉ hiện 3 ngôn ngữ
// ML Kit"*.
//
// Triệu chứng: sheet "Engine dịch thuật" chỉ liệt kê EN/VI/HI dù ML Kit hỗ trợ
// ~59 ngôn ngữ; user dùng JA/ZH/FR... không có cách nào tải gói offline ⇒
// tưởng app không hỗ trợ.
//
// Yêu cầu: hiện 3 ngôn ngữ phổ biến trước (gọn), và nút "Thêm ngôn ngữ" mở ra
// danh sách ĐẦY ĐỦ những ngôn ngữ ML Kit hỗ trợ **trong 26 ngôn ngữ chính của
// app** (không thêm ngôn ngữ ngoài danh mục app — bộ chọn ngôn ngữ đích không
// có chúng thì tải gói cũng vô ích).
//
// Logic ở đây THUẦN DART (nhận `supported` làm tham số) để test được trên host
// VM mà không cần plugin ML Kit.

import '../../core/language/app_language.dart';

/// 3 ngôn ngữ phổ biến nhất với người dùng app — hiện sẵn khi mở sheet.
///
/// Đúng thứ tự này (EN trước vì là ngôn ngữ nguồn phổ biến nhất, VI là tiếng
/// mẹ đẻ của owner, HI là thị trường lớn thứ ba).
const List<String> kMlKitPrimaryCodes = <String>['EN', 'VI', 'HI'];

/// Ngôn ngữ trong danh mục app mà ML Kit dịch offline được, chia 2 nhóm.
///
/// [supported] là phép thử của engine (`MlKitEngine.supportsTranslationCode`);
/// truyền vào để test không phải nạp plugin.
class MlKitPackCatalog {
  MlKitPackCatalog({
    List<AppLanguage>? languages,
    required bool Function(String code) supported,
  })  : _languages = languages ?? AppLanguageCatalog.languages,
        _supported = supported;

  final List<AppLanguage> _languages;
  final bool Function(String code) _supported;

  /// Ngôn ngữ ML Kit hỗ trợ, theo thứ tự trong danh mục app.
  List<AppLanguage> get _supportedLanguages => <AppLanguage>[
        for (final language in _languages)
          if (_supported(language.translationCode)) language,
      ];

  /// Nhóm hiện sẵn: 3 ngôn ngữ phổ biến, theo đúng thứ tự [kMlKitPrimaryCodes].
  ///
  /// Ngôn ngữ nào trong danh sách phổ biến mà máy KHÔNG hỗ trợ thì bỏ (không
  /// hiện hàng "Chưa hỗ trợ" ở nhóm chính — nhóm chính phải luôn bấm được).
  List<AppLanguage> get primary {
    final byCode = <String, AppLanguage>{
      for (final language in _supportedLanguages)
        language.translationCode: language,
    };
    return <AppLanguage>[
      for (final code in kMlKitPrimaryCodes)
        if (byCode[code] != null) byCode[code]!,
    ];
  }

  /// Nhóm "Thêm ngôn ngữ": phần còn lại, theo thứ tự danh mục app.
  List<AppLanguage> get extra {
    final primaryCodes = primary
        .map((language) => language.translationCode)
        .toSet();
    return <AppLanguage>[
      for (final language in _supportedLanguages)
        if (!primaryCodes.contains(language.translationCode)) language,
    ];
  }

  /// Toàn bộ (nhóm chính + phần mở rộng) — dùng khi đã bấm "Thêm ngôn ngữ".
  List<AppLanguage> get all => <AppLanguage>[...primary, ...extra];

  /// Có gì để mở rộng không (nếu không thì ẩn luôn nút "Thêm ngôn ngữ").
  bool get hasExtra => extra.isNotEmpty;
}
