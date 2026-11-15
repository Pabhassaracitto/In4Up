// test/media_tools/whisper_runtime_card_i18n_test.dart
//
// Quy tắc vàng #5 (AGENTS.md): locale ≠ vi thì chrome UI KHÔNG được còn tiếng
// Việt. `test/locale_chrome_no_vietnamese_test.dart` chỉ soi catalog ĐÃ sinh và
// vài màn cố định — nó không thấy nhãn mới thêm vào thẻ "Bộ chạy Whisper".
//
// Test này quét chính mã nguồn của thẻ + câu báo lỗi của bộ chạy, rồi tra
// `AppUITranslations` đúng như runtime sẽ tra: nhãn nào còn trả về nguyên tiếng
// Việt ở `en` là nhãn chưa đăng ký.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';

/// Ký tự chỉ có ở tiếng Việt.
final RegExp _viDiacritics = RegExp(
  r'[àảãáạăằắẳẵặâầấẩẫậèẻẽéẹêềếểễệìỉĩíịòọỏõóôồốổỗộơờớởỡợùủũúụừứửữựỳỷỹđ]',
  caseSensitive: false,
);

/// `uiText('...')`. CHỈ literal một dòng, không nội suy.
///
/// Cố ý KHÔNG quét `Text('...')`: shim `Text` dùng `translateExact`
/// (`allowTemplates: false`), còn `uiText` mới là đường dịch đầy đủ — nhãn nội
/// suy như `'Thiếu: ${...}'` phải đi qua `uiText` thì mới có bản dịch.
final List<RegExp> _labels = <RegExp>[
  RegExp(r"""uiText\(\s*'((?:[^'\\\n$]|\\.){3,}?)'\s*[,)]"""),
];

const List<String> _sources = <String>[
  'lib/screens/settings/whisper_runtime_card.dart',
];

void main() {
  test('mọi nhãn Việt trong thẻ Bộ chạy Whisper đều dịch được sang English',
      () {
    final missing = <String>[];
    var scanned = 0;

    for (final path in _sources) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'thiếu $path');
      // Bỏ comment để `Text('...')` trong ghi chú không bị coi là nhãn.
      final src = file.readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), '');
      for (final pattern in _labels) {
        for (final match in pattern.allMatches(src)) {
          final label = match.group(1)!;
          if (!_viDiacritics.hasMatch(label)) continue;
          scanned++;
          if (AppUITranslations.translate(label, 'en') == label) {
            missing.add('$path: $label');
          }
        }
      }
    }

    // Chống test "xanh giả": phải thật sự quét được nhãn.
    expect(scanned, greaterThan(5), reason: 'không quét được nhãn nào');
    expect(
      missing,
      isEmpty,
      reason: 'Nhãn UI chưa đăng ký sẽ hiện nguyên tiếng Việt ở en/hi/zh/si.\n'
          'Thêm vào tool/priority_native_pack.json (8 locale) rồi chạy:\n'
          '  python3 tool/generate_priority_native_pack.py\n'
          '${missing.join('\n')}',
    );
  });

  test('thẻ có bản dịch cho 7 locale ưu tiên (không rơi về tiếng Việt)', () {
    const probes = <String>[
      'Bộ chạy Whisper (whisper-cli.exe)',
      'Kiểm tra lại',
      'Cài bộ chạy Whisper',
      'Cách khác',
    ];
    for (final locale in <String>['en', 'zh', 'zh_TW', 'hi', 'si', 'my', 'th', 'ja']) {
      for (final probe in probes) {
        final value = AppUITranslations.translate(probe, locale);
        expect(value, isNot(probe), reason: '"$probe" chưa dịch cho $locale');
        expect(
          _viDiacritics.hasMatch(value),
          isFalse,
          reason: '"$probe" [$locale] còn tiếng Việt: "$value"',
        );
      }
    }
  });
}
