// M4U-IMPORT-003 — Parakeet: import được + dùng được cho LIVE STT.
//
// Bối cảnh (lỗi user thật):
//   1. User tải ĐÚNG bộ sherpa-onnx chính thức
//      `sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8` (encoder/decoder/joiner +
//      tokens.txt) rồi Import ở thẻ Parakeet ⇒ app báo "model không khớp
//      profile đã chọn". Nguyên nhân: heuristic "tokens.txt có ký tự tiếng
//      Việt" khớp vocab Unicode ĐA NGÔN NGỮ của tokenizer NVIDIA (â ê ô ă
//      đ é ý ù ò ì á è à) ⇒ app nhận nhầm là Zipformer VI.
//   2. Cabin live STT: plan đã resolve về Parakeet nhưng engine tra model
//      theo NGÔN NGỮ ⇒ rơi về profile chuyên ngôn ngữ chưa cài ⇒ "chưa có
//      model" dù máy đã cài Parakeet.
//   3. Tab Nghe ("sound to text"): chưa có đường live dùng model offline.
//
// Test này khoá các quyết định THUẦN + quét mã nguồn (không cần thiết bị).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/sherpa_model_manager.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('M4U-IMPORT-003 — heuristic "tiếng Việt" không nhận nhầm vocab đa ngôn ngữ',
      () {
    test('vocab tokenizer đa ngôn ngữ (tag <|xx|>) → KHÔNG phải tiếng Việt',
        () {
      final dir = Directory.systemTemp.createTempSync('m4u_tokens_multi_');
      try {
        final tokens = File('${dir.path}/tokens.txt')
          ..writeAsStringSync('<|unk|> 0\n<|vi|> 196\n<|zh|> 52\n<|hi|> 87\n'
              '<|si|> 164\n<|de|> 78\n<|fr|> 71\nâ 8024\nê 8027\nđ 8059\n');
        expect(SherpaModelManager.asrTokensLookVietnamese(tokens.path), isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('từ vựng tiếng Việt thật (dấu thanh) → vẫn nhận là VI', () {
      final dir = Directory.systemTemp.createTempSync('m4u_tokens_vi_');
      try {
        final tokens = File('${dir.path}/tokens.txt')
          ..writeAsStringSync('▁RỒI 100\n▁CŨNG 101\n▁HỖ 102\n▁TRỢ 103\n');
        expect(SherpaModelManager.asrTokensLookVietnamese(tokens.path), isTrue);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('M4U-IMPORT-003 — họ model NeMo nhận diện qua metadata ONNX', () {
    test('metadata ở CUỐI file ONNX → transducer NeMo (offline-only)', () {
      final dir = Directory.systemTemp.createTempSync('m4u_nemo_meta_');
      try {
        final encoder = File('${dir.path}/encoder.int8.onnx');
        final head = List<int>.filled(4096, 32);
        const meta = 'model_type EncDecRNNTBPEModel model_author NeMo feat_dim 128';
        encoder.writeAsBytesSync([...head, ...meta.codeUnits]);

        expect(SherpaModelManager.isNeMoTransducerEncoder(encoder.path), isTrue);
        expect(
          SherpaModelManager.detectEncoderKind(encoder.path),
          SherpaAsrEncoderKind.nonStreaming,
        );
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('file ONNX thường → không phải NeMo', () {
      final dir = Directory.systemTemp.createTempSync('m4u_plain_meta_');
      try {
        final encoder = File('${dir.path}/encoder.int8.onnx')
          ..writeAsBytesSync(List<int>.filled(4096, 32));
        expect(SherpaModelManager.isNeMoTransducerEncoder(encoder.path), isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('M4U-IMPORT-003 — ngôn ngữ model offline đã cài', () {
    test('installedOfflineLanguages bỏ model streaming', () {
      expect(
        AsrModelRouter.installedOfflineLanguages(
          isInstalled: (id) => id == kParakeetProfileId,
        ).length,
        25,
      );
      expect(
        AsrModelRouter.installedOfflineLanguages(
          isInstalled: (id) => id == 'asr-en-20M-streaming-int8',
        ),
        isEmpty,
      );
      expect(
        AsrModelRouter.installedOfflineLanguages(
          isInstalled: (id) => id == 'asr-vi-30M-int8',
        ),
        ['vi'],
      );
    });
  });

  group('M4U-IMPORT-003 — live offline ở tab Nghe + Cabin', () {
    test('service live offline dùng SherpaSttEngine + recorder PCM 16kHz', () {
      final service = _read(
        'lib/screens/listen_mode/services/listen_live_offline_stt.dart',
      );
      expect(service.contains('SherpaSttEngine'), isTrue);
      expect(service.contains('AudioRecorder'), isTrue);
      expect(service.contains('sampleRate: 16000'), isTrue);
      // Phải truyền ĐÚNG model đã tra (Parakeet khi profile chuyên ngôn ngữ
      // chưa cài) — không để engine tự tra lại theo ngôn ngữ.
      expect(service.contains('modelPaths: paths'), isTrue);
      // Nhả mic khi đóng màn (không giữ model ~670MB trong RAM).
      expect(service.contains('Future<void> dispose()'), isTrue);
    });

    test('tab Nghe có nút mic offline + hiện transcript live', () {
      final screen = _read('lib/screens/listen_mode/listen_mode_screen.dart');
      expect(screen.contains('ListenLiveOfflineMic'), isTrue,
          reason: 'tab Nghe phải nhúng widget mic offline');

      final widget = _read(
        'lib/screens/listen_mode/widgets/listen_live_offline_mic.dart',
      );
      expect(widget.contains('Ghi âm offline (Parakeet)'), isTrue);
      expect(widget.contains('Dừng ghi offline'), isTrue);
      expect(widget.contains('_stt.results.listen'), isTrue,
          reason: 'phải nghe kết quả live để hiện transcript');
      expect(widget.contains('installedOfflineLanguages'), isTrue,
          reason: 'chỉ hiện nút khi máy đã cài model offline');
    });

    test('Cabin live truyền modelPaths đúng profile đã plan', () {
      final cabin = _read('lib/features/cabin/services/stts_cabin_service.dart');
      // `plan.profile` là getter (không promote được) ⇒ phải gán biến cục bộ.
      expect(cabin.contains('final planProfile = plan.profile;'), isTrue);
      expect(cabin.contains('modelPaths: planProfile == null'), isTrue);
    });

    test('4 chuỗi UI mới đã đăng ký i18n rule #5 (đủ 5 locale)', () {
      final overrides = _read('lib/core/language/priority_ui_overrides.dart');
      const labels = [
        'Ghi âm offline (Parakeet)',
        'Dừng ghi offline',
        'Chưa có model nhận diện offline — hãy tải hoặc import Parakeet / Zipformer VI trong Quản lý Model AI.',
        'Không khởi động được nhận diện offline.',
      ];
      for (final label in labels) {
        final index = overrides.indexOf("'$label'");
        expect(index, greaterThan(0), reason: 'Thiếu chuỗi "$label" trong catalog');
        final block = overrides.substring(index, index + 700);
        for (final locale in ['en', 'hi', 'zh', 'zh_TW', 'si']) {
          expect(
            block.contains("'$locale'"),
            isTrue,
            reason: '"$label" thiếu bản dịch $locale (rule vàng #5)',
          );
        }
      }
    });

    test('chuỗi UI mới có bản dịch English trong legacy overrides', () {
      final json = _read('tool/legacy_ui_english_overrides.json');
      for (final label in [
        'Ghi âm offline (Parakeet)',
        'Dừng ghi offline',
        'Không khởi động được nhận diện offline.',
      ]) {
        expect(json.contains('"$label"'), isTrue,
            reason: 'Thiếu English cho "$label"');
      }
    });
  });
}
