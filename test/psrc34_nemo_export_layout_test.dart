// test/psrc34_nemo_export_layout_test.dart
//
// PSRC-34 (audit v1.27.0) — import thư mục `parakeet-tdt-0.6b-v3-int8` gồm
// `decoder_joint-model.int8.onnx`, `encoder-model.int8.onnx`, `nemo128.onnx`,
// `vocab.txt` bị từ chối. Owner: "chưa kết luận đây là lỗi nhận diện hay định
// dạng chưa hỗ trợ".
//
// Kết luận đã đối chiếu (card PSRC-34): ĐỊNH DẠNG CHƯA HỖ TRỢ — đây là dạng
// đóng gói của onnx-asr; sherpa-onnx (1.13.6 trong app, và cả 2.0.1) chỉ nạp
// transducer NeMo gồm ba đồ thị riêng encoder/decoder/joiner, không có loader
// cho `decoder_joint` gộp. App nhận diện ĐÚNG; cái thiếu là lối ra cho người
// dùng. Các test dưới đây khoá:
//   (1) nhận diện đúng bộ trong issue (tên file thật) và các biến thể;
//   (2) danh sách file "đã nhận ra" đưa cho người dùng;
//   (3) bước kế tiếp của hộp thoại (mời tải / đã cài / đang tải);
//   (4) màn cài đặt dùng HỘP THOẠI có nút tải, không còn snackbar ngõ cụt;
//   (5) 8 chuỗi mới đủ bản dịch (rule #5).
//   (6) hộp thoại chỉ nói điều app đã biết (không khẳng định file nguyên vẹn).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/core/language/generated_priority_native_pack.dart';
import 'package:in4up/screens/settings/asr_unsupported_layout_text.dart';
import 'package:in4up_stt/import/model_bundle_scanner.dart';

ScannedFile _f(String path, [int size = 10 * 1024 * 1024]) =>
    ScannedFile(path, sizeBytes: size);

/// Đúng bộ file trong issue (kèm `config.json` mà onnx-asr luôn ghi cùng).
/// Kích thước lấy từ manifest của một bản phát hành thật của layout này.
List<ScannedFile> _reportedFolder() => [
      _f('parakeet-tdt-0.6b-v3-int8/config.json', 121),
      _f('parakeet-tdt-0.6b-v3-int8/decoder_joint-model.int8.onnx', 18202004),
      _f('parakeet-tdt-0.6b-v3-int8/encoder-model.int8.onnx', 652282012),
      _f('parakeet-tdt-0.6b-v3-int8/nemo128.onnx', 138824),
      _f('parakeet-tdt-0.6b-v3-int8/vocab.txt', 93939),
    ];

/// Bộ sherpa-onnx của CÙNG model — bộ mà app dùng được.
List<ScannedFile> _sherpaSet() => [
      _f('sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/encoder.int8.onnx',
          652000000),
      _f('sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/decoder.int8.onnx',
          7000000),
      _f('sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/joiner.int8.onnx',
          2000000),
      _f('sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/tokens.txt', 93939),
    ];

final RegExp _vietnameseOnly = RegExp(
  r'[đĐơƠưƯ]|[ảạằắẳẵặầấẩẫậ]|[ẻẽẹềếểễệ]|[ỉĩị]|[ỏọồốổỗộờớởỡợ]|[ủũụừứửữự]|[ỳỷỹỵ]',
);

String _stripComments(String source) {
  final withoutBlocks = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return withoutBlocks.split('\n').map((line) {
    final idx = line.indexOf('//');
    return idx >= 0 ? line.substring(0, idx) : line;
  }).join('\n');
}

String _code(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'thiếu $path');
  return _stripComments(file.readAsStringSync());
}

String _between(String source, String start, String end) {
  final a = source.indexOf(start);
  expect(a, greaterThanOrEqualTo(0), reason: 'không thấy "$start"');
  final b = source.indexOf(end, a + start.length);
  expect(b, greaterThan(a), reason: 'không thấy "$end" sau "$start"');
  return source.substring(a, b);
}

void main() {
  group('PSRC-34 — bộ trong issue được NHẬN DIỆN ĐÚNG (không phải lỗi nhận '
      'diện)', () {
    test('thư mục parakeet-tdt-0.6b-v3-int8 ⇒ layout NeMo, đủ vai trò', () {
      final report = ModelBundleScanner.scan(_reportedFolder());
      final zip = report.zipformer;
      expect(zip, isNotNull);
      expect(zip!.isNeMoExport, isTrue);
      expect(zip.encoder?.name, 'encoder-model.int8.onnx');
      expect(zip.decoder?.name, 'decoder_joint-model.int8.onnx',
          reason: 'decoder GỘP joint — sherpa-onnx không có loader cho nó');
      expect(zip.joiner, isNull,
          reason: 'bộ này không có joiner riêng; đó là bản chất của layout, '
              'không phải người dùng chọn thiếu file');
      expect(zip.tokens?.name, 'vocab.txt');
    });

    test('chọn lẻ từng file (multi-select) cũng ra cùng kết luận', () {
      final picked = [
        for (final file in _reportedFolder())
          _f('/cache/file_picker/${file.name.hashCode}/${file.name}',
              file.sizeBytes),
      ];
      final report = ModelBundleScanner.scan(picked, groupByDirectory: false);
      expect(report.zipformer?.isNeMoExport, isTrue);
    });

    test('bộ sherpa-onnx của cùng model KHÔNG bị coi là layout NeMo', () {
      final zip = ModelBundleScanner.scan(_sherpaSet()).zipformer;
      expect(zip, isNotNull);
      expect(zip!.isNeMoExport, isFalse);
      expect(zip.isComplete, isTrue);
    });

    test('đồ thị mel của onnx-asr: nemo128 và nemo80, không nhận nhầm tên khác',
        () {
      for (final name in [
        'nemo128.onnx',
        'nemo80.onnx',
        'NEMO128.ONNX',
        'nemo128.int8.onnx',
      ]) {
        expect(ModelBundleScanner.isNeMoMelGraphName(name), isTrue,
            reason: name);
      }
      for (final name in [
        'nemo.onnx',
        'nemotron.onnx',
        'nemo128.txt',
        'encoder-model.int8.onnx',
        'vi_VN-nemo-medium.onnx',
      ]) {
        expect(ModelBundleScanner.isNeMoMelGraphName(name), isFalse,
            reason: name);
      }
    });

    test('nemo80.onnx không bị coi là một giọng Piper', () {
      final report = ModelBundleScanner.scan([
        _f('m/encoder-model.onnx'),
        _f('m/decoder_joint-model.onnx'),
        _f('m/nemo80.onnx', 100000),
        _f('m/vocab.txt', 9000),
      ]);
      expect(report.zipformer?.isNeMoExport, isTrue);
      expect(
        report.piperVoices.map((v) => v.onnx.name),
        isNot(contains('nemo80.onnx')),
      );
    });
  });

  group('PSRC-34 — danh sách file "đã nhận ra" hiện cho người dùng', () {
    test('bộ trong issue ⇒ đủ 5 file theo thứ tự cố định', () {
      expect(
        ModelBundleScanner.neMoExportLayoutFiles(
          _reportedFolder().map((f) => f.path),
        ),
        [
          'encoder-model.int8.onnx',
          'decoder_joint-model.int8.onnx',
          'nemo128.onnx',
          'vocab.txt',
          'config.json',
        ],
      );
    });

    test('đường dẫn Windows / thứ tự đảo / thiếu file tuỳ chọn', () {
      expect(
        ModelBundleScanner.neMoExportLayoutFiles([
          r'D:\models\parakeet\vocab.txt',
          r'D:\models\parakeet\nemo128.onnx',
          r'D:\models\parakeet\decoder_joint-model.int8.onnx',
          r'D:\models\parakeet\encoder-model.int8.onnx',
        ]),
        [
          'encoder-model.int8.onnx',
          'decoder_joint-model.int8.onnx',
          'nemo128.onnx',
          'vocab.txt',
        ],
      );
      expect(
        ModelBundleScanner.neMoExportLayoutFiles(
          ['decoder_joint-model.onnx', 'readme.md', 'tokens.txt'],
        ),
        ['decoder_joint-model.onnx'],
        reason: 'file ngoài layout không được liệt kê',
      );
      expect(ModelBundleScanner.neMoExportLayoutFiles(const []), isEmpty);
    });
  });

  group('PSRC-34 — bước kế tiếp của hộp thoại', () {
    test('chưa có bộ tương thích ⇒ mời tải', () {
      expect(
        asrLayoutNextStep(
          hasParakeetProfile: true,
          installed: false,
          downloading: false,
        ),
        AsrLayoutNextStep.offerDownload,
      );
    });

    test('đã cài ⇒ nói rõ không cần import (thắng cả trạng thái đang tải)', () {
      expect(
        asrLayoutNextStep(
          hasParakeetProfile: true,
          installed: true,
          downloading: false,
        ),
        AsrLayoutNextStep.alreadyInstalled,
      );
      expect(
        asrLayoutNextStep(
          hasParakeetProfile: true,
          installed: true,
          downloading: true,
        ),
        AsrLayoutNextStep.alreadyInstalled,
      );
    });

    test('đang tải ⇒ không mời tải lần nữa', () {
      expect(
        asrLayoutNextStep(
          hasParakeetProfile: true,
          installed: false,
          downloading: true,
        ),
        AsrLayoutNextStep.downloading,
      );
    });

    test('bản build không có profile Parakeet ⇒ chỉ giải thích', () {
      expect(
        asrLayoutNextStep(
          hasParakeetProfile: false,
          installed: true,
          downloading: true,
        ),
        AsrLayoutNextStep.explainOnly,
      );
    });

    test('câu mời tải khớp mẫu trong bảng dịch', () {
      expect(
        asrLayoutDownloadOffer(670),
        kAsrLayoutDownloadOfferTemplate.replaceAll('{value0}', '670'),
      );
    });
  });

  group('PSRC-34 — màn cài đặt: hộp thoại có lối ra, không còn snackbar ngõ cụt',
      () {
    late final String screen;
    late final String manager;

    setUpAll(() {
      screen = _code('lib/screens/settings/stt_model_settings_screen.dart');
      manager = _code('packages/in4up_stt/lib/sherpa_model_manager.dart');
    });

    test('unsupportedLayout rẽ sang hộp thoại TRƯỚC khi tới snackbar', () {
      final body = _between(
        screen,
        'void _showAsrImportResult(',
        'Future<void> _showUnsupportedLayoutDialog(',
      );
      final branch = body.indexOf(
        'if (result.status == SherpaAsrImportStatus.unsupportedLayout)',
      );
      final dialog = body.indexOf('_showUnsupportedLayoutDialog(context, result)');
      final snackbar = body.indexOf('showSnackBar(');
      expect(branch, greaterThanOrEqualTo(0));
      expect(dialog, greaterThan(branch));
      expect(snackbar, greaterThan(dialog),
          reason: 'snackbar dài tự biến mất sau vài giây — không đủ cho ca này');
    });

    test('hộp thoại: file đã nhận ra + quyết định thuần + nút tải qua xác nhận',
        () {
      final body = _between(
        screen,
        'Future<void> _showUnsupportedLayoutDialog(',
        'Future<void> _importFiles(',
      );
      expect(body.contains('showDialog<bool>('), isTrue);
      expect(body.contains('asrLayoutNextStep('), isTrue);
      expect(body.contains('result.layoutFiles'), isTrue);
      expect(body.contains('context.uiText(kAsrLayoutDialogTitle)'), isTrue);
      expect(body.contains('context.uiText(kAsrLayoutWhatItIs)'), isTrue);
      expect(body.contains('context.uiText(kAsrLayoutWhyNot)'), isTrue);
      expect(body.contains('context.uiText(kAsrLayoutDownloadButton)'), isTrue);
      expect(body.contains('AsrLayoutNextStep.offerDownload'), isTrue);
      expect(body.contains('await _handleDownload(context, parakeet)'), isTrue,
          reason: 'tải 670 MB vẫn phải qua hộp xác nhận dung lượng/Wi-Fi và '
              'chỉ chạy khi người dùng bấm');
      expect(body.contains('downloadAsrModel('), isFalse,
          reason: 'hộp thoại không tự tải thẳng');
    });

    test('manager gửi kèm danh sách file của layout trong kết quả từ chối', () {
      final start = manager.indexOf(
        'status: SherpaAsrImportStatus.unsupportedLayout',
      );
      expect(start, greaterThanOrEqualTo(0));
      final tail = manager.substring(start, start + 700);
      expect(
        tail.contains(
          'layoutFiles: ModelBundleScanner.neMoExportLayoutFiles(listing)',
        ),
        isTrue,
      );
      expect(manager.contains('final List<String> layoutFiles;'), isTrue);
    });
  });

  group('PSRC-34 — 8 chuỗi mới của hộp thoại (rule #5)', () {
    const sources = <String>[
      kAsrLayoutDialogTitle,
      kAsrLayoutWhatItIs,
      kAsrLayoutWhyNot,
      kAsrLayoutFilesHeader,
      kAsrLayoutAlreadyInstalled,
      kAsrLayoutDownloading,
      kAsrLayoutDownloadButton,
      kAsrLayoutDownloadOfferTemplate,
    ];
    const locales = ['en', 'zh', 'zh_TW', 'hi', 'si', 'my', 'th', 'ja'];

    test('đủ en + 7 ngôn ngữ ưu tiên, không còn ký tự tiếng Việt', () {
      for (final source in sources) {
        final entry = generatedPriorityNativePack[source];
        expect(entry, isNotNull, reason: 'thiếu trong pack: $source');
        for (final locale in locales) {
          final value = (entry![locale] ?? '').trim();
          expect(value, isNotEmpty, reason: '$locale — $source');
          expect(_vietnameseOnly.hasMatch(value), isFalse,
              reason: '$locale còn tiếng Việt: $value');
        }
      }
    });

    test('chuỗi cố định: ngôn ngữ ưu tiên ra bản địa, locale khác ra English',
        () {
      for (final source in sources.where((s) => !s.contains('{'))) {
        final entry = generatedPriorityNativePack[source]!;
        final english = entry['en']!;
        for (final locale in ['zh', 'zh_TW', 'hi', 'si', 'my', 'th', 'ja']) {
          final shown = AppUITranslations.translate(source, locale);
          expect(shown, entry[locale], reason: '$locale — $source');
          expect(shown, isNot(source), reason: '$locale còn tiếng Việt');
        }
        expect(AppUITranslations.translate(source, 'en'), english);
        expect(AppUITranslations.translate(source, 'fr'), english);
        expect(AppUITranslations.translate(source, 'vi'), source);
      }
    });

    test('câu mời tải có dung lượng được dịch qua mẫu {value0}', () {
      final offer = asrLayoutDownloadOffer(670);
      for (final locale in locales) {
        final shown = AppUITranslations.translate(offer, locale);
        expect(shown, contains('670MB'), reason: locale);
        expect(shown, isNot(offer), reason: '$locale còn tiếng Việt');
        expect(shown.contains('{value0}'), isFalse, reason: locale);
        expect(_vietnameseOnly.hasMatch(shown), isFalse, reason: shown);
      }
      expect(
        AppUITranslations.translate(offer, 'en'),
        'A compatible Parakeet set is available to download in the app '
        '(about 670MB).',
      );
    });

    test('hộp thoại chỉ nói điều app ĐÃ BIẾT — không khẳng định file nguyên vẹn',
        () {
      // Ở nhánh unsupportedLayout app dừng ngay khi nhận ra layout, chưa hề
      // kiểm tra tính toàn vẹn của file ⇒ không được viết "file của bạn không
      // hỏng". Điều nói được: đã nhận ra đúng loại model, và import lại chính
      // bộ này cũng không đổi kết quả.
      for (final source in const [kAsrLayoutWhatItIs, kAsrLayoutWhyNot]) {
        expect(source.contains('không hỏng'), isFalse, reason: source);
        final english = generatedPriorityNativePack[source]!['en']!;
        expect(english.toLowerCase().contains('not damaged'), isFalse,
            reason: english);
        expect(english.toLowerCase().contains('not corrupt'), isFalse,
            reason: english);
      }
      expect(kAsrLayoutWhyNot.contains('import lại chính bộ này'), isTrue);
      expect(
        generatedPriorityNativePack[kAsrLayoutWhyNot]!['en']!
            .contains('importing this same set again'),
        isTrue,
      );
    });
  });
}
