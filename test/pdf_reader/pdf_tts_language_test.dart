// test/pdf_reader/pdf_tts_language_test.dart
//
// AUDIT v1.30.1 (mục 1) — hồi quy cho «bảng cài đặt đọc chỉ có English và
// Tiếng Việt». Test khoá lại 3 điều:
//   1. Mã ngôn ngữ lạ KHÔNG còn bị nuốt khi khôi phục từ SharedPreferences.
//   2. Danh sách ngôn ngữ đọc phủ hết catalog (>= 20 ngôn ngữ, có Nhật/Hàn/
//      Trung/Pháp/Đức/Tây Ban Nha…), không chỉ 2.
//   3. `vi-VN`/`en-US` ở dạng viết hoa hoặc gạch dưới vẫn chuẩn hoá về đúng
//      `ttsLocale` (dữ liệu người dùng đã cài sẵn phải đọc được).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_language.dart';
import 'package:in4up/features/pdf_reader/services/pdf_tts_language.dart';

void main() {
  group('normalizePdfTtsLanguage', () {
    test('auto và rỗng đều về auto', () {
      expect(normalizePdfTtsLanguage(null), kPdfTtsAutoCode);
      expect(normalizePdfTtsLanguage(''), kPdfTtsAutoCode);
      expect(normalizePdfTtsLanguage('  '), kPdfTtsAutoCode);
      expect(normalizePdfTtsLanguage('auto'), kPdfTtsAutoCode);
      expect(normalizePdfTtsLanguage('AUTO'), kPdfTtsAutoCode);
    });

    test('hai ngôn ngữ cũ vẫn giữ nguyên (không phá dữ liệu đã lưu)', () {
      expect(normalizePdfTtsLanguage('en-US'), 'en-US');
      expect(normalizePdfTtsLanguage('vi-VN'), 'vi-VN');
      expect(normalizePdfTtsLanguage('vi_VN'), 'vi-VN');
      expect(normalizePdfTtsLanguage('EN-us'), 'en-US');
    });

    test('ngôn ngữ NGOÀI hai ngôn ngữ cũ không còn bị nuốt (lỗi audit)', () {
      expect(normalizePdfTtsLanguage('ja-JP'), 'ja-JP');
      expect(normalizePdfTtsLanguage('ja'), 'ja-JP');
      expect(normalizePdfTtsLanguage('ko-KR'), 'ko-KR');
      expect(normalizePdfTtsLanguage('zh-CN'), 'zh-CN');
      expect(normalizePdfTtsLanguage('fr-FR'), 'fr-FR');
      expect(normalizePdfTtsLanguage('de-DE'), 'de-DE');
    });

    test('mã rác rơi về auto thay vì ghim sai ngôn ngữ', () {
      expect(normalizePdfTtsLanguage('xx-YY'), kPdfTtsAutoCode);
      expect(normalizePdfTtsLanguage('lorem'), kPdfTtsAutoCode);
    });
  });

  group('pdfTtsLanguageOptions', () {
    test('có nhiều hơn 2 ngôn ngữ và chứa các ngôn ngữ người Việt học nhiều', () {
      final options = pdfTtsLanguageOptions();
      expect(options.length, greaterThanOrEqualTo(20));
      final locales = options.map((e) => e.ttsLocale).toSet();
      expect(locales, contains('en-US'));
      expect(locales, contains('vi-VN'));
      expect(locales, contains('ja-JP'));
      expect(locales, contains('ko-KR'));
      expect(locales, contains('zh-CN'));
      expect(locales, contains('fr-FR'));
    });

    test('đủ 26 ngôn ngữ của catalog, không trùng', () {
      final options = pdfTtsLanguageOptions();
      final locales = options.map((e) => e.ttsLocale).toList();
      expect(locales.length, AppLanguageCatalog.languages.length);
      expect(locales.toSet().length, locales.length);
    });

    test('tiếng Anh đứng đầu; 5 ngôn ngữ học nhiều nhất ở nhóm đầu', () {
      final options = pdfTtsLanguageOptions();
      expect(options.first.ttsLocale, 'en-US');
      expect(
        options.take(5).map((e) => e.ttsLocale).toList(),
        ['en-US', 'zh-CN', 'ja-JP', 'ko-KR', 'vi-VN'],
      );
    });

    test('mọi mã ưu tiên đều có trong catalog (không có mã lạ)', () {
      final locales = pdfTtsLanguageOptions().map((e) => e.ttsLocale).toSet();
      expect(locales.length, AppLanguageCatalog.languages.length);
      // Không trùng ⇒ danh sách ưu tiên phủ đúng toàn bộ catalog.
      final catalogLocales =
          AppLanguageCatalog.languages.map((e) => e.ttsLocale).toSet();
      expect(locales, catalogLocales);
    });

    test('không chứa auto (chip «Tự động» do nơi gọi tự thêm)', () {
      for (final option in pdfTtsLanguageOptions()) {
        expect(option.ttsLocale, isNot(kPdfTtsAutoCode));
      }
    });
  });

  group('pdfTtsLanguageLabel', () {
    test('auto không có nhãn (để nơi gọi dịch)', () {
      expect(pdfTtsLanguageLabel('auto'), isNull);
      expect(pdfTtsLanguageLabel(null), isNull);
    });

    test('nhãn = cờ + tên bản ngữ', () {
      expect(pdfTtsLanguageLabel('vi-VN'), '🇻🇳 Tiếng Việt');
      final japanese = AppLanguageCatalog.maybeFromCode('ja-JP');
      expect(japanese, isNotNull);
      expect(
        pdfTtsLanguageLabel('ja-JP'),
        '${japanese!.flag} ${japanese.nativeName}',
      );
    });
  });

  test('mọi ngôn ngữ trong catalog đều chuẩn hoá được (idempotent)', () {
    for (final language in AppLanguageCatalog.languages) {
      final normalized = normalizePdfTtsLanguage(language.ttsLocale);
      expect(normalized, language.ttsLocale,
          reason: 'ttsLocale ${language.ttsLocale} phải tự chuẩn hoá về chính nó');
      expect(normalizePdfTtsLanguage(normalized), normalized);
    }
  });

  test('AppLanguage.pickerLabel không rỗng cho mọi ngôn ngữ đọc', () {
    for (final language in pdfTtsLanguageOptions()) {
      expect(language.pickerLabel.trim(), isNotEmpty);
    }
  });
}
