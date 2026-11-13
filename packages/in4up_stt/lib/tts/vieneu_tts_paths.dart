// packages/in4up_stt/lib/tts/vieneu_tts_paths.dart
//
// PSRC-183..186 — các quy tắc THUẦN LOGIC (không platform channel, không
// isolate) của luồng import model / giọng VieNeu-TTS. Tách ra để test máy
// bắt được lỗi lệch quy ước giữa TtsService (copy file), engine (đọc danh
// sách giọng) và native (clone giọng).
//
// Quy ước dữ liệu (khớp `native/tts_vieneu/vieneu_tts.cpp`):
//   documents/vieneu_tts/
//     ├── vieneu-v3-turbo-q8_0.gguf
//     ├── voices/<voiceId>/ref_codes.txt | speaker.emb.txt | ref_codes.bin
//     └── cloned_voices/<voiceId>/{samples/*.wav, speaker.emb.txt}

import 'dart:convert';

import 'package:path/path.dart' as p;

/// Đuôi file mẫu mà native `vieneu_tts_clone_voice` thực sự đọc được.
///
/// Bản cũ cho import `.mp3/.m4a/.flac/.ogg` rồi native trả lỗi
/// "không tìm thấy file WAV mẫu" ⇒ PSRC-184/185 "Không thể tạo giọng".
const Set<String> vieneuSupportedSampleExtensions = <String>{'.wav'};

/// Tên file dữ liệu giọng hợp lệ (dùng để nhận diện một thư mục giọng).
const Set<String> vieneuVoiceDataFileNames = <String>{
  'ref_codes.txt',
  'speaker.emb.txt',
  'ref_codes.bin',
};

/// Thư mục tạm chứa mẫu thu âm — KHÔNG phải một giọng đã clone.
const String vieneuTempSamplesDirName = '_temp_samples';

/// Có phải file mẫu WAV hợp lệ không? (so sánh không phân biệt hoa/thường)
bool isVieneuVoiceSampleFile(String path) =>
    vieneuSupportedSampleExtensions.contains(p.extension(path).toLowerCase());

/// Có phải tên file dữ liệu giọng không?
bool isVieneuVoiceDataFile(String path) =>
    vieneuVoiceDataFileNames.contains(p.basename(path).toLowerCase());

/// File giọng có nội dung THỰC, không phải placeholder `# VieNeu-TTS default`.
///
/// Native `is_valid_voice_file()` có cùng logic; giữ một bản Dart để engine
/// không liệt kê "giọng ảo" (PSRC-186/187).
bool hasVieneuVoiceData(String content) {
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (trimmed.length > 4) return true;
  }
  return false;
}

/// Chuẩn hoá tên giọng do người dùng nhập thành một tên thư mục an toàn.
///
/// Ngăn `../`, `/`, `\`, ký tự điều khiển và tên quá dài — native dùng
/// `voice_id` làm tên thư mục (PSRC-184). Trả về chuỗi rỗng nếu không dùng được.
String sanitizeVieneuVoiceId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final buffer = StringBuffer();
  for (final rune in trimmed.runes) {
    const forbidden = <int>{
      0x2F, // /
      0x5C, // backslash
      0x3A, // :
      0x2A, // *
      0x3F, // ?
      0x22, // "
      0x3C, // <
      0x3E, // >
      0x7C, // |
    };
    if (rune < 0x20 || forbidden.contains(rune)) {
      buffer.write('_');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  final cleaned = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return '';
  if (cleaned.length <= 64) return cleaned;
  return cleaned.substring(0, 64).trimRight();
}

/// Các thư mục có thể chứa `voices/` đi kèm file GGUF người dùng chọn.
///
/// `file_picker` trên Android/SAF thường trả file đã COPY vào cache của app
/// (`.../cache/file_picker/model.gguf`), nên chỉ dò `dirname(file)/voices`
/// (cách cũ) gần như luôn trượt ⇒ PSRC-186 "không nạp giọng mẫu có sẵn".
/// Dò thêm thư mục cha và chính thư mục chứa GGUF; mỗi ứng viên được kiểm
/// tra lại bằng [isVieneuVoiceDataFile] trước khi copy.
List<String> bundledVoiceDirCandidates(String ggufFilePath) {
  final dir = p.dirname(ggufFilePath);
  final parent = p.dirname(dir);
  final candidates = <String>[
    p.join(dir, 'voices'),
    dir,
    p.join(parent, 'voices'),
    parent,
  ];
  final seen = <String>{};
  final result = <String>[];
  for (final candidate in candidates) {
    final normalized = p.normalize(candidate);
    if (seen.add(normalized)) result.add(normalized);
  }
  return result;
}

/// Đọc `voices/manifest.json` (nếu có trong gói model) → map id → tên hiển thị.
///
/// Chấp nhận 3 dạng nhà phát hành hay dùng; file hỏng/không đúng schema được
/// bỏ qua im lặng để không chặn việc liệt kê giọng (PSRC-186).
Map<String, String> parseVieneuVoiceNames(String jsonText) {
  final names = <String, String>{};
  try {
    final decoded = jsonDecode(jsonText);
    void add(String id, dynamic value) {
      if (id.isEmpty) return;
      if (value is String) {
        if (value.trim().isNotEmpty) names[id] = value.trim();
      } else if (value is Map) {
        final name = value['name'] ?? value['label'] ?? value['displayName'];
        if (name is String && name.trim().isNotEmpty) {
          names[id] = name.trim();
        }
      }
    }

    if (decoded is Map) {
      final voices = decoded['voices'];
      if (voices is Map) {
        voices.forEach((key, value) => add(key.toString(), value));
      } else if (voices is List) {
        for (final entry in voices) {
          if (entry is Map && entry['id'] != null) {
            add(entry['id'].toString(), entry);
          }
        }
      } else {
        decoded.forEach((key, value) {
          if (key.toString() != 'voices') add(key.toString(), value);
        });
      }
    }
  } catch (_) {
    // Manifest không bắt buộc — bỏ qua.
  }
  return names;
}

/// Sinh tên đích không trùng khi copy nhiều mẫu cùng tên từ nhiều thư mục con.
String uniqueVieneuCopyPath(String targetDir, String fileName, int sequence) {
  if (sequence == 0) return p.join(targetDir, fileName);
  final ext = p.extension(fileName);
  final stem = p.basenameWithoutExtension(fileName);
  return p.join(targetDir, '${stem}_$sequence$ext');
}

/// Nhận diện biến thể GGUF từ tên file người dùng chọn (dùng cho import
/// trọn bộ thư mục). Trả null nếu không khớp Q8_0 / bf16.
String? detectVieneuVariantName(String fileName) {
  final lower = p.basename(fileName).toLowerCase();
  if (!lower.endsWith('.gguf')) return null;
  if (lower.contains('bf16') || lower.contains('f16')) return 'bf16';
  if (lower.contains('q8')) return 'q8_0';
  return 'q8_0';
}

// ─── Từ điển phát âm SEA-G2P (ADR-0028, lane L6 — 1.29.0) ──────────────────
//
// VieNeu-TTS **không nhận chữ thô**: model ăn *phoneme* do SEA-G2P sinh ra.
// `sea_g2p.bin` (≈60 MiB) là dữ liệu của SEA-G2P; nó phải nằm CẠNH file GGUF
// (`documents/vieneu_tts/sea_g2p.bin`). Trước 1.29 app không có đường nào đưa
// file này vào ⇒ engine thật sự chạy được nhưng mọi lần đọc đều lỗi
// "missing sea_g2p.bin". Các hằng số dưới đây là một nguồn sự thật duy nhất
// cho cả service tải/xuất-nhập lẫn UI.
//
// Bản ghim khớp tag submodule `third_party/sea-g2p` = v0.10.0 (ADR-0028);
// digest lấy từ GitHub release API của chính tag đó (asset `sea_g2p.bin`).

/// Tên file mà audio.cpp tìm cạnh model (không đổi được — nằm trong native).
const String vieneuG2pDictFileName = 'sea_g2p.bin';

/// Tag SEA-G2P đang ghim (native lib + từ điển phải cùng phiên bản).
const String vieneuG2pReleaseTag = 'v0.10.0';

/// URL tải chính thức (GitHub release của pnnbao97/sea-g2p).
const String vieneuG2pDictDownloadUrl =
    'https://github.com/pnnbao97/sea-g2p/releases/download/v0.10.0/sea_g2p.bin';

/// Kích thước thật của asset v0.10.0 (62.829.820 byte) — dùng để hiện dung
/// lượng và để phát hiện tải hụt.
const int vieneuG2pDictBytes = 62829820;

/// sha256 của asset v0.10.0 — bắt buộc khớp sau khi tải.
const String vieneuG2pDictSha256 =
    '4346e690d0711ebc5231e7a42c5c88aaf6e40377e894b4617c018fd81c6f4096';

/// Ngưỡng "trông giống từ điển thật" cho file do người dùng tự chọn (không có
/// digest để đối chiếu). Nhỏ hơn nhiều so với 60 MiB ⇒ chặn file rỗng, file
/// `.bin` của model khác, và tệp `.txt` đổi tên.
const int vieneuG2pDictMinBytes = 40 * 1024 * 1024;

/// Tên file có phải `sea_g2p.bin` không (không phân biệt hoa/thường).
bool isVieneuG2pDictionaryFile(String path) =>
    p.basename(path).toLowerCase() == vieneuG2pDictFileName;

/// Đường dẫn đích của từ điển trong một thư mục model.
String vieneuG2pDictionaryPath(String modelDir) =>
    p.join(modelDir, vieneuG2pDictFileName);

/// Kích thước có đủ lớn để coi là từ điển SEA-G2P thật không?
bool isPlausibleVieneuG2pDictionarySize(int bytes) =>
    bytes >= vieneuG2pDictMinBytes;

/// Dung lượng hiển thị cho UI, vd `60,0 MB` (dùng dấu phẩy như phần còn lại
/// của app, làm tròn 1 chữ số).
String formatVieneuDictionarySize(int bytes) {
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
}
