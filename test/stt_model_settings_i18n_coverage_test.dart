// Quy tắc vàng #5 (AGENTS.md): locale ≠ vi thì chrome UI không được còn
// tiếng Việt. `test/locale_chrome_no_vietnamese_test.dart` chỉ soi catalog ĐÃ
// sinh — nó không thấy một nhãn MỚI thêm vào màn Quản lý Model AI.
//
// SETTINGS-UI-COMPACT-001 + WHISPER-VARIANT-001 + PARAKEET-001 đổi rất nhiều
// chuỗi trong màn này (nhóm gập/mở, sheet "Thông tin & lưu ý", chip ngôn ngữ,
// 2 dòng Whisper đa ngữ/English-only). Test này quét chính mã nguồn: mọi nhãn
// có dấu tiếng Việt phải tra được trong catalog (kèm bản `en`).
//
// Lưu ý: KHÔNG chạy `tool/generate_legacy_ui_fallbacks.py` — generator đang
// kẹt ở các key cũ không còn trong source. Thêm tay vào
// `lib/core/language/priority_ui_overrides.dart` (đúng như tiền lệ PDF Reader).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';

final RegExp _viDiacritics = RegExp(
  r'[àảãáạăằắẳẵặâầấẩẫậèẻẽéẹêềếểễệìỉĩíịòọỏõóôồốổỗộơờớởỡợùủũúụừứửữựỳỷỹđ]',
  caseSensitive: false,
);

/// `uiText('...')` / `Text('...')` + vài tham số nhãn. Chỉ literal một dòng,
/// KHÔNG nội suy (`$`) — chuỗi nội suy phải dùng template `{value0}` trong
/// catalog nên không kiểm tra được bằng so khớp nguyên văn ở đây.
final List<RegExp> _labels = [
  RegExp(r"""(?:uiText\(|\bText\()['']([^'\\\n$]{3,})['']\)"""),
  RegExp(
    r"""(?:tooltip|labelText|helperText|hintText|semanticLabel|message|alt):\s*['']([^'\\\n$]{3,})['']""",
  ),
];

const List<String> _catalogs = [
  'lib/core/language/generated_ui_translations.dart',
  'lib/core/language/priority_ui_overrides.dart',
  'lib/core/language/reviewed_runtime_ui_labels.dart',
  'lib/core/language/generated_legacy_ui_fallbacks.dart',
  'lib/core/language/generated_legacy_ui_prefixes.dart',
];

void main() {
  test('mọi nhãn Việt trong màn Quản lý Model AI đều có key dịch (rule #5)',
      () {
    final catalog = StringBuffer();
    for (final path in _catalogs) {
      final file = File(path);
      if (file.existsSync()) catalog.write(file.readAsStringSync());
    }
    final catalogText = catalog.toString();
    expect(catalogText.length, greaterThan(1000),
        reason: 'không đọc được catalog — test cần chạy từ thư mục gốc repo');

    final files = [
      File('lib/screens/settings/stt_model_settings_screen.dart'),
      File('lib/features/screen_translate/screen_translate_card.dart'),
    ].where((f) => f.existsSync()).toList();
    expect(files, isNotEmpty, reason: 'không tìm thấy file màn cài đặt model');

    final missing = <String>[];
    for (final file in files) {
      // Bỏ comment một dòng: `Text('...')` trong comment không phải nhãn.
      final src =
          file.readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), '');
      for (final pattern in _labels) {
        for (final match in pattern.allMatches(src)) {
          final label = match.group(1)!;
          if (!_viDiacritics.hasMatch(label)) continue;
          final registered = catalogText.contains("'$label':") ||
              catalogText.contains('"$label":');
          if (registered) continue;
          final english = AppUITranslations.translate(label, 'en');
          if (english != label) continue; // resolve được qua cơ chế khác
          missing.add('${file.path}: $label');
        }
      }
    }

    expect(missing, isEmpty,
        reason: 'Nhãn UI chưa đăng ký sẽ hiện nguyên tiếng Việt ở en/hi/zh/si. '
            'Thêm vào lib/core/language/priority_ui_overrides.dart '
            '(KHÔNG chạy tool/generate_legacy_ui_fallbacks.py).\n'
            '${missing.join('\n')}');
  });
}
