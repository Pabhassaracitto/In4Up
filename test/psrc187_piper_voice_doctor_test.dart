// test/psrc187_piper_voice_doctor_test.dart
//
// PSRC-187 (audit v1.27.0) — MÁY BẮT cho "đặt Piper ưu tiên đầu thì app sập".
//
// sherpa-onnx không ném lỗi khi giọng không đúng ý nó — nó `_Exit(-1)` (cả app
// biến mất, Dart không bắt được). Mọi luật trong `piper_voice_doctor.dart` đã
// được đối chiếu với sherpa-onnx 1.13.6 thật (bản Python cùng lõi native) trên
// giọng thật `vi_VN-vais1000-medium` tải từ rhasspy/piper-voices:
//   • model gốc: `metadata_props` RỖNG ⇒ tiến trình thoát mã 255
//     ("'sample_rate' does not exist in the metadata");
//   • nối 131 byte metadata vào cuối file ⇒ nạp được và đọc ra tiếng.
// Các hằng số byte bên dưới là NGUYÊN VĂN từ lần đối chiếu đó.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/tts/piper_voice_doctor.dart';

Uint8List _hex(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// 48 byte CUỐI của `vi_VN-vais1000-medium.onnx` gốc (đuôi graph +
/// opset_import) — không có mục metadata nào.
final Uint8List _rawModelTail = _hex(
  '6f75747075745f3012040a0208016a1a0a122f6465632f54616e685f6f757470'
  '75745f3012040a02080142040a00100f',
);

/// 131 byte đã nối vào giọng thật và được sherpa-onnx 1.13.6 chấp nhận:
/// model_type=vits, comment=piper, language=Vietnamese, voice=vi,
/// has_espeak=1, n_speakers=1, sample_rate=22050.
final Uint8List _acceptedMetadataTail = _hex(
  '72120a0a6d6f64656c5f7479706512047669747372100a07636f6d6d656e7412'
  '05706970657272160a086c616e6775616765120a566965746e616d657365720b'
  '0a05766f69636512027669720f0a0a6861735f65737065616b120131720f0a0a'
  '6e5f737065616b65727312013172140a0b73616d706c655f7261746512053232'
  '303530',
);

/// Phần liên quan của `vi_VN-vais1000-medium.onnx.json` (config Piper gốc).
const String _piperConfigJson = '''
{
  "audio": {"sample_rate": 22050, "quality": "medium"},
  "espeak": {"voice": "vi"},
  "inference": {"noise_scale": 0.667, "length_scale": 1, "noise_w": 0.8},
  "phoneme_id_map": {"_": [0], "^": [1], "\$": [2], " ": [3], "a": [14]},
  "num_symbols": 256,
  "num_speakers": 1,
  "piper_version": "1.0.0",
  "language": {"code": "vi_VN", "name_english": "Vietnamese"},
  "dataset": "vais1000"
}
''';

const Map<String, String> _piperMetadata = <String, String>{
  'model_type': 'vits',
  'comment': 'piper',
  'language': 'Vietnamese',
  'voice': 'vi',
  'has_espeak': '1',
  'n_speakers': '1',
  'sample_rate': '22050',
};

/// Bảng token tối thiểu hợp lệ kiểu Piper.
const String _goodTokens = '_ 0\n^ 1\n\$ 2\n  3\n! 4\na 14\n3 130\n';

Uint8List _concat(List<Uint8List> parts) {
  final builder = BytesBuilder();
  for (final part in parts) {
    builder.add(part);
  }
  return builder.toBytes();
}

String _stripComments(String source) {
  final withoutBlocks = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return withoutBlocks.split('\n').map((line) {
    final idx = line.indexOf('//');
    return idx >= 0 ? line.substring(0, idx) : line;
  }).join('\n');
}

void main() {
  group('PSRC-187 — metadata ONNX: giọng Piper GỐC làm sherpa-onnx thoát', () {
    test('đuôi model gốc của rhasspy KHÔNG có metadata ⇒ thiếu sample_rate',
        () {
      final meta = readOnnxMetadataProps(_rawModelTail);
      expect(meta, isEmpty,
          reason: 'đuôi graph không được bị đọc nhầm thành metadata');
      final verdict = assessSherpaVitsMetadata(meta);
      expect(verdict.isSafe, isFalse);
      expect(verdict.problem, 'missing:sample_rate');
      expect(verdict.isMissingRequired, isTrue);
    });

    test('thiếu từng key bắt buộc ⇒ đúng mã lý do của key đó', () {
      for (final key in kSherpaVitsRequiredMetadata) {
        final meta = Map<String, String>.from(_piperMetadata)..remove(key);
        expect(assessSherpaVitsMetadata(meta).problem, 'missing:$key');
      }
      // Có key nhưng RỖNG cũng là thiếu (macro READ_META_DATA kiểm empty()).
      final empty = Map<String, String>.from(_piperMetadata)..['language'] = '';
      expect(assessSherpaVitsMetadata(empty).problem, 'missing:language');
    });

    test('đủ metadata Piper ⇒ an toàn và đi qua bộ phát âm Piper', () {
      final verdict = assessSherpaVitsMetadata(_piperMetadata);
      expect(verdict.isSafe, isTrue);
      expect(verdict.problem, isNull);
      expect(verdict.usesPiperPhonemizer, isTrue);
    });

    test('comment không phải piper/coqui/icefall/Inflect ⇒ native thoát', () {
      final meta = Map<String, String>.from(_piperMetadata)
        ..['comment'] = 'something else';
      expect(assessSherpaVitsMetadata(meta).problem, 'unsupported-frontend');
      for (final ok in ['coqui', 'icefall', 'Inflect', 'piper-phonemize']) {
        final good = Map<String, String>.from(_piperMetadata)..['comment'] = ok;
        expect(assessSherpaVitsMetadata(good).isSafe, isTrue, reason: ok);
      }
    });

    test('model cần lexicon (jieba / g2pw / MeloTTS) ⇒ chặn', () {
      for (final extra in [
        {'jieba': '1'},
        {'has_g2pw': '1'},
        {'comment': 'melo piper'},
      ]) {
        final meta = Map<String, String>.from(_piperMetadata)..addAll(extra);
        expect(assessSherpaVitsMetadata(meta).problem, 'needs-lexicon',
            reason: '$extra');
      }
    });

    test('frontend "characters" ⇒ an toàn nhưng KHÔNG đòi ký hiệu Piper', () {
      final meta = Map<String, String>.from(_piperMetadata)
        ..['frontend'] = 'characters'
        ..['comment'] = 'mms';
      final verdict = assessSherpaVitsMetadata(meta);
      expect(verdict.isSafe, isTrue);
      expect(verdict.usesPiperPhonemizer, isFalse);
    });

    test('giá trị số ÂM ⇒ native thoát ("Invalid value")', () {
      final meta = Map<String, String>.from(_piperMetadata)
        ..['n_speakers'] = '-1';
      expect(assessSherpaVitsMetadata(meta).problem, 'negative:n_speakers');
    });
  });

  group('PSRC-187 — chữa giọng gốc: nối metadata vào cuối file ONNX', () {
    test('config Piper ⇒ đúng 7 mục metadata của script chuyển đổi sherpa-onnx',
        () {
      expect(sherpaMetadataFromPiperConfig(_piperConfigJson), _piperMetadata);
    });

    test('mã hoá ra ĐÚNG 131 byte mà sherpa-onnx thật đã chấp nhận', () {
      final derived = sherpaMetadataFromPiperConfig(_piperConfigJson)!;
      final bytes = encodeOnnxMetadataProps(derived);
      expect(bytes.length, 131);
      expect(bytes, _acceptedMetadataTail);
    });

    test('model gốc + phần nối ⇒ đọc lại đủ metadata và trở thành an toàn', () {
      final patched = _concat([_rawModelTail, _acceptedMetadataTail]);
      final meta = readOnnxMetadataProps(patched);
      expect(meta, _piperMetadata);
      expect(assessSherpaVitsMetadata(meta).isSafe, isTrue);
    });

    test('mã hoá ↔ đọc lại khớp nhau, kể cả giá trị dài (varint 2 byte) và '
        'tiếng Việt', () {
      final entries = <String, String>{
        'language': 'Tiếng Việt',
        'long': 'x' * 300,
        'sample_rate': '22050',
      };
      expect(readOnnxMetadataProps(encodeOnnxMetadataProps(entries)), entries);
    });

    test('chỉ thêm key còn thiếu vẫn ra model an toàn', () {
      // Model đã có sẵn model_type (do công cụ khác ghi) nhưng thiếu phần còn
      // lại ⇒ nối thêm đúng các key thiếu.
      final existing = encodeOnnxMetadataProps({'model_type': 'vits'});
      final meta0 = readOnnxMetadataProps(_concat([_rawModelTail, existing]));
      expect(meta0, {'model_type': 'vits'});
      final toAdd = <String, String>{
        for (final entry in _piperMetadata.entries)
          if ((meta0[entry.key] ?? '').isEmpty) entry.key: entry.value,
      };
      expect(toAdd.containsKey('model_type'), isFalse);
      final meta1 = readOnnxMetadataProps(
        _concat([_rawModelTail, existing, encodeOnnxMetadataProps(toAdd)]),
      );
      expect(assessSherpaVitsMetadata(meta1).isSafe, isTrue);
    });

    test('byte 0x72 lẫn trong trọng số KHÔNG bị đọc thành metadata', () {
      // 0x72 theo sau bởi độ dài không khớp / key không in được.
      final noise = Uint8List.fromList(<int>[
        0x72, 0x05, 0x0A, 0x03, 0x00, 0x01, 0x02, // key có byte điều khiển
        0x72, 0x7F, 0x0A, 0x01, 0x41, // độ dài vượt quá dữ liệu
        0x72, 0x04, 0x0B, 0x02, 0x41, 0x42, // không bắt đầu bằng 0x0A
        0x72, 0x06, 0x0A, 0x01, 0x41, 0x12, 0x05, 0x42, // value dài hơn khai
      ]);
      expect(readOnnxMetadataProps(noise), isEmpty);
    });

    test('dấu vết "sample_rate" dùng để dò toàn file khớp với mục đã mã hoá',
        () {
      expect(containsBytes(_acceptedMetadataTail, kOnnxSampleRateKeyNeedle),
          isTrue);
      expect(containsBytes(_rawModelTail, kOnnxSampleRateKeyNeedle), isFalse);
      expect(containsBytes(Uint8List(0), kOnnxSampleRateKeyNeedle), isFalse);
    });

    test('config không phải Piper-espeak ⇒ null (không đoán)', () {
      expect(sherpaMetadataFromPiperConfig('không phải json'), isNull);
      expect(sherpaMetadataFromPiperConfig('[]'), isNull);
      expect(
        sherpaMetadataFromPiperConfig('{"audio": {"sample_rate": 22050}}'),
        isNull,
        reason: 'thiếu espeak.voice',
      );
      expect(
        sherpaMetadataFromPiperConfig('{"espeak": {"voice": "vi"}}'),
        isNull,
        reason: 'thiếu audio.sample_rate',
      );
      expect(
        sherpaMetadataFromPiperConfig(
          '{"audio": {"sample_rate": 22050}, "espeak": {"voice": "vi"}, '
          '"phoneme_type": "text"}',
        ),
        isNull,
        reason: 'giọng theo ký tự, không phải espeak',
      );
    });

    test('config thiếu tên ngôn ngữ / số người nói ⇒ vẫn ra metadata hợp lệ',
        () {
      final meta = sherpaMetadataFromPiperConfig(
        '{"audio": {"sample_rate": 16000}, "espeak": {"voice": "en-us"}}',
      )!;
      expect(meta['sample_rate'], '16000');
      expect(meta['n_speakers'], '1');
      expect(meta['language'], 'en-us');
      expect(assessSherpaVitsMetadata(meta).isSafe, isTrue);
    });
  });

  group('PSRC-187 — tokens.txt theo luật ReadTokens() của sherpa-onnx', () {
    test('bảng token Piper chuẩn ⇒ hợp lệ', () {
      expect(validatePiperTokens(_goodTokens), isNull);
      // Không có xuống dòng cuối cũng được.
      expect(
        validatePiperTokens(_goodTokens.substring(0, _goodTokens.length - 1)),
        isNull,
      );
    });

    test('các dạng làm native thoát đều bị bắt, kèm số dòng', () {
      expect(validatePiperTokens(''), 'empty');
      expect(validatePiperTokens('${_goodTokens}a 200\n'), 'duplicate:8');
      expect(validatePiperTokens('${_goodTokens}ab 200\n'), 'multi-codepoint:8');
      expect(validatePiperTokens('${_goodTokens}q 200 extra\n'),
          'extra-field:8');
      expect(validatePiperTokens('${_goodTokens}q 20x\n'), 'bad-id:8');
      expect(validatePiperTokens('$_goodTokens\n\n'), 'blank:8',
          reason: 'dòng trống CUỐI file bị native đọc thành ký hiệu khoảng '
              'trắng lần hai ⇒ "Duplicated token"');
      expect(validatePiperTokens('_ 0\n\n^ 1\n\$ 2\n'), 'blank:2');
      expect(validatePiperTokens('${_goodTokens}q 200 \n'), 'trailing-space:8');
      expect(validatePiperTokens('${_goodTokens}q\v9\n'), 'control-char:8');
    });

    test('CRLF: dòng khoảng trắng " 3\\r" bị native đọc thành ký hiệu "3"', () {
      final crlf = _goodTokens.replaceAll('\n', '\r\n');
      expect(validatePiperTokens(crlf), 'cr:1');
    });

    test('BOM đầu file ⇒ ký hiệu đầu thành 2 code point', () {
      expect(validatePiperTokens('\uFEFF$_goodTokens'), 'multi-codepoint:1');
    });

    test('thiếu _ ^ \$ ⇒ native tra `.at()` ném ngoại lệ C++', () {
      expect(validatePiperTokens('^ 1\n\$ 2\n  3\na 14\n'), 'missing-pad');
      expect(validatePiperTokens('_ 0\n\$ 2\n  3\na 14\n'), 'missing-bos-eos');
      expect(validatePiperTokens('_ 0\n^ 1\n  3\na 14\n'), 'missing-bos-eos');
      // Frontend "characters" không dùng các ký hiệu đó.
      expect(
        validatePiperTokens('a 1\nb 2\n', requirePiperSymbols: false),
        isNull,
      );
    });

    test('tab làm dấu ngăn, id âm, ký hiệu <BLNK> ⇒ native chấp nhận', () {
      expect(validatePiperTokens(_goodTokens.replaceAll(' ', '\t')), isNull);
      expect(validatePiperTokens('${_goodTokens}q -5\n'), isNull);
      expect(validatePiperTokens('$_goodTokens<BLNK> 300\n'), isNull);
    });

    test('chuẩn hoá chữa được BOM + CRLF + dòng trống + khoảng trắng cuối dòng',
        () {
      final crlf = _goodTokens.replaceAll('\n', '\r\n');
      final broken = '\uFEFF$crlf\r\n   \r\nq 200  \r\n\r\n';
      expect(validatePiperTokens(broken), isNotNull);
      final fixed = normalizePiperTokens(broken);
      expect(fixed, '${_goodTokens}q 200\n');
      expect(validatePiperTokens(fixed), isNull);
    });

    test('chuẩn hoá GIỮ khoảng trắng đầu dòng (dòng ký hiệu khoảng trắng)', () {
      expect(normalizePiperTokens('_ 0\n  3\n'), '_ 0\n  3\n');
      expect(normalizePiperTokens(_goodTokens), _goodTokens,
          reason: 'file đã chuẩn thì không đổi một byte');
      expect(normalizePiperTokens('\n \n\t\n'), '');
    });

    test('chuẩn hoá KHÔNG che lỗi nội dung (trùng / nhiều code point)', () {
      expect(
        validatePiperTokens(normalizePiperTokens('${_goodTokens}a 200\r\n')),
        'duplicate:8',
      );
    });
  });

  group('PSRC-187 — espeak-ng-data', () {
    test('đủ 4 file mà espeak nạp lúc khởi tạo (chốt cũ chỉ có phontab)', () {
      expect(kEspeakRequiredDataFiles,
          ['phontab', 'phonindex', 'phondata', 'intonations']);
    });
  });

  group('PSRC-187 — SherpaPiperTtsCore dùng đúng các chốt trên', () {
    late final String core;
    late final String engine;

    setUpAll(() {
      core = _stripComments(
        File('packages/in4up_stt/lib/tts/sherpa_piper_tts_core.dart')
            .readAsStringSync(),
      );
      engine = _stripComments(
        File('lib/features/tts/engines/piper_tts_engine.dart')
            .readAsStringSync(),
      );
    });

    test('mỗi lượt chạy model chỉ MỘT câu (100 ⇒ 3,4 GB cho 2751 ký tự)', () {
      expect(
        RegExp(r'const int kPiperMaxSentencesPerBatch = 1;').hasMatch(core),
        isTrue,
      );
      expect(core.contains('maxNumSenetences: kPiperMaxSentencesPerBatch'),
          isTrue);
      expect(RegExp(r'maxNumSenetences:\s*\d').hasMatch(core), isFalse,
          reason: 'không được ghi cứng số câu (bản cũ: 100)');
    });

    test('khám giọng TRƯỚC khi gửi lệnh nạp xuống worker', () {
      final select = core.indexOf('Future<bool> selectVoice(');
      expect(select, greaterThanOrEqualTo(0));
      final body = core.substring(select);
      final exam = body.indexOf('examineVoice(voice)');
      final native = body.indexOf("'select'");
      expect(exam, greaterThanOrEqualTo(0));
      expect(native, greaterThan(exam),
          reason: 'examineVoice phải chạy trước lệnh select của worker');
    });

    test('espeak: kiểm đủ danh sách file bắt buộc, không chỉ phontab', () {
      expect(core.contains('kEspeakRequiredDataFiles'), isTrue);
      expect(core.contains("'phontab'"), isFalse,
          reason: 'không còn chốt riêng lẻ cho phontab');
    });

    test('vá metadata trên BẢN SAO rồi đổi tên (không ghi dở file model)', () {
      final start = core.indexOf('_appendModelMetadata(');
      expect(start, greaterThanOrEqualTo(0));
      expect(core.contains('.meta.tmp'), isTrue);
      expect(core.contains('encodeOnnxMetadataProps(entries)'), isTrue);
      expect(core.contains('tmp.rename(modelPath)'), isTrue);
    });

    test('OfflineTts chỉ được tạo trong worker (không còn trên luồng UI)', () {
      final factory = core.indexOf('IsolateRpcHandler _piperWorkerFactory()');
      final klass = core.indexOf('class SherpaPiperTtsCore');
      expect(factory, greaterThanOrEqualTo(0));
      expect(klass, greaterThan(factory));
      final classBody = core.substring(klass);
      expect(classBody.contains('sherpa.OfflineTts('), isFalse,
          reason: 'lời gọi native đồng bộ trên luồng UI = đứng hình/ANR');
      expect(classBody.contains('generateWithConfig('), isFalse);
    });

    test('engine báo đúng lý do giọng bị từ chối', () {
      expect(engine.contains('_core.lastProblem'), isTrue);
    });
  });

  group('PSRC-187 — vieneu worker: cấp phát đúng kích thước', () {
    test('không còn calloc.allocate<T>(1) (1 BYTE cho con trỏ 8 byte)', () {
      final code = _stripComments(
        File('packages/in4up_stt/lib/tts/vieneu_tts_core.dart')
            .readAsStringSync(),
      );
      expect(code.contains('calloc.allocate<'), isFalse);
      expect(code.contains('calloc<Pointer<Float>>()'), isTrue);
      expect(code.contains('calloc<Uint64>()'), isTrue);
      expect(code.contains('calloc<Int32>()'), isTrue);
    });

    test('json config mẫu trong test là JSON hợp lệ', () {
      expect(jsonDecode(_piperConfigJson), isA<Map<String, dynamic>>());
    });
  });
}
