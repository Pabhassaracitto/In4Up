// M4U-IMPORT-002 — Import model STT: báo "thiếu file" SAI dù user đã chọn
// đủ file (multi-select) + thư mục SAF không đọc được.
//
// Ba lỗi đã tái hiện trên máy thật (logcat 2026-11):
// 1. Chọn N file (Parakeet/Zipformer) → app báo "thiếu encoder/joiner/tokens"
//    dù file ĐỦ. Nguyên nhân: scanner GROUP THEO THƯ MỤC CHA, còn file_picker
//    trên Android copy file đã chọn vào cache (`cache/file_picker/<ts>/…`)
//    với các file ở thư mục KHÁC NHAU ⇒ mỗi file là 1 nhóm riêng ⇒ chỉ 1
//    role được giữ lại ⇒ báo thiếu oan.
// 2. Import THƯ MỤC trên Android → "Thư mục rỗng" (SAF `content://` không
//    đọc được bằng dart:io).
// 3. Bộ export NVIDIA NeMo (decoder_joint + nemo128 + vocab.txt) KHÔNG phải
//    layout sherpa-onnx ⇒ phải báo đúng, không báo "thiếu joiner".
//
// Test thuần (không I/O, không thiết bị) — chạy được trên CI.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/core/language/generated_legacy_ui_fallbacks.dart';
import 'package:in4up/core/language/priority_ui_overrides.dart';
import 'package:in4up_stt/import/model_bundle_scanner.dart';

ScannedFile _f(String path, [int size = 10 * 1024 * 1024]) =>
    ScannedFile(path, sizeBytes: size);

/// Bộ 4 file Zipformer chuẩn nằm ở 4 thư mục KHÁC NHAU — đúng tình huống
/// file_picker Android tạo ra khi user multi-select.
List<ScannedFile> _zipformerSplitDirs() => [
      _f('/cache/file_picker/1700000000001/decoder.onnx', 5 * 1024 * 1024),
      _f('/cache/file_picker/1700000000002/encoder.int8.onnx', 27 * 1024 * 1024),
      _f('/cache/file_picker/1700000000003/joiner.int8.onnx'),
      _f('/cache/file_picker/1700000000004/tokens.txt', 23 * 1024),
    ];

/// Bộ Parakeet export NVIDIA NeMo (đúng file user đã chọn trên máy).
List<ScannedFile> _nemoParakeet() => [
      _f('/cache/file_picker/1700000000001/decoder_joint-model.int8.onnx',
          18 * 1024 * 1024),
      _f('/cache/file_picker/1700000000002/encoder-model.int8.onnx',
          652 * 1024 * 1024),
      _f('/cache/file_picker/1700000000003/nemo128.onnx', 139 * 1024),
      _f('/cache/file_picker/1700000000004/vocab.txt', 93 * 1024),
    ];

/// Bộ Parakeet layout sherpa-onnx (bộ app tải về từ k2-fsa).
List<ScannedFile> _sherpaParakeet() => [
      _f('parakeet/decoder.int8.onnx', 11 * 1024 * 1024),
      _f('parakeet/encoder.int8.onnx', 652 * 1024 * 1024),
      _f('parakeet/joiner.int8.onnx', 6 * 1024 * 1024),
      _f('parakeet/tokens.txt', 93 * 1024),
    ];

void main() {
  group('M4U-IMPORT-002 — multi-select KHÔNG group theo thư mục cha', () {
    test('bộ đủ 4 file nằm ở 4 thư mục khác nhau → KHÔNG báo thiếu', () {
      final report = ModelBundleScanner.scan(
        _zipformerSplitDirs(),
        groupByDirectory: false,
      );
      expect(report.zipformer, isNotNull);
      expect(report.zipformer!.isComplete, isTrue,
          reason: 'user đã chọn đủ 4 file ⇒ không được báo "thiếu"');
      expect(report.zipformer!.missingRoles, isEmpty);
      expect(report.zipformer!.encoder?.name, 'encoder.int8.onnx');
      expect(report.zipformer!.decoder?.name, 'decoder.onnx');
      expect(report.zipformer!.joiner?.name, 'joiner.int8.onnx');
      expect(report.zipformer!.tokens?.name, 'tokens.txt');
    });

    test('cùng bộ đó, group theo thư mục → chỉ giữ 1 role (nguyên nhân lỗi)',
        () {
      // Pin lại hành vi CŨ để thấy rõ: group theo thư mục ⇒ mỗi file 1 nhóm ⇒
      // chỉ 1 role ⇒ báo thiếu oan. Đường multi-select KHÔNG được dùng cách
      // này nữa.
      final report = ModelBundleScanner.scan(_zipformerSplitDirs());
      expect(report.zipformer!.isComplete, isFalse);
      expect(report.zipformer!.missingRoles.length, greaterThanOrEqualTo(2));
    });

    test('Parakeet layout sherpa-onnx (bộ app tải về) → đủ bộ', () {
      final report = ModelBundleScanner.scan(
        _sherpaParakeet(),
        groupByDirectory: false,
      );
      expect(report.zipformer!.isComplete, isTrue);
      expect(report.zipformer!.missingRoles, isEmpty);
      expect(report.zipformer!.isNeMoExport, isFalse);
    });
  });

  group('M4U-IMPORT-002 — bộ export NVIDIA NeMo được nhận diện riêng', () {
    test('decoder_joint + nemo128 + vocab.txt → isNeMoExport = true', () {
      final report = ModelBundleScanner.scan(
        _nemoParakeet(),
        groupByDirectory: false,
      );
      expect(report.zipformer, isNotNull);
      expect(report.zipformer!.isNeMoExport, isTrue,
          reason: 'decoder gộp joint + mel graph ⇒ layout NeMo');
      expect(report.zipformer!.encoder?.name, 'encoder-model.int8.onnx');
      expect(report.zipformer!.decoder?.name, 'decoder_joint-model.int8.onnx');
      expect(report.zipformer!.tokens?.name, 'vocab.txt',
          reason: 'vocab.txt là bảng token của bộ NeMo');
      expect(report.zipformer!.joiner, isNull,
          reason: 'không có joiner tách riêng ⇒ KHÔNG được báo nhầm là thiếu '
              'file khi user đã chọn đủ');
    });

    test('nemo128.onnx KHÔNG bị coi là giọng Piper', () {
      final report = ModelBundleScanner.scan(
        _nemoParakeet(),
        groupByDirectory: false,
      );
      expect(
        report.piperVoices.map((v) => v.onnx.name),
        isNot(contains('nemo128.onnx')),
      );
    });

    test('nhận diện tên file NeMo', () {
      expect(
        ModelBundleScanner.isNeMoJointDecoderName('decoder_joint-model.int8.onnx'),
        isTrue,
      );
      expect(
        ModelBundleScanner.isNeMoJointDecoderName('decoder.int8.onnx'),
        isFalse,
      );
      expect(ModelBundleScanner.isNeMoMelGraphName('nemo128.onnx'), isTrue);
      expect(ModelBundleScanner.isNeMoMelGraphName('encoder.int8.onnx'), isFalse);
      expect(ModelBundleScanner.isAsrTokensName('vocab.txt'), isTrue);
      expect(ModelBundleScanner.isAsrTokensName('tokens.txt'), isTrue);
      expect(ModelBundleScanner.isAsrTokensName('readme.txt'), isFalse);
    });
  });

  group('M4U-IMPORT-002 — i18n chuỗi mới (rule #5: đủ 5 locale)', () {
    const newStrings = [
      'Không đọc được thư mục đã chọn. Hãy thử lại, hoặc chọn trực tiếp các '
          'file model trong thư mục.',
      'Không đọc được thư mục đã chọn. Hãy thử lại, hoặc chọn trực tiếp các '
          'file .onnx trong thư mục.',
      'Không đọc được thư mục đã chọn (SAF/thẻ nhớ ngoài). Hãy chọn trực tiếp '
          'các file model trong thư mục.',
      'Bộ model này là bản export NVIDIA NeMo (decoder gộp joint) — app cần bộ '
          'sherpa-onnx gồm encoder*.onnx + decoder*.onnx + joiner*.onnx + '
          'tokens.txt. Bấm "Tải về" ở thẻ Parakeet để lấy đúng bộ.',
    ];
    const locales = ['en', 'hi', 'zh', 'zh_TW', 'si'];

    for (final s in newStrings) {
      test('priorityUiOverrides đủ 5 locale + resolve English', () {
        final entry = priorityUiOverrides[s];
        expect(entry, isNotNull, reason: 'Thiếu entry: $s');
        for (final loc in locales) {
          final v = entry![loc];
          expect(v, isNotNull, reason: 'Thiếu locale $loc cho "$s"');
          expect(v!.trim(), isNotEmpty);
        }
        final en = AppUITranslations.translate(s, 'en');
        expect(en, isNot(equals(s)),
            reason: 'locale en phải ra English, không rơi về tiếng Việt');
      });

      test('legacy fallback en có mục tương ứng', () {
        expect(generatedLegacyUiEnglishFallbacks[s], isNotNull,
            reason: 'Thiếu English fallback: $s');
      });
    }
  });
}
