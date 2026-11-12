// PSRC-28 · XLAT-OFFLINE-LANG-001 (owner 2026-11-11) — *"chỉ hiện 3 ngôn ngữ
// ML Kit; thêm các ngôn ngữ còn lại"*.
//
// Trước: sheet "Engine dịch thuật" chỉ liệt kê EN/VI/HI (hard-code) ⇒ 16 ngôn
// ngữ còn lại của app mà ML Kit dịch offline được KHÔNG có đường tải gói.
//
// Hợp đồng (kiểm ở đây):
//   1. Nhóm hiện sẵn = ĐÚNG 3 ngôn ngữ phổ biến EN/VI/HI, đúng thứ tự đó.
//   2. Nhóm mở rộng = mọi ngôn ngữ ML Kit hỗ trợ TRONG 26 ngôn ngữ của app
//      (không thêm ngôn ngữ ngoài danh mục app — bộ chọn đích không có chúng).
//   3. Không trùng giữa 2 nhóm; gộp lại = toàn bộ ngôn ngữ hỗ trợ.
//   4. Ngôn ngữ ML Kit KHÔNG hỗ trợ (BO/KM/LO/MN/MY/SI...) không xuất hiện.
//
// Thuần Dart — `supported` được inject nên không cần plugin ML Kit.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_language.dart';
import 'package:in4up/features/translation/mlkit_pack_catalog.dart';

/// 59 bcpCode của `google_mlkit_translation` 0.14.x (đã đối chiếu source
/// `on_device_translator.dart`).
const List<String> _mlKitBcpCodes = <String>[
  'af', 'sq', 'ar', 'be', 'bn', 'bg', 'ca', 'zh', 'hr', 'cs', 'da', 'nl', 'en',
  'eo', 'et', 'fi', 'fr', 'gl', 'ka', 'de', 'el', 'gu', 'ht', 'he', 'hi', 'hu',
  'is', 'id', 'ga', 'it', 'ja', 'kn', 'ko', 'lv', 'lt', 'mk', 'ms', 'mt', 'mr',
  'no', 'fa', 'pl', 'pt', 'ro', 'ru', 'sk', 'sl', 'es', 'sw', 'sv', 'tl', 'ta',
  'te', 'th', 'tr', 'uk', 'ur', 'vi', 'cy',
];

bool _supports(String code) =>
    _mlKitBcpCodes.contains(code.trim().toLowerCase());

void main() {
  final catalog = MlKitPackCatalog(supported: _supports);

  group('PSRC-28 — danh sách gói ML Kit gọn nhưng đủ', () {
    test('nhóm hiện sẵn = đúng EN/VI/HI, đúng thứ tự', () {
      expect(
        catalog.primary.map((l) => l.translationCode).toList(),
        <String>['EN', 'VI', 'HI'],
      );
    });

    test('nhóm mở rộng có 16 ngôn ngữ (tổng 19 trong danh mục app)', () {
      expect(catalog.all, hasLength(19),
          reason: '26 ngôn ngữ app ∩ 59 ngôn ngữ ML Kit = 19');
      expect(catalog.extra, hasLength(16));
      expect(catalog.hasExtra, isTrue);
    });

    test('nhóm mở rộng chứa đúng các ngôn ngữ còn lại, không trùng nhóm chính',
        () {
      final extra = catalog.extra.map((l) => l.translationCode).toList();
      expect(
        extra,
        <String>[
          'AR', 'BN', 'DE', 'ES', 'FR', 'ID', 'IT', 'JA',
          'KO', 'MR', 'PT', 'RU', 'TA', 'TE', 'TH', 'ZH',
        ],
        reason: 'thứ tự theo danh mục app để mắt dò nhanh',
      );
      expect(extra.toSet().intersection(<String>{'EN', 'VI', 'HI'}), isEmpty);
    });

    test('ngôn ngữ ML Kit KHÔNG hỗ trợ không xuất hiện', () {
      final all = catalog.all.map((l) => l.translationCode).toSet();
      for (final code in <String>['BO', 'KM', 'LO', 'MN', 'MY', 'SI', 'ZH-TW']) {
        expect(all.contains(code), isFalse,
            reason: '$code không có trong ML Kit — tải gói là vô ích');
      }
    });

    test('không có ngôn ngữ nào ngoài danh mục 26 của app', () {
      final appCodes = AppLanguageCatalog.languages
          .map((l) => l.translationCode)
          .toSet();
      for (final language in catalog.all) {
        expect(appCodes.contains(language.translationCode), isTrue,
            reason: '${language.translationCode} không chọn được ở bộ chọn đích');
      }
    });

    test('mọi ngôn ngữ trong danh sách đều có nhãn bản ngữ để hiện', () {
      for (final language in catalog.all) {
        expect(language.nativeName.trim(), isNotEmpty);
        expect(language.flag.trim(), isNotEmpty);
      }
    });

    test('máy chỉ hỗ trợ 1 ngôn ngữ ⇒ nhóm chính co lại, "Thêm" ẩn đi', () {
      final narrow = MlKitPackCatalog(supported: (code) => code == 'VI');
      expect(narrow.primary.map((l) => l.translationCode).toList(), <String>['VI']);
      expect(narrow.extra, isEmpty);
      expect(narrow.hasExtra, isFalse,
          reason: 'không có gì để mở thì đừng hiện nút "Thêm ngôn ngữ"');
    });

    test('engine không hỗ trợ gì ⇒ danh sách rỗng, không crash', () {
      final none = MlKitPackCatalog(supported: (_) => false);
      expect(none.primary, isEmpty);
      expect(none.extra, isEmpty);
      expect(none.all, isEmpty);
      expect(none.hasExtra, isFalse);
    });

    test('so khớp mã KHÔNG phân biệt hoa/thường (mlkit trả bcpCode thường)', () {
      final lower = MlKitPackCatalog(supported: _supports);
      expect(lower.all.map((l) => l.translationCode), contains('JA'));
      // "JA" → "ja" khớp bcpCode thường; "ZH-TW" thì không (ML Kit không có).
      final appCodes = lower.all.map((l) => l.translationCode).toList();
      expect(appCodes.contains('ZH-TW'), isFalse);
    });
  });
}
