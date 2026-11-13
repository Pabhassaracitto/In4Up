// packages/in4up_stt/lib/tts/vieneu_model_files.dart
//
// BETA-1.29.0 · lane L6 (PSRC-214…218) — phần CHẠM ĐĨA của luồng nạp model /
// giọng VieNeu, tách khỏi `vieneu_tts_paths.dart` (thuần logic, không `dart:io`)
// để test đơn vị dựng được thư mục tạm thật mà không cần plugin nào.
//
// Vì sao có file này: trước 1.29 cả ba việc "file này có phải model GGUF",
// "thư mục này có giọng hợp lệ", "embedding clone có phải placeholder" đều
// nằm rải trong `TtsService` / widget, không test được, và mỗi lối import tự
// quyết định — đó là gốc của PSRC-214/215/217/218.

import 'dart:io';

import 'package:path/path.dart' as p;

import 'vieneu_tts_paths.dart';

/// Ảnh chụp một file model trên đĩa.
class VieneuModelReport {
  const VieneuModelReport({
    required this.path,
    required this.bytes,
    required this.problem,
    this.variantName,
  });

  final String path;

  /// Dung lượng thật (0 nếu không đọc được).
  final int bytes;

  /// `null` = tệp dùng được.
  final VieneuModelFileProblem? problem;

  /// Biến thể suy từ CHÍNH tên file (`q8_0` / `bf16`), `null` nếu không rõ.
  final String? variantName;

  bool get ok => problem == null;
}

/// Đọc dung lượng + 4 byte đầu của [path] rồi phân loại bằng
/// [inspectVieneuModelHead]. Không bao giờ ném: tệp không đọc được coi như
/// [VieneuModelFileProblem.empty] để UI nói được lý do thay vì im lặng.
Future<VieneuModelReport> inspectVieneuModelOnDisk(String path) async {
  var bytes = 0;
  final head = <int>[];
  try {
    final file = File(path);
    if (await file.exists()) {
      bytes = await file.length();
      if (bytes > 0) {
        final handle = await file.open();
        try {
          head.addAll(await handle.read(vieneuGgufMagic.length));
        } finally {
          await handle.close();
        }
      }
    }
  } catch (_) {
    // Không đọc được ⇒ coi như rỗng; `problem` sẽ nói rõ.
    bytes = 0;
  }

  return VieneuModelReport(
    path: path,
    bytes: bytes,
    problem: inspectVieneuModelHead(path: path, bytes: bytes, head: head),
    variantName: detectVieneuVariantName(path),
  );
}

/// Thư mục giọng có ít nhất một file dữ liệu CÓ NỘI DUNG THỰC.
///
/// Placeholder `# VieNeu-TTS default` (≈30 byte, toàn comment) KHÔNG tính —
/// native `is_valid_voice_file()` cũng loại nó (PSRC-186/187).
Future<bool> folderHasVieneuVoiceData(Directory folder) async {
  if (!await folder.exists()) return false;
  for (final name in vieneuVoiceDataFileNames) {
    final file = File(p.join(folder.path, name));
    if (!await file.exists()) continue;
    try {
      if (p.extension(name).toLowerCase() == '.bin') {
        if (await file.length() > 32) return true;
      } else if (hasVieneuVoiceData(await file.readAsString())) {
        return true;
      }
    } catch (_) {
      // File nhị phân không đọc được như text nhưng có kích thước hợp lệ.
      try {
        if (await file.length() > 32) return true;
      } catch (_) {}
    }
  }
  return false;
}

/// Liệt kê các THƯ MỤC GIỌNG trong [source]:
///   * chính [source] nếu nó đã là một giọng (có dữ liệu thật);
///   * ngược lại là các thư mục con có dữ liệu thật (bỏ `_temp_samples`, `_*`).
///
/// Ném [VieneuVoiceImportException] `unreadable` khi thư mục không tồn tại
/// hoặc hệ điều hành chặn `list()` (SAF/scoped storage) — đó chính là lý do
/// "import giọng báo lỗi" mà người dùng thấy trước 1.29 (PSRC-217).
Future<List<Directory>> findVieneuVoiceFolders(Directory source) async {
  if (!await source.exists()) {
    throw VieneuVoiceImportException(
      VieneuVoiceImportProblem.unreadable,
      detail: 'không thấy thư mục: ${source.path}',
    );
  }

  final found = <Directory>[];
  try {
    if (await folderHasVieneuVoiceData(source)) return <Directory>[source];
    await for (final entity in source.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      if (id.startsWith('_') || id == vieneuTempSamplesDirName) continue;
      if (await folderHasVieneuVoiceData(entity)) found.add(entity);
    }
  } on FileSystemException catch (e) {
    // Gồm cả PathAccessException (SAF/scoped storage chặn đọc thư mục).
    throw VieneuVoiceImportException(
      VieneuVoiceImportProblem.unreadable,
      detail: e.toString(),
    );
  }

  return found;
}

/// Embedding do `vieneu_tts_clone_voice` tạo có phải PLACEHOLDER toàn số 0?
///
/// Native hiện chỉ ghi embedding thật khi có `libspeaker_encoder.so`; thiếu
/// encoder thì nó ghi 256 số 0 và vẫn trả THÀNH CÔNG. Trước 1.29 UI hiện
/// "Đã tạo giọng" ⇒ người dùng tưởng đã clone được giọng mình (PSRC-218).
/// Hàm này để UI nói đúng: giọng tạo ra nhưng đang dùng embedding tạm.
Future<bool> isPlaceholderVieneuEmbedding(String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) return false;
    final text = await file.readAsString();
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
    if (lines.length < 2) return true;
    final values = lines[1].split(RegExp(r'\s+'));
    if (values.isEmpty) return true;
    for (final value in values) {
      final parsed = double.tryParse(value);
      if (parsed == null) return false;
      if (parsed.abs() > 1e-6) return false;
    }
    return true;
  } catch (_) {
    // Không đọc được ⇒ không kết luận (UI giữ câu thành công trung tính).
    return false;
  }
}

/// Đếm số file WAV trong [folder] (0 nếu không có/không đọc được).
Future<int> countVieneuWavSamples(Directory folder) async {
  if (!await folder.exists()) return 0;
  var count = 0;
  try {
    await for (final entity in folder.list(followLinks: false)) {
      if (entity is File && isVieneuVoiceSampleFile(entity.path)) count++;
    }
  } catch (_) {
    return count;
  }
  return count;
}
