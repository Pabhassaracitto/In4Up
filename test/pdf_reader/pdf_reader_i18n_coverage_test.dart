// Quy tắc #5: locale ngoài `vi` không được thấy chữ Việt "chrome".
// test/locale_chrome_no_vietnamese_test.dart chỉ quét catalog ĐÃ sinh ra; nó
// không phát hiện được một nhãn MỚI trong PDF Reader chưa kịp đăng ký. Test này
// quét chính mã nguồn feature: mọi nhãn UI chứa dấu tiếng Việt phải có key
// trong catalog (kèm bản `en`), nếu không là bug.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';

final RegExp _viDiacritics = RegExp(
  r'[àảãáạăằắẳẵặâầấẩẫậèẻẽéẹêềếểễệìỉĩíịòọỏõóôồốổỗộơờớởỡợùủũúụừứửữựỳỷỹđ]',
  caseSensitive: false,
);

/// Các chỗ một nhãn Việt đi thẳng vào UI: `uiText('...')`, `Text('...')` và mấy
/// tham số chuỗi của widget (`tooltip:`/`message:`/`labelText:`/…). Chỉ chuỗi
/// nguyên văn một dòng, không nội suy — vì đó mới là thứ tra được trong catalog
/// theo key đúng.
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
  test('mọi nhãn Việt trong PDF Reader đều có key dịch (rule #5)', () {
    final catalog = StringBuffer();
    for (final path in _catalogs) {
      final file = File(path);
      if (file.existsSync()) catalog.write(file.readAsStringSync());
    }
    final catalogText = catalog.toString();
    expect(catalogText.length, greaterThan(1000),
        reason: 'không đọc được catalog — test cần chạy từ thư mục gốc repo');

    final files = Directory('lib/features/pdf_reader')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty);

    final missing = <String>[];
    for (final file in files) {
      // Bỏ comment một dòng: nhắc tới `Text('...')` trong comment không phải nhãn.
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
            'Thêm vào lib/core/language/priority_ui_overrides.dart (KHÔNG chạy '
            'tool/generate_arbs.py).\n${missing.join('\n')}');
  });
}
