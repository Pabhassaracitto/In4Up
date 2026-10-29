// Quy tắc vàng #5 (AGENTS.md) áp cho feature OCR — ADR-0009 · KANBAN OCR-001.
//
// test/locale_chrome_no_vietnamese_test.dart chỉ quét catalog ĐÃ sinh ra; nó
// không phát hiện một nhãn OCR MỚI chưa kịp đăng ký. Test này quét chính mã
// nguồn `lib/features/ocr`: mọi nhãn UI chứa dấu tiếng Việt phải phân giải
// được sang English (tức đã có key trong catalog), nếu không là bug — nhãn đó
// sẽ hiện nguyên tiếng Việt ở en/hi/zh/zh_TW/si.
//
// Cùng cơ chế với test/pdf_reader/pdf_reader_i18n_coverage_test.dart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';

final RegExp _viDiacritics = RegExp(
  r'[àảãáạăằắẳẵặâầấẩẫậèẻẽéẹêềếểễệìỉĩíịòọỏõóôồốổỗộơờớởỡợùủũúụừứửữựỳỷỹđ]',
  caseSensitive: false,
);

/// Chuỗi nguyên văn một dòng (không nội suy `$`) — chỉ thứ đó mới tra được
/// trong catalog theo key đúng. Quét MỌI literal, không chỉ `Text(...)`:
/// nhãn OCR đi qua helper `_tr(...)` nên bắt theo `Text(` sẽ sót.
final RegExp _stringLiteral = RegExp(r"""['"]([^'"\\\n$]{3,})['"]""");

/// Tầng service/adapter — KHÔNG phải chrome UI, được miễn (cùng tiền lệ với
/// `lib/features/translation/engines/mlkit_engine.dart`: chuỗi lỗi kỹ thuật
/// của engine không nằm trong catalog). Lý do phải ghi rõ để agent sau không
/// tưởng nhầm là bỏ sót.
const Map<String, String> _exemptFiles = {
  'ocr_service.dart':
      'Tầng service: chuỗi lỗi kỹ thuật trả về cho caller, cùng tiền lệ '
          'mlkit_engine.dart (không phải chrome UI)',
  'ocr_image_picker.dart':
      'Adapter file_picker: chỉ có log debugPrint, không render UI',
};

/// 14 key ARB của OCR (ADR-0009). Liệt kê cứng để test này FAIL khi ai đó
/// xoá key mà quên sửa UI — thay vì âm thầm rơi về tiếng Việt.
const List<String> _ocrArbKeys = [
  'ocrScanImage',
  'ocrSheetTitle',
  'ocrSourceScanner',
  'ocrSourceScannerHint',
  'ocrSourceGallery',
  'ocrSourceGalleryHint',
  'ocrResultTitle',
  'ocrResultHint',
  'ocrRecognizing',
  'ocrEmptyResult',
  'ocrLoadedFromImage',
  'ocrScanPageText',
  'ocrReopenImage',
  'ocrUnsupported',
];

void main() {
  test('mọi nhãn Việt trong lib/features/ocr đều dịch được sang en (rule #5)', () {
    final dir = Directory('lib/features/ocr');
    expect(dir.existsSync(), isTrue,
        reason: 'Chạy test từ thư mục gốc repo; thiếu lib/features/ocr');

    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty);

    final missing = <String>[];
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      if (_exemptFiles.containsKey(name)) continue;

      // Bỏ comment: tiếng Việt trong comment không phải nhãn UI.
      final src = file
          .readAsStringSync()
          .replaceAll(RegExp(r'//[^\n]*'), '')
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

      for (final match in _stringLiteral.allMatches(src)) {
        final label = match.group(1)!;
        if (!_viDiacritics.hasMatch(label)) continue;
        final english = AppUITranslations.translate(label, 'en');
        if (english == label) {
          missing.add('${file.path}: $label');
        }
      }
    }

    expect(missing, isEmpty,
        reason: 'Nhãn UI chưa đăng ký sẽ hiện nguyên tiếng Việt ở en/hi/zh/si. '
            'Thêm vào ARB (en + 4 locale T2 hi/zh/zh_TW/si + đủ 26 locale để '
            'không tụt sàn ratchet ADR-0002) rồi chạy '
            '`python3 tool/generate_ui_translation_map.py`. '
            'KHÔNG chạy generate_arbs.py (đã vô hiệu).\n${missing.join('\n')}');
  });

  test('14 key ARB của OCR có mặt ở CẢ 26 locale (ADR-0002 + sàn ratchet)', () {
    final arbDir = Directory('lib/l10n');
    expect(arbDir.existsSync(), isTrue);

    final arbFiles = arbDir
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.uri.pathSegments.last.startsWith('app_') &&
            f.uri.pathSegments.last.endsWith('.arb'))
        .toList();
    // en + vi + 24 locale rollout = 26. Nếu con số này đổi, lộ trình ngôn ngữ
    // đã đổi → phải review lại ADR-0002 chứ không sửa test cho qua.
    expect(arbFiles.length, 26, reason: 'Số locale ARB khác 26 — kiểm tra ADR-0002');

    final violations = <String>[];
    for (final file in arbFiles) {
      final locale = file.uri.pathSegments.last;
      final text = file.readAsStringSync();
      for (final key in _ocrArbKeys) {
        if (!text.contains('"$key":')) {
          violations.add('$locale thiếu $key');
        }
      }
    }

    expect(violations, isEmpty,
        reason: 'Thiếu key ARB ở locale nào thì locale đó rơi về English — '
            'riêng T2 (hi/zh/zh_TW/si) là VI PHẠM ADR-0002 (bắt buộc 100%).\n'
            '${violations.join('\n')}');
  });

  test('giá trị vi của key OCR phân giải được sang en/hi/zh/si (không kẹt tiếng Việt)',
      () {
    final vi = File('lib/l10n/app_vi.arb');
    final en = File('lib/l10n/app_en.arb');
    expect(vi.existsSync() && en.existsSync(), isTrue);

    String valueOf(String content, String key) {
      final match = RegExp('"$key":\\s*"((?:[^"\\\\]|\\\\.)*)"').firstMatch(content);
      expect(match, isNotNull, reason: 'Không tìm thấy key $key trong ARB');
      return match!.group(1)!;
    }

    final viText = vi.readAsStringSync();
    final enText = en.readAsStringSync();

    for (final key in _ocrArbKeys) {
      final source = valueOf(viText, key);
      final expected = valueOf(enText, key);
      for (final locale in ['en', 'hi', 'zh', 'zh_TW', 'si']) {
        final translated = AppUITranslations.translate(source, locale);
        expect(translated, isNot(source),
            reason: '$key: locale $locale vẫn ra tiếng Việt '
                '(catalog chưa có — chạy generate_ui_translation_map.py)');
        if (locale == 'en') {
          expect(translated, expected, reason: '$key: en lệch giá trị ARB');
        }
      }
    }
  });
}
