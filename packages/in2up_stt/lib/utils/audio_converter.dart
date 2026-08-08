import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

// FFmpegKit -- native audio conversion backend on Mobile (Android/iOS).
// Does NOT rely on an `ffmpeg` binary in PATH (unlike `Process`).
// `ffmpeg_kit.dart` re-exports `return_code.dart`; we import it explicitly
// too so `ReturnCode` is always available regardless of re-export behavior.
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// Chuyen doi am thanh sang dinh dang Whisper-compatible (PCM 16kHz, mono).
///
/// Backend theo nen tang:
///  - Mobile (Android/iOS): dung [FFmpegKit] (native lib duoc bundle san,
///    khong can cai `ffmpeg` ngoai). Truoc day goi `Process` bi loi
///    `No such file or directory` vi Android khong co binary `ffmpeg`.
///  - Desktop (Windows/macOS/Linux): dung `ffmpeg` qua [Process].
///
/// Xu ly khoang trang trong duong dan (root-cause cua bug cu):
///  - Ten file dau ra duoc [sanitizeFileName] (xoa khoang trang) truoc khi
///    convert -> duong dan sinh ra khong bao gio chua space.
///  - Voi [FFmpegKit] (nhan mot chuoi command nhu go shell), moi duong dan
///    input/output deu duoc boc trong dau ngoac kep de FFmpeg parse dung
///    path co khoang trang.
class AudioConverter {
  /// Chuyen doi tep am thanh dau vao sang tep WAV tam thoi
  /// (PCM 16kHz, mono).
  ///
  /// [inputPath] la duong dan toi tep goc. Tra ve duong da chuyen doi neu
  /// can, hoac [inputPath] neu da dung dinh dang.
  static Future<String?> convertToWhisperCompatible(String inputPath) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw Exception('Tep am thanh khong ton tai: $inputPath');
    }

    // Kiem tra nhanh duoi tep (don gian hoa)
    final ext = path.extension(inputPath).toLowerCase();
    if (ext == '.wav') {
      return inputPath;
    }

    // Tao duong dan tam -- SANITIZE ten file de xoa khoang trang, tranh loi
    // "No such file or directory" khi truyen command cho FFmpegKit.
    final dir = Directory.systemTemp.path;
    final rawName = path.basenameWithoutExtension(inputPath);
    final safeName = sanitizeFileName(rawName);
    final outputPath = path.join(dir, '${safeName}_converted.wav');

    // Build FFmpeg arguments (chung cho ca 2 backend).
    final args = <String>[
      '-i',
      inputPath,
      '-ar',
      '16000',
      '-ac',
      '1',
      '-c:a',
      'pcm_s16le',
      '-y',
      outputPath,
    ];

    if (_useFFmpegKit) {
      await _runFFmpegKit(args);
    } else {
      await _runProcess(args);
    }

    // Dam bao file dau ra thuc su duoc tao ra (bao ve cho ca 2 backend).
    if (!await File(outputPath).exists()) {
      throw Exception(
        'Chuyen doi am thanh that bai: file dau ra khong duoc tao ($outputPath)',
      );
    }

    return outputPath;
  }

  /// Xoa tep tam neu ton tai.
  static Future<void> cleanupConvertedFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists() && filePath.contains('_converted.wav')) {
      await file.delete();
    }
  }

  /// Ước lượng thời lượng file (ms) bằng FFmpeg probe (nhanh, không decode hết).
  static Future<int?> probeDurationMs(String inputPath) async {
    try {
      if (_useFFmpegKit) {
        final session = await FFmpegKit.execute(
          '-i "$inputPath" -f null -',
        );
        final log = await session.getOutput() ?? '';
        final m = RegExp(r'Duration:\s*(\d+):(\d{2}):(\d{2})\.(\d{2})')
            .firstMatch(log);
        if (m != null) {
          final h = int.parse(m.group(1)!);
          final mi = int.parse(m.group(2)!);
          final s = int.parse(m.group(3)!);
          final cs = int.parse(m.group(4)!);
          return ((h * 3600) + (mi * 60) + s) * 1000 + cs * 10;
        }
        return null;
      } else {
        final result = await Process.run(
          'ffmpeg',
          ['-i', inputPath],
          stderrEncoding: systemEncoding,
        );
        final log = result.stderr.toString();
        final m = RegExp(r'Duration:\s*(\d+):(\d{2}):(\d{2})\.(\d{2})')
            .firstMatch(log);
        if (m != null) {
          final h = int.parse(m.group(1)!);
          final mi = int.parse(m.group(2)!);
          final s = int.parse(m.group(3)!);
          final cs = int.parse(m.group(4)!);
          return ((h * 3600) + (mi * 60) + s) * 1000 + cs * 10;
        }
        return null;
      }
    } catch (e) {
      debugPrint('[AudioConverter] probeDurationMs error: $e');
      return null;
    }
  }

  /// Cắt file WAV 16k/mono thành nhiều chunk trong thư mục temp.
  ///
  /// [inputWavPath] phải là WAV đã convert (16kHz, mono). Mỗi chunk dài
  /// [chunkDurationSeconds] giây. Trả về danh sách path + thời lượng ms
  /// (null nếu không probe được duration).
  static Future<({
    List<String> chunkPaths,
    int? durationMs,
  })> splitIntoChunks(
    String inputWavPath, {
    int chunkDurationSeconds = 30,
  }) async {
    final durationMs = await probeDurationMs(inputWavPath);

    final chunkSec = chunkDurationSeconds > 0 ? chunkDurationSeconds : 30;
    final totalSec = durationMs == null
        ? null
        : (durationMs / 1000.0).ceil();

    final chunkCount = totalSec == null
        ? 1
        : ((totalSec + chunkSec - 1) ~/ chunkSec).clamp(1, 1 << 20);

    final dir = Directory.systemTemp.path;
    final baseName = path.basenameWithoutExtension(inputWavPath);
    final chunkPaths = <String>[];

    for (var i = 0; i < chunkCount; i++) {
      final startSec = i * chunkSec;
      final outPath = path.join(dir, '${baseName}_chunk_$i.wav');

      final args = <String>[
        '-ss',
        '$startSec',
        '-i',
        inputWavPath,
        '-t',
        '$chunkSec',
        '-ar',
        '16000',
        '-ac',
        '1',
        '-c:a',
        'pcm_s16le',
        '-y',
        outPath,
      ];

      if (_useFFmpegKit) {
        await _runFFmpegKit(args);
      } else {
        await _runProcess(args);
      }

      if (await File(outPath).exists()) {
        chunkPaths.add(outPath);
      }
    }

    if (chunkPaths.isEmpty) {
      // Fallback: không chia được thì trả chính file gốc làm 1 chunk
      chunkPaths.add(inputWavPath);
    }

    return (chunkPaths: chunkPaths, durationMs: durationMs);
  }

  /// Dọn các file chunk tạm.
  static Future<void> cleanupChunkFiles(List<String> chunkPaths) async {
    for (final p in chunkPaths) {
      try {
        final f = File(p);
        if (await f.exists() && p.contains('_chunk_')) {
          await f.delete();
        }
      } catch (_) {}
    }
  }

  // -- Backend selector ---------------------------------------------------

  /// Mobile = Android/iOS -> FFmpegKit. Con lai (Desktop/Web...) -> Process.
  static bool get _useFFmpegKit =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Chay FFmpeg qua FFmpegKit (Mobile).
  ///
  /// [FFmpegKit.execute] nhan mot chuoi command (nhu go shell), do do moi
  /// duong dan chua khoang trang BAT BUOC duoc boc trong "...".
  static Future<void> _runFFmpegKit(List<String> args) async {
    final command = args.map(_quotePath).join(' ');

    debugPrint('FFmpegKit command: ffmpeg $command');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return; // OK
    }

    if (ReturnCode.isCancel(returnCode)) {
      throw Exception('Chuyen doi am thanh bi huy (FFmpegKit).');
    }

    // Loi -- thu thap log de chan doan.
    final output = (await session.getOutput()) ?? '';
    final failTrace = (await session.getFailStackTrace()) ?? '';
    final code = returnCode?.getValue();
    final codeStr = code == null ? '?' : '$code';
    throw Exception(
      'Chuyen doi am thanh that bai (FFmpegKit) [code=$codeStr]: '
      '$output $failTrace',
    );
  }

  /// Chay FFmpeg qua Process (Desktop). [Process.run] nhan list args, tu xu
  /// ly khoang trang nen KHONG boc ngoac kep (boc se thanh ky tu literal).
  static Future<void> _runProcess(List<String> args) async {
    final result = await Process.run('ffmpeg', args);
    if (result.exitCode != 0) {
      throw Exception('Chuyen doi am thanh that bai: ${result.stderr}');
    }
  }

  // -- Helpers ------------------------------------------------------------

  /// Boc mot doi so trong dau ngoac kep neu no la duong dan (tuc la KHONG
  /// phai flag bat dau bang `-`). Escape an toan ky tu `"` va `\` ben trong.
  static String _quotePath(String arg) {
    if (arg.startsWith('-')) {
      return arg; // flag, giu nguyen
    }
    final escaped = arg.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    return '"$escaped"';
  }

  /// Chuan hoa ten file: XOA khoang trang va cac ky tu co the pha vo command
  /// string cua FFmpegKit (dau ngoac kep, backslash). Giu nguyen ky tu unicode
  /// (tieng Viet) de ten file van co y nghia.
  ///
  /// Vi du: "Bai giang so 1" -> "Bai_giang_so_1".
  static String sanitizeFileName(String name) {
    var safe = name.trim();

    // Xoa ky tu dac biet nguy hiem cho command string.
    safe = safe.replaceAll('"', '').replaceAll('\\', '');

    // XOA moi khoang trang (space / tab / newline) -> '_'.
    safe = safe.replaceAll(RegExp(r'\s+'), '_');

    // Gop nhieu dau `_` lien tiep, cat `_` du o dau/cuoi.
    safe = safe.replaceAll(RegExp(r'_+'), '_');
    safe = safe.replaceAll(RegExp(r'^_+|_+$'), '');

    // Trang tranh ten rong.
    return safe.isEmpty ? 'audio' : safe;
  }
}
