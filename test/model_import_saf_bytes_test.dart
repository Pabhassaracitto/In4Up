// IN4-16 (MODELIMPORT-001) — Import model báo "thiếu file" SAI trên
// Android (SAF): picker trả URI content:// — dart:io không đọc được
// `path` đó, nên copy file CŨ thất bại hết → "thiếu" dù file ĐỦ.
//
// Fix: đường import theo BYTES (UI đọc bằng `withData: true`, truyền
// `Map<String, Uint8List>` vào `SherpaModelManager.importAsrNamedBytesResult`
// — cùng logic validate như đường file, chỉ khác nguồn copy).
//
// Test thuần này pin phần QUYẾT ĐỊNH (thuần Dart, không I/O):
// - Scanner nhận đủ bộ Zipformer từ TÊN file (đúng input của đường bytes:
//   tên file user chọn, không có path thư mục) → không báo thiếu.
// - Thiếu đúng 1 file → missingRoles nêu ĐÚNG role (không báo sai).
// - Bộ tên + i18n cho thông báo SAF mới đủ 5 locale (rule #5).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/generated_legacy_ui_fallbacks.dart';
import 'package:in4up/core/language/priority_ui_overrides.dart';
import 'package:in4up_stt/import/model_bundle_scanner.dart';
import 'package:in4up_stt/tts/piper_import_paths.dart';

/// Bộ 4 file Zipformer chuẩn (tên file — đúng thứ owner chọn trên máy).
const List<String> kFullZipformerNames = [
  'encoder.int8.onnx',
  'decoder.onnx',
  'joiner.int8.onnx',
  'tokens.txt',
];

ScannedFile _byName(String name, [int size = 10 * 1024 * 1024]) =>
    ScannedFile(name, sizeBytes: size);

void main() {
  group('IN4-16 — scanner với input kiểu "named bytes" (chỉ tên file)', () {
    test('bộ đủ 4 file → zipformer complete, KHÔNG báo thiếu', () {
      final report = ModelBundleScanner.scan([
        for (final n in kFullZipformerNames) _byName(n),
      ]);
      expect(report.zipformer, isNotNull,
          reason: 'Bộ đủ file phải được nhận diện là Zipformer');
      expect(report.zipformer!.isComplete, isTrue,
          reason: 'Đủ encoder/decoder/joiner/tokens → không role nào thiếu');
      expect(report.zipformer!.missingRoles, isEmpty);
      expect(report.kinds, contains(ModelBundleKind.zipformerAsr));
    });

    test('bộ đủ + bpe.vocab → vẫn complete', () {
      final report = ModelBundleScanner.scan([
        for (final n in kFullZipformerNames) _byName(n),
        _byName('bpe.vocab'),
      ]);
      expect(report.zipformer, isNotNull);
      expect(report.zipformer!.isComplete, isTrue);
    });

    test('bỏ 1 file → missingRoles nêu ĐÚNG role (không báo sai)', () {
      // Bỏ joiner — 2 file int8 còn lại vẫn phải nhận diện đúng role.
      final without = kFullZipformerNames.where((n) => !n.contains('joiner'));
      final report = ModelBundleScanner.scan([for (final n in without) _byName(n)]);
      expect(report.zipformer, isNotNull);
      expect(report.zipformer!.isComplete, isFalse);
      expect(
        report.zipformer!.missingRoles,
        ['joiner (joiner*.onnx)'],
        reason: 'Chỉ joiner thực sự thiếu — không được liệt encoder/decoder/tokens',
      );

      // Bỏ tokens.txt
      final noTok = kFullZipformerNames.where((n) => n != 'tokens.txt');
      final r2 = ModelBundleScanner.scan([for (final n in noTok) _byName(n)]);
      expect(r2.zipformer, isNotNull);
      expect(r2.zipformer!.missingRoles, ['tokens (tokens.txt)']);
    });

    test('tên file int8 + non-int8 cùng lúc → chọn int8 (profile app)', () {
      final report = ModelBundleScanner.scan([
        _byName('encoder.onnx'),
        _byName('encoder.int8.onnx'),
        _byName('decoder.onnx'),
        _byName('joiner.int8.onnx'),
        _byName('tokens.txt'),
      ]);
      expect(report.zipformer, isNotNull);
      expect(report.zipformer!.encoder?.name, 'encoder.int8.onnx');
      expect(report.zipformer!.isComplete, isTrue);
    });

    test('bộ Piper LẪN vào (onnx giọng) không làm sai role Zipformer', () {
      final report = ModelBundleScanner.scan([
        for (final n in kFullZipformerNames) _byName(n),
        _byName('vi_VN-hcm-medium.onnx'),
        _byName('vi_VN-hcm-medium_tokens.txt'),
      ]);
      expect(report.zipformer, isNotNull);
      expect(report.zipformer!.isComplete, isTrue);
      expect(report.piperVoices, hasLength(1),
          reason: 'Giọng Piper phải được tách riêng, không lẫn vào bộ ASR');
      expect(report.piperVoices.first.stem, 'vi_VN-hcm-medium');
    });
  });

  group('IN4-16 — bộ lọc tên TTS (đường folder không báo thiếu sai tên)', () {
    test('isOnnxModelName: nhận .onnx giọng Piper mọi ngôn ngữ', () {
      expect(PiperImportPaths.isOnnxModelName('vi_VN-hcm-medium.onnx'), isTrue);
      expect(PiperImportPaths.isOnnxModelName('en_US-libritts_r-medium.onnx'),
          isTrue);
      expect(PiperImportPaths.isOnnxModelName('my_MM-tat-a-medium.onnx'), isTrue);
    });

    test('isOnnxModelName: KHÔNG nhận .onnx.json (đó là config)', () {
      expect(PiperImportPaths.isOnnxModelName('vi_VN-hcm-medium.onnx.json'),
          isFalse);
    });
  });

  group('IN4-16 — i18n thông báo SAF (rule #5: 5 locale đủ)', () {
    const newStrings = [
      'Không đọc được file (SAF). Vui lòng chọn lại các file model.',
      'Không đọc trực tiếp thư mục trên thiết bị này (SAF/thẻ nhớ). '
          'Hãy chọn các file trong thư mục: encoder/decoder/joiner (.onnx) + tokens.txt.',
    ];
    const locales = ['en', 'hi', 'zh', 'zh_TW', 'si'];

    for (final s in newStrings) {
      test('priorityUiOverrides["$s…"] đủ 5 locale', () {
        final entry = priorityUiOverrides[s];
        expect(entry, isNotNull, reason: 'Thiếu entry "$s"');
        for (final loc in locales) {
          final v = entry![loc];
          expect(v, isNotNull, reason: 'Thiếu locale $loc cho "$s"');
          expect(v!.trim(), isNotEmpty);
        }
      });
      test('legacy fallback en["$s…"]', () {
        expect(generatedLegacyUiEnglishFallbacks[s], isNotNull,
            reason: 'Thiếu English fallback "$s"');
      });
    }
  });
}
