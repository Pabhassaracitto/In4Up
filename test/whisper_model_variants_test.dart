// WHISPER-VARIANT-001 — Whisper có 2 dòng model cho mỗi kích thước:
//   • đa ngữ:  ggml-tiny.bin … ggml-large-v2.bin  (99 ngôn ngữ)
//   • .en:     ggml-tiny.en.bin … ggml-medium.en.bin (chỉ tiếng Anh)
// Hai dòng KHÔNG được nhận nhầm là nhau. Test này chạy thuần Dart (không cần
// thiết bị, không cần Flutter binding) nên vào CI cùng nhóm ASR routing.
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/models/stt_model_info.dart';
import 'package:in4up_stt/stt_model_manager.dart';

void main() {
  group('WhisperModelLevel — 2 dòng model', () {
    test('danh sách đa ngữ / English-only', () {
      expect(kWhisperMultilingualLevels.length, 5);
      expect(kWhisperEnglishOnlyLevels.length, 4);
      expect(kWhisperMultilingualLevels.every((l) => !l.isEnglishOnly), isTrue);
      expect(kWhisperEnglishOnlyLevels.every((l) => l.isEnglishOnly), isTrue);
      // OpenAI chỉ phát hành .en cho tiny→medium (large KHÔNG có .en).
      expect(
        kWhisperEnglishOnlyLevels.map((l) => l.multilingualTwin).toSet(),
        {
          WhisperModelLevel.tiny,
          WhisperModelLevel.base,
          WhisperModelLevel.small,
          WhisperModelLevel.medium,
        },
      );
    });

    test('tên file & nhãn hiển thị', () {
      expect(WhisperModelLevel.tiny.fileName, 'ggml-tiny.bin');
      expect(WhisperModelLevel.large.fileName, 'ggml-large-v2.bin');
      expect(WhisperModelLevel.tinyEn.fileName, 'ggml-tiny.en.bin');
      expect(WhisperModelLevel.baseEn.fileName, 'ggml-base.en.bin');
      expect(WhisperModelLevel.smallEn.fileName, 'ggml-small.en.bin');
      expect(WhisperModelLevel.mediumEn.fileName, 'ggml-medium.en.bin');
      expect(WhisperModelLevel.tiny.displayLabel, 'TINY');
      expect(WhisperModelLevel.tinyEn.displayLabel, 'TINY · EN');
      // `.en` cùng kiến trúc ⇒ cùng dung lượng tham chiếu với bản đa ngữ.
      expect(WhisperModelLevel.tinyEn.sizeInMB, WhisperModelLevel.tiny.sizeInMB);
      expect(WhisperModelLevel.tinyEn.minimumAcceptedSizeMB,
          WhisperModelLevel.tiny.minimumAcceptedSizeMB);
    });

    test('alias plugin chỉ có ở dòng .en (không đè file đa ngữ)', () {
      expect(WhisperModelLevel.tiny.pluginAliasSubdir, isEmpty);
      expect(WhisperModelLevel.tinyEn.pluginAliasSubdir, 'plugin_alias/tinyEn');
      expect(WhisperModelLevel.mediumEn.pluginAliasSubdir,
          'plugin_alias/mediumEn');
    });

    test('mirrorUrl rỗng (GitHub release không có ggml-*.bin)', () {
      for (final level in WhisperModelLevel.values) {
        expect(level.mirrorUrl, isEmpty,
            reason: '${level.name}: URL GitHub cũ trả 404 — đừng thử lại');
        expect(level.downloadUrl, startsWith('https://huggingface.co/'));
        expect(level.downloadUrl, endsWith(level.fileName));
      }
    });
  });

  group('SttModelManager — nhận diện file theo dòng model', () {
    final manager = SttModelManager();

    test('tên file đa ngữ', () {
      expect(manager.detectLevelFromFileName('/x/ggml-tiny.bin'),
          WhisperModelLevel.tiny);
      expect(manager.detectLevelFromFileName('/x/ggml-base-q5_1.bin'),
          WhisperModelLevel.base);
      expect(manager.detectLevelFromFileName('ggml-large-v2.bin'),
          WhisperModelLevel.large);
    });

    test('tên file .en KHÔNG bị nhận thành bản đa ngữ', () {
      expect(manager.detectLevelFromFileName('/x/ggml-tiny.en.bin'),
          WhisperModelLevel.tinyEn);
      expect(manager.detectLevelFromFileName('/x/ggml-base.en.bin'),
          WhisperModelLevel.baseEn);
      expect(manager.detectLevelFromFileName('/x/ggml-small.en-q5_1.bin'),
          WhisperModelLevel.smallEn);
      expect(manager.detectLevelFromFileName('/x/ggml-medium.en.bin'),
          WhisperModelLevel.mediumEn);
    });

    test('file đa ngữ KHÔNG bị nhận thành .en', () {
      for (final level in kWhisperMultilingualLevels) {
        expect(manager.detectLevelFromFileName(level.fileName), level);
      }
      for (final level in kWhisperEnglishOnlyLevels) {
        expect(manager.detectLevelFromFileName(level.fileName), level);
      }
    });

    test('file lạ → null (không đoán)', () {
      expect(manager.detectLevelFromFileName('/x/ggml-xyz.bin'), isNull);
      expect(manager.detectLevelFromFileName('/x/notes.txt'), isNull);
    });
  });
}
