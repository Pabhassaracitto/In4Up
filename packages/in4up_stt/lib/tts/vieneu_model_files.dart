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

import 'dart:convert';
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

/// Số byte tối đa đọc để "ngửi" nội dung một file dữ liệu giọng lạ.
const int vieneuVoiceSniffBytes = 256 * 1024;

/// Đuôi file KHÔNG BAO GIỜ là dữ liệu giọng (bỏ qua khi dò theo nội dung).
const Set<String> vieneuVoiceNonDataExtensions = <String>{
  '.wav',
  '.mp3',
  '.flac',
  '.m4a',
  '.ogg',
  '.opus',
  '.aac',
  '.gguf',
  '.json',
  '.md',
  '.log',
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.zip',
  '.7z',
  '.rar',
};

/// Hai file dữ liệu giọng tìm được trong một thư mục giọng.
class VieneuResolvedVoiceFiles {
  const VieneuResolvedVoiceFiles({
    this.refCodesPath,
    this.speakerEmbeddingPath,
    this.samplePath,
    this.fileNames = const <String>[],
    this.resolvedByContent = false,
  });

  /// Đường dẫn file mã âm thanh (`ref_codes.txt` hoặc tên bất kỳ, đã kiểm nội
  /// dung). `null` = không có.
  final String? refCodesPath;

  /// Đường dẫn embedding giọng 192 chiều. `null` = không có / sai số chiều.
  final String? speakerEmbeddingPath;

  /// Mẫu WAV của giọng (gói giọng upstream: `<Tên>.pt` + `<Tên>.txt` +
  /// `<Tên>.wav`). Không có mã sẵn thì engine mã hoá mẫu này **một lần** bằng
  /// chính đường `encode_reference_only` của tính năng tạo giọng.
  final String? samplePath;

  /// Tên các file trong thư mục (để chẩn đoán khi không dùng được).
  final List<String> fileNames;

  /// `true` nếu phải nhận diện bằng NỘI DUNG (tên file không thuộc bộ chuẩn).
  final bool resolvedByContent;

  /// Dùng được ngay (đã có mã/embedding).
  bool get usable => refCodesPath != null || speakerEmbeddingPath != null;

  /// Thư mục này là một giọng — dù phải mã hoá mẫu WAV trước khi đọc.
  bool get isVoice => usable || samplePath != null;
}

Future<String?> _readTextHead(File file, int maxBytes) async {
  RandomAccessFile? handle;
  try {
    final opened = await file.open();
    handle = opened;
    final length = await opened.length();
    final take = length < maxBytes ? length : maxBytes;
    final bytes = await opened.read(take);
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    return null;
  } finally {
    try {
      await handle?.close();
    } catch (_) {}
  }
}

/// Tìm dữ liệu giọng trong [folder]: **tên chuẩn trước**, rồi mới tới nội dung.
///
/// Vì sao phải dò theo nội dung: mirror cộng đồng của gói VieNeu-TTS đặt tên
/// file khác (`codes.txt`, `embedding.txt`, `ref_codes.csv`…). audio.cpp nhận
/// đường dẫn bất kỳ nên chỉ cần nhận đúng loại là giọng hiện ra và đọc được.
Future<VieneuResolvedVoiceFiles> resolveVieneuVoiceFiles(
    Directory folder) async {
  final names = <String>[];
  final files = <File>[];
  try {
    if (!await folder.exists()) return const VieneuResolvedVoiceFiles();
    await for (final entity in folder.list(followLinks: false)) {
      if (entity is! File) continue;
      names.add(p.basename(entity.path));
      files.add(entity);
    }
  } catch (_) {
    return const VieneuResolvedVoiceFiles();
  }
  names.sort();

  String? refCodesPath;
  String? embeddingPath;
  var byContent = false;

  // 1) Tên chuẩn của gói gốc (giữ nguyên hành vi cũ).
  for (final name in const ['ref_codes.txt', 'ref_codes.bin']) {
    final file = files.where((f) => p.basename(f.path).toLowerCase() == name);
    if (file.isEmpty) continue;
    try {
      if (p.extension(name).toLowerCase() == '.bin') {
        if (await file.first.length() > 32) refCodesPath = file.first.path;
      } else {
        final text = await file.first.readAsString();
        if (hasVieneuVoiceData(text)) refCodesPath = file.first.path;
      }
    } catch (_) {}
    if (refCodesPath != null) break;
  }
  for (final file in files) {
    if (p.basename(file.path).toLowerCase() != 'speaker.emb.txt') continue;
    try {
      if (isUsableVieneuSpeakerEmbedding(await file.readAsString())) {
        embeddingPath = file.path;
      }
    } catch (_) {}
    break;
  }

  // 2) Chưa đủ ⇒ ngửi nội dung các file text còn lại.
  if (refCodesPath == null || embeddingPath == null) {
    for (final file in files) {
      final base = p.basename(file.path).toLowerCase();
      if (base.startsWith('.')) continue;
      if (vieneuVoiceNonDataExtensions.contains(p.extension(base))) continue;
      if (base == 'manifest.json') continue;
      int size;
      try {
        size = await file.length();
      } catch (_) {
        continue;
      }
      if (size < 8 || size > 8 * 1024 * 1024) continue;
      final text = await _readTextHead(file, vieneuVoiceSniffBytes);
      if (text == null || text.isEmpty) continue;
      final kind = classifyVieneuVoiceDataText(text);
      if (kind == VieneuVoiceDataKind.speakerEmbedding && embeddingPath == null) {
        embeddingPath = file.path;
        byContent = true;
      } else if (kind == VieneuVoiceDataKind.refCodes && refCodesPath == null) {
        refCodesPath = file.path;
        byContent = true;
      }
      if (refCodesPath != null && embeddingPath != null) break;
    }
  }

  // 3) Mẫu WAV: giọng đóng gói dạng mẫu âm thanh (upstream: `<Tên>.pt` +
  //    `<Tên>.txt` + `<Tên>.wav`). Engine mã hoá mẫu một lần rồi đọc.
  String? samplePath;
  for (final file in files) {
    if (!isVieneuVoiceSampleFile(file.path)) continue;
    try {
      if (await file.length() > 1024) {
        samplePath = file.path;
        break;
      }
    } catch (_) {}
  }

  return VieneuResolvedVoiceFiles(
    refCodesPath: refCodesPath,
    speakerEmbeddingPath: embeddingPath,
    samplePath: samplePath,
    fileNames: List<String>.unmodifiable(names),
    resolvedByContent: byContent,
  );
}

/// Thư mục giọng có ít nhất một file dữ liệu CÓ NỘI DUNG THỰC.
///
/// Placeholder `# VieNeu-TTS default` (≈30 byte, toàn comment) KHÔNG tính —
/// native `is_valid_voice_file()` cũng loại nó (PSRC-186/187).
Future<bool> folderHasVieneuVoiceData(Directory folder) async =>
    (await resolveVieneuVoiceFiles(folder)).isVoice;

/// Vì sao một thư mục giọng KHÔNG dùng được (dùng cho bảng chẩn đoán trong
/// Cài đặt — người dùng thấy đúng lý do thay vì "giọng tôi import không hiện").
enum VieneuVoiceFolderStatus {
  /// Dùng được ngay (có ref codes hoặc embedding hợp lệ).
  usable,

  /// Chỉ có mẫu WAV — engine mã hoá mẫu khi đọc lần đầu (chậm hơn ~1–3 s).
  sampleOnly,

  /// Thư mục không có file nào.
  emptyFolder,

  /// Có file nhưng không file nào là dữ liệu giọng (ảnh, wav, manifest…).
  noDataFile,

  /// Có file dữ liệu nhưng sai định dạng (vd. embedding không đủ 192 chiều).
  unknownFormat,
}

/// Một dòng của bảng chẩn đoán giọng.
class VieneuVoiceFolderDiagnosis {
  const VieneuVoiceFolderDiagnosis({
    required this.name,
    required this.status,
    required this.fileNames,
    required this.resolvedByContent,
  });

  final String name;
  final VieneuVoiceFolderStatus status;
  final List<String> fileNames;
  final bool resolvedByContent;
}

/// Liệt kê MỌI thư mục con của [parent] kèm lý do dùng được/không.
///
/// Đây là câu trả lời tại chỗ cho "tôi import giọng thành công mà sao không
/// thấy": thay vì đoán, Cài đặt hiển thị đúng đường dẫn gốc, tên từng thư mục,
/// các file bên trong và lý do bị bỏ qua.
Future<List<VieneuVoiceFolderDiagnosis>> diagnoseVieneuVoiceFolders(
    Directory parent) async {
  final result = <VieneuVoiceFolderDiagnosis>[];
  try {
    if (!await parent.exists()) return result;
    await for (final entity in parent.list(followLinks: false)) {
      if (entity is! Directory) continue;
      // `_temp_samples` (mẫu thu âm chưa tạo giọng) và thư mục hệ thống không
      // phải giọng — đừng làm rối bảng chẩn đoán.
      if (p.basename(entity.path).startsWith('_')) continue;
      final resolved = await resolveVieneuVoiceFiles(entity);
      VieneuVoiceFolderStatus status;
      if (resolved.usable) {
        status = VieneuVoiceFolderStatus.usable;
      } else if (resolved.samplePath != null) {
        status = VieneuVoiceFolderStatus.sampleOnly;
      } else if (resolved.fileNames.isEmpty) {
        status = VieneuVoiceFolderStatus.emptyFolder;
      } else if (await _folderHasAnyTextContent(entity)) {
        status = VieneuVoiceFolderStatus.unknownFormat;
      } else {
        status = VieneuVoiceFolderStatus.noDataFile;
      }
      result.add(VieneuVoiceFolderDiagnosis(
        name: p.basename(entity.path),
        status: status,
        fileNames: resolved.fileNames,
        resolvedByContent: resolved.resolvedByContent,
      ));
    }
  } catch (_) {
    // Duyệt lỗi (SAF) ⇒ trả những gì đã thấy.
  }
  result.sort((a, b) => a.name.compareTo(b.name));
  return result;
}

Future<bool> _folderHasAnyTextContent(Directory folder) async {
  try {
    await for (final entity in folder.list(followLinks: false)) {
      if (entity is! File) continue;
      final base = p.basename(entity.path).toLowerCase();
      if (vieneuVoiceNonDataExtensions.contains(p.extension(base))) continue;
      final text = await _readTextHead(entity, 4096);
      if (text == null) continue;
      for (final line in text.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        if (trimmed.length > 4) return true;
      }
    }
  } catch (_) {}
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
