// I4U18-MODEL-IMPORT-001 — test thuần cho validator/scanner import model
// thống nhất (Piper / eSpeak / Zipformer ASR / Silero VAD / Whisper GGML).
//
// Scanner nằm ở `packages/in4up_stt/lib/import/model_bundle_scanner.dart` —
// thuần Dart (không I/O) nên chạy được trong `flutter test` không thiết bị.
//
// Bối cảnh (owner 2026-09-30):
// - Chọn nhiều file có kèm thư mục `espeak` nhưng app không tự nhận.
// - Import thư mục báo thiếu `.onnx`/`.txt` dù file tồn tại.
// - STT offline chọn đúng file/thư mục vẫn báo không nhận dạng được.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/import/model_bundle_scanner.dart';

ScannedFile f(String path, [int size = 1024]) => ScannedFile(path, sizeBytes: size);

void main() {
  group('ModelBundleScanner — nhận diện tên file (alias)', () {
    test('tokens: tokens.txt / *_tokens.txt / *-tokens.txt', () {
      expect(ModelBundleScanner.isTokensName('tokens.txt'), isTrue);
      expect(ModelBundleScanner.isTokensName('Tokens.TXT'), isTrue);
      expect(ModelBundleScanner.isTokensName('en_US-lessac-medium_tokens.txt'), isTrue);
      expect(ModelBundleScanner.isTokensName('en_US-lessac-medium-tokens.txt'), isTrue);
      expect(ModelBundleScanner.isTokensName('readme.txt'), isFalse);
      expect(ModelBundleScanner.tokensStem('en_US-lessac-medium_tokens.txt'),
          'en_US-lessac-medium');
      expect(ModelBundleScanner.tokensStem('tokens.txt'), isNull);
    });

    test('Zipformer roles: encoder/decoder/joiner + coupler alias', () {
      expect(ModelBundleScanner.isAsrEncoderName('encoder.int8.onnx'), isTrue);
      expect(
        ModelBundleScanner.isAsrEncoderName(
          'encoder-epoch-99-avg-1-chunk-16-left-64.int8.onnx',
        ),
        isTrue,
      );
      expect(ModelBundleScanner.isAsrDecoderName('decoder.onnx'), isTrue);
      expect(ModelBundleScanner.isAsrJoinerName('joiner.int8.onnx'), isTrue);
      expect(ModelBundleScanner.isAsrJoinerName('coupler.onnx'), isTrue);
      // .onnx.json KHÔNG phải model file.
      expect(ModelBundleScanner.isAsrEncoderName('encoder.onnx.json'), isFalse);
    });

    test('Piper voice onnx loại trừ role ASR/VAD/whisper', () {
      expect(
        ModelBundleScanner.isPiperVoiceOnnxName('en_US-lessac-medium.onnx'),
        isTrue,
      );
      expect(ModelBundleScanner.isPiperVoiceOnnxName('encoder.int8.onnx'), isFalse);
      expect(ModelBundleScanner.isPiperVoiceOnnxName('joiner.onnx'), isFalse);
      expect(ModelBundleScanner.isPiperVoiceOnnxName('silero_vad.onnx'), isFalse);
      expect(ModelBundleScanner.isPiperVoiceOnnxName('vad_model.onnx'), isFalse);
      expect(
        ModelBundleScanner.isPiperVoiceOnnxName('en_US-lessac-medium.onnx.json'),
        isFalse,
      );
    });

    test('eSpeak leaf bằng tên lẻ (không extension)', () {
      expect(ModelBundleScanner.isEspeakLeafName('phontab'), isTrue);
      expect(ModelBundleScanner.isEspeakLeafName('phonindex'), isTrue);
      expect(ModelBundleScanner.isEspeakLeafName('vi_dict'), isTrue);
      expect(ModelBundleScanner.isEspeakLeafName('intonations'), isTrue);
      expect(ModelBundleScanner.isEspeakLeafName('tokens.txt'), isFalse);
    });

    test('eSpeak tail: chuẩn hoá Windows path', () {
      expect(
        ModelBundleScanner.espeakTail(
          ModelBundleScanner.normSep(r'vits-piper-en\espeak-ng-data\phontab'),
        ),
        'espeak-ng-data/phontab',
      );
      expect(
        ModelBundleScanner.espeakTail('a/espeak-ng-data/voices/vi'),
        'espeak-ng-data/voices/vi',
      );
      expect(ModelBundleScanner.espeakTail('docs/phontab'), isNull);
    });
  });

  group('ModelBundleScanner.scan — phân loại bundle', () {
    test('bundle k2-fsa Piper (nested + tokens chung + espeak-ng-data)', () {
      final report = ModelBundleScanner.scan([
        f('vits-piper-en_US-lessac-medium/en_US-lessac-medium.onnx', 63 * 1024 * 1024),
        f('vits-piper-en_US-lessac-medium/tokens.txt', 14 * 1024),
        f('vits-piper-en_US-lessac-medium/espeak-ng-data/phontab', 300 * 1024),
        f('vits-piper-en_US-lessac-medium/espeak-ng-data/phonindex', 60 * 1024),
        f('vits-piper-en_US-lessac-medium/espeak-ng-data/en_dict', 900 * 1024),
        f('vits-piper-en_US-lessac-medium/espeak-ng-data/intonations', 2 * 1024),
        f('vits-piper-en_US-lessac-medium/README.md', 3 * 1024),
      ]);

      expect(report.kinds, containsAll([
        ModelBundleKind.piperVoice,
        ModelBundleKind.espeakData,
      ]));
      expect(report.kinds, isNot(contains(ModelBundleKind.zipformerAsr)));
      expect(report.piperVoices, hasLength(1));
      final voice = report.piperVoices.single;
      expect(voice.stem, 'en_US-lessac-medium');
      expect(voice.isUsable, isTrue, reason: 'tokens.txt chung phải ghép được');
      expect(voice.sharedTokens?.name, 'tokens.txt');
      expect(report.espeak.hasPhontab, isTrue);
      expect(report.espeak.treeFiles, hasLength(4));
      // Thư mục gốc chứa espeak-ng-data.
      expect(report.espeakRootDir, 'vits-piper-en_US-lessac-medium');
      expect(report.unclassified, isEmpty);
    });

    test('layout HuggingFace rhasspy (onnx + onnx.json, KHÔNG tokens)', () {
      final report = ModelBundleScanner.scan([
        f('vi_VN-vais1000-medium.onnx', 70 * 1024 * 1024),
        f('vi_VN-vais1000-medium.onnx.json', 4 * 1024),
      ]);

      expect(report.piperVoices, hasLength(1));
      final voice = report.piperVoices.single;
      expect(voice.isUsable, isFalse);
      expect(voice.missingParts, isNotEmpty);
      expect(voice.missingParts.single, contains('tokens'));
      expect(voice.config?.name, 'vi_VN-vais1000-medium.onnx.json');
    });

    test('multi-file kèm espeak LẺ (không thư mục espeak-ng-data)', () {
      // User multi-select: onnx + tokens + phontab + vi_dict… (tên lẻ).
      final report = ModelBundleScanner.scan([
        f('vi_VN-vais1000-medium.onnx', 70 * 1024 * 1024),
        f('vi_VN-vais1000-medium_tokens.txt', 15 * 1024),
        f('phontab', 300 * 1024),
        f('phondata', 200 * 1024),
        f('vi_dict', 900 * 1024),
      ]);

      expect(report.piperVoices.single.ownTokens?.name,
          'vi_VN-vais1000-medium_tokens.txt');
      expect(report.piperVoices.single.isUsable, isTrue);
      expect(report.espeak.looseLeaves, hasLength(3));
      expect(report.espeak.hasPhontab, isTrue);
      expect(report.kinds, contains(ModelBundleKind.espeakData));
    });

    test('Zipformer VI đầy đủ trong thư mục con (import folder)', () {
      final report = ModelBundleScanner.scan([
        f('VI-sherpa-onnx-zipformer-vi-30M-int8-2026-02-09/encoder.int8.onnx', 15 * 1024 * 1024),
        f('VI-sherpa-onnx-zipformer-vi-30M-int8-2026-02-09/decoder.onnx', 9 * 1024 * 1024),
        f('VI-sherpa-onnx-zipformer-vi-30M-int8-2026-02-09/joiner.int8.onnx', 2 * 1024 * 1024),
        f('VI-sherpa-onnx-zipformer-vi-30M-int8-2026-02-09/tokens.txt', 60 * 1024),
        f('VI-sherpa-onnx-zipformer-vi-30M-int8-2026-02-09/bpe.vocab', 300 * 1024),
        f('VI-sherpa-onnx-zipformer-vi-30M-int8-2026-02-09/README.md', 2 * 1024),
      ]);

      expect(report.hasCompleteZipformer, isTrue);
      expect(report.zipformer!.missingRoles, isEmpty);
      expect(report.zipformer!.encoder!.name, 'encoder.int8.onnx');
      expect(report.zipformer!.bpeVocab?.name, 'bpe.vocab');
      expect(report.zipformerDir,
          'VI-sherpa-onnx-zipformer-vi-30M-int8-2026-02-09');
      // Không có giọng Piper nào trong bộ ASR.
      expect(report.piperVoices, isEmpty);
    });

    test('Zipformer thiếu joiner + tokens → báo ĐÚNG role thiếu', () {
      final report = ModelBundleScanner.scan([
        f('model/encoder.int8.onnx', 15 * 1024 * 1024),
        f('model/decoder.onnx', 9 * 1024 * 1024),
      ]);

      expect(report.hasCompleteZipformer, isFalse);
      final missing = report.zipformer!.missingRoles.join(' ');
      expect(missing, contains('joiner'));
      expect(missing, contains('tokens'));
      expect(missing, isNot(contains('encoder')));
      expect(missing, isNot(contains('decoder')));
      // tokens.txt lẻ (không thư mục onnx role) KHÔNG bị gán nhầm vào bộ ASR.
      final tokensOnly = ModelBundleScanner.scan([f('tokens.txt')]);
      expect(tokensOnly.zipformer, isNull);
    });

    test('hai thư mục: bundle hỏng trước walk-order — chọn bundle ĐỦ', () {
      // Trước đây lấy file đầu tiên thấy được (walk order) → nhận nhầm bộ
      // thiếu và báo "không nhận dạng". Scanner phải group theo thư mục và
      // chọn bộ đủ nhất.
      final report = ModelBundleScanner.scan([
        f('broken/encoder.int8.onnx', 15 * 1024 * 1024),
        f('sherpa-onnx-streaming-zipformer-en-20M/encoder-epoch-99-avg-1.int8.onnx', 8 * 1024 * 1024),
        f('sherpa-onnx-streaming-zipformer-en-20M/decoder-epoch-99-avg-1.onnx', 5 * 1024 * 1024),
        f('sherpa-onnx-streaming-zipformer-en-20M/joiner-epoch-99-avg-1.int8.onnx', 1 * 1024 * 1024),
        f('sherpa-onnx-streaming-zipformer-en-20M/tokens.txt', 12 * 1024),
      ]);

      expect(report.hasCompleteZipformer, isTrue);
      expect(report.zipformerDir, 'sherpa-onnx-streaming-zipformer-en-20M');
    });

    test('Silero VAD + Whisper GGML phân loại riêng, không trộn Piper', () {
      final report = ModelBundleScanner.scan([
        f('silero_vad.onnx', 629 * 1024),
        f('ggml-tiny.bin', 75 * 1024 * 1024),
        f('ggml-base.bin', 142 * 1024 * 1024),
      ]);

      expect(report.sileroVad?.name, 'silero_vad.onnx');
      expect(report.whisperBins, hasLength(2));
      expect(report.piperVoices, isEmpty);
      expect(report.zipformer, isNull);
      expect(
        report.kinds,
        containsAll([ModelBundleKind.sileroVad, ModelBundleKind.whisperGgml]),
      );
    });

    test('archive giữ riêng để caller giải nén (không tự tra cứu nội dung)',
        () {
      final report = ModelBundleScanner.scan([
        f('vits-piper-vi_VN-vais1000-medium.tar.bz2', 75 * 1024 * 1024),
        f('notes.txt'),
      ]);

      expect(report.archives, hasLength(1));
      expect(report.piperVoices, isEmpty);
      expect(report.kinds, isEmpty);
    });

    test('listing rác/rỗng → không throw, không nhận loại nào', () {
      final empty = ModelBundleScanner.scan(const []);
      expect(empty.kinds, isEmpty);

      final junk = ModelBundleScanner.scan([
        f('photo.jpg', 500 * 1024),
        f('document.pdf', 2 * 1024 * 1024),
      ]);
      expect(junk.kinds, isEmpty);
      expect(junk.unclassified, isEmpty);
    });

    test('onnx lạc không có tokens → unclassified (báo rõ cho user)', () {
      final report = ModelBundleScanner.scan([
        f('random/model.onnx', 40 * 1024 * 1024),
      ]);
      // 'model.onnx' không chứa từ khoá role, cũng không có tokens → vẫn xếp
      // Piper candidate (thiếu tokens) thay vì nuốt lặng.
      expect(report.piperVoices, hasLength(1));
      expect(report.piperVoices.single.isUsable, isFalse);
    });

    test('Windows path + tên HOA/thường trộn lẫn vẫn nhận diện', () {
      final report = ModelBundleScanner.scan([
        f(r'D:\Models\ZipVI\ENCODER.INT8.ONNX', 15 * 1024 * 1024),
        f(r'D:\Models\ZipVI\Decoder.onnx', 9 * 1024 * 1024),
        f(r'D:\Models\ZipVI\JOINER.int8.onnx', 2 * 1024 * 1024),
        f(r'D:\Models\ZipVI\TOKENS.TXT', 60 * 1024),
      ]);
      expect(report.hasCompleteZipformer, isTrue);
      expect(report.zipformerDir, 'D:/Models/ZipVI');
    });
  });
}

