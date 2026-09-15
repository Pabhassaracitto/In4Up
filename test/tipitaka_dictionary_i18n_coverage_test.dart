// Quy tắc #5 cho màn Tipiṭaka + Dictionary: locale ngoài `vi` không được thấy
// chrome tiếng Việt.
//
// Lý do file này tồn tại (có hậu cảnh thật): commit `c738b85` trên branch khác đã
// xoá 18 entry tipitaka khỏi `lib/core/language/priority_ui_overrides.dart` — coi
// như dọn catalog — trong khi `lib/features/tipitaka/**` VẪN gọi
// `context.uiText('Thư viện Tipiṭaka')`. Kết quả ở runtime: mọi locale ≠ `vi` hiện
// nguyên tiếng Việt. `test/locale_chrome_no_vietnamese_test.dart` KHÔNG bắt được,
// vì nó chỉ quét catalog ĐÃ SINH (`generatedUiTranslations`), còn ở đây catalog thì
// sạch mà key thì biến mất. Test này quét CHIỀU NGƯỢC: mỗi nhãn trong mã nguồn phải
// còn key trong catalog.
//
// Cùng khuôn với test/pdf_reader/pdf_reader_i18n_coverage_test.dart (giữ riêng vì
// hai feature khác nhau, sửa một bên không làm đỏ bên kia).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';

/// Nhãn có dấu tiếng Việt = nhãn chrome phải dịch. Chuỗi Pāli/Chữ Quốc ngữ không
/// dấu (vd 'Tipiṭaka', 'Namo tassa') không bị bắt — đó là nội dung, không phải chrome.
final RegExp _viDiacritics = RegExp(
  r'[àảãáạăằắẳẵặâầấẩẫậèẻẽéẹêềếểễệìỉĩíịòọỏõóôồốổỗộơờớởỡợùủũúụừứửữựỳỷỹđ]',
  caseSensitive: false,
);

/// `uiText('...')`, `Text('...')` và các tham số chuỗi của widget. Chỉ chuỗi
/// nguyên văn một dòng — đó mới là thứ tra được theo key đúng.
final List<RegExp> _labels = [
  RegExp(r"""(?:uiText\(|\bText\()['']([^'\\\n$]{3,})['']\)"""),
  RegExp(
    r"""(?:tooltip|labelText|helperText|hintText|semanticLabel|message|alt):\s*['']([^'\\\n$]{3,})['']""",
  ),
];

const List<String> _featureDirs = [
  'lib/features/tipitaka',
  'lib/features/dictionary',
];

/// Catalog mà `AppUITranslations.translate()` thực đọc. `reviewed_runtime_*` và
/// `generated_legacy_ui_prefixes` có thể không tồn tại ở một số branch ⇒ bỏ qua
/// im lặng (giống cách test PDF làm).
const List<String> _catalogs = [
  'lib/core/language/generated_ui_translations.dart',
  'lib/core/language/priority_ui_overrides.dart',
  'lib/core/language/reviewed_runtime_ui_labels.dart',
  'lib/core/language/generated_legacy_ui_fallbacks.dart',
  'lib/core/language/generated_legacy_ui_prefixes.dart',
];

/// 15 key đã phải đăng ký lại vì bị xoá khỏi catalog khi code vẫn dùng.
const List<String> _restoredKeys = [
  'Thư viện Tipiṭaka',
  'Đọc Tipiṭaka',
  'sách đang chọn',
  'Chưa tìm thấy sách trong mục này.',
  'Cài đặt hiển thị',
  'Pāli nguyên bản',
  'Thu nhỏ chữ',
  'Phóng to chữ',
  'Về đầu sách',
  'Tải thêm đoạn',
  'Đoạn đã tải',
  'đoạn đã tải',
  'Đã hiển thị toàn bộ nội dung sách.',
  'Đoạn này chưa có nội dung văn bản.',
  'Đoạn tiêu đề chưa có nội dung.',
  'Không thể mở nội dung sách.',
];

List<File> _dartFiles(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return const [];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

void main() {
  test('mọi nhãn Việt ở Tipiṭaka/Dictionary đều còn key trong catalog', () {
    final catalog = StringBuffer();
    for (final path in _catalogs) {
      final file = File(path);
      if (file.existsSync()) catalog.write(file.readAsStringSync());
    }
    final catalogText = catalog.toString();
    expect(catalogText.length, greaterThan(1000),
        reason: 'không đọc được catalog — test cần chạy từ thư mục gốc repo');

    final files = [for (final dir in _featureDirs) ..._dartFiles(dir)];
    expect(files.length, greaterThan(3),
        reason: 'không thấy mã nguồn Tipiṭaka/Dictionary — sai đường dẫn?');

    final missing = <String>[];
    for (final file in files) {
      // Bỏ comment một dòng: nhắc tới `Text('...')` trong comment không phải nhãn.
      final src = file.readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), '');
      for (final pattern in _labels) {
        for (final match in pattern.allMatches(src)) {
          final label = match.group(1)!;
          if (!_viDiacritics.hasMatch(label)) continue;
          final registered = catalogText.contains("'$label':") ||
              catalogText.contains('"$label":');
          if (registered) continue;
          // Còn một đường hợp lệ nữa: template/placeholder resolve được.
          final english = AppUITranslations.translate(label, 'en');
          if (english != label) continue;
          missing.add('${file.path}: $label');
        }
      }
    }

    expect(missing, isEmpty,
        reason: 'Nhãn UI không còn key trong catalog sẽ hiện nguyên tiếng Việt ở '
            'en/hi/zh/si (rule #5). Thêm vào '
            'lib/core/language/priority_ui_overrides.dart (KHÔNG chạy '
            'tool/generate_arbs.py).\n${missing.join('\n')}');
  });

  test('16 biến thể key đã đăng ký lại (15 nhãn) dịch ra tiếng Anh, không còn dấu Việt', () {
    for (final key in _restoredKeys) {
      final en = AppUITranslations.translate(key, 'en');
      expect(en, isNotEmpty, reason: '$key resolve ra rỗng');
      expect(
        _viDiacritics.hasMatch(en),
        isFalse,
        reason: 'locale `en` mà nhận chuỗi có dấu Việt ⇒ rule #5 vi phạm: $key → $en',
      );
    }
  });

  test('nhãn Pāli không bị coi là chrome (không ép dịch)', () {
    // 'Pāli nguyên bản' là chrome ⇒ CÓ key; nhưng 'Pāli' trần là tên ngôn ngữ,
    // không có dấu Việt ⇒ không bị test trên quét. Khóa hành vi này để sau này
    // không ai "sửa" regex cho bắt cả tên ngôn ngữ.
    expect(_viDiacritics.hasMatch('Pāli'), isFalse);
    expect(_viDiacritics.hasMatch('Namo tassa bhagavato arahato'), isFalse);
    expect(_viDiacritics.hasMatch('Pāli nguyên bản'), isTrue);
  });
}
