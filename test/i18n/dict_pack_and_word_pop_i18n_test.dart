// Quy tắc vàng #5 (AGENTS.md): locale ≠ vi thì chrome UI không được còn tiếng
// Việt.
//
// `test/locale_chrome_no_vietnamese_test.dart` chỉ soi catalog ĐÃ sinh — nó
// không thấy nhãn MỚI thêm vào hai màn của đợt 2026-10-25:
//   • "Tải bộ từ điển" (DICT-PACK-001),
//   • pop tra từ nhanh ở tab Đọc (READ-POP-003) + kiểu hiển thị từ
//     (READ-WORDSTYLE-001).
//
// Test này quét CHÍNH MÃ NGUỒN: mọi literal có dấu tiếng Việt đi qua
// `uiText(...)`/`Text(...)`, hoặc là nhãn/mô tả của `WordColorStyle`, phải tra
// được trong catalog (có bản `en`).
//
// Lưu ý: KHÔNG chạy `tool/generate_legacy_ui_fallbacks.py` — generator đang kẹt
// ở các key cũ không còn trong source (xem
// `test/stt_model_settings_i18n_coverage_test.dart`). Thêm tay vào
// `lib/core/language/priority_ui_overrides.dart`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _viDiacritics = RegExp(
  r'[àảãáạăằắẳẵặâầấẩẫậèẻẽéẹêềếểễệìỉĩíịòọỏõóôồốổỗộơờớởỡợùủũúụừứửữựỳỷỹđ]',
  caseSensitive: false,
);

/// Literal một dòng (không nội suy `$`) — chuỗi nội suy phải là template
/// `{value0}` trong catalog nên không so khớp nguyên văn ở đây được.
final List<RegExp> _labels = <RegExp>[
  RegExp(r"""uiText\(\s*'([^'\\\n$]{3,})'"""),
  RegExp(r'''uiText\(\s*"([^"\\\n$]{3,})"'''),
  RegExp(r"""\bText\(\s*'([^'\\\n$]{3,})'"""),
  RegExp(
    r"""\b(?:tooltip|labelText|helperText|hintText|semanticLabel|label|description):\s*'([^'\\\n$]{3,})'""",
  ),
];

const List<String> _catalogs = <String>[
  'lib/core/language/generated_ui_translations.dart',
  'lib/core/language/priority_ui_overrides.dart',
  'lib/core/language/reviewed_runtime_ui_labels.dart',
  'lib/core/language/generated_legacy_ui_fallbacks.dart',
  'lib/core/language/generated_legacy_ui_prefixes.dart',
  'lib/core/language/generated_priority_native_pack.dart',
];

const List<String> _sources = <String>[
  'lib/features/dictionary/widgets/dict_pack_screen.dart',
  'lib/features/dictionary/widgets/dict_definition_view.dart',
  'lib/screens/read_mode/widgets/word_mini_pop.dart',
  'lib/models/word_color_style.dart',
];

void main() {
  test('nhãn Việt ở màn "Tải bộ từ điển" + pop tra từ đều có bản dịch (rule #5)',
      () {
    final catalog = StringBuffer();
    for (final path in _catalogs) {
      final file = File(path);
      if (file.existsSync()) catalog.write(file.readAsStringSync());
    }
    final catalogText = catalog.toString();
    expect(
      catalogText.length,
      greaterThan(1000),
      reason: 'không đọc được catalog — test phải chạy từ thư mục gốc repo',
    );

    final files = _sources.map(File.new).where((f) => f.existsSync()).toList();
    expect(files, isNotEmpty, reason: 'không tìm thấy file nguồn cần quét');

    final missing = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        for (final pattern in _labels) {
          for (final match in pattern.allMatches(line)) {
            final label = match.group(1)!;
            if (!_viDiacritics.hasMatch(label)) continue;
            if (catalogText.contains("'$label'") ||
                catalogText.contains('"$label"')) {
              continue;
            }
            missing.add('${file.path}:${i + 1} → "$label"');
          }
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'Nhãn mới chưa có key dịch ⇒ locale ≠ vi sẽ hiện tiếng Việt.\n'
          'Thêm tay vào lib/core/language/priority_ui_overrides.dart:\n'
          '${missing.take(20).join('\n')}',
    );
  });
}
