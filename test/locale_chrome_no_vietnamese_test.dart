// AGENTS.md — Quy tắc vàng #5 (máy bắt):
//   Locale ≠ tiếng Việt → chrome UI không được còn tiếng Việt.
//   Thiếu bản dịch ngôn ngữ đó thì hiện English. Không bao giờ fallback về vi.
//
// Test này là "máy bắt" cho catalog đã review:
//   1. Mọi giá trị dịch trong generatedUiTranslations (mọi locale ≠ vi)
//      không chứa ký tự tiếng Việt (bộ ký tự không trùng với Romance
//      fr/es/pt/it — tránh false positive trên é/è/á/ó...).
//   2. Mọi entry phải có giá trị 'en' (canonical fallback — thứ tự
//      "locale có sẵn → en", không đoán).
//   3. English fallbacks legacy + legacy_ui_english_overrides.json
//      không chứa ký tự tiếng Việt.
//
// KHÔNG áp dụng cho: nội dung user, từ vựng/nghĩa user nhập, output AI,
// transcript STT, tiêu đề chương auto-TOC (những thứ đó không nằm trong
// catalog chrome này).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/generated_legacy_ui_fallbacks.dart';
import 'package:in4up/core/language/generated_ui_translations.dart';

/// Ký tự tiếng Việt KHÔNG trùng với chữ cái có dấu của Romance languages
/// (fr/es/pt/it). Ví dụ: `é`/`è`/`á`/`ó`/`ù` là fr/es — không flag;
/// `ế`/`ị`/`ờ`/`đ`/`ơ`/`ư` là Việt — flag.
final RegExp _vietnameseOnly = RegExp(
  // đ, ơ, ư — duy nhất tiếng Việt
  r'[đĐơƠưƯ]'
  // a + thanh (loại à á ã — fr/es/pt)
  r'|[ảạằắẳẵặầấẩẫậ]'
  // e + thanh (loại è é — fr)
  r'|[ẻẽẹềếểễệ]'
  // i + thanh (loại ì — it)
  r'|[ỉĩị]'
  // o + thanh (loại ó ò — es/fr)
  r'|[ỏọồốổỗộờớởỡợ]'
  // u + thanh (loại ù — fr)
  r'|[ủũụừứửữự]'
  // y + thanh (loại ý — es/pt)
  r'|[ỳỷỹỵ]',
);

void main() {
  group('Rule 5 — chrome UI không tiếng Việt khi locale ≠ vi', () {
    test('generatedUiTranslations: mọi locale ≠ vi không có ký tự Việt', () {
      final violations = <String>[];
      for (final entry in generatedUiTranslations.entries) {
        for (final localeValue in entry.value.entries) {
          if (localeValue.key == 'vi') continue;
          final match = _vietnameseOnly.firstMatch(localeValue.value);
          if (match != null) {
            violations.add(
              "'${entry.key}' [${localeValue.key}] → "
              "'${localeValue.value}' (ký tự: '${match.group(0)}')",
            );
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Catalog chrome còn tiếng Việt ở locale ≠ vi '
            '(rule #5: phải hiện English, không fallback vi):\n'
            '${violations.take(10).join('\n')}',
      );
    });

    test('generatedUiTranslations: mọi entry có giá trị en (canonical fallback)',
        () {
      final missing = generatedUiTranslations.entries
          .where((e) => !e.value.containsKey('en') ||
              e.value['en']!.trim().isEmpty)
          .map((e) => e.key)
          .toList();
      expect(
        missing,
        isEmpty,
        reason: 'Entry thiếu bản dịch en (rule #5: thứ tự locale → en, '
            'không đoán):\n${missing.take(10).join('\n')}',
      );
    });

    test('generatedLegacyUiEnglishFallbacks: English không có ký tự Việt', () {
      final violations = <String>[];
      for (final entry in generatedLegacyUiEnglishFallbacks.entries) {
        final match = _vietnameseOnly.firstMatch(entry.value);
        if (match != null) {
          violations.add(
            "'${entry.key}' → '${entry.value}' (ký tự: '${match.group(0)}')",
          );
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'English fallbacks còn tiếng Việt:\n'
            '${violations.take(10).join('\n')}',
      );
    });

    test('legacy_ui_english_overrides.json: English không có ký tự Việt', () {
      final file = File('tool/legacy_ui_english_overrides.json');
      expect(file.existsSync(), isTrue,
          reason: 'Thiếu file overrides — pipeline rule #5 bị hỏng');
      final overrides =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final violations = <String>[];
      overrides.forEach((key, value) {
        if (value is! String) return;
        final match = _vietnameseOnly.firstMatch(value);
        if (match != null) {
          violations.add(
            "'$key' → '$value' (ký tự: '${match.group(0)}')",
          );
        }
      });
      expect(
        violations,
        isEmpty,
        reason: 'Overrides English còn tiếng Việt:\n'
            '${violations.take(10).join('\n')}',
      );
    });
  });
}
