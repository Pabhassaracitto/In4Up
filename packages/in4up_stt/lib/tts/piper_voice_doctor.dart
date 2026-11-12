// packages/in4up_stt/lib/tts/piper_voice_doctor.dart
//
// PSRC-187 (audit 1.27.0) — "KHÁM" một giọng Piper TRƯỚC khi đưa xuống
// sherpa-onnx, và "CHỮA" những gì chữa được.
//
// VÌ SAO: sherpa-onnx (C++) không ném lỗi khi model/tokens/espeak không đúng ý
// nó — nó gọi `_Exit(-1)` (macro SHERPA_ONNX_EXIT), còn espeak-ng gọi
// `exit(1)`. Cả tiến trình app biến mất, Dart `try/catch` không bắt được.
// Mọi điều kiện dưới đây đã được ĐỐI CHIẾU với sherpa-onnx 1.13.6 thật (bản
// Python cùng lõi native) trên giọng thật `vi_VN-vais1000-medium`:
//
//   1. Model thiếu metadata `sample_rate` / `n_speakers` / `language` /
//      `comment` ⇒ `_Exit(-1)` ("'sample_rate' does not exist in the
//      metadata"). Giọng Piper GỐC của rhasspy (`<voice>.onnx` +
//      `<voice>.onnx.json`, tải từ HuggingFace) KHÔNG có metadata này — chỉ
//      bản k2-fsa `vits-piper-*.tar.bz2` mới có. App nhận cả hai loại (import
//      bộ `.onnx.json`, đường tải HuggingFace dự phòng) ⇒ giọng gốc làm app
//      văng ngay câu đầu tiên.
//   2. `comment` không chứa piper/coqui/icefall/Inflect (và không phải
//      frontend "characters") trong khi app không cấp lexicon ⇒ `_Exit(-1)`.
//   3. tokens.txt: ký hiệu trùng, ký hiệu nhiều code point, thừa cột, dòng
//      trống (kể cả dòng trống CUỐI file), xuống dòng kiểu Windows (CRLF),
//      BOM đầu file ⇒ `_Exit(-1)`; thiếu `_` `^` `$` ⇒ ngoại lệ C++ không ai
//      bắt.
//   4. espeak-ng-data thiếu một trong `phontab` / `phonindex` / `phondata` /
//      `intonations` ⇒ espeak `exit(1)`. Chốt cũ chỉ kiểm `phontab`.
//
// CÁCH CHỮA metadata: script chuyển đổi chính thức của sherpa-onnx chỉ làm
// đúng hai việc với giọng Piper gốc — sinh tokens.txt từ `phoneme_id_map` (app
// đã làm) và THÊM 7 mục `metadata_props` lấy từ `<voice>.onnx.json`. Vì
// `metadata_props` là trường lặp (field 14) của `ModelProto`, protobuf cho phép
// NỐI các mục đó vào cuối file mà không cần đọc lại model 60 MB. Đã kiểm: file
// gốc + 131 byte nối thêm ⇒ `onnx.checker` hợp lệ và sherpa-onnx đọc/đọc được
// tiếng.
//
// File này là hàm THUẦN (không I/O) để test được trên host VM. Phần đọc/ghi
// file nằm ở `SherpaPiperTtsCore`.

import 'dart:convert';
import 'dart:typed_data';

/// Metadata sherpa-onnx BẮT BUỘC có ở model VITS (thiếu ⇒ `_Exit(-1)`).
const List<String> kSherpaVitsRequiredMetadata = <String>[
  'sample_rate',
  'n_speakers',
  'language',
  'comment',
];

/// File espeak-ng-data mà espeak nạp lúc khởi tạo (thiếu ⇒ `exit(1)`).
const List<String> kEspeakRequiredDataFiles = <String>[
  'phontab',
  'phonindex',
  'phondata',
  'intonations',
];

/// `metadata_props` nằm sát CUỐI file ONNX (field 14, sau graph) ⇒ đọc bấy
/// nhiêu byte cuối là đủ.
const int kOnnxMetadataTailBytes = 64 * 1024;

/// Chuỗi byte đánh dấu mục metadata `sample_rate` trong file ONNX:
/// `0x0A <độ dài key = 11> "sample_rate" 0x12`. Dùng để dò TOÀN file khi đuôi
/// không thấy metadata (phòng model được ghi theo thứ tự trường khác).
final Uint8List kOnnxSampleRateKeyNeedle = Uint8List.fromList(<int>[
  0x0A,
  0x0B,
  ...ascii.encode('sample_rate'),
  0x12,
]);

class _MetadataEntry {
  const _MetadataEntry(this.key, this.value, this.end);

  final String key;
  final String value;
  final int end;
}

class _Reader {
  _Reader(this.bytes, this.pos);

  final Uint8List bytes;
  int pos;

  /// Đọc một varint (tối đa 5 byte). Trả -1 nếu hỏng/hết dữ liệu.
  int varint() {
    var result = 0;
    var shift = 0;
    for (var n = 0; n < 5; n++) {
      if (pos >= bytes.length) return -1;
      final byte = bytes[pos++];
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) return result;
      shift += 7;
    }
    return -1;
  }
}

_MetadataEntry? _tryReadMetadataEntry(Uint8List b, int start) {
  final r = _Reader(b, start + 1);
  final length = r.varint();
  if (length < 2) return null;
  final end = r.pos + length;
  if (end > b.length) return null;

  if (b[r.pos] != 0x0A) return null; // StringStringEntryProto.key
  r.pos++;
  final keyLength = r.varint();
  if (keyLength < 1 || keyLength > 128 || r.pos + keyLength > end) return null;
  for (var k = r.pos; k < r.pos + keyLength; k++) {
    final c = b[k];
    if (c < 0x21 || c > 0x7E) return null; // key là ASCII in được
  }
  final key = String.fromCharCodes(b, r.pos, r.pos + keyLength);
  r.pos += keyLength;

  if (r.pos == end) return _MetadataEntry(key, '', end);
  if (b[r.pos] != 0x12) return null; // StringStringEntryProto.value
  r.pos++;
  final valueLength = r.varint();
  if (valueLength < 0 || r.pos + valueLength != end) return null;
  final String value;
  try {
    value = utf8.decode(Uint8List.sublistView(b, r.pos, end));
  } catch (_) {
    return null;
  }
  return _MetadataEntry(key, value, end);
}

/// Đọc các mục `metadata_props` có trong [bytes] (thường là
/// [kOnnxMetadataTailBytes] byte cuối của file ONNX).
///
/// Không parse cả model: dò mẫu `0x72 <len> { 0x0A <klen> key 0x12 <vlen>
/// value }` và chỉ nhận khi MỌI độ dài khớp nhau + key là ASCII in được, nên
/// dữ liệu trọng số ngẫu nhiên không thể giả thành metadata.
Map<String, String> readOnnxMetadataProps(Uint8List bytes) {
  final out = <String, String>{};
  var i = 0;
  while (i < bytes.length) {
    if (bytes[i] != 0x72) {
      i++;
      continue;
    }
    final entry = _tryReadMetadataEntry(bytes, i);
    if (entry == null) {
      i++;
      continue;
    }
    out[entry.key] = entry.value;
    i = entry.end;
  }
  return out;
}

/// [needle] có nằm trong [haystack] không (dò byte).
bool containsBytes(Uint8List haystack, Uint8List needle) {
  if (needle.isEmpty) return true;
  final first = needle[0];
  final last = haystack.length - needle.length;
  for (var i = 0; i <= last; i++) {
    if (haystack[i] != first) continue;
    var matched = true;
    for (var j = 1; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}

void _writeVarint(BytesBuilder out, int value) {
  var v = value;
  while (v >= 0x80) {
    out.addByte((v & 0x7F) | 0x80);
    v >>= 7;
  }
  out.addByte(v);
}

/// Các byte cần NỐI vào cuối file ONNX để thêm [entries] vào
/// `metadata_props` (field 14 của `ModelProto`, mỗi mục là một
/// `StringStringEntryProto { key = 1; value = 2; }`).
Uint8List encodeOnnxMetadataProps(Map<String, String> entries) {
  final out = BytesBuilder();
  entries.forEach((key, value) {
    final k = utf8.encode(key);
    final v = utf8.encode(value);
    final body = BytesBuilder();
    body.addByte(0x0A);
    _writeVarint(body, k.length);
    body.add(k);
    body.addByte(0x12);
    _writeVarint(body, v.length);
    body.add(v);
    final bodyBytes = body.toBytes();
    out.addByte(0x72);
    _writeVarint(out, bodyBytes.length);
    out.add(bodyBytes);
  });
  return out.toBytes();
}

/// `atoi` của C: lấy số nguyên ở đầu chuỗi, không có thì 0.
int _atoi(String text) {
  final match = RegExp(r'^\s*([+-]?\d+)').firstMatch(text);
  if (match == null) return 0;
  return int.tryParse(match.group(1)!) ?? 0;
}

/// Kết luận về metadata của một model VITS khi app nạp nó bằng
/// `OfflineTtsVitsModelConfig(model, tokens, dataDir)` (KHÔNG có lexicon).
class SherpaVitsMetadataVerdict {
  const SherpaVitsMetadataVerdict._(this.problem, this.usesPiperPhonemizer);

  /// `null` = sherpa-onnx nạp được. Khác null = mã lý do nó sẽ `_Exit`:
  /// `missing:<key>`, `negative:<key>`, `needs-lexicon`,
  /// `unsupported-frontend`.
  final String? problem;

  /// Model đi qua bộ phát âm Piper (espeak) ⇒ tokens.txt phải có `_ ^ $`.
  final bool usesPiperPhonemizer;

  bool get isSafe => problem == null;

  /// Chỉ thiếu metadata bắt buộc ⇒ có thể chữa bằng cách thêm metadata.
  bool get isMissingRequired => problem != null && problem!.startsWith('missing:');
}

/// Áp đúng các điều kiện `_Exit(-1)` của sherpa-onnx 1.13.6
/// (`offline-tts-vits-model.cc` + `InitFrontend` trong
/// `offline-tts-vits-impl.h`) lên [meta].
SherpaVitsMetadataVerdict assessSherpaVitsMetadata(Map<String, String> meta) {
  for (final key in kSherpaVitsRequiredMetadata) {
    final value = meta[key];
    if (value == null || value.isEmpty) {
      return SherpaVitsMetadataVerdict._('missing:$key', false);
    }
  }
  const integerKeys = <String>[
    'sample_rate',
    'n_speakers',
    'add_blank',
    'speaker_id',
    'version',
    'num_emotions',
    'jieba',
    'blank_id',
    'bos_id',
    'eos_id',
    'use_eos_bos',
    'pad_id',
    'has_g2pw',
  ];
  for (final key in integerKeys) {
    final value = meta[key];
    if (value != null && value.isNotEmpty && _atoi(value) < 0) {
      return SherpaVitsMetadataVerdict._('negative:$key', false);
    }
  }

  // Thứ tự rẽ nhánh giữ đúng như InitFrontend().
  if (meta['frontend'] == 'characters') {
    return const SherpaVitsMetadataVerdict._(null, false);
  }
  final comment = meta['comment']!;
  final jieba = _atoi(meta['jieba'] ?? '0') != 0;
  final g2pw = _atoi(meta['has_g2pw'] ?? '0') != 0;
  if (jieba || g2pw || comment.contains('melo')) {
    // Các nhánh này cần lexicon — app không cấp ⇒ native thoát.
    return const SherpaVitsMetadataVerdict._('needs-lexicon', false);
  }
  if (comment.contains('piper') ||
      comment.contains('coqui') ||
      comment.contains('icefall') ||
      comment.contains('Inflect')) {
    return const SherpaVitsMetadataVerdict._(null, true);
  }
  return const SherpaVitsMetadataVerdict._('unsupported-frontend', false);
}

/// Metadata sherpa-onnx suy ra từ config Piper `<voice>.onnx.json` — đúng 7
/// mục mà script chuyển đổi chính thức của sherpa-onnx ghi cho giọng Piper.
///
/// Trả `null` khi JSON không phải config Piper dùng espeak (thiếu
/// `espeak.voice` / `audio.sample_rate`, hoặc `phoneme_type` khác espeak) —
/// khi đó KHÔNG được đoán.
Map<String, String>? sherpaMetadataFromPiperConfig(String rawJson) {
  Object? decoded;
  try {
    decoded = jsonDecode(rawJson);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;

  final phonemeType = decoded['phoneme_type'];
  if (phonemeType is String &&
      phonemeType.isNotEmpty &&
      phonemeType.toLowerCase() != 'espeak') {
    return null;
  }

  final espeak = decoded['espeak'];
  final voice = espeak is Map ? espeak['voice'] : null;
  if (voice is! String || voice.trim().isEmpty) return null;

  final audio = decoded['audio'];
  final sampleRate = audio is Map ? audio['sample_rate'] : null;
  if (sampleRate is! int || sampleRate <= 0) return null;

  final speakersRaw = decoded['num_speakers'];
  final speakers = speakersRaw is int && speakersRaw > 0 ? speakersRaw : 1;

  var languageName = '';
  final language = decoded['language'];
  if (language is Map) {
    final english = language['name_english'];
    final code = language['code'];
    if (english is String && english.trim().isNotEmpty) {
      languageName = english.trim();
    } else if (code is String && code.trim().isNotEmpty) {
      languageName = code.trim();
    }
  }
  if (languageName.isEmpty) languageName = voice.trim();

  return <String, String>{
    'model_type': 'vits',
    'comment': 'piper',
    'language': languageName,
    'voice': voice.trim(),
    'has_espeak': '1',
    'n_speakers': '$speakers',
    'sample_rate': '$sampleRate',
  };
}

/// Chuẩn hoá tokens.txt về dạng sherpa-onnx đọc được mà KHÔNG đổi nội dung
/// bảng: bỏ BOM, đổi CRLF/CR thành LF, bỏ khoảng trắng cuối dòng, bỏ dòng
/// trống, kết thúc bằng đúng một `\n`.
///
/// Giữ nguyên khoảng trắng ĐẦU dòng: dòng `" 3"` là ký hiệu khoảng trắng.
String normalizePiperTokens(String content) {
  var text = content;
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final trailing = RegExp(r'[ \t]+$');
  final kept = <String>[];
  for (final line in text.split('\n')) {
    final trimmed = line.replaceFirst(trailing, '');
    if (trimmed.isEmpty) continue;
    kept.add(trimmed);
  }
  if (kept.isEmpty) return '';
  return '${kept.join('\n')}\n';
}

/// Kiểm tokens.txt theo đúng luật của `ReadTokens()` trong sherpa-onnx.
///
/// Trả `null` nếu native đọc được; ngược lại là mã lý do
/// (`empty`, `cr:<dòng>`, `control-char:<dòng>`, `blank:<dòng>`,
/// `trailing-space:<dòng>`, `bad-id:<dòng>`, `extra-field:<dòng>`,
/// `multi-codepoint:<dòng>`, `duplicate:<dòng>`, `missing-pad`,
/// `missing-bos-eos`).
///
/// [requirePiperSymbols]: model dùng bộ phát âm Piper ⇒ bắt buộc có `_`, `^`,
/// `$` (native tra bằng `.at()` — thiếu là ngoại lệ C++ không ai bắt).
String? validatePiperTokens(
  String content, {
  bool requirePiperSymbols = true,
}) {
  final lines = content.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
  if (lines.isEmpty) return 'empty';

  final seen = <int>{};
  final splitter = RegExp(r'[ \t]+');
  final integer = RegExp(r'^[+-]?\d+$');
  for (var n = 0; n < lines.length; n++) {
    final line = lines[n];
    final at = n + 1;
    if (line.contains('\r')) return 'cr:$at';
    if (line.contains('\v') || line.contains('\f')) return 'control-char:$at';
    final fields =
        line.split(splitter).where((field) => field.isNotEmpty).toList();
    if (fields.isEmpty) return 'blank:$at';
    if (line.endsWith(' ') || line.endsWith('\t')) return 'trailing-space:$at';

    final String symbol;
    if (fields.length == 1) {
      // Dòng chỉ có một cột = id của ký hiệu KHOẢNG TRẮNG.
      symbol = ' ';
    } else if (fields.length == 2) {
      if (!integer.hasMatch(fields[1])) return 'bad-id:$at';
      symbol = fields[0];
    } else {
      return 'extra-field:$at';
    }

    final runes = symbol.runes.toList(growable: false);
    if (runes.length != 1) {
      if (symbol == '<BLNK>') continue; // tokens của coqui-ai/TTS
      return 'multi-codepoint:$at';
    }
    if (!seen.add(runes.first)) return 'duplicate:$at';
  }

  if (requirePiperSymbols) {
    if (!seen.contains(0x5F)) return 'missing-pad'; // _
    if (!seen.contains(0x5E) || !seen.contains(0x24)) {
      return 'missing-bos-eos'; // ^ $
    }
  }
  return null;
}
