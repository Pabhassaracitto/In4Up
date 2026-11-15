// test/tts/psrc171_voice_creation_test.dart — PSRC-171
//
// "Máy bắt" cho chuỗi import model → nạp engine → tạo giọng từ mẫu thu âm →
// đọc. Ba lỗi gốc của PSRC-171 (điện thoại báo "Không thể tạo giọng" mãi
// không hết) và bất biến khoá lại từng lỗi:
//
//   1. **Không có model spec.** audio.cpp v0.9.4 chỉ nhúng `model_specs/*.json`
//      vào libaudiocpp.so khi build với `AUDIOCPP_DEPLOYMENT_BUILD=ON` (mặc
//      định OFF), và các option `AUDIOCPP_MODEL_SET` / `AUDIOCPP_MODELS` mà
//      bản 1.28 truyền vào KHÔNG tồn tại ⇒ `audiocpp_model_load` ném
//      "model spec not found for family 'vietneu_tts'". Wrapper nay nhúng
//      spec của đúng family (sinh lúc configure từ submodule đã ghim) và chỉ
//      ghi ra cạnh model khi audio.cpp thật sự cần, rồi nạp lại với
//      `model_spec_override`.
//   2. **"Tạo giọng" không mã hoá gì.** `vieneu_tts_clone_voice` cũ ghi
//      `speaker.emb.txt` gồm 256 số 0 (placeholder) và trả THÀNH CÔNG, còn
//      audio.cpp từ chối file embedding đó ("must contain exactly 192 float
//      values") ⇒ giọng vừa tạo không bao giờ đọc được. Nay native đưa PCM
//      mẫu cho audio.cpp với `encode_reference_only` và ghi **ref codes**.
//   3. **Thông báo sai nguyên nhân.** Lỗi nạp model bị UI hiển thị thành
//      "kiểm tra mô hình TTS và mẫu thu âm". Nay lỗi native được PHÂN LOẠI
//      (model spec / từ điển / dữ liệu giọng / khác) trước khi hiện.
//
// Thuần đọc file + logic Dart thuần — không plugin, không native lib, không
// isolate. Build native thật do `vieneu_engine_build.yml` làm.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/tts/vieneu_tts_paths.dart';

String _read(String path) => File(path).readAsStringSync();

/// Bỏ dòng comment `//` (source-scan không được bắt chữ nằm trong giải thích).
String _codeOnly(String src) => src
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// Như [_codeOnly] cho CMake (`#`).
String _codeOnlyHash(String src) => src
    .split('\n')
    .where((line) =>
        !line.trimLeft().startsWith('//') && !line.trimLeft().startsWith('#'))
    .join('\n');

void main() {
  group('PSRC-171 · model spec — engine nạp được model đã import', () {
    final cmake = _codeOnlyHash(_read('android/vieneu/CMakeLists.txt'));
    final wrapper = _codeOnly(_read('native/tts_vieneu/vieneu_tts.cpp'));
    final template = _read('native/tts_vieneu/model_spec.inc.in');

    test('CMake nhúng spec của family từ submodule đã ghim', () {
      expect(cmake.contains('model_specs/vieneu_v3_turbo.json'), isTrue,
          reason: 'Spec phải lấy từ đúng file của audio.cpp đã ghim');
      expect(cmake.contains('configure_file('), isTrue);
      expect(cmake.contains('native/tts_vieneu/model_spec.inc.in'), isTrue);
      expect(cmake.contains('CMAKE_CURRENT_BINARY_DIR}/vieneu_model_spec.inc'),
          isTrue,
          reason: 'Include dir phải trỏ tới file sinh ở configure time');
      expect(cmake.contains('CMAKE_CONFIGURE_DEPENDS'), isTrue,
          reason: 'Sửa spec trong submodule phải khiến CMake configure lại');
      expect(cmake.contains('AUDIOCPP_V3_TURBO_SPEC_JSON'), isTrue);
    });

    test('KHÔNG dùng lại các option không tồn tại của audio.cpp v0.9.4', () {
      // Hai option này là no-op ở v0.9.4 ⇒ truyền vào chỉ tạo cảm giác an toàn
      // trong khi spec vẫn thiếu (đúng cái bẫy của bản 1.28).
      expect(cmake.contains('AUDIOCPP_MODEL_SET'), isFalse,
          reason: 'AUDIOCPP_MODEL_SET không tồn tại trong audio.cpp v0.9.4');
      expect(cmake.contains('AUDIOCPP_MODELS'), isFalse,
          reason: 'AUDIOCPP_MODELS không tồn tại trong audio.cpp v0.9.4');
    });

    test('mẫu inc là raw string, không nội suy gì thêm', () {
      expect(template.contains(r'R"in4up_spec('), isTrue);
      expect(template.contains(')in4up_spec"'), isTrue);
      expect(template.contains('@AUDIOCPP_V3_TURBO_SPEC_EMBEDDED@'), isTrue);
      // Chỉ DUY NHẤT một chỗ thay thế nội dung json (chỗ thứ hai sẽ làm hỏng
      // raw string, đúng lỗi gặp khi viết bản đầu của template).
      expect(
        RegExp(r'@AUDIOCPP_V3_TURBO_SPEC_JSON@').allMatches(template).length,
        1,
      );
    });

    test('wrapper include spec nhúng và truyền model_spec_override', () {
      expect(wrapper.contains('#include "vieneu_model_spec.inc"'), isTrue);
      expect(wrapper.contains('model_config.model_spec_override ='),
          isTrue,
          reason: 'audiocpp_model_config.model_spec_override là đường duy nhất '
              'đưa spec cho audio.cpp mà không phải build lại upstream');
      expect(wrapper.contains('materialize_embedded_model_spec(folder)'), isTrue,
          reason: 'Spec phải được ghi CẠNH model (thư mục app ghi được), '
              'không dùng /tmp — Android không có /tmp writable');
    });

    test('chỉ thử lại khi lỗi ĐÚNG là model spec', () {
      expect(wrapper.contains('first_error.find("model spec")'), isTrue,
          reason: 'Nạp lại 188 MB vì file hỏng/hết RAM chỉ tốn pin');
      // Lỗi gốc phải được giữ lại trong thông báo cuối cùng.
      expect(wrapper.contains('lỗi gốc: '), isTrue);
    });
  });

  group('PSRC-171 · tạo giọng từ mẫu — ref codes thật', () {
    final wrapper = _codeOnly(_read('native/tts_vieneu/vieneu_tts.cpp'));
    final header = _codeOnly(_read('native/tts_vieneu/vieneu_tts.h'));

    test('native mã hoá mẫu bằng chính model (encode_reference_only)', () {
      expect(wrapper.contains('audiocpp_request_set_voice_audio('), isTrue);
      expect(wrapper.contains('"encode_reference_only"'), isTrue);
      expect(wrapper.contains('AUDIOCPP_ARTIFACT_ACOUSTIC_TOKENS'), isTrue,
          reason: 'Ref codes là artifact acoustic-tokens của audio.cpp');
      expect(wrapper.contains('encode_reference_only'), isTrue);
    });

    test('clone cần handle: bộ mã hoá giọng nằm trong model', () {
      expect(
        RegExp(r'vieneu_tts_clone_voice\(\s*vieneu_tts_handle handle')
            .hasMatch(wrapper),
        isTrue,
        reason: 'Bản cũ không có handle nên không thể mã hoá gì — đó là lý do '
            'nó chỉ ghi được file placeholder',
      );
      expect(header.contains('vieneu_tts_handle handle'), isTrue);
    });

    test('KHÔNG còn ghi embedding placeholder 256 số 0', () {
      expect(wrapper.contains('const int embedding_dim = 256;'), isFalse,
          reason: 'Đây là nguồn của "giọng tạo ra không đọc được"');
      expect(wrapper.contains('emb_file << 0.0f'), isFalse);
      expect(wrapper.contains('libspeaker_encoder.so'), isFalse,
          reason: 'audio.cpp v3 Turbo không cần speaker encoder rời: ref codes '
              'đã đủ mô tả giọng');
    });

    test('dọn embedding placeholder cũ trong thư mục giọng', () {
      expect(wrapper.contains('fs::remove(voice_dir / "speaker.emb.txt"'),
          isTrue,
          reason: 'File 256 số 0 của bản 1.28 nằm lại sẽ làm MỌI lần đọc lỗi '
              '"must contain exactly 192 float values"');
    });

    test('ref codes ghi ra đúng file engine quét (ref_codes.txt)', () {
      expect(wrapper.contains('is_valid_voice_file(output_ref_codes_path)'),
          isTrue,
          reason: 'Ghi xong phải tự kiểm — không báo thành công với file rỗng');
    });

    test('đọc được WAV của app ghi (PCM16) và WAV import (float/24-bit)', () {
      expect(wrapper.contains('memcmp(header, "RIFF", 4)'), isTrue);
      expect(wrapper.contains('memcmp(header + 8, "WAVE", 4)'), isTrue);
      expect(wrapper.contains('memcmp(chunk, "fmt ", 4)'), isTrue);
      expect(wrapper.contains('read_le_u16(fmt + 14)'), isTrue,
          reason: 'bits per sample');
      expect(wrapper.contains('format == 3'), isTrue, reason: 'IEEE float');
      expect(wrapper.contains('0xFFFE'), isTrue,
          reason: 'WAVE_FORMAT_EXTENSIBLE (WAV từ nhiều máy/DAW)');
      expect(wrapper.contains('0x800000'), isTrue,
          reason: 'PCM 24-bit phải xử lý dấu');
      // Chunk lẻ chỉ được cộng 1 byte đệm MỘT lần; cộng hai lần làm mất chunk
      // `data` (bắt được bằng harness WAV có LIST chunk).
      expect(wrapper.contains('in.seekg(chunk_size, std::ios::cur);'), isTrue);
      expect(wrapper.contains('chunk_size + (chunk_size & 1u)'), isFalse);
    });

    test('giới hạn 8 giây tham chiếu như upstream (_MAX_REF_SECONDS)', () {
      expect(wrapper.contains('kMaxReferenceSeconds'), isTrue);
      final match =
          RegExp(r'kMaxReferenceSeconds = ([0-9.]+);').firstMatch(wrapper);
      expect(match, isNotNull);
      expect(double.parse(match!.group(1)!), lessThanOrEqualTo(8.0),
          reason: 'encode_reference_codes của audio.cpp cắt ở 8 s — cắt sớm '
              'để không nạp cả bản ghi dài vào RAM');
    });
  });

  group('PSRC-171 · Dart: protocol + phân loại lỗi', () {
    final core = _codeOnly(
        _read('packages/in4up_stt/lib/tts/vieneu_tts_core.dart'));
    final engine =
        _codeOnly(_read('lib/features/tts/engines/vieneu_tts_engine.dart'));
    final widget =
        _codeOnly(_read('lib/features/tts/widgets/voice_clone_section.dart'));

    test('worker nhận handle và trả ref codes', () {
      expect(core.contains("'outputRefCodes': outputRefCodes"), isTrue);
      expect(core.contains("'refCodesPath': outputRefCodes"), isTrue);
      expect(core.contains('_handle!,'), isTrue,
          reason: 'clone_voice phải chạy trên engine ĐÃ nạp model');
      expect(core.contains("p.join(p.dirname(samplesDir), 'ref_codes.txt')"),
          isTrue);
      expect(core.contains('Pointer<Void>,  // handle (engine đã nạp model)'),
          isTrue,
          reason: 'FFI signature phải khớp native/tts_vieneu/vieneu_tts.h');
    });

    test('kind của lỗi nạp model được suy ra từ thông điệp native', () {
      expect(
        classifyVieneuNativeLoadError(
            "vieneu_tts_create: nạp model thất bại: model spec not found for "
            "family 'vietneu_tts' (provide --model-spec-override, embed it in "
            'the GGUF, enable AUDIOCPP_DEPLOYMENT_BUILD, or install '
            'model_specs/vietneu_tts.json)'),
        VieneuEngineBlocker.modelSpecMissing,
      );
      expect(
        classifyVieneuNativeLoadError(
            'vieneu_tts_create: nạp model thất bại: missing sea_g2p.bin next '
            'to the model'),
        VieneuEngineBlocker.noPhonemeDictionary,
      );
      expect(
        classifyVieneuNativeLoadError(
            'Speaker embedding file x must contain exactly 192 float values, '
            'but got 256'),
        VieneuEngineBlocker.voiceDataUnusable,
      );
      expect(
        classifyVieneuNativeLoadError('std::bad_alloc: out of memory'),
        VieneuEngineBlocker.engineLoadFailed,
      );
    });

    test('mỗi lý do có câu riêng, không câu nào đổ lỗi cho mẫu thu âm', () {
      final messages = <VieneuEngineBlocker, String>{
        for (final blocker in VieneuEngineBlocker.values)
          blocker: vieneuEngineBlockerMessage(blocker),
      };
      expect(messages.values.every((m) => m.trim().isNotEmpty), isTrue);
      expect(messages.values.toSet().length, VieneuEngineBlocker.values.length,
          reason: 'Hai lý do khác nhau không được dùng chung một câu');
      // Câu "kiểm tra mô hình TTS và mẫu thu âm" là câu bị ticket chỉ ra.
      expect(
        messages.values.any((m) => m.contains('mẫu thu âm')),
        isFalse,
        reason: 'Lỗi engine không được đổ cho mẫu thu âm (PSRC-171)',
      );
      expect(
        vieneuEngineBlockerMessage(VieneuEngineBlocker.modelSpecMissing)
            .contains('model spec'),
        isTrue,
        reason: 'Phải nói đúng thứ còn thiếu để người dùng/log tìm được',
      );
    });

    test('engine dùng classification + loại embedding hỏng', () {
      expect(engine.contains('classifyVieneuNativeLoadError(_lastInitError!)'),
          isTrue);
      expect(engine.contains('_hasUsableEmbedding(emb)'), isTrue,
          reason: 'Không được truyền embedding sai số chiều xuống native');
      expect(engine.contains('isUsableVieneuSpeakerEmbedding('), isTrue);
    });

    test('UI nói lý do cụ thể, không còn "thành công một nửa"', () {
      expect(widget.contains('_CloneNotice.notReady'), isTrue);
      expect(widget.contains('_CloneNotice.successPlaceholder'), isFalse);
      expect(widget.contains('refCodesFile: refCodesPath'), isTrue);
      expect(widget.contains('speakerEmbeddingFile: embeddingPath'), isFalse);
    });
  });

  group('PSRC-171 · hợp đồng dữ liệu giọng', () {
    test('embedding chỉ dùng khi đúng 192 giá trị trên dòng đầu', () {
      expect(isUsableVieneuSpeakerEmbedding(List.filled(192, '0.5').join(',')),
          isTrue);
      expect(
          isUsableVieneuSpeakerEmbedding(
              '256\n${List.filled(256, '0.0').join(' ')}\n'),
          isFalse);
      expect(isUsableVieneuSpeakerEmbedding(''), isFalse);
    });

    test('ref codes thật là các dòng toàn số nguyên', () {
      expect(hasVieneuRefCodes('10 20 30\n40 50 60\n'), isTrue);
      expect(hasVieneuRefCodes('# VieNeu-TTS default\n'), isFalse);
      expect(vieneuRefCodeFrames('1 2\n3 4\n5 6\n'), 3);
    });

    test('native chỉ đặt speaker_embedding_file khi KHÔNG có ref codes', () {
      final wrapper = _codeOnly(_read('native/tts_vieneu/vieneu_tts.cpp'));
      expect(wrapper.contains('const bool has_ref_codes ='), isTrue);
      expect(wrapper.contains('!has_ref_codes && !ctx->speaker_embedding_file.empty()'),
          isTrue,
          reason: 'Giọng có ref codes không được kéo theo embedding cũ/hỏng');
    });
  });
}
