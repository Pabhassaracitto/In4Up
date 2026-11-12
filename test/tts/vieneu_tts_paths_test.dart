// test/tts/vieneu_tts_paths_test.dart — PSRC-183..186
//
// Quy ước dữ liệu giữa TtsService (import), engine (liệt kê giọng) và native
// (clone giọng). Thuần logic, không plugin / không isolate.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/tts/vieneu_tts_paths.dart';

void main() {
  group('mẫu WAV và dữ liệu giọng', () {
    test('chỉ WAV là mẫu native đọc được (PSRC-184/185)', () {
      expect(isVieneuVoiceSampleFile('sample.wav'), isTrue);
      expect(isVieneuVoiceSampleFile('SAMPLE.WAV'), isTrue);
      expect(isVieneuVoiceSampleFile('sample.mp3'), isFalse);
      expect(isVieneuVoiceSampleFile('sample.m4a'), isFalse);
      expect(isVieneuVoiceSampleFile('sample.flac'), isFalse);
    });

    test('nhận diện file dữ liệu giọng', () {
      expect(isVieneuVoiceDataFile('/voices/a/ref_codes.txt'), isTrue);
      expect(isVieneuVoiceDataFile('/voices/a/speaker.emb.txt'), isTrue);
      expect(isVieneuVoiceDataFile('/voices/a/ref_codes.bin'), isTrue);
      expect(isVieneuVoiceDataFile('/voices/a/manifest.json'), isFalse);
    });

    test('placeholder comment không được tính là giọng (PSRC-186/187)', () {
      expect(hasVieneuVoiceData('# VieNeu-TTS default\n'), isFalse);
      expect(hasVieneuVoiceData('\n# chỉ comment\n# nữa\n'), isFalse);
      // Embedding thật: dòng số chiều + dòng floats.
      expect(hasVieneuVoiceData('256\n0.01 0.02 0.03\n'), isTrue);
      expect(hasVieneuVoiceData('base64_ref_codes_value\n'), isTrue);
    });
  });

  group('tên giọng do người dùng nhập', () {
    test('chuẩn hoá khoảng trắng và ký tự cấm (PSRC-184)', () {
      expect(sanitizeVieneuVoiceId('  Giọng   tôi  '), 'Giọng tôi');
      expect(sanitizeVieneuVoiceId('a/b\\c'), 'a_b_c');
      expect(sanitizeVieneuVoiceId('../etc'), '.._etc');
      expect(sanitizeVieneuVoiceId(''), isEmpty);
      expect(sanitizeVieneuVoiceId('   '), isEmpty);
      expect(sanitizeVieneuVoiceId('..'), isEmpty);
    });

    test('giới hạn độ dài tên thư mục', () {
      final id = sanitizeVieneuVoiceId(List.filled(120, 'a').join());
      expect(id.length, 64);
    });
  });

  group('dò voices/ đi kèm GGUF (PSRC-186)', () {
    test('dò cả thư mục cha — file_picker hay copy vào cache', () {
      final candidates =
          bundledVoiceDirCandidates('/tmp/VieNeuBundle/model/q8_0.gguf');
      expect(candidates, <String>[
        '/tmp/VieNeuBundle/model/voices',
        '/tmp/VieNeuBundle/model',
        '/tmp/VieNeuBundle/voices',
        '/tmp/VieNeuBundle',
      ]);
    });

    test('không trùng ứng viên', () {
      final candidates = bundledVoiceDirCandidates('model.gguf');
      expect(candidates.toSet().length, candidates.length);
    });
  });

  group('manifest và import', () {
    test('manifest dạng map id → tên', () {
      final names = parseVieneuVoiceNames(
          '{"voices": {"minh_quan_pro": "Minh Quan", "thao_nguyen": {"name": "Thảo Nguyên"}}}');
      expect(names['minh_quan_pro'], 'Minh Quan');
      expect(names['thao_nguyen'], 'Thảo Nguyên');
    });

    test('manifest dạng list object', () {
      final names = parseVieneuVoiceNames(
          '{"voices": [{"id": "nu_a", "label": "Giọng nữ A"}]}');
      expect(names['nu_a'], 'Giọng nữ A');
    });

    test('manifest hỏng không làm sập liệt kê giọng', () {
      expect(parseVieneuVoiceNames('not json'), isEmpty);
      expect(parseVieneuVoiceNames('[]'), isEmpty);
    });

    test('tên đích không trùng khi copy nhiều mẫu', () {
      expect(uniqueVieneuCopyPath('/tmp/samples', 'a.wav', 0),
          '/tmp/samples/a.wav');
      expect(uniqueVieneuCopyPath('/tmp/samples', 'a.wav', 3),
          '/tmp/samples/a_3.wav');
    });

    test('nhận diện biến thể từ tên file', () {
      expect(detectVieneuVariantName('vieneu-v3-turbo-q8_0.gguf'), 'q8_0');
      expect(detectVieneuVariantName('vieneu-v3-turbo-bf16.gguf'), 'bf16');
      expect(detectVieneuVariantName('my-model.GGUF'), 'q8_0');
      expect(detectVieneuVariantName('readme.md'), isNull);
    });
  });
}
